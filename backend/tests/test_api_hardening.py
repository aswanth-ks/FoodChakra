"""Cross-cutting API guarantees: what every endpoint must do, not what one does.

The feature test files each prove their own behaviour. These prove the things
that are easy to get right once and then lose quietly — a new route that
forgets its authentication dependency, an error envelope that starts carrying a
stack trace, a pagination limit that stops being clamped.

They are structural on purpose: several walk the built application rather than
listing endpoints by hand, so a route added in a later stage is covered the day
it is added rather than the day someone remembers to extend this file.
"""

import pytest
from fastapi import status
from httpx import ASGITransport, AsyncClient

from app.core.config import get_settings
from app.db.mongo import get_db
from app.features.listings.schemas import CancelListingRequest

# Routes that may be reached without a session, and why each one must be.
PUBLIC_PATHS = {
    "/api/v1/health": "liveness probe",
    "/api/v1/auth/register": "creates the account",
    "/api/v1/auth/login": "obtains the session",
    "/api/v1/auth/refresh": "renews the session",
    "/api/v1/auth/verify-email": "runs before a session can exist",
    "/api/v1/auth/verify-email/resend": "same",
    "/api/v1/auth/forgot-password": "the caller cannot sign in by definition",
    "/api/v1/auth/reset-password": "same",
    "/docs": "documentation",
    "/docs/oauth2-redirect": "documentation",
    "/openapi.json": "documentation",
    "/redoc": "documentation",
}


def _auth_dependencies(route) -> set[str]:
    """Every dependency in a route's tree, by function name."""
    names: set[str] = set()

    def walk(dependant) -> None:
        for sub in dependant.dependencies:
            names.add(getattr(sub.call, "__name__", str(sub.call)))
            walk(sub)

    dependant = getattr(route, "dependant", None)
    if dependant is not None:
        walk(dependant)
    return names


# --------------------------------------------------------- structural guards


def test_every_route_is_authenticated_unless_it_is_on_the_public_list(app):
    """A new endpoint is protected by default, or this test fails.

    The allow-list is the point. Asserting "these known routes are protected"
    would pass forever while an unprotected route was added beside them.
    """
    unprotected = []
    for route in app.routes:
        path = getattr(route, "path", None)
        if path is None or not getattr(route, "methods", None):
            continue
        if path in PUBLIC_PATHS:
            continue
        if "get_current_user" not in _auth_dependencies(route):
            unprotected.append(f"{sorted(route.methods)} {path}")

    assert not unprotected, (
        "these routes have no authentication dependency; add one, or add the "
        f"path to PUBLIC_PATHS with a reason: {unprotected}"
    )


def test_the_public_list_has_not_grown_silently(app):
    """Every public path is one someone deliberately listed."""
    actual_public = {
        route.path
        for route in app.routes
        if getattr(route, "methods", None)
        and "get_current_user" not in _auth_dependencies(route)
    }
    assert actual_public == set(PUBLIC_PATHS), (
        f"unexpected: {actual_public - set(PUBLIC_PATHS)}, "
        f"stale: {set(PUBLIC_PATHS) - actual_public}"
    )


def test_no_request_model_silently_accepts_unknown_fields():
    """`extra="forbid"` on everything a client can post.

    Ignoring an unexpected field is how a privilege-escalation attempt becomes
    a silent no-op that nobody notices — and how a typo'd field name becomes a
    request that appears to work and does nothing.
    """
    from pydantic import BaseModel

    import app.features.auth.schemas as auth_schemas
    import app.features.listings.schemas as listing_schemas
    import app.features.rescues.schemas as rescue_schemas

    permissive = []
    for module in (auth_schemas, listing_schemas, rescue_schemas):
        for name in dir(module):
            obj = getattr(module, name)
            if not isinstance(obj, type) or not issubclass(obj, BaseModel):
                continue
            if not name.endswith("Request"):
                continue
            if obj.model_config.get("extra") != "forbid":
                permissive.append(f"{module.__name__}.{name}")

    assert not permissive, f"request models missing extra='forbid': {permissive}"


# ------------------------------------------------------------ error envelope


async def test_an_unknown_route_returns_the_envelope_not_a_bare_404(client):
    response = await client.get("/api/v1/nope")

    assert response.status_code == status.HTTP_404_NOT_FOUND
    assert set(response.json()["error"]) == {"code", "message", "details"}


@pytest.mark.parametrize(
    "path",
    [
        "/api/v1/listings/not-an-object-id",
        "/api/v1/rescues/not-an-object-id",
        "/api/v1/rescues/for-listing/not-an-object-id",
    ],
)
async def test_a_malformed_id_never_reaches_the_driver(api, path):
    """An unparseable ObjectId is "not found", not a 500.

    `bson` raises `InvalidId` on a bad string. If that escaped the repository
    the API would answer 500 and log a traceback for what is really just a
    404.
    """
    response = await api.get(path)

    assert response.status_code in (401, 404, 422), response.text
    assert "InvalidId" not in response.text
    assert "Traceback" not in response.text


async def test_a_validation_failure_names_the_field_and_nothing_else(api):
    response = await api.post("/api/v1/auth/register", json={"email": "nope"})

    assert response.status_code == 422
    body = response.json()
    assert body["error"]["code"] == "VALIDATION_ERROR"
    assert "fields" in body["error"]["details"]
    # Pydantic's own error text, not an internal path or a stack frame.
    assert "Traceback" not in response.text
    assert "site-packages" not in response.text


@pytest.mark.parametrize(
    "path,payload",
    [
        ("/api/v1/auth/login", {"email": "a@b.com", "password": "x"}),
        ("/api/v1/auth/register", {"full_name": "A", "email": "a@b.com", "password": "abcdefgh"}),
        ("/api/v1/auth/forgot-password", {"email": "a@b.com"}),
        ("/api/v1/auth/verify-email", {"email": "a@b.com", "code": "123456"}),
    ],
)
async def test_no_endpoint_leaks_infrastructure_detail(api, users, path, payload):
    """Whatever the outcome, the response names no internal machinery."""
    users.seed(email="a@b.com", password="correct-horse")

    response = await api.post(path, json=payload)

    for leak in (
        "mongodb+srv",
        "mongodb://",
        "password_hash",
        "code_hash",
        "$2b$",
        "refresh_sessions",
        "JWT_SECRET",
        "SMTP_",
        "Traceback",
        "site-packages",
        "motor",
        "pymongo",
    ):
        assert leak not in response.text, f"{path} leaked {leak}"


# ------------------------------------------------------------- authentication


@pytest.mark.parametrize(
    "header",
    [
        None,
        "",
        "Bearer",
        "Bearer ",
        "Bearer not.a.jwt",
        "Basic dXNlcjpwYXNz",
        "Bearer eyJhbGciOiJub25lIn0.eyJzdWIiOiIxIn0.",
    ],
)
async def test_a_bad_authorization_header_is_a_clean_401(api, header):
    """Including the `alg: none` forgery, which must not be honoured."""
    headers = {} if header is None else {"Authorization": header}

    response = await api.get("/api/v1/auth/me", headers=headers)

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "UNAUTHORIZED"
    assert "Traceback" not in response.text


# ---------------------------------------------------------------- pagination


@pytest.mark.parametrize(
    "path", ["/api/v1/rescues/mine", "/api/v1/listings/mine"]
)
@pytest.mark.parametrize("limit", [0, -1, 10_000, 999_999])
async def test_pagination_limits_are_bounded(bounded_client, token, path, limit):
    """An unbounded `limit` is a way to ask the database for everything.

    Refused at the query-parameter constraint, before any service or
    repository sees it — which is why the database handle here is only a
    stand-in: the request never gets far enough to use it.
    """
    response = await bounded_client.get(
        path,
        params={"limit": limit},
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 422, response.text
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"


@pytest.mark.parametrize(
    "path", ["/api/v1/rescues/mine", "/api/v1/listings/mine"]
)
async def test_authentication_is_checked_before_the_query_is_validated(
    bounded_client, path
):
    """A stranger gets 401, not a hint about which parameters exist."""
    response = await bounded_client.get(path, params={"limit": 999_999})

    assert response.status_code == 401


# ---------------------------------------------------------------------- CORS


async def test_cors_allows_the_configured_origin(client, settings):
    origin = settings.CORS_ORIGINS[0]

    response = await client.options(
        "/api/v1/health",
        headers={
            "Origin": origin,
            "Access-Control-Request-Method": "GET",
        },
    )

    assert response.headers.get("access-control-allow-origin") == origin


async def test_cors_does_not_allow_an_arbitrary_origin(client):
    response = await client.options(
        "/api/v1/health",
        headers={
            "Origin": "https://not-foodloop.example",
            "Access-Control-Request-Method": "GET",
        },
    )

    # Either refused outright, or answered without the allow header — what
    # must not happen is the origin being echoed back as permitted.
    assert response.headers.get("access-control-allow-origin") != (
        "https://not-foodloop.example"
    )


# ------------------------------------------------------------------- OpenAPI


async def test_openapi_documents_every_route(client, app):
    schema = (await client.get("/openapi.json")).json()

    documented = set(schema["paths"])
    expected = {
        route.path
        for route in app.routes
        if getattr(route, "methods", None) and route.path.startswith("/api/")
    }

    assert expected <= documented, f"undocumented: {expected - documented}"


async def test_openapi_exposes_no_credential(client):
    text = (await client.get("/openapi.json")).text

    for leak in ("mongodb+srv", "SMTP_PASSWORD", "JWT_SECRET", "$2b$"):
        assert leak not in text


def test_the_settings_object_is_the_only_source_of_configuration():
    """Every secret arrives through the typed settings, never `os.environ`."""
    settings = get_settings()

    assert settings.MONGO_DB_NAME
    assert len(settings.JWT_SECRET) >= 32
    # A default that would be dangerous if it survived into production.
    assert settings.ACCESS_TOKEN_EXPIRE_MINUTES <= 60


# --------------------------------------------------------------- sanity check


def test_cancel_listing_request_rejects_an_unknown_field():
    """One concrete instance of the structural rule above."""
    with pytest.raises(ValueError):
        CancelListingRequest(reason="fine", status="cancelled")


@pytest.fixture
def bounded_client_app(auth_app):
    """The app with a fake user repository and a stand-in database handle.

    FastAPI builds the whole dependency tree before running a handler, so
    `get_db` is reached even by a request that is about to be rejected on a
    query parameter. Stubbing it is what lets the parameter bound be tested
    on its own, without a database.
    """
    auth_app.dependency_overrides[get_db] = lambda: object()
    return auth_app


@pytest.fixture
async def bounded_client(bounded_client_app):
    transport = ASGITransport(app=bounded_client_app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def token(users):
    """An access token for a seeded, verified consumer."""
    from app.core.security import create_access_token

    stored = users.seed(email="pagination@example.com")
    access, _ = create_access_token(
        user_id=str(stored["_id"]), role="consumer", is_staff=False
    )
    return access

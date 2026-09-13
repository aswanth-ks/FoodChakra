"""The account-holder's own profile: renaming, and changing a known password.

Both endpoints identify the account from the access token alone. There is no
request shape that names another user, and these tests exist largely to keep
it that way.
"""

from app.core.security import verify_password
from tests.test_auth import auth_header


async def _sign_in(api, users, *, email: str, password: str) -> str:
    users.seed(email=email, password=password)
    login = await api.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    return login.json()["access_token"]


# ------------------------------------------------------------------ renaming


async def test_a_user_can_rename_their_own_account(api, users):
    token = await _sign_in(
        api, users, email="asha@example.com", password="correct-horse"
    )

    response = await api.patch(
        "/api/v1/auth/me",
        json={"full_name": "Asha Rao"},
        headers=auth_header(token),
    )

    assert response.status_code == 200
    assert response.json()["full_name"] == "Asha Rao"


async def test_the_new_name_is_what_me_returns_afterwards(api, users):
    token = await _sign_in(
        api, users, email="asha@example.com", password="correct-horse"
    )
    await api.patch(
        "/api/v1/auth/me",
        json={"full_name": "Asha Rao"},
        headers=auth_header(token),
    )

    response = await api.get("/api/v1/auth/me", headers=auth_header(token))

    # Persisted, not just echoed back by the write.
    assert response.json()["full_name"] == "Asha Rao"


async def test_a_name_is_trimmed(api, users):
    token = await _sign_in(
        api, users, email="asha@example.com", password="correct-horse"
    )

    response = await api.patch(
        "/api/v1/auth/me",
        json={"full_name": "  Asha Rao  "},
        headers=auth_header(token),
    )

    assert response.json()["full_name"] == "Asha Rao"


async def test_a_blank_name_is_refused(api, users):
    token = await _sign_in(
        api, users, email="asha@example.com", password="correct-horse"
    )

    for blank in ["", "   ", "\t"]:
        response = await api.patch(
            "/api/v1/auth/me",
            json={"full_name": blank},
            headers=auth_header(token),
        )
        assert response.status_code == 422


async def test_an_absurdly_long_name_is_refused(api, users):
    token = await _sign_in(
        api, users, email="asha@example.com", password="correct-horse"
    )

    response = await api.patch(
        "/api/v1/auth/me",
        json={"full_name": "a" * 121},
        headers=auth_header(token),
    )

    assert response.status_code == 422


async def test_renaming_requires_a_session(api, users):
    users.seed(email="asha@example.com", password="correct-horse")

    response = await api.patch(
        "/api/v1/auth/me", json={"full_name": "Somebody Else"}
    )

    assert response.status_code == 401


async def test_a_user_cannot_rename_another_account(api, users):
    victim = users.seed(email="victim@example.com", password="correct-horse")
    token = await _sign_in(
        api, users, email="attacker@example.com", password="correct-horse"
    )

    # The obvious attempt: name the other account in the body. `extra="forbid"`
    # refuses it outright, which is the point — there is no field to smuggle an
    # id through, so ownership can never be taken from the request.
    response = await api.patch(
        "/api/v1/auth/me",
        json={"full_name": "Renamed", "user_id": str(victim["_id"])},
        headers=auth_header(token),
    )

    assert response.status_code == 422
    assert victim["full_name"] == "Seeded User"


async def test_role_and_status_cannot_be_changed_through_the_profile(api, users):
    token = await _sign_in(
        api, users, email="asha@example.com", password="correct-horse"
    )

    for field, value in [
        ("role", "partner"),
        ("status", "suspended"),
        ("email", "other@example.com"),
        ("is_staff", True),
        ("email_verified", True),
        ("partner_id", "507f1f77bcf86cd799439011"),
    ]:
        response = await api.patch(
            "/api/v1/auth/me",
            json={"full_name": "Asha Rao", field: value},
            headers=auth_header(token),
        )
        assert response.status_code == 422, field


# ---------------------------------------------------------- password change


async def test_a_user_can_change_their_password(api, users):
    token = await _sign_in(
        api, users, email="asha@example.com", password="correct-horse"
    )

    response = await api.post(
        "/api/v1/auth/change-password",
        json={
            "current_password": "correct-horse",
            "new_password": "battery-staple-9",
        },
        headers=auth_header(token),
    )

    assert response.status_code == 204
    stored = await users.find_by_email("asha@example.com")
    assert verify_password("battery-staple-9", stored["password_hash"])


async def test_the_new_password_is_what_login_accepts(api, users):
    token = await _sign_in(
        api, users, email="asha@example.com", password="correct-horse"
    )
    await api.post(
        "/api/v1/auth/change-password",
        json={
            "current_password": "correct-horse",
            "new_password": "battery-staple-9",
        },
        headers=auth_header(token),
    )

    old = await api.post(
        "/api/v1/auth/login",
        json={"email": "asha@example.com", "password": "correct-horse"},
    )
    new = await api.post(
        "/api/v1/auth/login",
        json={"email": "asha@example.com", "password": "battery-staple-9"},
    )

    assert old.status_code == 401
    assert new.status_code == 200


async def test_a_wrong_current_password_is_refused(api, users):
    token = await _sign_in(
        api, users, email="asha@example.com", password="correct-horse"
    )

    response = await api.post(
        "/api/v1/auth/change-password",
        json={
            "current_password": "not-my-password",
            "new_password": "battery-staple-9",
        },
        headers=auth_header(token),
    )

    assert response.status_code == 401
    # Nothing changed.
    stored = await users.find_by_email("asha@example.com")
    assert verify_password("correct-horse", stored["password_hash"])


async def test_changing_the_password_signs_every_device_out(api, users):
    users.seed(email="asha@example.com", password="correct-horse")
    first = await api.post(
        "/api/v1/auth/login",
        json={"email": "asha@example.com", "password": "correct-horse"},
    )
    second = await api.post(
        "/api/v1/auth/login",
        json={"email": "asha@example.com", "password": "correct-horse"},
    )
    other_device_refresh = second.json()["refresh_token"]

    await api.post(
        "/api/v1/auth/change-password",
        json={
            "current_password": "correct-horse",
            "new_password": "battery-staple-9",
        },
        headers=auth_header(first.json()["access_token"]),
    )

    # A change that left a thirty-day session alive on another device would
    # not actually lock anybody out.
    replay = await api.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": other_device_refresh},
    )
    assert replay.status_code == 401


async def test_a_weak_new_password_is_refused(api, users):
    token = await _sign_in(
        api, users, email="asha@example.com", password="correct-horse"
    )

    response = await api.post(
        "/api/v1/auth/change-password",
        json={"current_password": "correct-horse", "new_password": "short"},
        headers=auth_header(token),
    )

    assert response.status_code == 422


async def test_reusing_the_same_password_is_refused(api, users):
    token = await _sign_in(
        api, users, email="asha@example.com", password="correct-horse"
    )

    response = await api.post(
        "/api/v1/auth/change-password",
        json={
            "current_password": "correct-horse",
            "new_password": "correct-horse",
        },
        headers=auth_header(token),
    )

    assert response.status_code == 422


async def test_changing_a_password_requires_a_session(api, users):
    users.seed(email="asha@example.com", password="correct-horse")

    response = await api.post(
        "/api/v1/auth/change-password",
        json={
            "current_password": "correct-horse",
            "new_password": "battery-staple-9",
        },
    )

    assert response.status_code == 401
    stored = await users.find_by_email("asha@example.com")
    assert verify_password("correct-horse", stored["password_hash"])


async def test_a_password_is_never_echoed_back(api, users):
    token = await _sign_in(
        api, users, email="asha@example.com", password="correct-horse"
    )

    changed = await api.post(
        "/api/v1/auth/change-password",
        json={
            "current_password": "correct-horse",
            "new_password": "battery-staple-9",
        },
        headers=auth_header(token),
    )
    profile = await api.get("/api/v1/auth/me", headers=auth_header(token))

    assert changed.content in (b"", None)
    body = profile.text
    for secret in ["correct-horse", "battery-staple-9", "password_hash"]:
        assert secret not in body

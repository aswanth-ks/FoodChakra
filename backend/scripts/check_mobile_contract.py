"""Match every endpoint the Flutter app calls against the built FastAPI app.

    python -m scripts.check_mobile_contract

The two halves of FoodLoop are written in different languages and share no
generated client, so nothing but a check like this notices when a path is
renamed on one side. A mobile call to a route that does not exist is a 404 the
user sees as "something went wrong", and it will not show up in either test
suite — the Flutter tests use fakes and the backend tests never read Dart.

Exits non-zero when the app calls something the API does not serve. Routes the
app does not call are reported but are not a failure: the operations console
and future stages legitimately use endpoints the phone does not.
"""

import re
import sys
from pathlib import Path

from app.main import create_app

MOBILE_LIB = Path(__file__).resolve().parent.parent.parent / "mobile" / "lib"

#: `dio.post<Map<String, dynamic>>('/auth/login', ...)` and friends.
#:
#: The type argument is optional and may itself contain `>` — `<Map<String,
#: dynamic>>` is the common case — so it is matched up to the opening bracket
#: rather than with a naive `[^>]*`, which stops at the first inner `>` and
#: silently matches almost nothing.
_CALL = re.compile(
    r"\.(get|post|put|patch|delete)\s*(?:<[^(]*?>)?\s*\(\s*'([^']+)'",
    re.S,
)

#: `$rescueId` / `${listing.id}` — any Dart interpolation is a path parameter.
_INTERPOLATION = re.compile(r"\$\{?[A-Za-z_][A-Za-z0-9_.]*\}?")

#: `{listing_id}` and `{rescue_id}` differ in name but not in shape.
_PATH_PARAM = re.compile(r"\{[^}]+\}")

#: A path literal anywhere in the file, for calls routed through a helper —
#: `_post('/auth/register', body)` carries no method at the call site.
_ENDPOINT_LITERAL = re.compile(
    r"'(/(?:auth|listings|rescues|health)[A-Za-z0-9/${}._-]*)'"
)


def backend_routes() -> set[tuple[str, str]]:
    app = create_app()
    routes: set[tuple[str, str]] = set()
    for route in app.routes:
        methods = getattr(route, "methods", None)
        if not methods or not route.path.startswith("/api/"):
            continue
        for method in methods - {"HEAD", "OPTIONS"}:
            routes.add((method, _PATH_PARAM.sub("{}", route.path)))
    return routes


def mobile_calls(prefix: str) -> tuple[set[tuple[str, str]], set[str]]:
    """Endpoints the app calls, plus every endpoint path literal it contains.

    Two passes, because the repositories use both styles. A direct call gives
    a method and a path. A path handed to a private helper gives only a path,
    so it can be matched on path alone — reporting those separately keeps the
    method matching in the first group honest about what it actually proved.
    """
    calls: set[tuple[str, str]] = set()
    literals: set[str] = set()

    for file in MOBILE_LIB.rglob("*.dart"):
        text = file.read_text(encoding="utf-8", errors="ignore")
        for method, url in _CALL.findall(text):
            if url.startswith("/"):
                calls.add((method.upper(), prefix + _INTERPOLATION.sub("{}", url)))
        for url in _ENDPOINT_LITERAL.findall(text):
            literals.add(prefix + _INTERPOLATION.sub("{}", url))

    return calls, literals


def main() -> int:
    if not MOBILE_LIB.is_dir():
        print(f"mobile sources not found at {MOBILE_LIB}")
        return 2

    backend = backend_routes()
    backend_paths = {path for _, path in backend}
    # The mobile client's base URL already carries the version prefix, so its
    # paths are relative to it.
    mobile, literals = mobile_calls("/api/v1")

    missing = sorted(mobile - backend)
    matched = sorted(mobile & backend)

    matched_paths = {path for _, path in matched}
    helper_matched = sorted(
        p for p in literals if p in backend_paths and p not in matched_paths
    )
    helper_missing = sorted(p for p in literals if p not in backend_paths)

    uncalled = sorted(
        (m, p) for m, p in backend if (m, p) not in mobile and p not in literals
    )

    print(f"backend routes       : {len(backend)}")
    print(f"matched with method  : {len(matched)}")
    print(f"matched by path only : {len(helper_matched)}\n")

    for method, path in matched:
        print(f"  ok   {method:6} {path}")
    for path in helper_matched:
        print(f"  ok   {'(any)':6} {path}   called through a helper")

    if uncalled:
        print("\nserved but not called by mobile (not a failure):")
        for method, path in uncalled:
            print(f"  --   {method:6} {path}")

    if missing or helper_missing:
        print("\nCALLED BY MOBILE WITH NO MATCHING ROUTE:")
        for method, path in missing:
            print(f"  !!   {method:6} {path}")
        for path in helper_missing:
            print(f"  !!   {'(any)':6} {path}")
        return 1

    print("\nEvery mobile endpoint has a matching backend route.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

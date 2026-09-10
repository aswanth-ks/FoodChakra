# FoodLoop — Architecture

This document is the technical contract. Changing anything here requires an ADR in
`docs/adr/` explaining why.

---

## 1. Guiding principles

1. Prefer simplicity over cleverness.
2. Prefer maintainability over premature optimization.
3. Prefer established patterns over invented ones.
4. Avoid premature AI/ML, microservices, and dependencies.
5. FoodLoop is a **modular monolith** that could later be split — not a distributed system today.

---

## 2. Backend architecture (FastAPI)

### 2.1 The mandatory layering

```text
Router      HTTP concerns only. Wires dependencies, returns the service result.
   |        No business logic. No database access.
   v
Schema      Pydantic request/response models. The wire contract.
   |
   v
Service     ALL business logic. Owns rules, validation beyond types,
   |        orchestration, and raises AppError subclasses.
   v
Repository  The ONLY layer permitted to import or call the MongoDB driver.
   |        Returns plain dicts or domain models — never a Motor cursor.
   v
MongoDB
```

**Enforcement:** a route that imports `motor` or calls `db.<collection>` is a defect and must
be rejected in review. `app/features/health/` is the reference implementation — copy its shape.

### 2.2 Feature module layout

Every feature is a self-contained folder:

```text
app/features/donations/
├── __init__.py
├── router.py        endpoints + dependency wiring
├── schemas.py       Pydantic request/response models
├── service.py       business logic
├── repository.py    MongoDB access
└── models.py        internal domain models (optional)
```

Adding a feature is two steps: create the folder, add one `include_router` line to
`app/api/v1/router.py`.

### 2.3 Dependency injection

- `get_settings()` — cached settings singleton (`app/core/config.py`).
- `get_db()` — the shared Motor database handle (`app/db/mongo.py`).
- `get_<feature>_service()` — defined in the feature router; builds the service from its
  repository. This is the seam tests override.

Repositories **receive** a database handle. They never construct a client.

### 2.4 Configuration

All configuration is typed in `Settings` and loaded from the environment or `backend/.env`.

- No secret is ever written into tracked source.
- `backend/.env` is git-ignored; `backend/.env.example` documents every required key.
- `CORS_ORIGINS` is annotated `NoDecode` so it accepts a plain comma-separated string
  rather than requiring JSON.

### 2.5 Error model

One envelope for every error the API returns:

```json
{ "error": { "code": "VALIDATION_ERROR", "message": "...", "details": {} } }
```

Services raise `AppError` subclasses (`NotFoundError`, `ConflictError`, `ForbiddenError`, …).
Handlers in `app/core/exceptions.py` serialize them. Routers do not build `HTTPException`s
by hand.

| Exception | Status | Code |
|---|---|---|
| `UnauthorizedError` | 401 | `UNAUTHORIZED` |
| `ForbiddenError` | 403 | `FORBIDDEN` |
| `NotFoundError` | 404 | `NOT_FOUND` |
| `ConflictError` | 409 | `CONFLICT` |
| `ValidationError` | 422 | `VALIDATION_ERROR` |
| `ServiceUnavailableError` | 503 | `SERVICE_UNAVAILABLE` |

### 2.6 Startup and shutdown

The FastAPI `lifespan` opens the Motor client, runs `ensure_indexes()`, and closes the client
on shutdown.

**Deliberate decision:** an unreachable database does **not** crash startup. `/api/v1/health`
must stay reachable so the failure is observable rather than invisible — it reports
`status: "degraded"` instead.

### 2.7 The canonical lifecycle (Stage B)

`app/shared/lifecycle.py` holds **the** state machine. There is exactly one.

The audit found three lifecycle enums already in the codebase — the console's nine
`LifecycleStep`s, mobile's five `RescueStage`s, partner's six `PartnerSurplusStatus`es. They
describe one journey at three levels of detail. The backend stores the **widest** (the
console's) and narrows it for the other clients through pure functions in the same module.

- `LifecycleState` — all thirteen states. Wire values use the console's exact spelling
  (`"onTheWay"`), so the dashboard's TypeScript unions parse responses untranslated.
- `LISTING_STATES` / `RESCUE_STATES` — which subset each document may hold. Ownership of the
  journey passes from the listing to the rescue at `matched`.
- `LISTING_TRANSITIONS` / `RESCUE_TRANSITIONS` + `can_transition()` — legality lives here, not
  in each service, so the rules cannot diverge per feature.
- `to_rescue_stage()` / `to_partner_status()` — the client projections.

**Rule:** no feature module may define its own status enum. Adding a state is an edit to this
one file, and `tests/test_lifecycle.py` fails loudly if a new state is left out of the
listing/rescue split or of a client projection.

### 2.8 Collections, indexes and the claim race (Stage B)

`app/db/collections.py` names the ten collections; `app/db/indexes.py` declares every index and
creates them idempotently in the lifespan. Repositories import the name constants rather than
writing string literals — MongoDB silently creates `db.listing` for a typo and then returns
nothing forever.

Two index categories carry real weight:

- **`2dsphere`** — Explore is a `$near` and the dynamic radius is a `$geoWithin`. Without these
  the features cannot be written at all, not merely written slowly.
- **`uniq_active_rescue_per_listing`** — a *partial* unique index on `rescues.listing_id`
  filtered to non-terminal statuses. This is the only correct place to enforce "one active
  rescue per listing": a check-then-insert in the service loses the race when two consumers tap
  Rescue within the same few milliseconds, and the window is small enough to pass every manual
  test before failing in production. The filter is partial rather than plain-unique so that a
  cancelled rescue frees its listing instead of burning the surplus permanently. Its state list
  is derived from `RESCUE_ACTIVE_STATES`, so it cannot fall behind the lifecycle.

Stage E completes the pair with an atomic `find_one_and_update` on the listing. The loser gets a
duplicate-key error, which the repository translates to `ConflictError` -> `409`.

`ensure_indexes()` pings once before creating anything: each `create_indexes` against an
unreachable server blocks for the full server-selection timeout, and ten of those would stall
startup behind an outage that `/health` exists to report.

### 2.9 Activity events (Stage B)

`app/features/activity/` is the append-only audit trail. One collection serves the console's
Activity Log, the Analytics aggregations, and (much later) Predictive Demand's input — which is
why it is captured from day one: reconstructing this history retroactively is impossible.

`ActivityService.record()` **never raises**. A failed audit write must not roll back the
operation that triggered it; losing a log line is bad, making the audit collection a single
point of failure for every rescue is worse. That trade-off holds only while nothing reads
`activity_events` to make a decision — if anything ever does, revisit it.

The feature has no router. Nothing is exposed over HTTP until the ops console needs it (Stage H).

### 2.10 Authentication and authorization (Stage C)

`app/core/security.py` is the only module that imports `bcrypt` or `jwt`. Everything else goes
through `app/features/auth/`.

**Roles vs. staff access.** `AccountRole` has exactly two values — `consumer` and `partner` —
because the product has two account kinds. Operations access is **not** a third role: it is an
optional `staff` capability on the user document, checked by `require_staff`. Role answers
"what kind of account is this"; staff answers "may they open the console". They are unrelated
questions, and an operator may well also hold a consumer account — collapsing both onto one
field forces a false choice and is how privilege bugs start. This supersedes the `ops_admin`
role sketched in `BACKEND_CONTRACT.md` §6.

**The client is never trusted.** `RegisterRequest` has no `role`, `status`, `staff` or
`partner_id` field and is `extra="forbid"`, so an escalation attempt is a `422`, not a silent
downgrade. Public registration hardcodes an active consumer.

**Tokens assert identity, the database decides permission.** `get_current_user` re-reads the
user record on every request rather than trusting the token's role claim. That costs one
indexed lookup and makes a suspension or role change effective immediately instead of lingering
for up to the access token's lifetime. Refresh tokens deliberately carry no role at all: they
outlive role changes.

**Refresh rotation is single-use.** The jti is consumed with an atomic `$pull`, which is the
check — a replayed token finds nothing to consume, and the response is to revoke every session
on the account, since replay means the token was captured. Sessions are embedded on the user
document (capped, always read with their user), so no eleventh collection was needed.

**Authorization lives in dependencies**, never in route bodies: `get_current_user`,
`require_consumer`, `require_partner`, `require_staff`. A route declares its requirement in its
signature and so cannot forget the check.

**Deleted on the client:** `roleForEmail()`. An email domain is not an authorization, and a
client-side check is bypassed by typing a different address. The Flutter app now learns its
role from `/auth/me` only — `mobile/test/account_role_test.dart` stands guard over that.

---

## 3. Mobile architecture (Flutter)

### 3.1 Feature layering

```text
lib/features/<feature>/
├── domain/          Pure Dart. Entities + repository interfaces.
│                    No Flutter, no JSON, no Dio.
├── data/            DTOs (own fromJson), remote sources,
│                    repository implementations.
└── presentation/    Riverpod providers, screens, feature-local widgets.
```

Dependencies point **inward**: `presentation -> domain <- data`. The presentation layer
depends on the repository *interface*, never the implementation — which is what makes the
widget tests run with zero HTTP.

### 3.2 State management — Riverpod

- `Provider` — dependency injection (`dioProvider`, `healthRepositoryProvider`).
- `FutureProvider` / `AsyncNotifierProvider` — async screen state.
- `AsyncValue.when(loading:, error:, data:)` maps directly onto the four required UI states.

Business logic lives in notifiers and repositories, **never in a widget's `build`**.

### 3.3 Networking

A single `Dio` instance from `dioProvider`. Configured once with base URL, timeouts, and
interceptors:

- `ErrorInterceptor` — converts every `DioException` into a domain `Failure`.
- `LogInterceptor` — debug builds only.
- `AuthInterceptor` — Phase 3; attaches the bearer token and refreshes on 401.

Widgets never see a `DioException`. They see a `Failure`, which carries a user-safe message.

### 3.4 Configuration

`lib/core/config/env.dart` reads compile-time values via `String.fromEnvironment`, injected
with `--dart-define`. There are **no hardcoded URLs anywhere else in the app**.

Note: Android emulators must use `http://10.0.2.2:8000`, not `localhost`.

### 3.5 Theming

`lib/app/theme/` holds `AppColors`, `AppSpacing`, `AppRadius`, and `AppTheme`. Widgets read
styling from `Theme.of(context)` or these tokens — never raw `Color(0x…)` literals. This makes
adopting the exact Stitch palette a one-file change.

Current token values are **placeholders** pending the approved designs.

### 3.6 Routing

`go_router`, configured in `lib/app/router.dart`. Paths are constants on `AppRoutes`; screens
never navigate with string literals. Phase 3 adds a role-aware `redirect` guard.

### 3.7 The four UI states

`lib/shared/widgets/` provides `LoaderView`, `EmptyStateView`, and `ErrorStateView`. These
were built in Phase 0 **on purpose**: retrofitting state handling across thirty screens does
not happen in practice, so the scaffolding exists before the first real screen.

An empty result is not an error. It gets its own state.

---

## 4. Dashboard architecture (React)

Architecturally separate from the mobile app; same `/api/v1` backend.

- **TanStack Query** owns all server state — no manual loading booleans.
- `src/lib/api/client.ts` is the single fetch wrapper. It parses the shared error envelope
  into a typed `ApiError`.
- Base URL comes from `VITE_API_BASE_URL`.

---

## 5. Data flow, end to end

```text
User taps "Create donation"
   -> Screen calls a Riverpod notifier
   -> Notifier calls DonationRepository (interface)
   -> DonationRepositoryImpl serializes a DTO and POSTs via Dio
   -> FastAPI router validates against a Pydantic schema
   -> DonationService applies business rules
   -> DonationRepository writes to MongoDB
   <- response flows back, DTO -> entity -> AsyncValue.data -> UI
```

Any error at any layer surfaces as a `Failure` and renders through `ErrorStateView`.

---

## 6. Testing strategy

| Layer | Approach |
|---|---|
| Backend unit | Fake the repository, test the service in isolation |
| Backend API | `httpx.AsyncClient` + `ASGITransport`, override the service dependency |
| Flutter widget | Override the repository provider with a fake — no HTTP |
| Flutter unit | Plain Dart tests for DTO parsing and domain logic |
| Integration | Phase 15 — real backend, real database, full journeys |

**Tests must not require a running MongoDB.** This is only possible because the layering
forbids routes from touching the driver directly — the fake slots in at the repository seam.

---

## 7. Security posture (hardened in Phase 17)

Already in place:

- Secrets only in git-ignored `.env` files; `.gitignore` blocks `**/.env`, keystores, and
  service-account JSON.
- Typed settings — a missing `MONGO_URI` or short `JWT_SECRET` fails fast at startup.
- CORS restricted to an explicit origin allowlist.
- Errors never leak stack traces to clients.

Phase 3 adds bcrypt password hashing and JWT access/refresh tokens with a role claim.
Phase 17 adds rate limiting, upload validation, input sanitization, and an audit trail.

---

## Live verification (Stage K)

`backend/scripts/live_atlas_smoke_test.py` exercises the real services against the real Atlas
cluster and a real uvicorn process:

```bash
cd backend
python -m scripts.live_atlas_smoke_test
```

It is **not** part of `pytest`, and must not become part of it. The unit suite has to keep
running for someone with no Atlas credentials and no SMTP account, and a test suite that needs
a live cluster stops being run.

What it adds over the unit tests is the part that fakes cannot answer: whether MongoDB itself
applies the conditional updates, whether the partial unique index actually refuses a second
active rescue, and whether documents survive the process that wrote them.

Safety rules it follows, and that any future live script must follow too:

- Every document it creates is recorded and deleted by `_id` in a `finally`. It never deletes
  by query, so a bug in it cannot reach a document it did not create.
- Temporary accounts use a unique `+tag` on the configured sending address, so they cannot
  collide with a real user and are obvious in the Atlas UI.
- Nothing it prints is a credential — not a password, a one-time code, a handover code, a
  token, an SMTP setting or a connection string. Codes are captured in memory to drive the
  flow and compared, never displayed.

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

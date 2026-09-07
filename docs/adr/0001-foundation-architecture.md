# ADR 0001 — Foundation Architecture

**Status:** Accepted
**Date:** 2026-09-07

## Context

FoodLoop was starting from an empty repository. Decisions made now determine how easily the
system reaches its eventual scope: matching, rescue escalation, geospatial search, a fallback
network, predictive demand, and a separate operations dashboard.

## Decisions

### 1. Monorepo with three workspaces

`mobile/`, `backend/`, `dashboard/`, plus shared `docs/`.

The API contract is the coupling point between all three. A single repository keeps a
contract change and its two client updates in one commit.

### 2. Modular monolith, not microservices

Feature-first modules on both ends, isolated well enough to extract later. Microservices
would add distributed-systems cost long before there is scale to justify it.

### 3. Riverpod for Flutter state

`AsyncValue` maps exactly onto the four required UI states (loading, data, error, and empty
via a data check). Compile-safe dependency injection, and providers can be overridden in
tests without a widget tree — which is how the health screen is tested with zero HTTP.

Rejected: BLoC (three files per screen of boilerplate); Provider/ChangeNotifier (does not
scale to live rescue and map state).

### 4. MongoDB Atlas over local MongoDB

FoodLoop's core algorithm — the dynamic rescue radius — is a geospatial query. Atlas provides
`2dsphere` indexes with `$near` and `$geoWithin`, no local install, and the same connection
string shape as production. `mongosh` was not installed locally and Docker Desktop was not
running.

### 5. React + Vite + TypeScript for the dashboard

Dense admin tables, charts, and live maps are where React's ecosystem is strongest
(TanStack Table/Query, Recharts). Flutter Web was rejected: weak for data-dense admin UI and
a heavy initial bundle, despite the appeal of sharing Dart models.

### 6. Strict backend layering

`Router -> Schema -> Service -> Repository -> MongoDB`, with the repository as the only layer
permitted to touch the driver.

This is what makes the system testable without a running database: fakes slot in at the
repository seam. `app/features/health/` is the reference implementation.

### 7. Async driver (Motor), not pymongo

FoodLoop is I/O-bound coordination work — many concurrent geospatial lookups and
notifications. Blocking the event loop on database calls would negate FastAPI's concurrency.

### 8. One error envelope

`{"error": {"code", "message", "details"}}` for every failure. Two clients in two languages
parse errors; one shape means one parser each.

### 9. State widgets built in Phase 0

`LoaderView`, `EmptyStateView`, and `ErrorStateView` exist before the first real screen.
Retrofitting state handling across thirty screens does not happen in practice.

### 10. Compile-time config via `--dart-define`

No hardcoded URLs or secrets. Chosen over `flutter_dotenv` because it needs no asset bundling
and works identically on web and mobile — so that dependency was removed.

### 11. An unreachable database does not crash startup

`/api/v1/health` returns 200 with `status: "degraded"`, so the failure is observable.
A crash-on-boot would make the outage invisible to monitoring.

## Consequences

**Positive:** all three workspaces build and are tested independently; tests need no
database; swapping the Stitch palette is a one-file change; features are added by copying one
folder shape.

**Negative:** the layering is more files per feature than putting queries in routes — this is
the deliberate trade for testability. Riverpod and TanStack Query are both learning curves.

**Revisit if:** rescue coordination needs real-time push at a scale HTTP polling cannot serve
(consider WebSockets or MongoDB change streams), or a single feature module outgrows the
monolith.

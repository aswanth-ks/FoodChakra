# FoodLoop — API Contract

Base URL: `{API_BASE_URL}/api/v1`
Interactive docs: `{API_BASE_URL}/docs`

This document grows as features are implemented. Every endpoint is documented here **when it
is built**, not after.

---

## Conventions

### Versioning

All endpoints live under `/api/v1/`. Breaking changes require `/api/v2/`.

### Error envelope

Every error response — expected or not — uses one shape:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The submitted data is invalid.",
    "details": { "fields": [] }
  }
}
```

| Status | Code | Meaning |
|---|---|---|
| 401 | `UNAUTHORIZED` | Missing, invalid, or expired credentials |
| 403 | `FORBIDDEN` | Authenticated but not permitted |
| 404 | `NOT_FOUND` | Resource does not exist |
| 409 | `CONFLICT` | Conflicting state (e.g. donation already claimed) |
| 422 | `VALIDATION_ERROR` | Field validation failed; `details.fields` lists them |
| 500 | `INTERNAL_ERROR` | Unhandled server error |
| 503 | `SERVICE_UNAVAILABLE` | A required dependency is down |

### Authentication (from Phase 3)

`Authorization: Bearer <access_token>`

Roles: `donor`, `receiver`, `volunteer`, `ops_admin`.

---

## Implemented endpoints

### `GET /api/v1/health`

Liveness and MongoDB connectivity. Public — no authentication.

**200 OK**

```json
{
  "status": "ok",
  "app": "FoodLoop API",
  "environment": "local",
  "database": { "connected": true, "version": "8.0.0", "error": null }
}
```

`status` is `"degraded"` when the database is unreachable. The endpoint still returns **200**
so monitoring can distinguish "API is down" from "API is up, database is down"; inspect
`database.connected` and `database.error`.

---

## Planned endpoints

Documented here as they are built.

| Phase | Prefix | Purpose |
|---|---|---|
| 3 | `/auth` | register, login, refresh, logout, verify, password reset |
| 3 | `/users` | profile, role, organization |
| 5 | `/donations` | create, list, detail, update, cancel, history |
| 6 | `/requests` | browse, search, filter, request, track, confirm receipt |
| 7 | `/rescues` | opportunities, accept, pickup, deliver, history |
| 8 | `/matches` | candidate receivers and volunteers for a donation |
| 10 | `/fallback` | fallback cases, partners, transfers |
| 12 | `/notifications` | list, mark read, register push token |
| 14 | `/ops` | dashboard metrics, live operations, escalations |

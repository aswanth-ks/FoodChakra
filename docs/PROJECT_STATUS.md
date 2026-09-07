# FoodLoop — Project Status

**Last updated:** 2026-09-07 (Stitch MCP connected)
**Current phase:** Phase 2 — Database Design (not started)
**Phases complete:** 0 (Foundation), 1 (Architecture)

---

## 1. Where we are

Phases 0 and 1 are complete. The repository is a working monorepo with three buildable
workspaces and a verified end-to-end request path. No product feature has been implemented
yet — this is deliberate, per the development contract.

---

## 2. Completed

### Phase 0 — Foundation

| Item | Status | Evidence |
|---|---|---|
| Git repository initialised (`main`) | Done | `git log` |
| Root `.gitignore` / `.editorconfig` | Done | `.env` confirmed ignored |
| FastAPI project + venv | Done | `uvicorn` boots clean |
| Typed configuration from `.env` | Done | `app/core/config.py` |
| MongoDB connection lifecycle | Done | `app/db/mongo.py` |
| Global error envelope | Done | verified `404` returns the envelope |
| `/api/v1/health` reference slice | Done | full Router→Service→Repository shape |
| Backend tests | Done | **4 passed** |
| Backend lint (ruff) | Done | **All checks passed** |
| Flutter project + Riverpod/go_router/Dio | Done | `flutter analyze` clean |
| Dio client + error interceptor | Done | `core/network/` |
| Theme tokens (placeholder) | Done | `app/theme/` |
| Loader / Empty / Error widgets | Done | `shared/widgets/` |
| Health screen (all 4 states) | Done | **4 widget tests pass** |
| React + Vite + TS dashboard | Done | `npm run build` succeeds |
| Typed API client + error parsing | Done | `src/lib/api/client.ts` |
| CORS verified for dashboard origin | Done | preflight returns the allow headers |

### Phase 1 — Architecture

`docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `README.md`, and ADR-0001 are written and agreed.

---

## 3. Verification results

```text
backend    pytest ................ 4 passed
backend    ruff check ............ All checks passed
backend    uvicorn boot .......... OK, /docs and /openapi.json served
backend    error envelope ........ OK (404 -> {"error":{...}})
backend    CORS preflight ........ OK (allow-origin: http://localhost:5173)
mobile     flutter analyze ....... No issues found
mobile     flutter test .......... 4 passed
dashboard  npm run build ......... built in 295ms
```

Two real defects were found and fixed during verification, both only detectable by actually
running the code:

1. `pydantic-settings` JSON-decodes list fields from `.env` before validators run — fixed
   with the `NoDecode` annotation on `CORS_ORIGINS`.
2. Dio 5 added `DioExceptionType.transformTimeout`, making the failure-mapping switch
   non-exhaustive — fixed.

---

## 4. Blockers

| # | Blocker | Impact | Owner |
|---|---|---|---|
| B1 | **No MongoDB connection string.** `MONGO_URI` is a local placeholder and nothing is listening on 27017. | `/health` reports `degraded`. Phase 2 cannot be implemented. | User — create an Atlas M0 cluster and paste the URI into `backend/.env`. |
| ~~B2~~ | ~~Stitch designs not accessible.~~ **RESOLVED** — Stitch MCP connected at local scope; 46 mobile + 2 ops screens inventoried in `docs/UI_INVENTORY.md`. | — | Done |
| B3 | **Exposed API key.** The Stitch key was pasted into chat twice and must be considered compromised. It is stored in `~/.claude.json` (outside the repo, not in git). | Security. | User — rotate it, then re-run `claude mcp add`. |
| B4 | **Android licenses not accepted; no emulator.** | App runs only in Chrome. Camera, GPS, and push cannot be validated. | User — `flutter doctor --android-licenses`, then create an AVD. Needed before Phase 5. |
| B5 | **Visual Studio Build Tools incomplete.** | Windows desktop target broken. | Low priority — not a target platform. |
| B6 | **Docker Desktop not running.** | Could not verify the live-DB `ok` path locally. | Optional — B1 resolves this instead. |
| **B7** | **Role model mismatch.** The designs use **Consumer** + **Restaurant Partner**, not the donor/receiver/volunteer trio in the brief. A Consumer both gives and rescues food; there is no separate volunteer role. | **Blocks Phase 2 and 3** — changes the `users` schema and the auth role enum. | **User — decide the role model.** See `docs/UI_INVENTORY.md`. |

---

## 5. Technical debt

| # | Item | Plan |
|---|---|---|
| D1 | Theme tokens are invented placeholders and **confirmed wrong** (bright `#2E7D32` green vs the real `#183B2B` Primary Forest; cool canvas vs warm `#FAF9F6`). Font should be Plus Jakarta Sans. | Replace with the extracted "Verdant Precision" tokens — values are in `docs/UI_INVENTORY.md`. Ready to do now. |
| D2 | The health screen is scaffolding, not product. | Delete once real screens exist (Phase 4). |
| D3 | `ensure_indexes()` is an empty stub. | Populate in Phase 2 alongside `docs/DATABASE.md`. |
| D4 | Dashboard uses inline styles. | Adopt a styling approach in Phase 14. |
| D5 | No CI pipeline. | Add a workflow running all three check suites. |

---

## 6. Completion tracking

**Backend:** foundation complete. 1 of ~10 planned feature modules exists (health).
**Database:** 0 collections designed. Phase 2 is next.
**Mobile pages:** 1 of ~30 (the temporary health screen). 0 product pages.
**Dashboard pages:** 0 of ~10.
**Tests:** 8 total (4 backend, 4 widget).

---

## 7. Next task

**Phase 2 — Database Design.**

Write `docs/DATABASE.md` covering, for every collection: fields, types, required flags,
references, status enums, and indexes. Collections to design:

`users` · `organizations` · `donations` · `food_requests` · `matches` · `rescues` ·
`volunteers` · `notifications` · `escalations` · `fallback_cases` · `waste_partners` ·
`waste_transfers` · `analytics_events`

Pay particular attention to:

- `2dsphere` indexes on every location field — the dynamic rescue radius depends on them.
- Compound indexes on `(status, expires_at)` for expiry sweeps and escalation.
- The full status lifecycle of a donation, including every failure and fallback state.

**Document first, implement second.** No collection is created until this document is agreed.

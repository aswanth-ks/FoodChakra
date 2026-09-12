# FoodLoop — Project Status

**Last updated:** 2026-09-12 (final backend verification)
**Current phase:** Backend Stage H — Dynamic Rescue Radius / Smart Escalation (not started)
**Phases complete:** 0 (Foundation), 1 (Architecture)
**Backend stages complete:** A (Audit + design), B (Foundation), C (Authentication), D (Listings), E (Rescues), F (Handover verification), G (Walkable loop), G.1 (Travel transition), H (Mobile completion)

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

### Backend Stage A — Frontend audit and backend design — **Complete**

Full output in `docs/BACKEND_CONTRACT.md`. The audit read the implemented Flutter app and ops
console rather than working from the original assumptions, and changed the plan:

- The product has **consumer** and **partner** accounts, not donor/receiver/volunteer. A
  consumer both rescues and shares; a partner is a business granted access from the console.
- `food_requests`, `matches`, `volunteers` and `organizations` were **dropped** — no screen
  submits a request that someone approves, so the flow is search-and-claim, not negotiation.
  Thirteen proposed collections became ten.
- The console's nine-step lifecycle is canonical; the mobile and partner enums are projections.

### Backend Stage B — Backend and MongoDB foundation — **Complete**

| Item | Status | Evidence |
|---|---|---|
| Canonical lifecycle, single source of truth | Done | `app/shared/lifecycle.py`, 20 tests |
| Ten collection names, closed set | Done | `app/db/collections.py` |
| Index bootstrap, all 10 collections (31 indexes) | Done | `app/db/indexes.py`, 15 tests |
| Rescue claim partial unique index | Done | `uniq_active_rescue_per_listing` |
| Geospatial `2dsphere` indexes (6) | Done | listings, partners, users, rescues, recovery_partners, zones |
| Activity event foundation (append-only) | Done | `app/features/activity/`, 6 tests |
| Optional `GOOGLE_MAPS_API_KEY` setting | Done | `app/core/config.py`, `.env.example` |
| Startup does not stall on a DB outage | Done | boots in 5.5s, `/health` reports `degraded` |

Not started, deliberately: authentication, listings, rescues, matching, escalation, fallback,
ops APIs. Stage B is foundation only.

### Backend Stage C — Authentication and authorization — **Complete**

| Item | Status | Evidence |
|---|---|---|
| bcrypt password hashing (cost 12) | Done | `app/core/security.py` |
| JWT access (30 min) + refresh (30 day) | Done | typed, separated by a `type` claim |
| Refresh rotation, single-use, replay revokes all | Done | atomic `$pull` in the repository |
| Consumer registration (role not client-settable) | Done | `extra="forbid"` → 422 on escalation |
| Login with status enforcement | Done | suspended/disabled refused |
| `GET /auth/me` | Done | the client's only role source |
| Guards: consumer / partner / staff | Done | `app/features/auth/dependencies.py` |
| Ops access as a capability, not a role | Done | `staff` field + `require_staff` |
| `roleForEmail()` removed from the auth path | Done | deleted; router reads the session |
| Flutter auth layer on the real API | Done | `features/auth/{domain,data,presentation}` |
| Backend tests | Done | **112 passed** |
| Mobile tests | Done | **56 passed**, `flutter analyze` clean |

No new collection was added; no index changed. `users.uniq_email` already covered lookup and
uniqueness. Refresh sessions are embedded on the user document.

Not started, deliberately: listings, rescues, matching, escalation, fallback, ops APIs.
Email verification and password reset are **designed but unimplemented** — they need an email
provider that is not configured; see `docs/API.md`.

### Backend Stage D — Listings — **Complete**

The Give and Explore flows now run against the real API instead of fixtures.

| Item | Status | Evidence |
|---|---|---|
| `POST /listings` — publish surplus | Done | opens at `published` from `lifecycle.py` |
| `GET /listings/nearby` — Explore | Done | `$nearSphere` on `geo_pickup_location` |
| `GET /listings/mine` — Activity / partner Surplus | Done | `by_owner_created` |
| `GET /listings/{id}` — Food Details | Done | explicit allowlist projection |
| `POST /listings/{id}/cancel` — withdraw | Done | legality from `LISTING_TRANSITIONS` |
| Activity events | Done | `listing_created`, `listing_cancelled` |
| Ownership / lifecycle / timestamps server-assigned | Done | `extra="forbid"` → 422 |
| `urgency` derived per read, never stored | Done | asserted in tests |
| Stage E claim readiness | Done | shared `claimable_filter()` + guarded `set_status` |
| Flutter: Explore, Details, Give publish on the API | Done | fixtures now unused by those screens |
| Backend tests | Done | **179 passed** |
| Mobile tests | Done | **62 passed**, `flutter analyze` clean |

**No new collections and no index changes.** `geo_pickup_location`, `by_status_expires_at` and
`by_owner_created` already covered every query. Still ten collections.

Deliberately not built: `PATCH /listings` (nothing in the app edits a published listing), draft
endpoints (no UI creates a draft), photo upload (no upload surface yet).

Not started: rescues, matching, escalation, fallback, notifications, ops APIs.

### Backend Stage E — Rescue / tap-to-claim — **Complete**

| Item | Status | Evidence |
|---|---|---|
| `POST /rescues` — atomic tap-to-claim | Done | one `find_one_and_update` on the listing |
| `GET /rescues/mine`, `GET /rescues/{id}` | Done | 404 for another account's rescue |
| `POST /rescues/{id}/on-the-way` | Done | `matched -> onTheWay` |
| `POST /rescues/{id}/cancel` | Done | listing returns to the pool as `searching` |
| Consumer-only claiming | Done | partner receives 403 |
| Compensating release on a failed insert | Done | guarded on `active_rescue_id` |
| Activity events | Done | `rescue_created`, `rescue_cancelled`, `rescue_ontheway` |
| Concurrency proven | Done | 2-way and 10-way races: exactly one winner |
| Flutter: claim, Rescuer Found, Active Rescue, cancel | Done | fixtures gone from those routes |
| Backend tests | Done | **228 passed** |
| Mobile tests | Done | **66 passed**, `flutter analyze` clean |

**No new collections, no index changes.** `uniq_active_rescue_per_listing` is unchanged and
still partial. Still ten collections, 31 indexes.

**Collection is not implemented, deliberately.** The canonical lifecycle routes `collected`
through `verified`, and no handover verification workflow exists in the product — the app's own
code calls its "I have collected this food" button a stand-in. Faking verification or removing
the rule were both rejected; see `docs/API.md`.

### Backend Stage F — Handover verification & completion — **Complete**

The core loop now closes: **Share → Discover → Rescue → On the way → Arrived → Verified →
Collected → Completed.**

| Item | Status | Evidence |
|---|---|---|
| `POST /rescues/{id}/arrived` — issues the code | Done | rescuer only |
| `POST /rescues/{id}/verify` — owner confirms | Done | rescuer refused unconditionally |
| `POST /rescues/{id}/collected` — completes | Done | `verified -> collected -> completed` |
| Code generated with `secrets`, stored hashed | Done | `app/core/security.py` |
| 30-min expiry, 5-attempt cap, single use | Done | atomic `$inc` on attempts |
| Replay-proof under concurrency | Done | 2 simultaneous verifies -> 1 success, 1 event |
| `arrived -> collected` guard preserved | Done | asserted still false |
| Verifier authority from existing fields | Done | `owner_user_id`, `users.partner_id` |
| Activity events | Done | six, one per transition; owner recorded on verify |
| Backend tests | Done | **271 passed** |
| Mobile tests | Done | **68 passed**, `flutter analyze` clean |

**No new collections, no index changes.** Still ten collections, 31 indexes. New rescue fields:
`handover_code_hash`, `handover_code_expires_at`, `handover_attempts`, `verified_at`,
`verified_by`, `collected_at`, `completed_at`.

**Two UI pieces remain before the loop is walkable in the app** — see the Stage F report:
the rescuer's arrival + code display, and the owner's confirmation entry. The backend contract
for both is complete and documented in `docs/API.md`.

### Final backend verification — 2026-09-12

A full re-verification before the Operations Console. **Atlas was unreachable that day** —
outbound 27017 refused on the college network, the same signature as the original B1 — so the
live checks could not be re-run. What that day could prove, it proved; what it could not, it
says so about rather than inheriting Stage K's result silently.

**Verified fresh, 2026-09-12:**

| Area | How |
|---|---|
| Startup failure behaviour | uvicorn started with Mongo unreachable: it **logs the failure and exits**. It does not come up pretending the database is healthy. |
| Real SMTP | `scripts.send_test_email` delivered through `smtp.gmail.com:587`. Port 587 is open; only 27017 is blocked. |
| Route/auth inventory | Generated from the built app. All 14 product endpoints authenticated; the only public routes are health, the auth bootstrap, and the docs. |
| Mobile ↔ backend contract | New `scripts/check_mobile_contract.py`: all 24 routes accounted for, **no mobile call without a route**. |
| Error envelope, input validation, CORS, OpenAPI | New `tests/test_api_hardening.py`, 35 tests. |
| Credential and fake-code audit | No real credential in tracked source; no executable fake authentication; the redacting log interceptor is still the one installed. |

**Inherited from Stage K (2026-09-10), not re-run:** every live-Atlas result — the concurrent
claim, the partial index, the lifecycle, the handover, live authorization, and restart
persistence. Those are two days old and were green; they are not evidence about today.

#### New structural guards

`tests/test_api_hardening.py` walks the built application rather than listing endpoints, so a
route added in a later stage is covered the day it is added:

- **every route is authenticated unless it is on a named public list**, and the public list
  cannot grow without the test failing — the guard that matters most going into a stage that
  adds staff endpoints;
- every `*Request` model sets `extra="forbid"`, so a privilege-escalation attempt is a 422
  rather than a silent no-op;
- `alg: none` and other malformed `Authorization` headers are clean 401s;
- pagination limits are refused at the query-parameter bound;
- no response carries a stack trace, a connection string, a bcrypt hash or an SMTP setting.

**No defect was found.** Nothing in the application was changed.

#### One thing worth knowing

Startup is now fail-fast: `main.py` no longer wraps `ensure_indexes()` in a `try`, so an
unreachable database stops the process instead of leaving `/health` up reporting `degraded`.
That is the right trade for a deployment with a supervisor to restart it, and it is why the
API cannot be exercised at all while 27017 is blocked — worth remembering rather than
rediscovering.

Backend **373 passed** (was 338), mobile **170 passed**, `ruff` and `flutter analyze` clean.

### Stage K — Live Atlas integration verification — **Complete**

Everything before this stage was proven against fakes. This one re-proved it against the real
cluster, and the difference matters: a conditional update that is conditional in a Python
dictionary tells you nothing about whether MongoDB applies the same filter.

**`backend/scripts/live_atlas_smoke_test.py`** — 136 checks, all passing. Development-only and
deliberately outside `pytest`, which must keep running for someone with no Atlas credentials.

| Proven live | How |
|---|---|
| Registration → verification → login → refresh → logout → reset | real services, real documents, codes captured from the email body and never printed |
| Listing creation, detail, `$nearSphere`, food-type filter | real 2dsphere query; GeoJSON asserted longitude-first |
| **Concurrent claim** | two real `claim()` calls in flight at once — **exactly one succeeded**, the other got 409 |
| **`uniq_active_rescue_per_listing`** | a raw second active insert refused with E11000; two *terminal* rescues coexist, so history never blocks a future claim |
| Full lifecycle `matched → onTheWay → arrived → verified → collected → completed` | every state read back from Atlas after each step |
| Invalid transitions | `matched → collected`, repeated `onTheWay`, `completed → onTheWay` all refused, with Atlas unchanged |
| Handover | code returned once to the rescuer, only a bcrypt hash stored, attempts `$inc` atomically, rescuer cannot verify their own, consumed code cannot be replayed |
| Activity events | all seven actions written; the repository has no update or delete method at all |
| Authorization | a stranger cannot cancel another's listing; an owner cannot rescue their own; `GET /rescues/{id}` stays scoped to the rescuer (404, not 403 — a rescue id is not public); the owner discovers the rescue via `for-listing` and is never shown the code |
| **The whole golden path over real HTTP** | uvicorn on a real port, two accounts, claim → travel → arrive → verify → collect |
| **Restart persistence** | uvicorn killed and restarted as a separate OS process; the account and listing read back intact |

**Cleanup is by `_id` of documents this run inserted** — never by query — and runs in a
`finally`, so a crashed run still tidies up. Verified afterwards: every FoodLoop collection is
back to zero documents.

**Collections with no code behind them.** Six of the ten — `partners`, `escalations`,
`fallback_cases`, `recovery_partners`, `zones`, `notifications` — have schemas and indexes but
**no service writes to them**. Not "implemented but unexercised": not yet implemented. Nothing
in this stage pretended otherwise.

#### The defect this stage found

Mobile was logging credentials. `dio_client.dart` installed Dio's `LogInterceptor` with
`requestBody: true, responseBody: true`, which prints every body and header verbatim. On these
endpoints that meant the device log held the user's **password** (`/auth/login`), their
**one-time code** (`/auth/verify-email`, `/auth/reset-password`), the **handover code**
(`/rescues/{id}/verify`), the `Authorization` header, and both tokens from the login response.

Debug-only is not a defence on its own: an Android debug log is readable over adb, and a
developer reading a bug report should not be handed someone's password either.

Replaced with `RedactingLogInterceptor`, which keeps what logging is for — method, path,
status, payload shape — and replaces any credential-bearing value with `***`, at any nesting
depth. It fails closed on `code`, redacting the error envelope's `UNAUTHORIZED` along with
one-time codes; the envelope's `message` and the HTTP status still identify the failure. Nine
regression tests.

**No backend defect was found.** Every other finding during this stage was a wrong assumption
in the check script — the stored GeoJSON key, the real activity action names, the `lat`/`lng`
query parameter names — corrected in the script, not in the application.

Mobile **170 passed** (was 161), backend **338 passed**, `ruff` and `flutter analyze` clean,
plus **136 live checks** against Atlas.

### Stage J — Email verification, password reset, login email — **Complete**

Mobile authentication is finished. The three inert pieces are real: verification delivers a
code, reset changes a password, and a sign-in sends a confirmation.

**Email lives in one module.** `app/core/email.py` owns everything about sending mail, the way
`security.py` owns everything about cryptography. `AuthService` never sees SMTP — it calls
`send_verification_otp`, `send_password_reset_otp` and `send_login_notification`, which say
*what* is being sent. Swapping SMTP for a hosted API later touches no authentication code.

`smtplib` is synchronous, so each send runs in a worker thread under a hard timeout. No new
dependency was added.

**SMTP configuration is backend-only** — seven `SMTP_*` settings in `backend/.env`, which is
git-ignored. Nothing SMTP-related appears in Flutter, in any client response, or in
`.env.example` beyond placeholders. When `SMTP_HOST` is blank the API answers **503** on the
endpoints that need mail; it never reports a code as sent when nothing left the process.

**Registration no longer issues tokens.** The account is created unverified and a code is
emailed; the client goes to the verification screen, then to sign-in. Handing over a session at
sign-up would have made verification optional in practice whatever the login rule said.

**Login now requires a verified address**, refused with a distinct `EMAIL_NOT_VERIFIED` code so
the app can open the verification screen rather than showing "wrong password". Checked only
after the password is proven, so an unauthenticated caller still learns nothing.

**One-time codes** — `secrets`, six digits, bcrypt-hashed, ten-minute expiry, five attempts
then destroyed, single use enforced by a conditional update, superseded by any newer code, and
a sixty-second resend cooldown. A code is never returned, never logged, never stored in the
clear.

**Forgot-password answers identically to everything** — registered, unknown, suspended, inside
its cooldown, or SMTP down. The cooldown is enforced by *not sending*, never by a 429, because
a 429 for a known address beside a 200 for an unknown one is the leak in a different shape.

**A password reset revokes every session** in the same conditional write that changes the
password. Three separate calls could be interrupted between, and a reset that left a
thirty-day session alive would be worse than no reset at all.

**The login email claims nothing it cannot know** — no device, no IP, no city. The backend
collects none of them, and "signed in from Chennai" would train people to ignore the one signal
that should alarm them. It is sent as a background task and never awaited.

| Endpoint | Added |
|---|---|
| `POST /auth/verify-email` | Stage J |
| `POST /auth/verify-email/resend` | Stage J |
| `POST /auth/forgot-password` | Stage J |
| `POST /auth/reset-password` | Stage J |

Two subdocuments were added to `users` (`email_verification`, `password_reset`) — no new
collections, no new indexes. See `docs/DATABASE.md`.

**One screen had to be built.** The Stitch set stops at "Forgot Password" and has no
enter-code-and-choose-a-password step. `ResetPasswordScreen` is assembled entirely from the
existing `auth_widgets.dart` pieces with the same header, spacing and footer as its sibling, so
it reads as the next page of that flow rather than a new design. The forgot-password copy also
changed from "reset link" to "reset code" — FoodLoop sends a code, and promising a link would
send the user hunting for a button that is not in the email.

**Real SMTP delivery was tested** and works: `python -m scripts.send_test_email` sent a live
message through `smtp.gmail.com:587` and it arrived. That script sends the real login
notification rather than a special test message, so a pass means the production path works.

**Atlas became reachable during this stage**, so the flow was also checked against the real
cluster: a probe account was registered through the real service, its stored document inspected
(unverified, bcrypt code hash, no plaintext, attempts at zero), login refused with
`EMAIL_NOT_VERIFIED`, a wrong password refused with the generic 401 instead, a wrong code
counted as an attempt, and the account deleted afterwards. A real verification email was
delivered as part of it. This is the first live database verification in the project — every
earlier stage remains verified against fakes only.

Backend **338 passed** (was 279), mobile **161 passed** (was 139), `ruff` and
`flutter analyze` clean.

### Stage I — Authentication session & navigation hardening — **Complete**

The last two mobile defects are closed. No product feature was added, no screen redesigned,
and the backend authentication model was not changed — `/auth/me` already answered everything
the client needed.

**One gate, in one place.** `_authRedirect` in `lib/app/router.dart` is now the only code that
decides whether a screen may be shown. Screens do not check for a session, no API failure
pushes `/login`, and nothing navigates imperatively out of an interceptor.

It answers exactly one question — *does a session exist?* Role, account status, permissions and
staff capability stay the backend's to enforce. The router reads the role only to pick *which*
home a signed-in account lands on, and that role arrived on the session, never from the email.

**Protection is an allow-list.** `kPublicRoutes` in `lib/app/session_gate.dart` names the
routes reachable without a session; everything else is protected. A route added later is
protected by default, which is the safe direction to fail.

**Startup.** `AuthController.build()` already called `restoreSession()`; the router now reads it
at launch so the restore starts immediately. `restoreSession()` calls `/auth/me` through the
Stage H interceptor stack, so an expired access token is refreshed and replayed by the existing
mechanism — no second refresh path was created. A 401 or 403 (the latter is what a suspended
account gets) clears the tokens and resolves to "signed out". A *network* failure keeps the
tokens: they may be perfectly good, and signing a user out because a train went into a tunnel
would be wrong.

**Splash.** It no longer picks a destination. It reports that its animation is finished, and
the gate moves the app on once the restore has *also* settled — whichever lands second. The
Stitch design, timeline and hold duration are untouched.

**Logout** clears the stored tokens and the router does the rest, so no authenticated screen is
left on the stack to pop back to.

| Defect | Before | After |
|---|---|---|
| No route guard | `/home` typed by hand rendered Home, then error states | redirected to `/login` |
| Splash ignored the session | every launch went through onboarding | a restored session goes straight to its home |
| Logout only navigated | tokens survived sign-out | tokens cleared, gate redirects |

Mobile **139 passed** (was 111), backend **279 passed**, `flutter analyze` and `ruff` clean.

### Stage H — Mobile completion pass — **CORE COMPLETE**

Every production screen now runs on the real backend. **All four fixture files were deleted**
(`sample_listings`, `sample_activity`, `sample_impact`, `sample_partner`) — no production code
path can reach fake data any more, and the screens' constructor defaults are empty rather than
sample-backed, so a mis-wired route shows nothing instead of inventing food.

| Screen | Source |
|---|---|
| Home | `/listings/nearby` + session name + completed-rescue count |
| Explore | `/listings/nearby`, filters applied |
| Food Details | `/listings/{id}` |
| Give publish | `POST /listings` — the success state now waits on the server |
| Activity (both tabs) | `/rescues/mine` + `/listings/mine` |
| My Impact | computed from completed rescues and listings |
| Rescue / handover / complete | `/rescues/*` |
| Partner Home + Surplus | `/listings/mine` |

**Two real defects were found and fixed:**

1. **No bearer token was attached to any request.** Only `/auth/me` and `/auth/logout` set the
   header by hand — every listings and rescues call went out anonymous and would have been
   refused. `core/network/auth_interceptor.dart` now attaches it globally and refreshes once on
   a 401, with rotation stored immediately (the server treats a reused refresh token as replay).
2. **Give showed "Live" before calling the API.** The confirmation ran on a hardcoded delay, so
   a rejected publish still looked like it worked. Success is now the server's answer.

Also fixed: three pre-existing layout overflows (Active Rescue action row, two Explore rows) at
390pt, invisible until these screens were first rendered in tests.

Honest gaps, deliberately not faked: kilograms diverted shows "—" (no listing carries a weight),
partner **profile** name/locality falls back to the account (no `/partners/me` endpoint), and the
My Impact range chips are reduced to "All time" (rescues carry no completion date client-side).

Mobile **111 passed**, backend **279 passed**, `flutter analyze` and `ruff` clean.

### Stage G.1 — Travel transition — **Complete**

`matched -> onTheWay` is now reachable in the app, closing the last gap in the golden path.

The rescuer confirms departure explicitly with **"I'm on my way"**; opening the maps app
mutates nothing, because looking at a route is not travelling. The backend endpoint already
met every requirement (auth, rescuer ownership, canonical validation, guarded write, activity
event) and needed no change beyond a docstring that described the old trigger.

Backend **279 passed**, mobile **87 passed**, both linters clean.

### Stage G — The walkable rescue loop — **Complete**

The golden path is now executable by two real people in the app:

**A shares → B discovers → B rescues → B travels → B taps "I've arrived" → FoodLoop shows B a
one-time code → B reads it to A → A confirms → B collects → Rescue Complete.**

| Item | Status | Evidence |
|---|---|---|
| Rescuer "I've arrived" + code display | Done | `_ArrivedButton`, `_HandoverCodeCard` |
| Code held in memory only, never stored | Done | widget state; dropped on leaving |
| Owner confirmation screen (6-digit entry) | Done | `HandoverConfirmationScreen` |
| Works for **consumer**-owned listings | Done | reached from Activity |
| Works for **partner**-owned listings | Done | reached from Partner Surplus |
| Owner can discover the rescue | Done | `GET /rescues/for-listing/{id}` |
| Collection calls the real endpoint | Done | no local success path remains |
| Rescue Complete on real data | Done | fixtures removed from the rescue flow |
| Activity + Partner Surplus on real data | Done | `activeActivityProvider`, `partnerDashboardProvider` |
| Backend tests | Done | **276 passed** |
| Mobile tests | Done | **82 passed**, `flutter analyze` clean |

Only one backend addition, and it was necessary: `GET /rescues/for-listing/{id}`. Everything
else in Stage F was reused unchanged, and `lifecycle.py` was not touched.

### Phase 1 — Architecture

`docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `README.md`, and ADR-0001 are written and agreed.

---

## 3. Verification results

```text
backend    pytest ................ 373 passed (final verification)
backend    ruff check ............ All checks passed
backend    uvicorn boot .......... OK, /docs and /openapi.json served
backend    MongoDB Atlas ......... REACHABLE — 10 collections, 31 indexes present
backend    live smoke test ....... 136 checks passed against real Atlas + HTTP
backend    real SMTP send ........ OK, delivered via smtp.gmail.com:587
backend    error envelope ........ OK (404 -> {"error":{...}})
backend    CORS preflight ........ OK (allow-origin: http://localhost:5173)
mobile     flutter analyze ....... No issues found
mobile     flutter test .......... 170 passed (Stage K)
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
| **B1** | **Atlas reachability comes and goes with the network.** Reachable 2026-09-10 (Stage K ran 136 live checks against it); refused again on 27017 by 2026-09-12 on the college network. SMTP on 587 stays open, so only the database is affected, and nothing is wrong with the credentials or the cluster — the failure is at TCP connect, before authentication. | Live verification can only be run from a network that permits 27017. Startup is fail-fast, so the API will not come up at all while it is blocked. | User — run `python -m scripts.live_atlas_smoke_test` from a permitting network; a mobile hotspot has worked before. |
| ~~B2~~ | ~~Stitch designs not accessible.~~ **RESOLVED** — Stitch MCP connected at local scope; 46 mobile + 2 ops screens inventoried in `docs/UI_INVENTORY.md`. | — | Done |
| B3 | **Exposed API key.** The Stitch key was pasted into chat twice and must be considered compromised. It is stored in `~/.claude.json` (outside the repo, not in git). | Security. | User — rotate it, then re-run `claude mcp add`. |
| **B8** | **SMTP app password shared in chat.** The Gmail app password was pasted into the conversation, so it must be treated as compromised. It is in `backend/.env`, which is git-ignored and was never committed. | Security. | User — revoke it at Google Account → Security → App passwords once the demo is done, and issue a fresh one. |
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
**Mobile pages:** 26 product screens complete, plus the temporary health screen.

| Screen | Stitch ID | Status |
|---|---|---|
| Splash | `70ccef9d…` | COMPLETE |
| Welcome & Onboarding (step 1) | `862135f8…` | COMPLETE |
| Onboarding — Turn Extra Food (step 2) | `ccb514b6…` | COMPLETE |
| Onboarding — Every Rescue Counts (step 3) | `2d98bc12…` | COMPLETE |
| Location Setup | `cce80807…` | COMPLETE (real permission flow) |
| Consumer Account Creation | `2abb740e…` | COMPLETE (UI only) |
| Consumer Sign In | `266ac198…` | COMPLETE (UI only) |
| Consumer Forgot Password | `21993dcd…` | COMPLETE (UI only) |
| Consumer Email Verification | `e8885e82…` | COMPLETE (UI only) |
| Consumer Home | `ec02ee87…` | COMPLETE (UI only) |
| Consumer Explore Food | `03d1ce15…` | COMPLETE (UI only) |
| Consumer Activity | `3e283e15…` | COMPLETE (UI only) |
| Consumer My Impact | `193a47c4…` | COMPLETE (UI only) |
| Consumer Profile | `1c0764bd…` | COMPLETE (UI only) |
| Give Surplus Food Entry | `d61ab0df…` | COMPLETE (UI only) |
| Surplus Food Details | `c8299f4a…` | COMPLETE (UI only) |
| Availability & Pickup | `3d47cf51…` | COMPLETE (UI only) |
| Review & Publish | `807b6f65…` | COMPLETE (UI only) |
| Consumer Food Details | `87586e9e…` | COMPLETE (UI only) |
| Consumer Rescue Confirmation Sheet | `a1032738…` | COMPLETE (UI only) |
| Consumer Rescuer Found | `e722e6e8…` | COMPLETE (UI only) |
| Consumer Active Rescue | `8a01e8c0…` | COMPLETE (maps hand-off live) |
| Consumer Rescue Complete | `41bd3493…` | COMPLETE (UI only) |

Flow wired: Splash -> Welcome -> Turn Extra Food -> Every Rescue Counts. Verified running on the Android emulator. `Skip`, `Sign in`, and step 2's
`Continue` have no destination yet — they need the login screen and onboarding step 3,
which are out of scope until instructed. `Sign in` on all three onboarding screens now opens the Sign In screen. `Start rescuing` now opens Location Setup, whose Skip / Enable location / Not now need Account Creation; Sign In's `Forgot password?` now opens the Forgot Password screen; its submit, `Create one` and the Google/Apple buttons stay inert until the Phase 3 auth service exists. Forgot Password's `Send reset link` validates the email locally but does not call a backend until Phase 3. Account Creation's `Create account`, once the form validates, now pushes the Email Verification screen (`/verify-email?email=…`); its OTP row, `Resend code` (30s countdown) and `Change email` (pops back) are UI only until Phase 3; entering six digits lands on Home so the consumer flow is reachable.

**Consumer rescue flow wired:** Home (`/home`) -> tap a nearby opportunity -> Food Details (`/food/:id`) -> `Rescue this food` -> Rescue Confirmation sheet -> tick the commitment box -> `Confirm rescue` (reserving -> confirmed) -> Active Rescue (`/rescue/:id`). Listings come from `features/rescue/data/sample_listings.dart`, the Stitch fixtures — **Phase 5 deletes that file** and feeds the same constructor parameters from a repository. On Active Rescue, `Start navigation`, `View route` and tapping the map are live: they hand off to the device's maps app via `core/navigation/maps_launcher.dart` (universal Google Maps HTTPS links, so Maps opens when installed and the browser otherwise), and show a SnackBar when nothing can handle the link. Confirming the rescue now lands on Rescuer Found (`/rescue/:id/found`) — the match confirmation, whose own primary CTA is `View active rescue` — and that leads to Active Rescue; its `Done` drops the stack back to Home, leaving the rescue running. Active Rescue then leads to Rescue Complete (`/rescue/:id/complete`), whose `Back to home` drops the whole rescue stack. **Design divergence:** the Stitch Active Rescue screen has no forward action — it assumes a live backend advances the stage as the partner verifies the handover. Until that exists, an outlined `I have collected this food` button stands in, deliberately secondary to `Start navigation`. Remove it once the Phase 5 rescue stream drives the stage to `collected` on its own. Explore (`/explore`) is now the destination for Home's `Rescue food` card, `Explore nearby` and `See all`, and for the Explore nav tab; its cards open Food Details, joining the same rescue flow. Its search box, filter chips and List/Map toggle hold local state but do not filter yet — Phase 5 sends the query to the listings API. The Map half shows an honest placeholder until Phase 8. Activity (`/activity`) is wired to its nav tab, with Active/History segments; an in-flight rescue's `View rescue` opens Active Rescue. **Design divergence:** the Stitch mock carries a generic top app bar titled "Item Details" — a leftover from its template — which is omitted, since Activity is a nav destination and takes its title from the heading block like Home and Explore. A share's `Matching status` opens Live Rescue Matching (`/give/matching`). My Impact (`/impact`, constant `AppRoutes.myImpact` — distinct from the onboarding `impact` route) is wired to its nav tab and to Home's `View impact`; its back arrow only renders when there is something to pop, its time-range pill opens a working selector, and `View all` goes to Activity. Profile (`/profile`) completes the bottom nav — **all five consumer tabs are now wired**. Its ten settings rows stay inert rather than pointing at placeholders, since none of those screens exist. `Sign out` confirms in a dialog, then returns to Welcome; there is no session to end until Phase 3. **Give surplus flow wired:** Home's `Give food` card -> Give entry (`/give`) -> Food details (`/give/details`, 1 of 3) -> Availability & pickup (`/give/pickup`, 2 of 3) -> Review & publish (`/give/review`, 3 of 3) -> Live matching (`/give/matching`). The `SurplusDraft` travels forward in the route's `extra`, so each step stays a pure function of the draft handed to it; opening a step directly falls back to an empty draft. Step 1's Continue unlocks only once name, type, quantity and the safety confirmation are set. Step 2's date chips, both time controls and the custom-date picker are live. Publishing is simulated (Phase 5 posts the draft), and lands on Live matching with `go`, so the form steps drop out of the stack. That screen is the giver's mirror of Active Rescue: the pickup-window countdown is recomputed from the wall clock every 20s (turning amber inside the last 15 minutes), and the radar map, floating nodes and slow spinner are painted, not fetched — Phase 8 replaces the map. Its three-stage progress row is driven by a `MatchingStage` parameter that Phase 5's matching service will advance; it is fixed at `searching` for now. The nearby nodes are deliberately anonymous, matching the design's note that no rescuer identity is shown while matching. Reaching it from an Activity share has no stored draft behind it until Phase 5, so it falls back to the draft defaults. `Manage post` and its help button stay inert. Photo upload needs `image_picker` and says so rather than opening a dead picker; changing the pickup point needs the Phase 8 map. Still inert, pending their own screens or the rescue service: notifications / Explore's Filters and Change location / Activity's filter / My Impact's methodology info / Profile's settings rows and Edit profile, Active Rescue's help, Something wrong? and Cancel rescue, and Rescue Complete's `View my impact`. The two maps are `CustomPainter` translations of the designs' SVG geometry, not real cartography — Phase 8 replaces them.

**Partner sign-in gate:** there is one sign-in screen for everyone; the account decides which app it opens. `features/auth/domain/account_role.dart` maps an email to an `AccountRole`, and the router's `homeForRole` sends a partner to `/partner` and everyone else to `/home`. Sign In and Email Verification both route through it. **This is a stand-in, not authorization.** Partner access is really a grant issued from the ops console, and only the server can say whether an account holds it; until the Phase 3 auth service exists there is nothing to ask, so the `@foodloop.com` domain stands in so the partner app is reachable and testable. A client-side check like this is bypassed by typing a different address, so Phase 3 must replace it with the role claim on the authenticated session and delete the domain rule — it must never be what protects partner data. `test/account_role_test.dart` covers the rule, including that the domain has to be the actual domain (`foodloop.com@example.org` is a consumer). Partner Home (`/partner`) is the first of the eleven partner screens: a `PartnerDashboard` fixture in `features/partner/data/sample_partner.dart` (**Phase 5 deletes that file**) feeds today's metrics, the pickup alert, active surplus and recent activity. `PartnerNavBar` is deliberately separate from `ConsumerNavBar` — the two apps share a brand but not a destination list, and a partner never sees Explore. Surplus Management (`/partner/surplus`) is the second: Active / Drafts / History tabs with live counters, the two card treatments, and the standing Kitchen Dispatch Notice. **Design divergence:** the design shows a Drafts count of 1 and a History tab but draws only the Active list; rather than ship two dead tabs, both render the same card against fixture entries, with a real empty state behind them. Home's `View all` and `Rescue history` and the Surplus nav tab all reach it. `presentation/widgets/partner_widgets.dart` holds the partner-only tones (amber for time-critical, emerald for live/matched/collected, stone for closed) plus `PartnerTag`, `PartnerSurplusCard` and `PartnerThumbnail`, so the partner screens share one palette. The other three tabs and every card action stay inert until the remaining nine partner screens are built.

**Operations Console (`dashboard/`) started.** The console is a separate React + Vite + TypeScript app, not part of the Flutter build, and it uses its own Material-style palette from the Stitch console theme — deliberately different from the mobile brand surface, because this is a dense operations tool rather than a consumer app. `src/styles/tokens.css` holds that palette and the type scale; `src/styles/console.css` holds the layout. Routing is `react-router-dom` (added this phase): `/login`, `/overview`, and `/health` (the Phase 0 backend check, moved out of `App.tsx` into `features/health/HealthPage.tsx` and kept for diagnostics). **Console Sign In (`/login`) has no Stitch design** — the console designs begin at Overview — so it is built from the console's own tokens: split layout, network stats on the brand panel, email and password on the form side. **It is not authentication.** No password is checked and no token is issued; any `@foodloop.com` address writes a `localStorage` flag and `RequireAuth` reads it. A client-side guard only decides what renders, so Phase 3 must add a real ops-staff login and a console API that rejects every request without a valid session — the screen says so in-page rather than implying a real login. Overview (`/overview`) is a full translation of the console design: the greeting, a working sector menu (click-away and Escape close it), the live UTC clock, four KPI cards, the drawn sector map with zoom, a layers toggle, routes, status nodes, countdown callouts and the legend, the three-case priority queue, the four trailing-24h health tiles with sparklines, and the five-entry event feed. The map is a schematic, not cartography — Phase 14 replaces it with a real map surface. `features/overview/data/sampleOverview.ts` holds the fixtures (**Phase 14 deletes that file**); the page takes an `OverviewData` prop so only the source changes. Every other sidebar destination renders as a disabled row rather than a link to nothing, and search, filter, export, dispatch broadcast and the queue's "view all" are visibly disabled pending the Phase 14 console API. Intervening on a case surfaces an explicit "needs the Phase 14 rescue service" notice rather than pretending an override was sent.

**Console Live Rescues added.** Live Rescue Map (`/live-rescues`) and Rescue Opportunity Detail (`/live-rescues/:id`) are built, so the sidebar's Live Rescues entry is now a real destination and the nav highlights the parent while drilled into a detail. The map page pairs the large operational map — working zoom, recenter, severity filter tabs, clickable and keyboard-reachable markers with inline labels on the flagged ones — with the Active Rescues panel, whose search and four filter pills both filter live; selecting a marker or row drives the focus card. `Open Rescue` goes to the detail page and `Intervene` deep-links straight into its drawer via `?intervene=1`. The detail page carries the nine-step lifecycle tracker, the incident banner, surplus and partner cards, the countdown bar computed from the remaining minutes against the window length, the escalation tags, the operator action list and the audit timeline. The intervention drawer is real UI — protocol choice, dispatch note, Escape and click-away to close, focus moved into the panel — but applying reports what *would* be sent, because the rescue service does not exist; every other operator action is visibly disabled for the same reason. **Design divergence:** both mocks carry a generic mobile "Item Details" app bar (a template leftover, the same one omitted from the mobile Activity screen) and redraw the sidebar per page; both use the shared console layout instead. A `ConsoleStatusStrip` was added to that layout for the fixed bottom strip these two designs have. Fixtures live in `features/rescues/data/sampleRescues.ts` (**Phase 14 deletes that file**); the fixtures carry one detail record, so any `:id` renders it and the page says so.

**Dynamic Rescue Coverage** (`/live-rescues/:id/coverage`) is built. Both the detail page's `Intervene` button and its `Expand rescue coverage perimeter` action now open it — it is where a widening decision is actually made. The page carries the adaptive-coverage banner with its three counters, the coverage map (concentric standard / expanded / extended bands centred on the rescue, with the responders and neighbouring partners plotted inside them), the three "why coverage changed" factor columns, the coverage events timeline, the selected-rescue card, the four-level progression tracker, the operator controls and the three bottom stat cards. `Expand coverage` reveals the design's inline confirmation before doing anything, and confirming reports that nothing was broadcast — widening coverage pings real couriers, which needs the Phase 14 dispatch service. The remaining three controls stay disabled for the same reason. The status strip gained an optional expanded-coverage counter for this page. Fixtures: `features/rescues/data/sampleCoverage.ts` (**Phase 14 deletes that file**).

**Inventory correction:** listing the Stitch projects showed the console has more designs than `UI_INVENTORY.md` recorded. Newly catalogued and still unbuilt: Smart Escalation, Rescue Queue, Analytics, Restaurants, Restaurant Onboarding steps 1-3, and Zero-Waste Network — Fallback Opportunity. All live in the **Mobile Design System** project (`11421962422199014836`), not the Operations Console project, which holds only Overview and the operations mark.

**Rescue Queue, Smart Escalation and Analytics built.** Those three sidebar entries are now real destinations, so five of the six Operations Core links work; only Zero-Waste Network and the four Management entries remain disabled. All three pages reuse the existing console primitives rather than introducing parallel styling: `ConsoleLayout`, `ConsoleStatusStrip`, the `.card` / `.section-head` / `.kpi` / `.audit` / `.progress` classes and the shared severity palette, with `styles/tables.css` adding the generic table, funnel, stage and rate patterns the three share. Rescue Queue (`/rescue-queue`) pairs the filterable, searchable queue table with the inspection panel; the panel's three workflow buttons route to the rescue detail, Smart Escalation and Dynamic Coverage respectively, and its rows open the detail page. Smart Escalation (`/escalations`) carries the escalation banner, the active queue table with a selectable focus row, the five-stage lifecycle tracker, the telemetry tiles, the audit feed, the operator action stack and the "how it works" card; `Expand rescue coverage` reveals the design's confirmation preview, and confirming reports that nothing was broadcast. Analytics (`/analytics`) has the four headline metrics, a hand-drawn SVG performance chart with toggleable series and per-day hover readout (no charting dependency for two series over thirty points), the five-stage conversion funnel, matching and pickup rate panels, the intervention grid, the ranked bottlenecks, the sector table and the operations insight card. Paging, CSV export and the Zero-Waste handover stay visibly disabled pending the Phase 14 console API. Fixtures: `features/rescues/data/sampleQueue.ts` and `features/analytics/data/sampleAnalytics.ts` (**Phase 14 deletes both**).

**Restaurant Partners directory built** at `/restaurants`, and the sidebar now separates the two concerns: **Restaurants** is the directory of existing partners, and **Onboard Restaurant** is its own entry pointing at the wizard. The directory carries the four totals, the search box, the status tabs and the location filter (all filtering live), the partner table, and the dossier drawer with its stats, operations health, recent activity and action panel. Selecting a row swaps the dossier; a rescue in the activity list opens the rescue detail page, and "View active rescues" reaches Live Rescues. The per-partner profile page and operational log are their own screens and are not built, so those two actions stay disabled. The directory's "Onboard Restaurant" button, the wizard's breadcrumb, its Cancel, and the post-grant "View All Restaurants" and "Cancel Provisioning" now all route between the two pages properly. Fixtures: `features/restaurants/data/samplePartners.ts` (**Phase 14 deletes that file**); the table shows 6 of 248 because the design does, and paging needs the API.

**Restaurant onboarding (steps 1-3) built** at `/restaurants/onboard/:step`. This is the console side of the partner grant described above: onboarding a restaurant here is what would later let it sign in to the partner app, closing the loop with `roleForEmail` on the mobile side. **Nothing is provisioned.** No account is created, no email is dispatched, and the granted state is a local flag; the page says so in-page rather than implying a real provisioning run, and Phase 14 posts the draft to the backend, which is the only thing that can issue a grant or an activation token. The three steps share one route so the draft survives moving between them; a step is addressable but a hard reload restarts the wizard, since there is no server to hold a partial record. Step 1 gates Continue on the five required fields; step 2 validates the email format, runs the registry check copy off the entered domain, and carries the design's operator toggle for exercising the collision path; step 3 renders all three of the design's views — review, success and the 409 conflict — with the conflict reached the way it really would be, from a collision staged at step 2. **Design divergence:** step 3's mock carries a floating "State Preview Controls" pill bar for flipping between its three views; that is a presentation aid for the mock rather than an operator control, so it is omitted. **Security note:** the designs specify a zero-password architecture — desk operators never see, set, or handle partner passwords, and the partner sets their own credentials from the activation link. `OnboardingDraft` therefore has no password field and must never gain one; the capability list is presentational and Phase 14 must source the real scope from the backend's role definitions, so the console cannot claim a scope the server would not grant.
**Rescuers, Locations and Activity built.** The three Management destinations are now real
pages, so every sidebar entry works except Zero-Waste Network. **None of the three has a Stitch
design** — the console designs never covered them — so, like Console Sign In, they are built
from the console's own tokens and primitives rather than translated from a mock. Rescuers
(`/rescuers`) and Locations (`/locations`) deliberately reuse the Restaurants directory shape
(KPI row, filter bar, table, detail panel) instead of inventing a second layout language for
the same job; Activity (`/activity`) uses the denser Rescue Queue shape, since a log is not a
directory. Rescuers is the capacity side of the network — who is on shift, who is carrying a
rescue, and how reliably each completes one; its verification, suspension and reinstatement
controls are disabled, because each changes what a real person is allowed to do and only the
backend can carry that decision and record who made it. Locations is the standing configuration
behind Dynamic Rescue Coverage: that page asks whether to widen the band for one rescue now,
this one asks what a zone's normal is and whether it is holding, so a zone that keeps expanding
reads as a supply problem rather than a run of individual escalations; editing a radius and
pausing or resuming a zone are disabled for the same reason. Activity is the audit trail, and
it is **read-only by design** — there is deliberately no edit, no delete and no retention
control on the page, only an export, which is disabled because a signed audit file has to be
produced server-side. Its entries are fixtures and the page says so in-page rather than
implying anything was really logged. **Role-model note:** Rescuers treats "rescuer" as a
capability on an account, which holds whichever way blocker **B7** is decided; if B7 lands on a
separate volunteer role, only the fixture source changes. Fixtures:
`features/rescuers/data/sampleRescuers.ts`, `features/locations/data/sampleLocations.ts` and
`features/activity/data/sampleActivity.ts` (**Phase 14 deletes all three**). One fix along the
way: `.partnercell`, the avatar-plus-name table cell the Restaurants table already used, was
never defined in CSS; it is now in `styles/tables.css` and both tables use it.

**Settings built** at `/settings`, so the sidebar's footer row is now a real destination. The
page is organised around one distinction, which is the point of its layout: **what this browser
draws** versus **what the network does**. *Console preferences* are real and take effect
immediately — landing page (honoured by the sign-in redirect) and table density (applied via
`data-density` on the shell, tightening the dense tables only). They persist in `localStorage`
per browser and are **not** attached to an account, because there is no account yet; the page
says so rather than implying they sync, and `readPreferences()` validates every stored field,
since a hand-edited `landing` would otherwise route the console to nothing. *Everything else* —
dispatch and coverage defaults, the auto-expand threshold Smart Escalation acts on, alerting,
access policy and audit retention — is disabled, and each row states the reason rather than
showing a dead toggle: these apply to every operator, change what real people are dispatched to
do, and have to be recorded in the audit trail. **Security note:** there is deliberately no
password field, no MFA toggle and no API-token generator here. Console sign-in is still a local
flag, and a credential UI in front of a stand-in would imply a protection that does not exist;
the page carries that warning in-page. Phase 3 brings the real ops login and these controls with
it. Preferences live in `features/settings/data/preferences.ts` — unlike the other console
fixtures, **Phase 14 does not delete this file**; Phase 3 moves the values onto the ops profile.

**Zero-Waste Network built** — four pages at `/zero-waste`, `/zero-waste/fallback/:id`,
`/zero-waste/partners` and `/zero-waste/routing`. This was the last disabled sidebar entry, so
**every console destination now has a route.** **The sidebar lists the section's pages directly**, as nested rows under the
Zero-Waste Network entry, in operational order: **Overview, Fallback Opportunity, Recovery
Partners, Routing** - see the tier, work the urgent case, then the standing configuration behind
it. Fallback Opportunity is a `:id` detail view, so the sidebar entry points at
`/zero-waste/fallback`, which redirects to whichever open case has the least time left - the same
case the overview ranks first. That target comes from `mostUrgentCaseId()`, derived from the
fixture rather than hard-coded, so the sidebar and the overview cannot disagree about which case
is most urgent; Phase 14 resolves it from the API. (This replaced a first pass
that hid them behind in-page pill tabs — the pages were reachable but not visible as
destinations, which is not what a console sidebar is for.) `NavEntry` gained a `children` field
and the row renderer became a recursive `NavRow`, so any future section can do the same. The matching
rules that fell out of it each fix a real defect: a nested row whose path *is* the section root
(the section's Overview) matches **exactly**, because prefix matching lit it on every page in the
section; nested rows *below* the root still prefix-match, so Fallback Opportunity stays lit while
viewing one case at `/zero-waste/fallback/:id`; a section header never takes the selected
treatment itself, because its child already carries it and two highlights read as two selections;
and top-level entries still prefix-match, so Live Rescues stays lit while drilled into
`/live-rescues/:id`. The
header keeps a distinct `navitem--section` treatment whenever any page beneath it is open, which
is what marks the section on Fallback Opportunity.

The tier is modelled on the **food-use hierarchy** — human consumption, animal feed, composting,
energy recovery, landfill — and that ordering is load-bearing rather than decorative, because it
is what waste regulation is written around. It is enforced in three places: the Overview
hierarchy panel always renders best-to-worst and is not re-sortable; Fallback Opportunity ranks
candidate partners by tier first and arrival time second, marks any candidate that would **drop a
rung**, and warns that Phase 14 must require a recorded reason before accepting one; and Routing
always renders its rules in priority order, since first-match-wins makes a rule's position as
meaningful as its condition. Routing's preview table is the page's real payload — it answers
"given these rules, where does each case in hand actually end up" — and flags the cases no rule
can place, which are the ones that become landfill. Recovery Partners shows a used/ceiling
capacity bar rather than a single number, because a partner at 95% is effectively unavailable for
a large consignment while still reading as "accepting".

Continuity with the rest of the console is deliberate: case `FB-3081` comes from rescue `FL-20470`,
whose failed dispatch is the `EV-90390` entry in the Activity Log, and the zones match Locations.
**Nothing dispatches** — assigning a case sends a real vehicle to a real address, so every action
reports what it *would* do. **Fallback Opportunity is now a faithful translation of its Stitch
design** (`a75b3478a61043db95d66ff928a1c838`). The Stitch MCP server is not exposed to the
editor session, so it was driven directly over stdio with the project's own configured
credentials to fetch the screen's HTML and screenshot. The page follows the mock section by
section: the dark surplus banner with its countdown, the surplus inventory profile, the four
recovery pathways, the recommendation analysis, the partner shortlist, the chain-of-custody
routing strip, the operator decision panel, the fallback activity trail and the cancellation
dialog. It is built as the decision it represents — choosing a **pathway** filters the
**partners**, choosing a partner completes the **routing** strip, and the handoff stays
unavailable until both are settled; a partner cannot outlive the pathway it was chosen on,
because the selection resolves against the filtered list rather than being reset by an effect.
`features/zerowaste/data/fallbackTypes.ts` and `sampleFallback.ts` carry the design's own
vocabulary (recovery *pathways*, not tiers), and `styles/fallback.css` the pieces no earlier
page had. **Three deliberate divergences:** the mock is drawn on the mobile brand surface and
redraws its own sidebar, so this is re-based onto the console palette and `ConsoleLayout` as
every Mobile-DS console screen has been; the mock names the origin rescue `FL-20481`, which in
this console is the rescue Amara Okonkwo is currently carrying, so the origin is `FL-20470` —
the dispatch that actually failed per Activity Log entry `EV-90390`; and the mock lists
Animal-Feed Recovery *below* composting and biogas, which is not the food-use hierarchy order
this module enforces, so the cards render in the design's order but selecting a pathway below
the recommended tier raises the module's usual warning, and the ordering cannot quietly cost a
rung. The overview's lead case was aligned to the design (Green Leaf Kitchen, 25 meal boxes,
12 min) so clicking through shows the same surplus, and the superseded `FallbackDetail` types
and fixture were deleted rather than left as dead code. Fixtures: `features/zerowaste/data/sampleZeroWaste.ts`
(**Phase 14 deletes that file**); tier colours live apart from the components in
`data/tierStyle.ts` so the component module exports components only, which is what Fast Refresh
needs.

**Recovery History built** at `/zero-waste/history`, translated from its Stitch design
(`0cfa0a7d733d45f3b5142b0a442db1f8`) and placed after Routing in the sidebar, which is where the
mock's own sidebar puts it. The page is the tier's record: title and quoted subtitle, the toolbar
(search, All/Completed/Cancelled/Failed, Date, Newest sort), the seven-column table, and the
Recovery Details panel with its Status Notes and View Partner action. Every toolbar control the
design draws actually works - search, status, date bucket and sort direction all filter and order
the table live, because a row of controls that only looked filterable would be the worst outcome
on a page whose whole job is finding one past record. Records carry a `day` bucket and a sortable
`at` timestamp so the Date and Sort controls have something real to act on. Like the Activity Log
it is **read-only by design**: a completed recovery is evidence of what happened to real food, so
there is no edit, no delete and no re-run, and the panel says corrections come from the backend
that wrote the record. The three records the mock does not detail carry notes written to match
their outcome, since a cancelled or failed record with no explanation is the one thing an operator
opens this page to read. Fixtures: `features/zerowaste/data/sampleRecoveryHistory.ts`
(**Phase 14 deletes that file**).

**Design backlog discovered.** Listing the Stitch project's 67 screens showed that several pages
built before Stitch was reachable **do have designs**: Zero-Waste Overview, Recovery Partners and
Routing, plus Rescuers Management, Locations Management, a second Locations screen, and the
Activity Log. Three more are designed and unbuilt: Zero-Waste Analytics, Zero-Waste Handover
(Review), and a *second* Fallback Opportunity screen (`4489ee49...`, distinct from the
`a75b3478...` one already translated). All are listed with their IDs at the end of
`docs/UI_INVENTORY.md`. Those pages work and are internally consistent, but none of them has been
checked against its mock.

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

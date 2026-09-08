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
| B1 | **Cannot reach MongoDB Atlas — outbound port 27017 appears blocked on this network.** The Atlas URI is configured in `backend/.env` and is valid: the SRV record resolves to the real shard hosts (`ac-hpbwtyy-shard-00-0{0,1,2}.9qy2c0c.mongodb.net`). All three refuse TCP on 27017, while ports 80/443 connect fine and every non-standard high port tested (8080, 27017, 27018) is refused after a uniform ~2s. The failure is at TCP connect, **before authentication** — so the password is not the problem. | `/health` reports `degraded`. Phase 2 cannot be verified against a real cluster. | User — (a) add public IP `115.244.249.170` to Atlas Network Access, and (b) if it still fails, switch network (mobile hotspot) or run MongoDB locally via Docker. |
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

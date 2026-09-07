# FoodLoop — Development Roadmap

Every phase has an **entry condition**, **deliverables**, and an **exit condition**. A phase
is complete only when its exit condition is objectively met — not when it looks finished.

> **Build -> Connect -> Test -> Verify -> Complete -> Move Forward**

---

## Phase 0 — Foundation ✅ COMPLETE

**Exit condition:** all three workspaces run; a request travels Flutter -> FastAPI -> MongoDB.

Delivered: git repo, FastAPI skeleton with the reference vertical slice, Mongo lifecycle,
error envelope, Flutter app with Riverpod/go_router/Dio and the four state widgets, React
dashboard, `/api/v1/health` verified from both clients.

---

## Phase 1 — Architecture ✅ COMPLETE

**Exit condition:** the layering, state, error, and config contracts are written and agreed.

Delivered: `docs/ARCHITECTURE.md`, `README.md`, this roadmap, ADR-0001.

---

## Phase 2 — Database Design ⏭️ NEXT

**Entry:** Phase 1 agreed; a MongoDB Atlas URI is available (blocker **B1**).

**Deliverables:** `docs/DATABASE.md` documenting every collection — fields, types, required
flags, references, status enums, indexes. Then `app/db/indexes.py` implements them.

Collections: `users`, `organizations`, `donations`, `food_requests`, `matches`, `rescues`,
`volunteers`, `notifications`, `escalations`, `fallback_cases`, `waste_partners`,
`waste_transfers`, `analytics_events`.

Critical: `2dsphere` indexes on all location fields; compound indexes on
`(status, expires_at)`; the complete donation status lifecycle including failure states.

**Exit:** the document is agreed, indexes are created at startup, and a connection to Atlas
succeeds (`/health` returns `status: "ok"`).

---

## Phase 3 — Authentication

**Entry:** Phase 2 complete.

**Deliverables:** register, login, logout, bcrypt hashing, JWT access + refresh tokens, role
selection (`donor | receiver | volunteer | ops_admin`), a role-guard dependency, verification,
password reset. Flutter: login/register screens, secure token storage, `AuthInterceptor`,
role-aware router redirect.

**Exit:** a user can register, log in, receive a token, call a protected endpoint, be
rejected without a token, and be rejected with the wrong role — all covered by tests.

---

## Phase 4 — Stitch to Flutter UI

**Entry:** Phase 3 complete **and** the approved designs are accessible (blocker **B2**).

**Deliverables:** `docs/UI_INVENTORY.md` mapping every screen to a route and shared widget;
real theme tokens replacing the placeholders; the shared component library (app bars, food
cards, status badges, buttons, bottom nav, inputs, location components).

**Per-screen process:**

```text
Analyze design -> identify reusable components -> implement UI -> navigation
-> local state -> API connection -> loading/empty/error/success -> test
-> visual comparison -> COMPLETE
```

**Exit:** every screen passes the 17-point gate in `docs/PAGE_CHECKLIST.md`. No screen is
"done" while it only looks right.

---

## Phase 5 — Donor System

**Deliverables:** onboarding, home, create donation (food info, quantity, category, images,
pickup location, pickup time, expiry/urgency), active donations, tracking, history, edit,
cancel.

**Exit:** a donor can create a donation that persists to MongoDB and appears in their list,
with all four UI states working. **Requires a real device or emulator (blocker B4)** — camera
and location cannot be validated in Chrome.

---

## Phase 6 — Receiver System

**Deliverables:** onboarding, home, browse available food, search, filters, food details,
request food, request tracking, history, receipt confirmation.

**Exit:** a receiver can discover a donor's real donation and request it end to end.

---

## Phase 7 — Volunteer System

**Deliverables:** onboarding, home, rescue opportunities, nearby opportunities, rescue
details, accept, navigate to donor, confirm pickup, navigate to receiver, confirm delivery,
history, performance.

**Exit:** the **first complete rescue** — donor creates, receiver requests, volunteer picks
up and delivers, everyone sees the correct final state.

---

## Phase 8 — Matching Engine

**Deliverables:** deterministic matching on distance, food compatibility, quantity, time
window, and availability. Ranked candidate receivers and volunteers.

**Exit:** given a new donation, the system proposes sensible matches, proven by tests over
fixture data. No ML — rules only.

---

## Phase 9 — Rescue Intelligence

**Deliverables:** dynamic rescue radius (expand on no response), smart escalation, rescue
priority, volunteer network expansion, escalation states, timeout handling.

**Exit:** an unclaimed donation demonstrably expands its radius, raises priority, and reaches
a terminal escalated state — verified by a time-simulated test.

---

## Phase 10 — Zero-Waste Fallback

**Deliverables:** fallback detection, fallback cases, waste partners, partner matching,
transfer requests, transfer tracking, completion.

**Safety rule:** never assume food is safe for a given use. Routing to human consumption,
animal feed, biogas, or compost depends on validated food condition and operational rules.

**Exit:** a donation that fails rescue is routed to an appropriate partner and tracked to
completion.

---

## Phase 11 — Predictive Demand

**Deliverables:** historical demand capture, aggregation, simple forecasting, high-demand
locations and categories.

**Rule:** start with aggregation and simple statistics. Do not introduce ML before enough
real data exists to justify it.

---

## Phase 12 — Notifications

**Deliverables:** notification service, in-app + push, history, read/unread, event triggers
(donation requested/accepted, volunteer assigned, pickup and delivery reminders, escalation,
approaching expiry, fallback triggered, delivery complete).

---

## Phase 13 — Maps

**Deliverables:** location permissions, current location, map display, markers, routes,
distance, ETA, rescue radius visualization, navigation handoff.

---

## Phase 14 — Operations Dashboard

**Deliverables:** ops authentication, overview metrics, live operations map, users, food,
smart rescue, zero-waste, and analytics sections.

**Exit:** an operator can see live system state and act on an escalated case.

---

## Phase 15 — System Integration

**Exit:** both journeys pass end to end.

```text
Happy:   Donor -> donation -> matching -> receiver -> request -> volunteer
         -> pickup -> delivery -> completion -> analytics

Failure: Donation -> no volunteer -> radius expansion -> escalation
         -> still unsuccessful -> fallback network
```

The failure path is tested as rigorously as the happy path.

---

## Phase 16 — Testing

Widget, navigation, form and validation, state, responsive layout, API, auth, database,
matching, rescue, escalation, fallback, integration, and end-to-end journeys.

---

## Phase 17 — Security

Authentication and authorization hardening, API validation, rate limiting, secrets
management, CORS review, secure database access, file upload validation, input sanitization,
logging, audit trail.

---

## Phase 18 — Deployment

Production FastAPI deployment, production MongoDB configuration, Flutter release builds,
dashboard web deployment, environment variables, monitoring, logging, backups, crash
reporting.

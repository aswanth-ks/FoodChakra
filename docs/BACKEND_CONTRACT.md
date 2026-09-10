# FoodLoop — Backend Contract (Phase 2 design)

Derived from an audit of the **implemented** Flutter app (`mobile/lib`) and the
**implemented** ops console (`dashboard/src`). Nothing here is speculative product design:
every collection, field and endpoint below traces to a screen that exists today.

Status: **design only — no implementation.** Awaiting `START BACKEND FOUNDATION`.

---

## 0. The headline finding — read this first

The planning vocabulary (`donor` / `receiver` / `volunteer` as three separate apps) **does not
match what was built.** The shipped app has two account kinds:

| Built role | Who | Evidence |
|---|---|---|
| `consumer` | A person. Rescues food **and** shares their own surplus — same account, one bottom nav | `account_role.dart`, `consumer_nav_bar.dart`; Give flow and Explore flow are both reachable from it |
| `partner` | A business (restaurant, caterer, hotel). Access **granted from the ops console**, never self-signup | `account_role.dart` doc comment, `partner_dashboard.dart` — `PartnerProfile` is not editable in the app |
| `ops_admin` | Console operator | `dashboard/src/features/auth` |

Consequences — these are simplifications, and they are the whole point of doing the audit first:

1. **There is no separate "volunteer".** The person who rescues the food *keeps* it. Rescuer =
   consumer. The console's Rescuers directory is a *view over consumers who rescue*, not a
   separate account type.
2. **There is no `food_requests` collection and no `matches` collection.** No screen submits a
   request that a donor then approves. A consumer taps "Rescue this" on a listing and it is
   theirs (`rescue_confirmation_sheet.dart`). Matching is a **search + claim**, not a
   negotiation. So `donations + food_requests + matches + rescues` collapses to
   **`listings` + `rescues`**.
3. **There is no `organizations` collection for receivers.** Only partners are organizations.

Do not build those collections. They would be dead weight the frontend never calls.

---

## 1. Frontend screen inventory

### 1.1 Mobile (Flutter) — routes from `mobile/lib/app/router.dart`

**AUTH** — `/login`, `/register`, `/create-account`, `/forgot-password`, `/verify-email`

**ONBOARDING** — `/onboarding/welcome`, `/onboarding/share`, `/onboarding/impact`,
`/onboarding/location`

**CONSUMER SHELL** — `/home`, `/explore`, `/activity`, `/impact`, `/profile`

**GIVE (consumer shares surplus)** — `/give` (source) → `/give/details` → `/give/pickup` →
`/give/review` → `/give/matching`

**RESCUE (consumer collects)** — `/food/:id` → `/rescue/:id` → `/rescue/:id/found` →
`/rescue/:id/complete`

**PARTNER** — `/partner`, `/partner/surplus`, `/partner/activity`, `/partner/impact`,
`/partner/profile`

**SYSTEM** — `/` (splash), `/health`

`/donor`, `/receiver`, `/volunteer` exist as route constants but are aliases/stubs — the real
app is the consumer/partner split above.

### 1.2 Console (React) — `dashboard/src/features`

| Module | Pages |
|---|---|
| overview | OverviewPage — KPIs, priority cases, live map, network events |
| rescues | LiveRescueMapPage, RescueQueuePage, RescueDetailPage, EscalationPage, CoveragePage |
| zerowaste | ZeroWasteOverviewPage, FallbackOpportunityPage, RoutingPage, RecoveryPartnersPage, RecoveryHistoryPage |
| restaurants | RestaurantsPage, OnboardingWizard (the partner grant) |
| rescuers | RescuersPage — directory, verification, dossier |
| locations | LocationsPage — zones, pickup points |
| activity | ActivityLogPage — audit trail |
| analytics | AnalyticsPage — funnel, rates, bottlenecks |
| settings / auth / health | SettingsPage, LoginPage, HealthPage |

---

## 2. The canonical state machine

The console already defines nine lifecycle steps (`rescueTypes.ts: LifecycleStep`). **That is the
source of truth.** The mobile and partner enums are *presentation projections* of it — the
backend stores one value and each client narrows it.

```text
draft -> published -> searching -> matched -> onTheWay -> arrived -> verified -> collected -> completed
```

Split across two documents, because ownership changes at `matched`:

- **`listings.status`** owns `draft -> published -> searching -> matched`, plus terminal
  `expired | cancelled | completed`.
- **`rescues.status`** owns `matched -> onTheWay -> arrived -> verified -> collected ->
  completed`, plus `cancelled | no_show`.

### Projection tables

Implement these as pure mapping functions. Never re-derive them ad hoc per screen.

Mobile `RescueStage` (`food_listing.dart`) from canonical:

| RescueStage | canonical |
|---|---|
| `confirmed` | matched |
| `preparing` | matched (owner not ready) |
| `ready` | onTheWay |
| `pickup` | arrived / verified |
| `collected` | collected / completed |

`PartnerSurplusStatus` (`partner_dashboard.dart`) from canonical:

| Partner status | canonical |
|---|---|
| `draft` | draft |
| `lookingForRescuer` | published, searching |
| `rescuerMatched` | matched, onTheWay |
| `awaitingHandover` | arrived, verified |
| `collected` | collected, completed |
| `expired` | expired |

`ListingUrgency` (`available | expiring | critical | scheduled`) is **derived, never stored** —
computed from the pickup window against now. Storing it guarantees it goes stale.

### Failure path

```text
searching --(no claim, window closing)--> escalation opened
  stage 1 notify -> 2 search expanded (radius grows) -> 3 operator review
  -> 4 courier dispatch -> 5 fallback handoff
       |
       v
  fallback_case (reason, kg, minutes_left)
       |
       v  routing walks TIER_ORDER, best recoverable tier first
  human -> animal_feed -> composting -> energy -> landfill
```

Tier order is from `zeroWasteTypes.ts` and is **regulatory, not cosmetic** — routing must always
attempt the highest recoverable tier first.

---

## 3. MongoDB architecture

Ten collections. The ones from the original plan that are deliberately excluded are listed at
the end, with reasons.

| Collection | Purpose |
|---|---|
| `users` | All accounts: consumer, partner_member, ops_admin. Embeds rescuer state and impact. |
| `partners` | Businesses granted access via the console onboarding wizard. |
| `listings` | Surplus offered — by a partner, or by a consumer's Give flow. |
| `rescues` | One consumer's claim on a listing, through to handover. |
| `escalations` | Five-stage escalation state and radius history for a stalled listing. |
| `fallback_cases` | Surplus that left the human tier, and where it was routed. |
| `recovery_partners` | Animal feed / compost / biogas / energy operators. |
| `zones` | Operating areas, coverage state, pickup points. |
| `notifications` | In-app and push records. |
| `activity_events` | Append-only audit trail behind ActivityLog and Analytics. |

### 3.1 `users`

```text
_id            ObjectId
email          str    required, unique, lowercased
password_hash  str    required (bcrypt)
full_name      str    required                  <- create_account_screen.dart
role           enum   consumer | partner_member | ops_admin   required
phone          str?
email_verified bool   default false             <- /verify-email
avatar_url     str?
home_location  GeoJSON Point?                   <- /onboarding/location
locality       str?                             "Karur, Tamil Nadu"
partner_id     ObjectId? -> partners            required iff role = partner_member
rescuer        { status: on_rescue|available|offline|suspended,
                 verification: verified|pending|expired,
                 verified_until: datetime?,
                 completed_rescues: int, cancelled: int, no_shows: int,
                 reliability: float 0..1,
                 last_location: GeoJSON Point?, last_seen_at: datetime? }
impact         { meal_boxes: int, servings: int, rescues: int, shares: int }
created_at / updated_at
```

Indexes: `{email:1}` unique · `{role:1}` · `{"rescuer.last_location":"2dsphere"}` ·
`{"rescuer.status":1, "rescuer.verification":1}` for the console directory filters.

`rescuer` and `impact` are embedded, not separate collections: both are always read with the
user and never queried alone. This is why there is no `volunteers` collection.

### 3.2 `partners`

```text
_id, name, category ("Restaurant Partner"), locality
status         enum  onboarding | active | paused | suspended
location       GeoJSON Point   required
address, contact_name, contact_phone, contact_email
zone_id        ObjectId -> zones
pickup_points  [{ label: "Pickup counter - Main entrance", instructions }]
is_open        bool                        <- PartnerProfile.isOpen green dot
onboarding     { step: int, completed_steps: [str], documents: [...] }
impact         { meal_boxes, servings, listings, collected }
created_at / updated_at
```

Indexes: `{location:"2dsphere"}` · `{status:1}` · `{zone_id:1}`.

### 3.3 `listings` — the heart

Traced field by field to `SurplusDraft` (what a consumer submits) and `FoodListing` (what a
viewer sees).

```text
_id
reference         str   "FL-20481", unique          <- RescueDetail.reference
source_kind       enum  partner | consumer
partner_id        ObjectId?  set iff source_kind = partner
owner_user_id     ObjectId   always — who published
surplus_source    enum  home | event                <- SurplusSource, consumer only
title             str   "25 Meal Boxes"             derived from quantity + unit
food_name         str   required                    <- SurplusDraft.foodName
food_type         enum  vegetarian|vegan|non_veg|other   <- FoodType
quantity          int   required, > 0
unit              enum  meal_boxes|servings|kilograms    <- QuantityUnit
servings_estimate int
weight_kg         float?  required before fallback routing — tiers are kg-based
prepared_when     enum  just_prepared|earlier_today|yesterday|other
description       str?
tags              [str]
photo_url         str?    optional throughout       <- SurplusDraft.photoPath
safety_confirmed  bool    must be true to publish   <- the mandatory checkbox
pickup_location   { label: "Community Hall", locality,
                    point: GeoJSON Point,
                    pickup_point: "Pickup counter - Main entrance" }
pickup_from       datetime  required  (UTC; built from PickupDay + TimeOfDay)
pickup_until      datetime  required
expires_at        datetime  required  = pickup_until unless food safety shortens it
status            enum  draft|published|searching|matched|collected|completed
                        |expired|cancelled|fallback
active_rescue_id  ObjectId? -> rescues
search_radius_km  float  default 3.0                grows with escalation
escalation_id     ObjectId?
is_live           bool                              <- FoodListing.isLive badge
published_at, created_at, updated_at
```

Indexes:

- `{pickup_location.point:"2dsphere"}` — Explore's entire query
- `{status:1, expires_at:1}` — the expiry/escalation sweep; without it that job is a full scan
- `{owner_user_id:1, created_at:-1}` — Activity and Partner Surplus tabs
- `{partner_id:1, status:1}`
- `{reference:1}` unique

Validation: `pickup_until > pickup_from`; `safety_confirmed == true` to leave `draft`;
`quantity > 0`; a consumer listing may not set `partner_id`.

### 3.4 `rescues`

```text
_id, reference
listing_id       ObjectId -> listings   required
rescuer_id       ObjectId -> users      required
status           enum  matched|onTheWay|arrived|verified|collected|completed
                       |cancelled|no_show
lifecycle        [{ step, at: datetime, by: user|system|operator }]   the tracker
handover_code    str?    6-digit, checked at `verified`
distance_km      float   snapshot at claim time
travel_estimate  str?    "Est. 6 min drive / 18 min walk"
rescuer_location GeoJSON Point?   last known, for the live map
cancel_reason    str?
problem_reports  [{ at, reason, note }]              <- "Report a problem"
matched_at, collected_at, completed_at, created_at, updated_at
```

Indexes: `{listing_id:1}` · `{rescuer_id:1, created_at:-1}` · `{status:1, updated_at:-1}` ·
`{rescuer_location:"2dsphere"}`.

Invariant: **at most one non-terminal rescue per listing.** Enforce with a partial unique index
on `{listing_id:1}` where status is not terminal. That is what makes a double-claim a clean
`409 CONFLICT` rather than a race.

### 3.5 `escalations`

```text
_id, listing_id, zone_id
stage           int 1..5                          <- EscalationStage
state           enum  active | resolved | fallback_handoff | cancelled
radius_history  [{ km, at, reason }]
stage_events    [{ stage, at, source: "Automated SLA trigger" | operator_id, detail }]
notified_user_ids [ObjectId]
minutes_remaining_at_open int
resolved_at, created_at / updated_at
```

Indexes: `{listing_id:1}` · `{state:1, stage:1}` · `{zone_id:1, state:1}`.

### 3.6 `fallback_cases`

```text
_id, listing_id, rescue_id?, escalation_id
kg                  float required
reason              str    why the human tier failed
zone_id
proposed_tier       enum  human|animal_feed|composting|energy|landfill
final_tier          enum?
severity            derived from minutes left — do not store, it goes stale
recoverable_until   datetime
recovery_partner_id ObjectId?
state               enum  open|routing|dispatched|transferred|completed|failed
routing_trail       [{ tier, partner_id?, outcome, at }]
created_at / updated_at
```

Indexes: `{state:1, recoverable_until:1}` · `{zone_id:1}` · `{final_tier:1, created_at:-1}`.

`waste_transfers` is **not** a separate collection — `routing_trail` is always read with its
case and never queried alone.

### 3.7 `recovery_partners`

```text
_id, name, tier, location GeoJSON Point, zone_id, service_radius_km
state               enum  recommended|available|limited|check    <- PathwayState
capacity_kg_per_day float
accepts             [food_type...]
contact {...}, operating_hours [...], created_at / updated_at
```

Indexes: `{location:"2dsphere"}` · `{tier:1, state:1}`.

### 3.8 `zones`, `notifications`, `activity_events`

```text
zones
  _id, name, status(live|strained|expanded|paused),
  boundary GeoJSON Polygon, centre Point, base_radius_km,
  coverage_level, pickup_points[], created_at/updated_at
  idx: {boundary:"2dsphere"}, {status:1}

notifications
  _id, user_id, kind, title, body,
  payload{listing_id?, rescue_id?}, read_at?,
  sent_channels[in_app|push], created_at
  idx: {user_id:1, created_at:-1}, {user_id:1, read_at:1}
  device tokens: embedded on users, or a small {user_id, token, platform, last_seen} collection

activity_events                                   APPEND ONLY
  _id, actor{kind: operator|system|partner|rescuer, id?, name},
  category, outcome(ok|warning|failed),
  subject{type, id, reference}, summary, detail, zone_id?, created_at
  idx: {created_at:-1}, {category:1, created_at:-1}, {"subject.id":1}
```

`activity_events` is also the **only** source Analytics reads. That is deliberate: predictive
demand later needs an event history, and this is it — collected from day one, cheaply, without
building any ML now.

### 3.9 Deliberately not created

`food_requests`, `matches`, `volunteers`, `organizations` — see §0.
`waste_transfers` — see §3.6.
`analytics_events` — named `activity_events`, and serves both purposes.

---

## 4. API contract

All under `/api/v1`. The error envelope and codes are already fixed in `docs/API.md` and are
unchanged by this design.

### `/auth`

| Method | Path | Auth | Role | Notes |
|---|---|---|---|---|
| POST | `/auth/register` | – | – | full_name, email, password. Consumers only — partners are granted, never self-registered |
| POST | `/auth/login` | – | – | returns access + refresh + `user` including `role` |
| POST | `/auth/refresh` | refresh | – | rotates |
| POST | `/auth/logout` | yes | any | revokes the refresh token |
| POST | `/auth/verify-email` | – | – | token from email |
| POST | `/auth/resend-verification` | yes | any | |
| POST | `/auth/forgot-password` | – | – | |
| POST | `/auth/reset-password` | – | – | |

### `/users`

`GET /users/me` · `PATCH /users/me` · `PUT /users/me/location` (the onboarding location step) ·
`GET /users/me/impact` (My Impact hero figures) · `POST /users/me/devices` (push token).

### `/listings`

| Method | Path | Auth | Role | Notes |
|---|---|---|---|---|
| GET | `/listings/nearby` | yes | consumer | `lat, lng, radius_km, food_type, urgency, limit` → Explore. `$near` on the 2dsphere index |
| GET | `/listings/{id}` | yes | any | Food Details |
| POST | `/listings` | yes | consumer, partner_member | Give review → publish; body is the SurplusDraft fields |
| POST | `/listings/draft` | yes | partner_member | Partner Drafts tab |
| PATCH | `/listings/{id}` | yes | owner | draft edits only |
| POST | `/listings/{id}/publish` | yes | owner | requires `safety_confirmed` |
| POST | `/listings/{id}/cancel` | yes | owner | |
| GET | `/listings/mine` | yes | owner | `?status=active\|drafts\|history` → Partner Surplus tabs and Activity |
| GET | `/listings/{id}/matching` | yes | owner | Live Matching screen: current radius, candidates notified, elapsed |

### `/rescues`

| Method | Path | Auth | Role | Notes |
|---|---|---|---|---|
| POST | `/rescues` | yes | consumer | `{listing_id}` — the claim. `409` if already claimed |
| GET | `/rescues/{id}` | yes | rescuer, owner, ops | Active Rescue / Rescuer Found |
| POST | `/rescues/{id}/on-the-way` | yes | rescuer | Start navigation |
| POST | `/rescues/{id}/arrived` | yes | rescuer | |
| POST | `/rescues/{id}/verify` | yes | owner | handover code |
| POST | `/rescues/{id}/collected` | yes | rescuer | → Rescue Complete |
| POST | `/rescues/{id}/cancel` | yes | rescuer, owner | reason required |
| POST | `/rescues/{id}/report-problem` | yes | rescuer | |
| PUT | `/rescues/{id}/location` | yes | rescuer | live map ping |
| GET | `/rescues/mine` | yes | consumer | Activity and History tabs |

### `/notifications`

`GET /notifications` · `POST /notifications/{id}/read` · `POST /notifications/read-all`.

### `/ops` — all `ops_admin`

`GET /ops/overview` ·
`GET /ops/rescues` (queue + filters) · `GET /ops/rescues/{id}` ·
`POST /ops/rescues/{id}/intervene` (the intervention drawer options) ·
`GET /ops/escalations` · `POST /ops/escalations/{id}/advance` · `POST /ops/escalations/{id}/resolve` ·
`GET /ops/coverage` · `GET /ops/zones` · `PATCH /ops/zones/{id}` ·
`GET /ops/rescuers` · `GET /ops/rescuers/{id}` · `POST /ops/rescuers/{id}/verify` · `POST /ops/rescuers/{id}/suspend` ·
`GET /ops/partners` · `POST /ops/partners` (onboarding wizard) · `PATCH /ops/partners/{id}` ·
`GET /ops/fallback/cases` · `POST /ops/fallback/cases/{id}/route` ·
`GET /ops/fallback/partners` · `GET /ops/fallback/history` ·
`GET /ops/activity` · `GET /ops/analytics`.

---

## 5. Layering — where each rule lives

Unchanged from `docs/ARCHITECTURE.md` §2.1. `app/features/health/` is the reference shape.

| Concern | Layer |
|---|---|
| Token decode, role guard | Router, as a `Depends` |
| Field types, ranges, enum membership | Schema (Pydantic) |
| Window must be in the future; safety must be confirmed; claim conflict; status transition legality; radius growth; tier ordering; impact tallying | **Service** |
| `$near`, `$geoWithin`, index-backed sweeps, the atomic claim | **Repository** |

The claim is the one place to be careful. `POST /rescues` must use a single atomic
`find_one_and_update` on the listing (status in `{published, searching}` → `matched`) inside the
repository. A read-then-write in the service is a race that double-books a listing.

---

## 6. Authentication architecture

- **Hashing:** bcrypt, cost 12, via `passlib`.
- **Tokens:** JWT. Access 30 minutes, refresh 30 days. Claims: `sub`, `role`, `partner_id?`,
  `jti`, `exp`.
- **Refresh rotation:** each refresh issues a new token and revokes the old `jti`. Store revoked
  jtis with a TTL index; reuse of a revoked jti revokes the whole family.
- **Roles:** `consumer`, `partner_member`, `ops_admin`, behind a `require_role(...)` dependency.
- **Ownership** ("is this your listing") is checked in the **service**, not the router — it is
  business logic, not an HTTP concern.
- **`roleForEmail()` in Flutter must be deleted at Stage C.** Its own doc comment says it is a
  stand-in; the server's role claim replaces it. Until then, partner data is not protected.
- Partner accounts are created only via `POST /ops/partners` plus an invite — never through
  `/auth/register`.

---

## 7. Core flow, end to end

```text
Partner or consumer publishes surplus     POST /listings  (+ /publish)
  listing.status: draft -> published -> searching
  service notifies consumers within search_radius_km  ($near)
       |
       v
Consumer sees it on Explore               GET /listings/nearby
Consumer opens details, confirms rescue    POST /rescues
  atomic claim: listing -> matched, rescue -> matched
       |
       v
Rescuer navigates                          POST /rescues/{id}/on-the-way -> /arrived
Owner verifies the handover code           POST /rescues/{id}/verify
Rescuer confirms collection                POST /rescues/{id}/collected
  listing -> completed; impact tallies increment on both users;
  an activity_event is appended
```

Failure branch: the expiry sweep (on the `{status, expires_at}` index) finds a `searching`
listing close to `pickup_until` with no rescue → opens an `escalation` → stages 1 to 5 → if
still unresolved, opens a `fallback_case` → routing walks `TIER_ORDER` → the transfer is
recorded → the listing reaches a terminal state.

---

## 8. How the smart features attach later

Each is a **service-layer strategy swap**, not new architecture. The data they need is captured
from day one; the algorithms stay dumb until there is history to learn from.

| Feature | Day-one placeholder | Later — no schema change |
|---|---|---|
| Dynamic Rescue Radius | `listings.search_radius_km` fixed at 3.0 | grow on a schedule, then from zone density; `radius_history` already records every change |
| Smart Escalation | five stages advanced by fixed SLA timers | learn stage timings per zone from `escalations.stage_events` |
| Predictive Demand | nothing | read `activity_events` — already append-only, timestamped and zone-tagged |
| Zero-Waste routing | first `available` partner in `TIER_ORDER` | optimise on capacity, distance and kg |
| Analytics | aggregate `activity_events` on read | pre-aggregate into a rollup collection if it gets slow |

No ML, no microservices, no message queue. The escalation and expiry sweep is a single
background task in the same process (APScheduler or an asyncio loop). That is sufficient at this
scale and can move to a worker later without touching the schema.

---

## 9. Implementation roadmap

| Stage | Scope | Exit condition |
|---|---|---|
| **B** | Mongo connection, `ensure_indexes()` for all ten collections | `/health` reports `connected: true`; indexes present |
| **C** | `/auth` and `/users/me`; bcrypt, JWT, refresh rotation, role guards; delete `roleForEmail` | Flutter signs in and lands in the right shell from a server claim |
| **D1** | `/listings` create, publish, mine — the Give flow | A consumer publishes; it appears in Activity and Partner Surplus |
| **D2** | `/listings/nearby` and `/listings/{id}` — Explore and Details | Geospatial search returns real listings at real distances |
| **E** | `/rescues` full lifecycle including the atomic claim | Explore → claim → navigate → verify → collected, end to end, on device |
| **F** | Matching notifications, Live Matching screen, fixed-radius search | Publishing notifies nearby consumers |
| **G1** | Expiry sweep and `escalations` on fixed SLA timers | A stale listing escalates on its own |
| **G2** | `fallback_cases`, `recovery_partners`, tier routing | An unrescued listing lands on a tier and is recorded |
| **H** | `/ops/*` — the console runs off real data; `activity_events` written everywhere | Console fixtures deleted |
| **I** | Integration tests, rate limiting, upload validation, deployment | Phase 17 hardening per ARCHITECTURE §7 |

Frontend fixtures are deleted as each stage lands: `sample_listings.dart`,
`sample_activity.dart`, `sample_impact.dart`, `sample_partner.dart`, and
`dashboard/src/features/*/data/sample*.ts`.

---

## §9 — Email, verification and password reset (Stage J)

### 9.1 Where SMTP may exist

Backend environment variables only. SMTP configuration must never appear in Flutter source, in
a client environment file, in an API response, or in a git-tracked file — `.env.example` holds
placeholders and nothing else.

Settings: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM_EMAIL`,
`SMTP_FROM_NAME`, `SMTP_USE_TLS`, `SMTP_TIMEOUT_SECONDS`.

### 9.2 Failing safely

`Settings.email_configured` is read before every send. When it is false the API answers **503**
with a message saying so. The one thing the API must never do is report that a code was sent
when nothing left the process — a user waiting for an email that does not exist has no way to
discover the truth.

The two failures are kept apart: `EmailNotConfiguredError` is an operator's problem,
`EmailDeliveryError` is usually transient, and the logs say which. Neither ever reaches a
client as SMTP detail, a hostname, or a stack trace.

### 9.3 One-time codes

Generated with `secrets`, exactly six digits, stored only as a bcrypt hash. Ten-minute expiry,
five attempts before the code is destroyed, single use, and superseded by any newer code.
Sixty-second gap between two code emails to one address.

Six digits is about twenty bits, so the hash alone does not make a code safe against an
attacker who steals the database. What makes it safe is the combination — short expiry, hard
attempt cap, single use, and a conditional update that lets exactly one request win.

### 9.4 Consumption must be conditional

Verification and reset both complete with an update filtered on the stored `code_hash`. Reading
the code, checking it, then writing unconditionally would let two concurrent requests both
succeed and leave the code usable. The filter is the check.

A password reset performs three changes in that one update: the new password hash, removal of
the code, and `refresh_sessions: []`. They cannot be separate calls.

### 9.5 What may be said to an unauthenticated caller

`/auth/forgot-password` and `/auth/verify-email/resend` answer identically for every address —
registered, unknown, suspended, already verified, inside a cooldown, or with SMTP down.
Rate-limiting on forgot-password is enforced by not sending, never by a 429: a 429 for a known
address beside a 200 for an unknown one leaks exactly what the shared message hides.

Verification failures are one message for a wrong code, an expired code, a consumed code and an
unknown address.

Account status and verification state are revealed only *after* the password has been proven —
`EMAIL_NOT_VERIFIED` on login is a post-authentication answer.

### 9.6 What may appear in an email

The verification and reset emails carry a code. The login notification carries nothing at all
beyond a first name.

Never: a password, an access token, a refresh token, a password hash, staff or role
information, or any claim about device, IP or location. The backend does not collect the last
of these, and asserting them would make the notification worse than useless — it would teach
the reader to ignore it.

### 9.7 Sessions

Registration issues **no** tokens. Verification issues **no** tokens. Password reset issues
**no** tokens. Only `/auth/login` and `/auth/refresh` mint a session, and login requires
`email_verified: true`.

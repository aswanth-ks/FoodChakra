# FoodLoop

**A food rescue and redistribution platform.**
FoodLoop connects surplus food with the people and organizations that need it — and, when
food can no longer be eaten, routes it away from landfill into animal feed, biogas, or compost.

> FoodLoop is not "an app where restaurants donate food". It is a **food rescue coordination
> ecosystem** that answers: *what food is available, where is it, who needs it, who can move
> it, how urgent is it, and what happens if the normal rescue path fails?*

---

## Table of contents

- [What FoodLoop does](#what-foodloop-does)
- [System architecture](#system-architecture)
- [Tech stack](#tech-stack)
- [Repository layout](#repository-layout)
- [Getting started](#getting-started)
- [Development plan (Phases 0-18)](#development-plan-phases-0-18)
- [Code quality rules](#code-quality-rules)
- [Documentation index](#documentation-index)
- [Current status](#current-status)

---

## What FoodLoop does

FoodLoop serves five participant types:

| Participant | Role |
|---|---|
| **Donors** | Restaurants, hotels, bakeries, caterers, events, supermarkets, individuals. List surplus food before it becomes waste. |
| **Receivers** | NGOs, charities, shelters, community organizations. Discover and request available food. |
| **Volunteers** | Physically move food from donor to receiver. Accept tasks, navigate, pick up, deliver, confirm. |
| **Fallback partners** | Animal-feed, composting, and biogas facilities — the Zero-Waste Fallback Network. |
| **Operations team** | Authorized staff monitoring and managing the ecosystem via a separate web dashboard. |

### The core flow

```text
                    SURPLUS FOOD
                         |
                         v
                  FOODLOOP SYSTEM
                         |
              +----------+----------+
              v                     v
       Human Consumption       Cannot Consume
              |                     |
              v                     v
          RECEIVER             FALLBACK NETWORK
              |                     |
              v             +-------+--------+
          VOLUNTEER         v       v        v
              |           Feed   Biogas  Compost
              v
           DELIVERY
              |
              v
        RESCUE COMPLETED
```

### The failure path

The hard problem is not listing food — it is what happens when nobody collects it.

```text
DONATION -> VOLUNTEER SEARCH -> NO RESPONSE -> DYNAMIC RESCUE RADIUS
         -> ESCALATION -> SECONDARY ATTEMPT -> ZERO-WASTE FALLBACK
```

---

## System architecture

```text
                    FOODLOOP
                       |
        +--------------+--------------+
        v                             v
   MOBILE APP                 OPERATIONS DASHBOARD
   Flutter                      React + Vite
        |                             |
        +--------------+--------------+
                       v
                    FASTAPI
                       |
        +--------------+--------------+
        v              v              v
     MongoDB        Maps API     Notifications
                       |
                       v
              INTELLIGENT SYSTEMS
       +---------------+----------------+
       v               v                v
   Matching       Smart Rescue      Predictive
                    System            Demand
                       |
                       v
              ZERO-WASTE FALLBACK
```

FoodLoop is a **modular monolith**, not a microservice system. Feature modules are isolated
well enough that services can be extracted later if scale demands it — but not before.

### The layering contract

Every request flows through the same layers. **Shortcuts are defects, not style choices.**

```text
Flutter widget
     |
Riverpod provider
     |
Repository (interface)
     |  HTTP
FastAPI Router
     |
Pydantic Schema
     |
Service          <- all business logic lives here
     |
Repository       <- the only layer allowed to touch the DB driver
     |
MongoDB
```

**Forbidden:**

```text
Flutter --X--> MongoDB          (never)
Route   --X--> MongoDB query    (never - go through a repository)
Widget  --X--> business logic   (never - put it in a service/notifier)
```

---

## Tech stack

| Layer | Technology | Version |
|---|---|---|
| Mobile | Flutter / Dart | 3.44.9 / 3.12.2 |
| Mobile state | Riverpod | 3.x |
| Mobile routing | go_router | 17.x |
| Mobile HTTP | Dio | 5.x |
| Backend | Python / FastAPI | 3.13 / 0.120 |
| DB driver | Motor (async) | 3.7 |
| Database | MongoDB Atlas | 8.x |
| Dashboard | React + Vite + TypeScript | 19 / 8 / 5 |
| Dashboard data | TanStack Query | 5.x |
| Maps | Google Maps API | Phase 13 |

---

## Repository layout

```text
Food-Chakra/
├── README.md              <- you are here
├── docs/                  <- architecture, roadmap, status, DB & API contracts
├── backend/               <- FastAPI (Python)
│   └── app/
│       ├── main.py            app factory, CORS, lifespan
│       ├── core/              config · logging · exceptions
│       ├── db/                mongo connection · indexes
│       ├── api/v1/router.py   aggregates all feature routers
│       ├── features/<name>/   router · schemas · service · repository
│       └── shared/            cross-feature helpers
├── mobile/                <- Flutter
│   └── lib/
│       ├── app/               theme · router · root widget
│       ├── core/              config · network · error · storage
│       ├── features/<name>/   data · domain · presentation
│       └── shared/widgets/    reusable UI (loader, empty, error, cards)
└── dashboard/             <- React + Vite ops dashboard
    └── src/{lib/api,features,components}
```

---

## Getting started

**Prerequisites:** Flutter 3.44+, Python 3.13+, Node 20+, a MongoDB Atlas cluster.

### 1. Backend

```bash
cd backend
python -m venv .venv
./.venv/Scripts/python.exe -m pip install -r requirements-dev.txt   # Windows
# source .venv/bin/activate && pip install -r requirements-dev.txt  # macOS/Linux

cp .env.example .env        # then fill in MONGO_URI and JWT_SECRET
./.venv/Scripts/python.exe -m uvicorn app.main:app --reload
```

- API: <http://127.0.0.1:8000/api/v1/health>
- Docs: <http://127.0.0.1:8000/docs>

Generate a JWT secret with:

```bash
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

### 2. Mobile

```bash
cd mobile
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

On an **Android emulator**, `localhost` refers to the emulator itself — use:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

### 3. Dashboard

```bash
cd dashboard
npm install
cp .env.example .env
npm run dev        # http://localhost:5173
```

### 4. Stitch designs (design source of truth)

The approved UI lives in Stitch and is pulled through an MCP server. Configure it once:

```bash
claude mcp add stitch -s local -e STITCH_API_KEY=<your-key>   -- npx -y @_davideast/stitch-mcp@0.9.0 proxy
```

`-s local` keeps the key in `~/.claude.json`, **outside the repository**. Never put it in a
tracked file.

Verify and browse:

```bash
export STITCH_API_KEY=<your-key>
npx @_davideast/stitch-mcp doctor                 # check auth
npx @_davideast/stitch-mcp tool list_projects     # find project IDs
npx @_davideast/stitch-mcp view --projects        # interactive browser
```

Projects: **FoodLoop Mobile Design System** (`11421962422199014836`) and
**FoodLoop Operations Console** (`8883198284374486482`). The full screen inventory and the
extracted design tokens are in [`docs/UI_INVENTORY.md`](docs/UI_INVENTORY.md).

> `@_davideast/stitch-mcp` is an independent, experimental package — not an official Google
> product, and provided with no warranty.

### Running the checks

```bash
cd backend   && ./.venv/Scripts/python.exe -m pytest && ./.venv/Scripts/python.exe -m ruff check .
cd mobile    && flutter analyze && flutter test
cd dashboard && npm run build
```

---

## Development plan (Phases 0-18)

We build **incrementally**. The rule is:

> **Build -> Connect -> Test -> Verify -> Complete -> Move Forward**

A screen that merely looks right is not done. See `docs/ROADMAP.md` for the full entry and
exit conditions of every phase.

| # | Phase | Outcome | Status |
|---|---|---|---|
| 0 | **Foundation** | All three workspaces run; health endpoint proves the chain | Done |
| 1 | **Architecture** | Layering, state, error model, config documented | Done |
| 2 | **Database design** | Collections, fields, indexes, status enums documented | Next |
| 3 | **Authentication** | Register, login, JWT, roles, refresh, reset | Not started |
| 4 | **Stitch to Flutter UI** | Design system + screens from approved designs | Blocked |
| 5 | **Donor system** | Create/track/edit/cancel donations, images, pickup | Not started |
| 6 | **Receiver system** | Browse, search, filter, request, confirm receipt | Not started |
| 7 | **Volunteer system** | Opportunities, accept, navigate, pickup, deliver | Not started |
| 8 | **Matching engine** | Deterministic matching on distance, type, quantity, time | Not started |
| 9 | **Rescue intelligence** | Dynamic rescue radius, escalation, priority, timeouts | Not started |
| 10 | **Zero-waste fallback** | Fallback detection, partners, transfers | Not started |
| 11 | **Predictive demand** | Demand aggregation and forecasting foundation | Not started |
| 12 | **Notifications** | In-app + push, history, event triggers | Not started |
| 13 | **Maps** | Location, markers, routes, ETA, rescue radius | Not started |
| 14 | **Operations dashboard** | Overview, live ops, users, escalations, analytics | Not started |
| 15 | **System integration** | Full happy path *and* full failure path | Not started |
| 16 | **Testing** | Widget, API, integration, end-to-end | Not started |
| 17 | **Security** | Authz, rate limiting, secrets, uploads, audit trail | Not started |
| 18 | **Deployment** | Prod backend, DB, mobile builds, dashboard, monitoring | Not started |

### Build order

```text
Structure -> Architecture -> Flutter -> FastAPI -> MongoDB -> Auth
   -> First complete user flow -> Donor -> Receiver -> Volunteer
   -> Matching -> Rescue -> Maps -> Notifications -> Smart Rescue
   -> Fallback -> Predictive -> Dashboard -> Integration -> Security -> Deploy
```

### Deliberate sequencing decisions

- **Deterministic before intelligent.** The matching engine ships as plain rules (Phase 8)
  and only becomes smart once it is reliable (Phase 9).
- **No premature ML.** Predictive demand (Phase 11) needs real data to exist first.
- **The failure path is a feature.** Phase 15 tests the *unsuccessful* rescue as rigorously
  as the successful one — that path is what makes FoodLoop different.

---

## Code quality rules

### Flutter

**Do not** put business logic in widgets · duplicate widgets · hardcode API URLs or secrets ·
put database logic in the app · create giant files · build unnecessary abstractions.

**Do** extract reusable widgets · use feature modules · use the repository pattern ·
use Riverpod for state · read config from `Env`.

### FastAPI

**Do not** query the database from a route · put business logic in a route · hardcode
secrets · mix unrelated modules · duplicate services.

**Do** follow `Router -> Schema -> Service -> Repository -> MongoDB` without exception.

### Every screen must handle four states

Never build only the happy path. `LoaderView`, `EmptyStateView`, and `ErrorStateView` exist
in `mobile/lib/shared/widgets/` so this is structurally hard to skip.

```text
Loading   ->  spinner
Success   ->  real data
Empty     ->  "No active donations"
Error     ->  message + retry
```

### API conventions

All endpoints live under `/api/v1/`. Every error — expected or not — returns one envelope:

```json
{ "error": { "code": "NOT_FOUND", "message": "...", "details": {} } }
```

### Before writing any code

1. Inspect the existing project.
2. Search for reusable components, services, and models.
3. Reuse what exists.
4. Make the smallest clean change.
5. Do not rewrite working code.
6. Explain architectural changes before making them.

---

## Documentation index

| File | Purpose |
|---|---|
| `docs/ARCHITECTURE.md` | Layering, state management, error model, configuration |
| `docs/ROADMAP.md` | Every phase with entry conditions, deliverables, exit conditions |
| `docs/PROJECT_STATUS.md` | Living tracker — current phase, blockers, next task |
| `docs/DATABASE.md` | Collection schemas, indexes, status enums |
| `docs/API.md` | Endpoint contract, grows with each feature |
| `docs/UI_INVENTORY.md` | Stitch screen to Flutter route and shared widget map |
| `docs/PAGE_CHECKLIST.md` | The 17-point per-page completion gate |
| `docs/adr/` | Architecture Decision Records |

---

## Current status

**Phase 0 and 1 complete.** All three workspaces build, run, and pass their checks. The
`/api/v1/health` endpoint exercises the entire chain from Flutter through FastAPI to MongoDB.

**Next:** Phase 2 — database design, documented in `docs/DATABASE.md` before any collection
is implemented.

See `docs/PROJECT_STATUS.md` for the live tracker and the current blocker list.

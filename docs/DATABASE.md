# FoodLoop — Database Design

**Status: NOT STARTED — this is Phase 2, the next task.**

MongoDB Atlas. Access is only ever through a repository
(`Service -> Repository -> MongoDB`); no route touches the driver.

---

## Rules for this document

Before any collection is implemented, this file must specify, for each one:

- Fields and types
- Required vs optional
- References to other collections
- Status enums with the **complete** set of values
- Indexes, including geospatial and compound

**Document first, implement second.** Indexes are then declared in
`backend/app/db/indexes.py`, which runs idempotently at startup.

---

## Collections to design

| Collection | Purpose |
|---|---|
| `users` | Accounts, roles, credentials, profile |
| `organizations` | Donor and receiver organizations |
| `donations` | Surplus food listings |
| `food_requests` | Receiver requests against donations |
| `matches` | Proposed donation/receiver/volunteer pairings |
| `rescues` | An accepted rescue task through to delivery |
| `volunteers` | Volunteer availability, location, performance |
| `notifications` | In-app and push notification records |
| `escalations` | Rescue escalation state and radius history |
| `fallback_cases` | Food routed away from human consumption |
| `waste_partners` | Animal feed, biogas, composting partners |
| `waste_transfers` | Transfers to a fallback partner |
| `analytics_events` | Aggregation source for metrics and predictive demand |

---

## Design points that must not be missed

### Geospatial

Every location is a GeoJSON Point with a `2dsphere` index:

```js
{ "type": "Point", "coordinates": [longitude, latitude] }   // lng first
```

Needed on: `donations.pickup_location`, `organizations.location`,
`volunteers.current_location`, `waste_partners.location`.

Without these, the dynamic rescue radius (`$near`, `$geoWithin`) cannot work.

### The donation lifecycle

The status enum must cover the **failure** path, not just the happy one. Draft:

```text
draft -> listed -> matched -> claimed -> assigned -> picked_up
      -> delivered -> completed

Failure branches:
listed   -> expiring_soon -> escalated -> radius_expanded
         -> fallback_pending -> fallback_transferred -> fallback_completed
any      -> cancelled
any      -> expired
```

### Expiry and escalation sweeps

A background job scans for donations nearing expiry. This needs a compound index on
`(status, expires_at)` — without it the sweep is a full collection scan.

### Referencing

Prefer `ObjectId` references over embedding for anything queried independently. Embed only
data that is always read with its parent and never queried alone.

### Timestamps

Every collection carries `created_at` and `updated_at` (UTC).

---

## Next step

Write the full schema for each collection above, agree it, then implement
`ensure_indexes()`. See `docs/ROADMAP.md` for the exit condition.

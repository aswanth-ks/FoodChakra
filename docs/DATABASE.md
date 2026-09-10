# FoodLoop — Database Design

**Status: DESIGNED — the full schema lives in [`BACKEND_CONTRACT.md`](BACKEND_CONTRACT.md) §3,
derived from an audit of the implemented Flutter app and ops console.**

That document supersedes the collection list below in three ways, and the reasons are in its §0:

- `food_requests`, `matches`, `volunteers` and `organizations` are **not** built — the app has
  no request/approve step and no separate volunteer account, so they collapse into
  `listings` + `rescues`.
- `waste_transfers` is embedded as `fallback_cases.routing_trail`.
- `analytics_events` is named `activity_events` and serves the audit log too.

**Stage D note.** `listings` is implemented as specified in `BACKEND_CONTRACT.md` §3.3, with two
clarifications learned from the UI: `pickup_location.point` is **required** (Explore is entirely
a `$near`, so a listing without a point is undiscoverable), and `weight_kg` stays **optional**
at creation because the Give flow does not collect it — fallback routing must obtain it before
tiering. `owner_display_name` is denormalised onto the listing so a card can name its publisher
without a second lookup. No index was added: the Stage B set already covered every query.

**Stage E note.** `rescues` is implemented per `BACKEND_CONTRACT.md` §3.4, minus the fields no
workflow drives yet: no `handover_code` (there is no verification step in the product), no
`travel_estimate`, `rescuer_location` or `problem_reports`. `listings.active_rescue_id` now
carries the claiming rescue and is the guard that makes the compensating release safe. The
`uniq_active_rescue_per_listing` partial index is unchanged and is the second line of defence
behind the atomic listing claim. No index was added.

**Stage F note.** `rescues` gains the handover fields: `handover_code_hash` (bcrypt — the
plaintext is never stored), `handover_code_expires_at`, `handover_attempts`, plus `verified_at`,
`verified_by`, `collected_at` and `completed_at`. `handover_code_hash` is not read by any
response projection, so the stored secret has no route to a client. Verification authority is
derived from fields that already existed — `listings.owner_user_id` and, for business listings,
`users.partner_id` matched against `listings.partner_id` — so no schema change was needed to
answer "who may confirm this handover". No index was added: verification is always a lookup by
`_id`.

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


---

## Stage J — verification and reset state on `users`

Two optional subdocuments were added to `users`. Neither is a new collection, for the same
reason `refresh_sessions` is not one: they are read only with their user, never queried alone,
and each is a single small bounded object. `email_otps` and `password_resets` collections would
have added two collections and a join to store one 4-field object.

```jsonc
{
  // ... existing user fields ...
  "email_verified": false,          // already existed; now actually meaningful

  "email_verification": {           // absent once verified or consumed
    "code_hash":  "$2b$12$...",     // bcrypt; the code itself is never stored
    "expires_at": ISODate("..."),
    "attempts":   0,                // wrong guesses so far
    "sent_at":    ISODate("...")    // the resend-cooldown clock
  },

  "password_reset": {               // same shape, same rules
    "code_hash":  "$2b$12$...",
    "expires_at": ISODate("..."),
    "attempts":   0,
    "sent_at":    ISODate("...")
  }
}
```

**No new indexes.** Both are reached through the existing `uniq_email` lookup — there is no
query that finds a user *by* a code, and there could not be: only a hash is stored.

Consumption is a conditional update filtered on `<field>.code_hash`, which is what makes single
use real rather than advisory. A password reset does its three writes — new hash, code removed,
`refresh_sessions` emptied — in that one update, so the sequence cannot be interrupted halfway.

### Existing accounts

Login now requires `email_verified: true`. Accounts created before Stage J hold `false` and
would be refused. No production accounts exist — Atlas has never been reachable from this
environment — but if any are found, the fix is a one-line backfill
(`{"email_verified": false}` → `true` for accounts created before the Stage J deploy), *not* a
weakening of the login rule.

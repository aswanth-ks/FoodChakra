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

## `/auth` — Stage C, extended in Stage J

Roles: `consumer`, `partner`. Operations access is a separate capability (`is_staff`), not a
role — see `docs/ARCHITECTURE.md` §2.10.

### `POST /api/v1/auth/register`

Public. Creates an **active consumer**, always. `role`, `status`, `staff` and `partner_id` are
not fields on the request model, so sending one is rejected with `422` rather than ignored.
Partner accounts are provisioned through the operations console instead.

```json
{ "full_name": "Asha Rao", "email": "asha@example.com", "password": "a-good-password" }
```

**201** → an acknowledgement, **not** a token pair:

```json
{
  "message": "Account created. Check your email for a 6-digit verification code.",
  "email": "asha@example.com",
  "expires_in_minutes": 10
}
```

No session is issued. The account exists with `email_verified: false`, and a 6-digit code is
emailed. Handing over tokens here would make verification optional in practice, whatever the
login rule says — so the client's next stop is `/auth/verify-email`, then `/auth/login`.

**409** if the email is taken. **422** on validation. **503** if the code could not be emailed
— the account was still created, so `/auth/verify-email/resend` recovers it. The API never
reports a code as sent when nothing left the process.

Password: 8 characters minimum, 72 bytes maximum (bcrypt's limit — longer is rejected rather
than silently truncated). The same policy applies to `/auth/reset-password`, from one shared
validator, so reset cannot be used to get round it.

### `POST /api/v1/auth/verify-email`

```json
{ "email": "asha@example.com", "code": "481920" }
```

**200** → `{ "message": "Email verified. You can now sign in." }`. No tokens: proving control
of the address is not the same as proving the password.

**422** for a wrong code, an expired code, a consumed code, an unknown address, or an account
that is already verified — all with the same message, because telling them apart helps only
someone guessing. The code is constrained to exactly six digits at the edge, so a malformed
guess is rejected before it can cost the account an attempt.

Only a bcrypt hash of the code is stored, and the update is conditional on that hash still
being present, so two requests carrying the same correct code produce exactly one success.

### `POST /api/v1/auth/verify-email/resend`

`{ "email": "asha@example.com" }` → **200**, always the same message. Issues a fresh code,
which invalidates the previous one. **429** inside the cooldown window.

Silent about whether the address is registered or already verified: the caller is
unauthenticated, and answering differently would make this a way to discover accounts.

### `POST /api/v1/auth/forgot-password`

`{ "email": "asha@example.com" }` → **200**, with one message for every address:

```json
{ "message": "If that email address has a FoodLoop account, a reset code is on its way." }
```

Identical status and body whether the address is registered, suspended, inside its cooldown, or
unknown — and identical when SMTP itself fails. Anything else would turn this endpoint into a
free "who has an account here?" lookup. A suspended account is sent nothing at all, since
resetting a password it cannot use would only confirm the address exists.

### `POST /api/v1/auth/reset-password`

```json
{ "email": "asha@example.com", "code": "481920", "new_password": "a-brand-new-password" }
```

**200** → `{ "message": "Password updated. Sign in with your new password." }`. **422** for a
wrong, expired, consumed or over-attempted code, and for a password that fails the policy.

One conditional write sets the password, consumes the code **and empties `refresh_sessions`**.
Those cannot be three separate calls: a reset that changed the password but left an attacker's
thirty-day session alive would be worse than no reset at all.

No tokens are issued. Control of a mailbox is enough to *change* a password, not to become the
user without knowing it.

### `POST /api/v1/auth/login`

```json
{ "email": "asha@example.com", "password": "a-good-password" }
```

**200** → a token pair. **401** `Invalid email or password.` for both a wrong password and an
unknown account — deliberately indistinguishable, and equalised in time, so the endpoint is not
an account-enumeration oracle. **403** if the account is suspended or disabled, checked only
*after* the password is verified.

**403 `EMAIL_NOT_VERIFIED`** if the address was never confirmed — also checked only after the
password is proven, so an unauthenticated caller learns nothing. The code is distinct because
the client must act on it: the mobile app opens the verification screen rather than showing a
refusal.

A confirmation email is sent afterwards, as a background task. It is never awaited: the
response is already correct by then, and a mail outage must not turn a valid sign-in into a
failed one. The message names no device, IP or location, because the backend collects none of
them — inventing "signed in from Chennai" would train people to ignore the one signal that
should alarm them.

Token pair shape, returned by login and refresh (**not** register):

```json
{
  "access_token": "…", "refresh_token": "…", "token_type": "bearer",
  "expires_at": "2026-09-10T12:34:56Z",
  "user": {
    "id": "…", "email": "…", "full_name": "…",
    "role": "consumer", "status": "active",
    "email_verified": false, "is_staff": false, "partner_id": null,
    "created_at": "…", "last_login_at": "…"
  }
}
```

### `POST /api/v1/auth/refresh`

`{ "refresh_token": "…" }` → a new pair. Rotation is single-use: the old token is consumed
atomically. A replayed refresh token revokes **every** session on the account, because replay
means the token was captured. **401** on an invalid, expired or replayed token; **403** if the
account is no longer active.

### `POST /api/v1/auth/logout`

Authenticated. Body optional: `{ "refresh_token": "…" }` revokes that session; omitting it
revokes all of them. **204**. Never fails on a bad token — a client must always be able to
clear its own session.

### `GET /api/v1/auth/me`

Authenticated. Returns the `user` object above.

**This is the client's only source of truth for role.** The account record is re-read on every
authenticated request, so a suspension or role change takes effect immediately rather than
lingering until the access token expires. Clients must never infer a role from the email
address — the `roleForEmail()` helper that did so was deleted in Stage C.

### One-time codes

Verification and reset codes share one implementation and one set of rules:

| Property | Value | Why |
|---|---|---|
| Generation | `secrets.randbelow`, zero-padded to 6 digits | `random` is seeded predictably; without the padding one code in ten would be five digits |
| Storage | bcrypt hash only | a database dump hands over no live codes |
| Expiry | `OTP_EXPIRE_MINUTES` (default 10) | |
| Attempts | `OTP_MAX_ATTEMPTS` (default 5), then the code is destroyed | six digits is a million guesses, which an automated client exhausts in minutes; the cap, not the length, is what makes guessing impractical |
| Single use | consumed by a conditional update | two concurrent requests with one code yield one success |
| Supersession | issuing a new code overwrites the old hash | the previous code stops matching immediately |
| Resend gap | `OTP_RESEND_COOLDOWN_SECONDS` (default 60) | one address must not be an unlimited outbound mail generator |

A code is **never** returned by any endpoint, written to any log, or stored in plaintext. The
only place one exists in the clear is the email itself.

### Authentication header

`Authorization: Bearer <access_token>`. Access tokens live 30 minutes, refresh tokens 30 days.
An access token is not accepted where a refresh token is expected, or vice versa.

---

## `/listings` — Stage D

All endpoints require authentication. Ownership, lifecycle state, `reference` and every
timestamp are assigned by the server; sending any of them is a `422` (the request models are
`extra="forbid"`).

### `POST /api/v1/listings`

Publishes surplus. Both roles may publish — a partner listing is marked `source_kind:
"partner"` and `shared_by_verified: true`, derived from the account, never from the body.

```json
{
  "food_name": "Vegetable biryani",
  "food_type": "vegetarian",
  "quantity": 25,
  "unit": "meal_boxes",
  "source": "event",
  "prepared_when": "earlier_today",
  "safety_confirmed": true,
  "description": "Freshly prepared vegetarian meals.",
  "tags": ["Plant-Based"],
  "weight_kg": null,
  "pickup_location": {
    "label": "Community Hall",
    "locality": "Karur, Tamil Nadu",
    "latitude": 10.9577,
    "longitude": 78.0809
  },
  "pickup_from": "2026-09-10T14:00:00Z",
  "pickup_until": "2026-09-10T15:00:00Z"
}
```

- `food_type`: `vegetarian | vegan | non_veg | other`
- `unit`: `meal_boxes | servings | kilograms`
- `prepared_when`: `just_prepared | earlier_today | yesterday | other`
- `source`: `home | event`, optional
- **`weight_kg` is optional.** The Give UI does not collect it, and requiring it would break
  that flow. Zero-Waste tier routing is weight-based, so a fallback stage must obtain it before
  routing a listing — it is not required to publish.
- **Coordinates are required.** Explore is entirely a `$near` query, so a listing without a
  point is one nobody can find. The client supplies the device position at publish time.

**201** → a listing detail. **409** when the safety confirmation is missing or the pickup
window has already closed. **422** on validation.

The new listing opens at lifecycle state `published`, chosen by the server from
`app/shared/lifecycle.py`. Emits a `listing_created` activity event.

### `GET /api/v1/listings/nearby`

Backs Explore. Returns only listings that can still be claimed — lifecycle state in
`{published, searching}` **and** `expires_at` in the future — nearest first, via `$nearSphere`
on the `geo_pickup_location` 2dsphere index.

| Query | Default | Notes |
|---|---|---|
| `lat`, `lng` | required | |
| `radius_km` | 5 | max 50 |
| `food_type` | – | repeatable |
| `source` | – | `home` or `event` |
| `limit` | 20 | max 50 |
| `offset` | 0 | |

**200** → `{ "items": [...], "limit": 20, "offset": 0, "has_more": false }`.
`has_more` is computed by fetching one extra row; there is no `total`, because counting every
match on each page is expensive and nothing in the UI shows one.

### `GET /api/v1/listings/mine`

The caller's own listings, newest first (`by_owner_created`). Optional repeatable `status`
filter, plus `limit`/`offset`. Unlike `/nearby`, this **includes** completed, cancelled and
expired listings — the Activity History tab exists to show them.

### `GET /api/v1/listings/{id}`

One listing, with `description`, `tags`, `prepared_note` and `weight_kg`. **404** if unknown.

`is_available` reports whether it can still be claimed, so the detail screen can show a stale
listing honestly rather than pretending.

### `POST /api/v1/listings/{id}/cancel`

Owner only. Optional `{ "reason": "..." }`. Permitted only while the listing is `published` or
`searching` — legality comes from `LISTING_TRANSITIONS`, not a rule restated here. Once a
rescuer has claimed it, the listing is `matched` and withdrawal becomes a rescue-side
cancellation, so this returns **409**. **403** for a non-owner. Emits a `listing_cancelled`
event.

### Listing response fields

`id`, `reference`, `title`, `food_name`, `food_type`, `category`, `quantity`, `unit`,
`quantity_label`, `servings`, `status`, `urgency`, `pickup_from`, `pickup_until`, `expires_at`,
`pickup_location`, `distance_km` (`/nearby` only), `shared_by`, `shared_by_verified`, `source`,
`source_kind`, `photo_url`, `is_live`, `is_available`, `created_at`.

`owner_user_id` and `partner_id` are **never** exposed — the publisher appears as a display
name only. The projection is an explicit allowlist, so a field added to storage cannot leak
into a response by default.

**`urgency` (`available | expiring | critical | scheduled`) is computed on every read** from
the pickup window against the current time, and is never stored. Storing it would guarantee it
goes stale between the write and the next read.

### Not implemented, deliberately

- **No `PATCH /listings/{id}`.** Nothing in the app edits a published listing — the Give flow's
  edit actions all operate on the in-memory draft before publishing.
- **No draft endpoints.** The partner Drafts tab exists, but no UI creates a draft.
- **No photo upload.** The Give flow keeps a local file path; there is no upload surface yet.

---

## `/rescues` — Stage E (tap-to-claim)

All endpoints require authentication. Claiming requires a **consumer** account: a partner is a
business publishing surplus, not collecting it.

### `POST /api/v1/rescues`

```json
{ "listing_id": "68c0f1a2b3c4d5e6f7a8b9c0" }
```

The listing id is the **only** field accepted. Rescuer identity comes from the session,
timestamps from the server clock, and the opening lifecycle state from `lifecycle.py`. Sending
`rescuer_id`, `status`, `created_at` or `reference` is a `422`.

**201** → a rescue. The listing becomes `matched` and carries `active_rescue_id`.

| Status | When |
|---|---|
| 404 | The listing does not exist |
| 409 | Already claimed, withdrawn, expired, or otherwise not claimable |
| 409 | You published the listing yourself |
| 403 | Partner account |
| 422 | Malformed listing id, or a forged field |

#### The atomic claim

The claim is **one** `find_one_and_update` on the listing:

```python
find_one_and_update(
    {"_id": listing_id, "status": {"$in": LISTING_CLAIMABLE_STATES}, "expires_at": {"$gt": now}},
    {"$set": {"status": "matched", "active_rescue_id": rescue_id}},
    return_document=False,
)
```

MongoDB applies the condition and the write as one indivisible operation, so of two consumers
tapping Rescue in the same millisecond exactly one matches a claimable document. The other
matches nothing, receives `409`, and **no rescue is created for it**.

The read-check-write alternative is not used: it leaves a window in which both requests see
"available", both proceed, and the surplus is promised twice.

#### Consistency without transactions

Claiming touches two collections. The order guarantees no interleaving can produce a rescue
without a claimed listing:

1. The rescue id is minted **before** either write.
2. The listing is claimed atomically, stamped with that id.
3. The rescue document is inserted with that id.
4. If step 3 fails, step 2 is **compensated** — the listing is released back to the status it
   held, guarded on `active_rescue_id` so a later legitimate claim is never clobbered.

The worst case is a listing briefly `matched` with no rescue, invisible to users and corrected
immediately. The inverse cannot occur. `uniq_active_rescue_per_listing` — still a *partial*
unique index over non-terminal statuses — is the independent second line of defence.

No transaction is used, because correctness here does not need one and Atlas has not been
reachable to verify session support.

### `GET /api/v1/rescues/mine`

The caller's own rescues, newest first. `?active=true` limits to rescues still running.
`limit` (max 50) and `offset`.

### `GET /api/v1/rescues/{id}`

One rescue. Another account's rescue returns **404, not 403** — a rescue id is not public, so
confirming that one exists would leak something the caller had no way to know. (Listings are
the opposite: their ids are public, so they use 403.)

### `POST /api/v1/rescues/{id}/on-the-way`

`matched → onTheWay`. Rescuer only; **404** for anyone else, **409** if already past that point.

**Confirmed explicitly by the rescuer, never inferred from the maps hand-off.** Opening a maps
app proves only that someone looked at a route. Until the rescuer confirms, the rescue stays
`matched` and the listing stays claimed but unstarted.

### `POST /api/v1/rescues/{id}/cancel`

Optional `{ "reason": "..." }`. Legal from `matched` or `onTheWay`. The listing returns to the
pool as `searching` — it has been offered once, so it re-enters actively looking. Because the
rescue index is partial, the cancelled rescue stops occupying the listing and another consumer
can claim it.

### Rescue response

```json
{
  "id": "…", "reference": "FL-20481",
  "status": "matched", "stage": "confirmed", "is_active": true,
  "distance_km": null, "cancel_reason": null,
  "created_at": "…", "updated_at": "…",
  "listing": {
    "id": "…", "reference": "FL-20481", "title": "25 Meal Boxes",
    "category": "Vegetarian", "quantity_label": "Approx. 25 servings", "servings": 25,
    "pickup_location": { "label": "…", "locality": "…", "latitude": 0, "longitude": 0 },
    "pickup_from": "…", "pickup_until": "…",
    "shared_by": "Asha Rao", "shared_by_verified": false,
    "description": "…", "tags": []
  }
}
```

`status` is the canonical lifecycle value and is authoritative. `stage` is the mobile stepper's
five-step projection of it, computed server-side by `lifecycle.py` so the clients cannot
disagree. No account identifiers appear anywhere — the publisher is a display name only.

### Lifecycle states used

`matched` (on claim) → `onTheWay`, and `cancelled` from either. Every transition is checked
against `RESCUE_TRANSITIONS`; there is no second table.

## Handover verification & completion — Stage F

The lifecycle rule that **collection cannot bypass verification** is preserved, not weakened.
A rescuer can never self-declare that they collected the food; someone must attest that it
actually changed hands.

### Who may confirm a handover

Answered from fields the data model already carries — nothing was invented:

| Actor | Rule |
|---|---|
| **The listing's owner** | `listings.owner_user_id`, set on *every* listing. For a consumer-published listing this is that consumer — the person actually handing the food over. |
| **A colleague at the owning business** | a user whose `users.partner_id` equals `listings.partner_id`. A restaurant's surplus is rarely handed over by whoever posted it. |
| **The rescuer** | refused, first and unconditionally. |
| **Anyone else** | 403. |

`partner_id` is read from the authenticated user record, never from the request, so it cannot
be forged.

### The code

Six digits, generated with `secrets` when the rescuer marks arrival — not at claim time, so it
exists only in the window it is needed.

**Direction matters:** the server returns the plaintext **to the rescuer only**, in the
`/arrived` response. The rescuer reads it out; the **owner** types it into `/verify`. That is
what the code proves — that the two are standing together. A code the owner already knew would
prove nothing about the rescuer being present.

Only a bcrypt hash is stored. Be clear about what that does and does not buy: six digits is
~20 bits, so an attacker who steals the hash can exhaust it offline regardless of cost factor.
The hash limits dump exposure; the protections that make the code safe are:

- **30-minute expiry**
- **5-attempt cap**, counted with an atomic `$inc` so parallel guesses cannot walk past it
- **single use** — the hash is cleared in the same write that verifies
- **the lifecycle state guard**, which is the real replay protection

### `POST /api/v1/rescues/{id}/arrived`

Rescuer only. `onTheWay → arrived`. Returns the rescue with `handover_code` and
`handover_code_expires_at` populated — the one and only time the plaintext appears.

### `POST /api/v1/rescues/{id}/verify`

Owner (or owning-business colleague). Body `{ "code": "481920" }`. `arrived → verified`.

| Status | When |
|---|---|
| 403 | Wrong code; rescuer attempting to verify; unrelated account |
| 409 | Not in `arrived`; code expired; attempt cap reached; already confirmed |
| 422 | Code not six digits, or a privileged field supplied |

Replay is impossible: the transition is a conditional update expecting `arrived`, so of two
simultaneous verifications with the same valid code exactly one succeeds and one audit entry is
written.

### `POST /api/v1/rescues/{id}/collected`

Rescuer only. `verified → collected → completed`, and the listing follows
`matched → collected → completed`.

**Completion is not a separate endpoint.** Once the owner has confirmed and the rescuer has the
food, no actor remains to advance it, so `completed` is applied internally in the same call
rather than exposed as a button nobody would press. Calling this before verification returns
409 with a message naming what is missing.

### Lifecycle states used

`matched → onTheWay → arrived → verified → collected → completed`, plus `cancelled`. Every
transition is checked against `RESCUE_TRANSITIONS`. No second state machine, and the
`arrived → collected` guard remains in place.

### Activity events

`rescue_created`, `rescue_ontheway`, `rescue_arrived`, `rescue_verified`, `rescue_collected`,
`rescue_completed` — one per successful transition. `rescue_verified` records the **owner** as
the actor, not the rescuer, which is what makes the audit trail answer "who confirmed this".
A failed verification writes no lifecycle event.

### `GET /api/v1/rescues/for-listing/{listing_id}` — Stage G

How an owner **finds** the rescue they are being asked to confirm. `GET /rescues/{id}` is
scoped to the rescuer, so without this an owner had no way to reach the handover at all.

Authorised by the same rule as `/verify` (owner, or a colleague at the owning business). The
handover code is never included — an owner who could read the code would make the step
meaningless. **404** when nobody is currently rescuing the listing.

### Notification integration point (not built)

When a rescue reaches `arrived`, the owner has no way to learn that someone is waiting. That is
where a "confirm the handover" notification belongs. No notification infrastructure was built
in this stage.

### Still not implemented, deliberately

Problem reports, rescuer location pings, reassignment, delivery, and anything volunteer-shaped.
User impact tallies (`users.impact`) are not incremented on completion — the My Impact screen
is still fixture-backed.

---

## Designed, not implemented

### Email verification and password reset

The screens exist (`/verify-email`, `/forgot-password`) and `users.email_verified` is stored,
but **no endpoints are built**: delivering a code or a reset link needs an email provider, and
none is configured. Rather than invent a fake one, the boundary is left clean.

To finish these, configure an email provider and add: `POST /auth/verify-email`,
`POST /auth/resend-verification`, `POST /auth/forgot-password`, `POST /auth/reset-password`.
Login is deliberately **not** gated on `email_verified` — gating it before delivery works would
lock every account out.

---

## Planned endpoints

Documented here as they are built.

| Phase | Prefix | Purpose |
|---|---|---|
| 4 | `/users` | profile, location, impact, devices |
| 10 | `/fallback` | fallback cases, partners, transfers |
| 12 | `/notifications` | list, mark read, register push token |
| 14 | `/ops` | dashboard metrics, live operations, escalations |

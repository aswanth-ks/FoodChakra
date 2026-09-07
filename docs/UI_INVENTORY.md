# UI Inventory — Stitch to Flutter

Maps every approved Stitch screen to its Flutter route, screen class, and the shared widgets
it uses. **Populated in Phase 4**, once the designs are accessible (blocker B2).

Purpose: guarantee that a component appearing on several screens is built **once**.

---

## Status

| | |
|---|---|
| Designs accessible | No — Stitch MCP server not configured |
| Screens inventoried | 0 |
| Shared components extracted | 3 (state widgets only) |

---

## Route map

| Stitch screen | Route | Screen class | Shared widgets | Status |
|---|---|---|---|---|
| _(temporary)_ Health | `/` | `HealthScreen` | Loader, Empty, Error | Scaffolding — delete in Phase 4 |
| _pending_ | | | | |

---

## Shared component library

Components live in `mobile/lib/shared/widgets/`. Anything used on more than one screen
belongs here.

### Built

| Component | File | Purpose |
|---|---|---|
| `LoaderView` | `loader_view.dart` | The app's single loading indicator |
| `EmptyStateView` | `empty_state_view.dart` | Successful but empty result |
| `ErrorStateView` | `error_state_view.dart` | Failure message + retry, icon per failure type |

### Expected from the designs

Derived from the brief; confirmed against the real screens in Phase 4.

| Component | Used by | Notes |
|---|---|---|
| `AppTopBar` | most screens | Title, back, actions |
| `FoodCard` | receiver browse, donor list, volunteer opportunities | The most reused component |
| `DonationCard` | donor home, history | Status + expiry emphasis |
| `StatusBadge` | everywhere | One colour per donation/rescue status |
| `PrimaryButton` | forms, actions | Wraps the themed `FilledButton` |
| `AppBottomNav` | role home screens | Tabs differ per role |
| `AppTextField` | all forms | Themed input + validation display |
| `LocationPicker` | create donation, onboarding | Map + address search |
| `QuantityInput` | create donation | Amount + unit |
| `TimeWindowPicker` | create donation | Pickup window |
| `UrgencyIndicator` | food cards, details | Derived from expiry |

---

## Working rules

1. **Match** layout, spacing, typography, hierarchy, component behavior, navigation, and
   responsive behavior.
2. **Do not** blindly copy poor implementation patterns from generated UI — translate the
   design into clean Flutter architecture.
3. If a component appears on multiple screens, build it once and list it above.
4. Never hardcode a colour or spacing value; use the tokens in `lib/app/theme/`.
5. Every screen passes `docs/PAGE_CHECKLIST.md` before it is called complete.

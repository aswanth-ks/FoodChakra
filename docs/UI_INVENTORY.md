# UI Inventory — Stitch to Flutter

Maps every approved Stitch screen to its Flutter route, screen class, and shared widgets.

**Source:** Stitch MCP (`@_davideast/stitch-mcp` proxy, configured at local scope).

| Stitch project | ID | Screens |
|---|---|---|
| FoodLoop Mobile Design System | `11421962422199014836` | 46 (38 screens + 8 assets) |
| FoodLoop Operations Console | `8883198284374486482` | 2 |

Fetch any screen with:

```bash
npx @_davideast/stitch-mcp tool get_screen_code \
  -d '{"projectId":"11421962422199014836","screenId":"<id>"}'
```

---

## ⚠ Architectural divergence — must be resolved before Phase 2

The designs do **not** use the donor / receiver / volunteer role model in the project brief.
They use two roles:

| Design role | Behaviour |
|---|---|
| **Consumer** | Both *gives* surplus food (Give Surplus Food Entry → Review & Publish) **and** *rescues* it (Explore → Rescue → Active Rescue → Complete) |
| **Restaurant Partner** | Business donor: surplus management, handover verification, impact |

There is no separate "volunteer" app role — rescuing is something a Consumer does. There is
no separate "receiver organization" role either.

This changes the auth role enum (Phase 3) and the `users` schema (Phase 2). **Do not design
the database until this is decided.** See `docs/PROJECT_STATUS.md` blocker B7.

---

## Design tokens — "Verdant Precision"

Extracted from *FoodLoop Design System & Components*
(`7b3405194b8d49cebfeea99b7c5b98ff`). These replace the Phase 0 placeholders in
`mobile/lib/app/theme/`.

| Token | Hex | Design name |
|---|---|---|
| Primary | `#183B2B` | Primary Forest |
| Primary (mid) | `#436653` | — |
| Text | `#142018` | Text Ink |
| Background | `#FAF9F6` | Warm Canvas |
| Surface tint | `#FAF8F5` | — |
| Accent | `#EBF3ED` | Sage Accent |
| Accent (strong) | `#A9CFB9` / `#95D4B3` / `#B1F0CE` | — |
| Text secondary | `#727973` | — |
| Border | `#E3E2DF` | — |
| Error | `#93000A` | — |

**Typography:** Plus Jakarta Sans (400 / 500 / 600 / 700).
**Icons:** Material Symbols Outlined.
**Scale:** Display Large · Headline Medium · Title Small · Body Medium · Micro Action Label.

The design system uses Material 3 semantic naming (`on-surface-variant`), which maps cleanly
onto Flutter's `ColorScheme`.

> The Phase 0 placeholder palette (`#2E7D32` bright green, cool grey canvas) is **wrong** and
> must be replaced. Tracked as technical debt D1.

---

## Screen inventory

### Brand and system

| Screen | Screen ID | Route | Status |
|---|---|---|---|
| FoodLoop Splash Screen | `70ccef9d18be42c79eaf778a924c7738` | `/splash` | Not built |
| FoodLoop Brand Logo | `cfcf778590ed488a897baaec579bb4e9` | asset | Not built |
| Design System & Components | `7b3405194b8d49cebfeea99b7c5b98ff` | reference | Tokens extracted |

### Onboarding and auth

| Screen | Screen ID | Route | Status |
|---|---|---|---|
| Welcome & Onboarding | `862135f80727445281ad1faf328502d5` | `/onboarding` | Not built |
| Onboarding 3 — Turn Extra Food | `ccb514b6ddfe44eeb589b84ce04230ea` | `/onboarding/3` | Not built |
| Onboarding 4 — Every Rescue Counts | `2d98bc1215e347cfb850e70725115000` | `/onboarding/4` | Not built |
| Location Setup | `cce80807fdbe43e28fe84d970260b8f4` | `/onboarding/location` | Not built |
| Consumer Sign In | `266ac1989d5a4f338f57c6c51b367936` | `/login` | Not built |
| Consumer Account Creation | `2abb740e1ba741bfa7b7c6a6acdc1e7f` | `/register` | Not built |
| Consumer Email Verification | `e8885e82739a4d58a8736084dad28b36` | `/verify-email` | Built (`EmailVerificationScreen`, UI only) |
| Consumer Forgot Password | `21993dcd125d4786bb20d167e90c2747` | `/forgot-password` | Built (`ForgotPasswordScreen`, UI only) |

### Consumer — discovery and rescue

| Screen | Screen ID | Route | Status |
|---|---|---|---|
| Consumer Home | `ec02ee8746be482d8c189b1a0c8f1ae7` | `/home` | Built (`HomeScreen`, UI only) |
| Consumer Explore Food | `03d1ce15100b42a2bddce7b60f3274df` | `/explore` | Built (`ExploreScreen`, UI only) |
| Consumer Food Details | `87586e9ef13d4197977c3d229a7a4b91` | `/food/:id` | Built (`FoodDetailsScreen`, UI only) |
| Consumer Rescue Confirmation Sheet | `a1032738300c4089ab43b5b3a57ed769` | sheet | Built (`showRescueConfirmationSheet`, UI only) |
| Consumer Live Rescue Matching | `0483482c28fe4d19932a48305d8d054f` | `/give/matching` | Built |
| Consumer Rescuer Found | `e722e6e8aa6c4460b93d55a5310a6f28` | `/rescue/:id/found` | Built (`RescuerFoundScreen`, UI only) |
| Consumer Active Rescue | `8a01e8c064ff4d16ad96343f5ad4d6c4` | `/rescue/:id` | Built (`ActiveRescueScreen`, maps hand-off live) |
| Consumer Rescue Complete | `41bd3493561546c4af16f9bf8ccdc75e` | `/rescue/:id/complete` | Built (`RescueCompleteScreen`, UI only) |

### Consumer — giving surplus

| Screen | Screen ID | Route | Status |
|---|---|---|---|
| Give Surplus Food Entry | `d61ab0dfa7f8490186c40344bb801985` | `/give` | Built (`GiveEntryScreen`, UI only) |
| Surplus Food Details | `c8299f4a379940debf632c160a3602b9` | `/give/details` | Built (`SurplusDetailsScreen`, UI only) |
| Availability & Pickup | `3d47cf51ed654c5aac6fc3c7c884b342` | `/give/pickup` | Built (`AvailabilityPickupScreen`, UI only) |
| Review & Publish | `807b6f65ad7c4528a68c2ca235f4ff36` | `/give/review` | Built (`ReviewPublishScreen`, UI only) |

### Consumer — account

| Screen | Screen ID | Route | Status |
|---|---|---|---|
| Consumer Activity | `3e283e153cb14c248d37838d9255e1bb` | `/activity` | Built (`ActivityScreen`, UI only) |
| Consumer My Impact | `193a47c489864bfca7fce11800f7ce35` | `/impact` | Built (`MyImpactScreen`, UI only) |
| Consumer Profile | `1c0764bd3d524834be8cb9cb61e9900f` | `/profile` | Built (`ProfileScreen`, UI only) |

### Restaurant Partner

| Screen | Screen ID | Route | Status |
|---|---|---|---|
| Partner Home | `a28e2ad4001447d19e06b3f8c70a2f02` | `/partner` | Built |
| Partner Activity | `2a41a236575f4c2dbeeef7511838b8df` | `/partner/activity` | Not built |
| Surplus Management | `1dfcc1f17d784472998243e653639be0` | `/partner/surplus` | Built |
| Add Surplus Quick Start | `80897a01b04f4bb1af9e55365653c106` | `/partner/surplus/new` | Not built |
| Partner Availability & Pickup | `8c4434f7d9124080ac592412e0aaabc4` | `/partner/surplus/pickup` | Not built |
| Partner Review & Publish | `64bf9da70a2a4d42bad4bb8f850f0836` | `/partner/surplus/review` | Not built |
| Live Rescue Operations | `7edc7382e53b4dd1be05cb0bac68ece2` | `/partner/live` | Not built |
| Handover Verification | `13f129318c9147779ff815756bda8ae4` | `/partner/handover` | Not built |
| Handover Complete | `fcf3f61745454254bd7132edfbbadfa9` | `/partner/handover/done` | Not built |
| Partner Impact | `da7c3c26eb5e488ba3a07927496a3857` | `/partner/impact` | Not built |
| Partner Profile & Settings | `1f7164e710a2414aad68618870ccb80c` | `/partner/profile` | Not built |

### Operations Console (Phase 14 — dashboard, not Flutter)

| Screen | Project | Screen ID | Status |
|---|---|---|---|
| Overview | Mobile DS | `90a39f15d47f43faa930c9b0995e51d8` | Not built |
| Live Rescue Map | Mobile DS | `a09ee9419df34806981f38b776c5b172` | Built (`/live-rescues`) |
| Rescue Opportunity Detail | Mobile DS | `804145037efc453ab479efffe0867c56` | Built (`/live-rescues/:id`) |
| Overview | Ops Console | `6d0e54157764439abe027aefe7303a8d` | Built (`/overview`) |
| Dynamic Rescue Coverage | Mobile DS | `d944fd65322b4b6c883e39a2bac4159a` | Built (`/live-rescues/:id/coverage`) |
| Smart Escalation | Mobile DS | `04f4eb21239a4f9fa5a3c4108afcf70f` | Built (`/escalations`) |
| Rescue Queue | Mobile DS | `5f3fede2b5f74d57834db003fcfc2d66` | Built (`/rescue-queue`) |
| Analytics | Mobile DS | `425247d520024816b1f7cc5891946928` | Built (`/analytics`) |
| Restaurants | Mobile DS | `0db51c916c3441faa27126cf53fa3b05` | Not built |
| Restaurant Onboarding: Step 1 | Mobile DS | `7ef47ae53bc945adb7a1444678d3d754` | Built (`/restaurants/onboard/1`) |
| Restaurant Onboarding: Step 2 | Mobile DS | `ab93f88ddd2c4670aad9771485e0803d` | Built (`/restaurants/onboard/2`) |
| Restaurant Onboarding: Step 3 | Mobile DS | `0af8dfeeed2c44ecb8fd00e28a0f9f08` | Built (`/restaurants/onboard/3`) |
| Zero-Waste Network — Fallback Opportunity | Mobile DS | `a75b3478a61043db95d66ff928a1c838` | Not built |
| Operations Mark | Ops Console | `e5db80818371418ca387fb9eae8c31e9` | asset |
| Console Sign In | *(no design — built from console tokens)* | — | Built (`/login`) |

### Image assets (not screens)

Six AI-generated food photographs plus the brand marks. These are Stitch image generations
used inside the designs, not UI to implement. Export them as assets during Phase 4.

---

## Shared component library

Components live in `mobile/lib/shared/widgets/`. Anything used on more than one screen
belongs here.

### Built (Phase 0)

| Component | File | Purpose |
|---|---|---|
| `LoaderView` | `loader_view.dart` | The app's single loading indicator |
| `EmptyStateView` | `empty_state_view.dart` | Successful but empty result |
| `ErrorStateView` | `error_state_view.dart` | Failure message + retry |

### Built (Phase 4)

Auth chrome lives in `features/auth/presentation/widgets/auth_widgets.dart`; the consumer
rescue chrome lives in `features/rescue/presentation/widgets/rescue_widgets.dart`. Each owns
the palette its designs share (`AuthColors`, `RescueColors`).

| Component | File | Purpose |
|---|---|---|
| `AuthTextField` / `AuthPrimaryButton` / `AuthSocialButton` / `AuthDivider` / `AuthFooterPrompt` | `auth_widgets.dart` | Sign In, Create Account, Forgot Password, Email Verification |
| `ConsumerNavBar` | `shared/widgets/consumer_nav_bar.dart` | Five consumer tabs: **Home · Explore · Activity · Impact · Profile** |
| `RescueCard` / `LivePill` / `LiveDot` / `RescueChip` / `SectionHeader` / `IconTile` / `DetailRow` / `RescuePrimaryButton` / `RescueMiniButton` / `RescueIconButton` | `rescue_widgets.dart` | Home, Food Details, Confirmation Sheet, Active Rescue |
| `ListingCard` | `features/home/presentation/home_screen.dart` | Home's nearby opportunity row |
| `ExploreListingCard` | `rescue/presentation/explore_screen.dart` | Explore's result row — a distinct composition (92px photo, distance chip, ruled footer), not a variant of `ListingCard` |
| `GiveStepAppBar` / `GiveFieldLabel` / `GiveBadge` / `GiveTextField` / `GiveChoiceChip` / `GiveInfoPanel` / `GiveActionBar` | `give/presentation/widgets/give_widgets.dart` | The four give steps. Reuses `RescueColors` and `rescueFont` — the give designs share the same brand scale |
| `NearbyMap` / `RouteMap` | `rescue/presentation/widgets/stylised_map.dart` | The designs' stylised SVG maps, as `CustomPainter`s. **Phase 8 replaces both with a real map.** |

### Identified in the designs — still to build

| Component | Seen on | Notes |
|---|---|---|
| `StatusBadge` | throughout | States seen: **Reserved · Confirmed · Ready · Active Handshake · Live Context** |
| `MapDiscoveryModule` | Explore, Live Rescue Map | "Spatial Hub" map card |
| `HandoverPinDisplay` | Handover Verification | "Store Handshake PIN" |
| `ImpactStatTile` | My Impact, Partner Impact | "Surplus Rescued", "Weekly Diverted Food Goal", "Target Met" |
| `ProgressGoalBar` | Impact screens | Weekly goal progress |
| `AppTextField` | all forms | Themed input + validation |
| `PrimaryButton` | throughout | Wraps themed `FilledButton` |
| `LocationPicker` | Location Setup, pickup screens | Map + address search |

---

## Working rules

1. **Match** layout, spacing, typography, hierarchy, component behavior, and navigation.
2. **Do not** copy generated-UI implementation patterns — translate into clean Flutter
   architecture. Stitch emits Tailwind HTML; that is a visual reference, not a code source.
3. If a component appears on multiple screens, build it once and list it above.
4. Never hardcode a colour or spacing value; use the tokens in `lib/app/theme/`.
5. Every screen passes `docs/PAGE_CHECKLIST.md` before it is called complete.

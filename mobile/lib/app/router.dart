import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/account.dart';
import '../features/auth/domain/account_role.dart';
import '../features/auth/presentation/auth_providers.dart';
import '../core/error/failures.dart';
import '../features/auth/presentation/create_account_screen.dart';
import '../features/auth/presentation/email_verification_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/give/domain/surplus_draft.dart';
import '../features/give/presentation/availability_pickup_screen.dart';
import '../features/give/presentation/give_entry_screen.dart';
import '../features/give/presentation/live_matching_screen.dart';
import '../features/give/presentation/review_publish_screen.dart';
import '../features/give/presentation/surplus_details_screen.dart';
import '../features/health/presentation/health_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/impact_screen.dart';
import '../features/partner/presentation/partner_home_screen.dart';
import '../features/partner/domain/partner_dashboard.dart';
import '../features/partner/presentation/partner_surplus_providers.dart';
import '../features/partner/presentation/partner_surplus_screen.dart';
import '../features/onboarding/presentation/location_setup_screen.dart';
import '../features/onboarding/presentation/share_surplus_screen.dart';
import '../features/onboarding/presentation/welcome_screen.dart';
import '../features/give/data/surplus_draft_mapper.dart';
import '../features/rescue/domain/food_listing.dart';
import '../features/rescue/domain/rescue.dart';
import '../features/rescue/presentation/listing_providers.dart';
import '../features/rescue/presentation/active_rescue_view.dart';
import '../features/rescue/presentation/explore_view.dart';
import '../features/rescue/presentation/activity_providers.dart';
import '../features/rescue/presentation/impact_providers.dart';
import '../features/rescue/presentation/handover_confirmation_view.dart';
import '../features/rescue/presentation/rescue_providers.dart';
import '../shared/widgets/error_state_view.dart';
import '../shared/widgets/loader_view.dart';
import '../features/rescue/presentation/activity_screen.dart';
import '../features/rescue/presentation/food_details_screen.dart';
import '../features/rescue/presentation/my_impact_screen.dart';
import '../features/rescue/presentation/profile_screen.dart';
import '../features/rescue/presentation/rescue_complete_screen.dart';
import '../features/rescue/presentation/rescuer_found_screen.dart';
import '../features/rescue/presentation/widgets/rescue_confirmation_sheet.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'session_gate.dart';
import '../features/rescue/domain/activity_item.dart';
import '../shared/widgets/consumer_nav_bar.dart';
import '../shared/widgets/partner_nav_bar.dart';

/// Named route paths. Screens navigate with these constants, never string
/// literals, so a path change is a one-line edit.
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';

  /// Temporary Phase 0 connectivity screen. Removed once real screens land.
  static const String health = '/health';

  // Onboarding
  static const String welcome = '/onboarding/welcome';
  static const String shareSurplus = '/onboarding/share';
  static const String impact = '/onboarding/impact';
  static const String locationSetup = '/onboarding/location';

  // Phase 3
  static const String login = '/login';
  static const String register = '/register';
  static const String createAccount = '/create-account';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String verifyEmail = '/verify-email';

  // Consumer discovery and rescue
  static const String home = '/home';
  static const String explore = '/explore';
  static const String activity = '/activity';

  /// Distinct from [impact], which is the onboarding screen.
  static const String myImpact = '/impact';
  static const String profile = '/profile';

  // Give surplus, a four-step flow. The draft travels in the route's `extra`.
  static const String give = '/give';
  static const String giveDetails = '/give/details';
  static const String givePickup = '/give/pickup';
  static const String giveReview = '/give/review';

  /// Where a published surplus lands while it waits for a rescuer.
  static const String giveMatching = '/give/matching';
  static const String foodDetails = '/food/:id';
  static const String activeRescue = '/rescue/:id';
  static const String rescuerFound = '/rescue/:id/found';
  static const String rescueComplete = '/rescue/:id/complete';

  /// The food owner's handover confirmation, keyed by the listing they own.
  static const String handover = '/handover/:id';

  static String foodDetailsFor(String id) => '/food/$id';
  static String activeRescueFor(String id) => '/rescue/$id';
  static String rescuerFoundFor(String id) => '/rescue/$id/found';
  static String rescueCompleteFor(String id) => '/rescue/$id/complete';
  static String handoverFor(String listingId) => '/handover/$listingId';

  // Restaurant partner. Reached by signing in with a partner account, never
  // by signing up — access is granted from the ops console.
  static const String partnerHome = '/partner';
  static const String partnerSurplus = '/partner/surplus';
  static const String partnerActivity = '/partner/activity';
  static const String partnerImpact = '/partner/impact';
  static const String partnerProfile = '/partner/profile';

  // Phase 5-7 role home routes
  static const String donorHome = '/donor';
  static const String receiverHome = '/receiver';
  static const String volunteerHome = '/volunteer';
}

/// The `:id` path parameter shared by the food and rescue routes.
String listingId(GoRouterState state) => state.pathParameters['id'] ?? '';

/// The `:id` on the rescue routes, which carries a **rescue** id from Stage E
/// onward — the screens there render a rescue, not a listing.
String rescueId(GoRouterState state) => state.pathParameters['id'] ?? '';

/// Reads the surplus draft a give step was pushed with, falling back to an
/// empty draft when the route is opened directly (a deep link, or `--route`).
SurplusDraft giveDraft(GoRouterState state) => state.extra is SurplusDraft
    ? state.extra! as SurplusDraft
    : const SurplusDraft();

/// Where an account lands after authenticating.
///
/// One sign-in screen serves both apps; the account's role picks the home.
String homeForRole(AccountRole role) =>
    role.isPartner ? AppRoutes.partnerHome : AppRoutes.home;

/// Runs an authentication call, then routes by the role the **server**
/// returned.
///
/// The role is never derived from the submitted email: it arrives on the
/// authenticated session. A `Failure` is surfaced on a snackbar, because the
/// auth screens take plain callbacks and have no error slot of their own.
/// Runs an unauthenticated auth call, showing the server's message on failure.
///
/// Registration, verification and password reset all produce no session, so
/// they cannot go through [_authenticateThen]. Returns whether the server
/// accepted it, so a screen can wait for the real answer instead of assuming
/// the tap worked.
Future<bool> _authAction(
  BuildContext context,
  Future<void> Function() action, {
  String? successMessage,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await action();
    if (successMessage != null) {
      messenger?.showSnackBar(SnackBar(content: Text(successMessage)));
    }
    return true;
  } on Failure catch (failure) {
    // The backend's wording, whatever went wrong. It is deliberately vague
    // about codes ("not valid or has expired") and about whether an address
    // is registered, and repeating it verbatim keeps it that way.
    messenger?.showSnackBar(SnackBar(content: Text(failure.message)));
    return false;
  }
}

Future<void> _authenticateThen(
  BuildContext context,
  Ref ref,
  Future<Account> Function() action, {
  String Function(Account account)? destination,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final account = await action();
    if (!context.mounted) return;
    context.go((destination ?? (a) => homeForRole(a.role))(account));
  } on EmailNotVerifiedFailure catch (failure) {
    // The password was right; the address was never confirmed. Sending the
    // user to the code screen is the only useful thing to do, and no session
    // exists to clean up because the server issued none.
    if (!context.mounted) return;
    messenger?.showSnackBar(SnackBar(content: Text(failure.message)));
    context.go(_verifyEmailFor(_lastAttemptedEmail));
  } on Failure catch (failure) {
    messenger?.showSnackBar(SnackBar(content: Text(failure.message)));
  }
}

/// The address of the most recent sign-in attempt.
///
/// Needed because the failure comes back from the notifier, not the form, and
/// the verification screen has to know which address to talk about. It is a
/// display value only — nothing authorises anything from it.
String _lastAttemptedEmail = '';

String _verifyEmailFor(String email) => Uri(
  path: AppRoutes.verifyEmail,
  queryParameters: {'email': email},
).toString();

String _resetPasswordFor(String email) => Uri(
  path: AppRoutes.resetPassword,
  queryParameters: {'email': email},
).toString();

/// Publishes a Give draft, then opens its live matching screen.
///
/// The pickup point's coordinates come from the device, not the form: the
/// Give UI collects a place *name* ("Community Hall"), and Explore is a
/// geospatial query, so a listing with no point is one nobody could ever find.
Future<bool> _publishDraft(
  BuildContext context,
  Ref ref,
  SurplusDraft draft,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final origin = await ref.read(currentOriginProvider.future);
    await ref
        .read(listingRepositoryProvider)
        .create(
          draft.toNewListing(
            latitude: origin.latitude,
            longitude: origin.longitude,
          ),
        );
    // Explore and the owner's own lists must show the new listing.
    ref.invalidate(nearbyListingsProvider);
    ref.invalidate(myListingsProvider);
    return true;
  } on Failure catch (failure) {
    messenger?.showSnackBar(SnackBar(content: Text(failure.message)));
    return false;
  }
}

/// Claims a listing, then opens the Rescuer Found screen for the new rescue.
///
/// A refused claim is the normal case, not an error: someone else got there
/// first. The backend answers 409 and the message it returns is what the user
/// sees, so the wording stays in one place.
Future<void> _claimListing(
  BuildContext context,
  WidgetRef ref,
  String listingId,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final rescue = await ref.read(rescueRepositoryProvider).claim(listingId);
    // The listing has left the pool, so Explore must not keep showing it.
    ref.invalidate(nearbyListingsProvider);
    ref.invalidate(myRescuesProvider);
    if (!context.mounted) return;
    context.push(AppRoutes.rescuerFoundFor(rescue.id));
  } on Failure catch (failure) {
    messenger?.showSnackBar(SnackBar(content: Text(failure.message)));
  }
}


/// Confirms collection, completing the rescue.
///
/// Fails with a clear message until the owner has confirmed the handover —

/// Renders an async provider through the shared loading / error views.
///
/// The screens themselves take plain data, exactly as designed, so connecting
/// one to the API is this wrapper rather than a change to the screen.
Widget _asyncView<T>(
  AsyncValue<T> value,
  Widget Function(T value) builder, {
  VoidCallback? onRetry,
}) => value.when(
  loading: () => const LoaderView(),
  error: (error, _) => ErrorStateView(error: error, onRetry: onRetry),
  data: builder,
);

/// Partner bottom-nav routing. Only Home has a screen so far; the other four
/// tabs stay inert until theirs are built.
void onPartnerTab(BuildContext context, PartnerTab tab) => switch (tab) {
  PartnerTab.home => context.go(AppRoutes.partnerHome),
  PartnerTab.surplus => context.go(AppRoutes.partnerSurplus),
  PartnerTab.activity => null,
  PartnerTab.impact => null,
  PartnerTab.profile => null,
};

/// Bottom-nav routing. Only Home and Explore have screens so far; the other
/// three tabs stay inert until theirs are built.
void onConsumerTab(BuildContext context, ConsumerTab tab) => switch (tab) {
  ConsumerTab.home => context.go(AppRoutes.home),
  ConsumerTab.explore => context.go(AppRoutes.explore),
  ConsumerTab.activity => context.go(AppRoutes.activity),
  ConsumerTab.impact => context.go(AppRoutes.myImpact),
  ConsumerTab.profile => context.go(AppRoutes.profile),
};

/// The single authentication gate.
///
/// Every decision about whether a screen may be shown is made here, once.
/// Screens do not check for a session, API failures do not push `/login`, and
/// nothing navigates imperatively out of an interceptor.
///
/// It answers exactly one question — *does a session exist?* — and never asks
/// what that session is allowed to do. Role, account status, permissions and
/// staff capability are the backend's to enforce; a router that decided them
/// locally would be deciding them from data the client controls.
String? _authRedirect(Ref ref, GoRouterState state) {
  final auth = ref.read(authControllerProvider);
  final location = state.matchedLocation;

  // `hasValue` distinguishes the first restore from a later refresh: an
  // in-flight sign-out should not throw the user back onto the splash screen.
  final restoring = auth.isLoading && !auth.hasValue;
  final account = auth.value;
  final signedIn = account != null;

  if (location == AppRoutes.splash) {
    // Hold the splash until the animation has rested *and* the restore has
    // settled. A restore that fails leaves `account` null, which is the same
    // answer as never having signed in — the user goes to onboarding.
    if (!ref.read(splashGateProvider) || restoring) return null;
    return signedIn ? homeForRole(account.role) : AppRoutes.welcome;
  }

  // Deep links and cold starts can reach a route before the restore finishes.
  // Sending them back to the splash screen is what makes the guard reliable:
  // otherwise a returning user would be bounced to sign-in for the fraction of
  // a second before their own session arrives.
  if (restoring) {
    return isProtectedRoute(location) ? AppRoutes.splash : null;
  }

  if (!signedIn && isProtectedRoute(location)) return AppRoutes.login;

  if (signedIn && kUnauthenticatedOnlyRoutes.contains(location)) {
    return homeForRole(account.role);
  }

  return null;
}

/// Re-runs the router's redirect whenever the session or the splash gate
/// changes, so signing out takes effect immediately and everywhere.
class _RouterRefresh extends ChangeNotifier {
  void bump() => notifyListeners();
}

/// App router.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authControllerProvider, (_, _) => refresh.bump());
  ref.listen(splashGateProvider, (_, _) => refresh.bump());
  ref.onDispose(refresh.dispose);

  // Starts the restore at launch rather than when a screen first happens to
  // read it, so the gate has an answer as early as possible.
  ref.read(authControllerProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: refresh,
    redirect: (context, state) => _authRedirect(ref, state),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        // The splash no longer chooses a destination. It only reports that
        // its animation has finished; `_authRedirect` decides where to go
        // once the session restore has also settled.
        builder: (context, state) => SplashScreen(
          onComplete: () => ref.read(splashGateProvider.notifier).markComplete(),
        ),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        name: 'welcome',
        builder: (context, state) => WelcomeScreen(
          onGetStarted: () => context.push(AppRoutes.shareSurplus),
          onSignIn: () => context.push(AppRoutes.login),
        ),
      ),
      GoRoute(
        path: AppRoutes.shareSurplus,
        name: 'shareSurplus',
        builder: (context, state) => ShareSurplusScreen(
          onContinue: () => context.push(AppRoutes.impact),
          onSignIn: () => context.push(AppRoutes.login),
        ),
      ),
      GoRoute(
        path: AppRoutes.impact,
        name: 'impact',
        builder: (context, state) => ImpactScreen(
          onSignIn: () => context.push(AppRoutes.login),
          onStartRescuing: () => context.push(AppRoutes.locationSetup),
        ),
      ),
      GoRoute(
        path: AppRoutes.locationSetup,
        name: 'locationSetup',
        builder: (context, state) => LocationSetupScreen(
          onBack: () => context.canPop() ? context.pop() : null,
          // Whatever the location outcome, a new user lands on account
          // creation next — there is no further onboarding screen.
          onContinue: (_) => context.go(AppRoutes.createAccount),
        ),
      ),
      GoRoute(
        path: AppRoutes.createAccount,
        name: 'createAccount',
        builder: (context, state) => CreateAccountScreen(
          onBack: () => context.canPop() ? context.pop() : null,
          onSignIn: () => context.push(AppRoutes.login),
          // Registers a consumer account and asks the server to email a
          // code. No session is created, so this cannot go through
          // `_authenticateThen`. The verification screen is only opened if
          // the server actually accepted the registration — a 503 means the
          // email never went out, and waiting for it would be pointless.
          onCreateAccount: (name, email, password) async {
            final created = await _authAction(
              context,
              () => ref
                  .read(authControllerProvider.notifier)
                  .register(
                    fullName: name,
                    email: email,
                    password: password,
                  ),
            );
            if (!created || !context.mounted) return;
            context.go(_verifyEmailFor(email));
          },
          // Skip / Google / Apple / Terms / Privacy stay inert until the
          // Phase 3 auth service exists.
        ),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        name: 'verifyEmail',
        builder: (context, state) => EmailVerificationScreen(
          email: state.uri.queryParameters['email'] ?? '',
          onBack: () => context.canPop() ? context.pop() : null,
          onChangeEmail: () => context.canPop() ? context.pop() : null,
          // The code is checked by the backend against a hash it stored at
          // registration. It is single use, expires, and is capped at a few
          // attempts; nothing about it is known to this client.
          //
          // Verification issues no session — proving the address is not the
          // same as proving the password — so the user signs in next.
          onVerify: (code) async {
            final verified = await _authAction(
              context,
              () => ref
                  .read(authControllerProvider.notifier)
                  .verifyEmail(
                    email: state.uri.queryParameters['email'] ?? '',
                    code: code,
                  ),
              successMessage: 'Email verified. Sign in to continue.',
            );
            if (!verified || !context.mounted) return;
            context.go(AppRoutes.login);
          },
          onResend: () => _authAction(
            context,
            () => ref
                .read(authControllerProvider.notifier)
                .resendVerification(
                  state.uri.queryParameters['email'] ?? '',
                ),
            successMessage: 'A new code is on its way.',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => _asyncView<List<FoodListing>>(
            ref.watch(nearbyListingsProvider),
            (listings) => HomeScreen(
              // The signed-in account's own name, not a hardcoded one.
              userName: ref.watch(authControllerProvider).value?.fullName
                  .split(' ')
                  .first ??
                  'there',
              // The locality of the nearest listing is the honest answer to
              // "where are you looking?"; the account carries no locality yet.
              location: listings.isEmpty
                  ? 'Near you'
                  : (listings.first.pickupLocality ?? 'Near you'),
              listings: listings,
              opportunityCount: listings.length,
              nearestDistanceLabel: listings.isEmpty
                  ? 'Nothing nearby right now'
                  : 'Nearest: ${listings.first.distanceLabel}',
              mealsRescued:
                  ref.watch(completedRescueCountProvider).value ?? 0,
              // Left unknown on purpose — no listing carries a weight.
              foodDivertedKg: null,
              onOpenListing: (listing) =>
                  context.push(AppRoutes.foodDetailsFor(listing.id)),
          // All three routes into discovery land on Explore.
          onRescueFood: () => context.go(AppRoutes.explore),
          onExploreNearby: () => context.go(AppRoutes.explore),
          onSeeAll: () => context.go(AppRoutes.explore),
          onGiveFood: () => context.push(AppRoutes.give),
          onViewImpact: () => context.push(AppRoutes.myImpact),
              onSelectTab: (tab) => onConsumerTab(context, tab),
              // The notification bell stays inert: there is no notification
              // system, and a bell that opens an empty list would imply one.
            ),
            onRetry: () => ref.invalidate(nearbyListingsProvider),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.explore,
        name: 'explore',
        builder: (context, state) => ExploreView(
          onOpenListing: (listing) =>
              context.push(AppRoutes.foodDetailsFor(listing.id)),
          onSelectTab: (tab) => onConsumerTab(context, tab),
        ),
      ),
      GoRoute(
        path: AppRoutes.foodDetails,
        name: 'foodDetails',
        builder: (context, state) {
          final id = listingId(state);
          return Consumer(
            builder: (context, ref, _) => _asyncView<FoodListing>(
              ref.watch(listingDetailProvider(id)),
              (listing) => FoodDetailsScreen(
                listing: listing,
                onBack: () => context.canPop() ? context.pop() : null,
                onRescue: () async {
                  final confirmed = await showRescueConfirmationSheet(
                    context,
                    listing: listing,
                  );
                  if (!(confirmed ?? false)) return;
                  if (!context.mounted) return;
                  await _claimListing(context, ref, listing.id);
                },
              ),
              onRetry: () => ref.invalidate(listingDetailProvider(id)),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.give,
        name: 'give',
        builder: (context, state) => GiveEntryScreen(
          draft: giveDraft(state),
          onBack: () => context.canPop() ? context.pop() : null,
          onContinue: (draft) =>
              context.push(AppRoutes.giveDetails, extra: draft),
        ),
      ),
      GoRoute(
        path: AppRoutes.giveDetails,
        name: 'giveDetails',
        builder: (context, state) => SurplusDetailsScreen(
          draft: giveDraft(state),
          onBack: () => context.canPop() ? context.pop() : null,
          onContinue: (draft) =>
              context.push(AppRoutes.givePickup, extra: draft),
        ),
      ),
      GoRoute(
        path: AppRoutes.givePickup,
        name: 'givePickup',
        builder: (context, state) => AvailabilityPickupScreen(
          draft: giveDraft(state),
          onBack: () => context.canPop() ? context.pop() : null,
          onContinue: (draft) =>
              context.push(AppRoutes.giveReview, extra: draft),
          // Choosing a different pickup point needs the Phase 8 map.
        ),
      ),
      GoRoute(
        path: AppRoutes.giveReview,
        name: 'giveReview',
        builder: (context, state) => ReviewPublishScreen(
          draft: giveDraft(state),
          onBack: () => context.canPop() ? context.pop() : null,
          // Edit walks back up the stack to the step that owns the field.
          onEditFood: () => context.pop(),
          onEditPickup: () => context.pop(),
          // The API call and the navigation are deliberately separate: the
          // screen shows its confirmation state only after the server accepted
          // the listing. The form steps are then dropped from the stack so
          // Back leaves the flow.
          onPublish: (draft) => _publishDraft(context, ref, draft),
          onPublished: () =>
              context.go(AppRoutes.giveMatching, extra: giveDraft(state)),
        ),
      ),
      GoRoute(
        path: AppRoutes.giveMatching,
        name: 'giveMatching',
        builder: (context, state) => LiveMatchingScreen(
          draft: giveDraft(state),
          onBack: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
          // Help and Manage post need the Phase 5 support and listings
          // services, so they stay inert.
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        builder: (context, state) => ProfileScreen(
          onBack: context.canPop() ? () => context.pop() : null,
          onSelectTab: (tab) => onConsumerTab(context, tab),
          // Signing out clears the stored tokens; the router's redirect is
          // what moves the user, so there is no authenticated screen left
          // behind on the stack to pop back to.
          onSignOut: () =>
              ref.read(authControllerProvider.notifier).signOut(),
          // Every settings row needs a screen that does not exist yet, so
          // they stay inert rather than pointing at placeholders.
        ),
      ),
      GoRoute(
        path: AppRoutes.myImpact,
        name: 'myImpact',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => _asyncView<ConsumerImpact>(
            ref.watch(consumerImpactProvider),
            // Every figure is a count or sum of completed records. A new
            // account sees real zeroes, which is true, rather than someone
            // else's numbers.
            (impact) => MyImpactScreen(
              summary: impact.summary,
              recent: impact.recent,
              // Reached from Home's "View impact" as well as the nav tab; the
              // back arrow only appears when there is something to pop.
              onBack: context.canPop() ? () => context.pop() : null,
              onViewAll: () => context.go(AppRoutes.activity),
              onSelectTab: (tab) => onConsumerTab(context, tab),
              // The methodology note needs copy that does not exist yet.
            ),
            onRetry: () => ref.invalidate(consumerImpactProvider),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.activity,
        name: 'activity',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => _asyncView<List<ActivityItem>>(
            ref.watch(activeActivityProvider),
            (items) => ActivityScreen(
              active: items,
              // Both tabs come from the same two API reads.
              history:
                  ref.watch(activityHistoryProvider).value ?? const [],
              historyHeading: 'Completed',
              historySummary: '',
              onSelectTab: (tab) => onConsumerTab(context, tab),
              // A rescue in flight opens Active Rescue. The user's own share
              // opens the handover confirmation once someone has claimed it —
              // this is how an owner finds out a rescuer is coming, since
              // FoodLoop sends no notifications.
              onOpenActivity: (item) => switch (item.status) {
                ActivityStatus.readyForPickup => context.push(
                  AppRoutes.activeRescueFor(item.id),
                ),
                ActivityStatus.rescuerArriving => context.push(
                  AppRoutes.handoverFor(item.id),
                ),
                ActivityStatus.lookingForRescuer => context.push(
                  AppRoutes.giveMatching,
                ),
              },
              // Filter needs query support that does not exist yet.
            ),
            onRetry: () => ref.invalidate(activeActivityProvider),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.rescuerFound,
        name: 'rescuerFound',
        builder: (context, state) {
          final id = rescueId(state);
          return Consumer(
            builder: (context, ref, _) => _asyncView<Rescue>(
              ref.watch(rescueDetailProvider(id)),
              (rescue) => RescuerFoundScreen(
                listing: rescue.listing,
                onBack: () => context.canPop() ? context.pop() : null,
                onViewActiveRescue: () =>
                    context.push(AppRoutes.activeRescueFor(rescue.id)),
                // "Done" leaves the rescue running in the background, so the
                // whole stack is dropped rather than popped screen by screen.
                onDone: () => context.go(AppRoutes.home),
                // Help needs the support surface, so it stays inert.
              ),
              onRetry: () => ref.invalidate(rescueDetailProvider(id)),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.activeRescue,
        name: 'activeRescue',
        // The whole rescuer half of the loop — arrive, read out the code,
        // collect — lives in this connector.
        builder: (context, state) => ActiveRescueView(
          rescueId: rescueId(state),
          onBack: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
          onCancelled: () => context.go(AppRoutes.home),
          onCompleted: (rescueId) =>
              context.go(AppRoutes.rescueCompleteFor(rescueId)),
        ),
      ),
      GoRoute(
        path: AppRoutes.rescueComplete,
        name: 'rescueComplete',
        builder: (context, state) {
          final id = rescueId(state);
          return Consumer(
            builder: (context, ref, _) => _asyncView<Rescue>(
              ref.watch(rescueDetailProvider(id)),
              (rescue) => RescueCompleteScreen(
                listing: rescue.listing,
                onBack: () => context.canPop() ? context.pop() : null,
                // Home is the start of the flow, so the whole rescue stack
                // is dropped rather than pushed on top of.
                onBackToHome: () => context.go(AppRoutes.home),
                // View my impact needs the Impact screen, which is not built
                // yet.
              ),
              onRetry: () => ref.invalidate(rescueDetailProvider(id)),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.handover,
        name: 'handover',
        // The owner's side of the handover. Reached from Activity (a consumer
        // who shared food) and from Partner Surplus — the same screen for
        // both, because owning a listing is not a partner-only thing.
        builder: (context, state) => HandoverConfirmationView(
          listingId: listingId(state),
          onBack: () => context.canPop() ? context.pop() : null,
          onDone: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.home),
        ),
      ),
      GoRoute(
        path: AppRoutes.partnerHome,
        name: 'partnerHome',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => _asyncView<PartnerDashboard>(
            ref.watch(partnerDashboardProvider),
            (dashboard) => PartnerHomeScreen(
              dashboard: dashboard,
              onSelectTab: (tab) => onPartnerTab(context, tab),
              // Both shortcuts and "View all" open the Surplus screen, which
              // is where every batch lives.
              onViewAllSurplus: () => context.go(AppRoutes.partnerSurplus),
              onRescueHistory: () => context.go(AppRoutes.partnerSurplus),
              // A claimed batch opens its handover confirmation.
              onOpenSurplus: (surplus) =>
                  context.push(AppRoutes.handoverFor(surplus.id)),
              // Add surplus and notifications need partner screens that do
              // not exist, so they stay inert rather than pointing at
              // placeholders.
            ),
            onRetry: () => ref.invalidate(partnerDashboardProvider),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.partnerSurplus,
        name: 'partnerSurplus',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => _asyncView<PartnerDashboard>(
            ref.watch(partnerDashboardProvider),
            (dashboard) => PartnerSurplusScreen(
              dashboard: dashboard,
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.partnerHome),
              onSelectTab: (tab) => onPartnerTab(context, tab),
              // A claimed batch opens the handover confirmation — the same
              // screen a consumer owner uses, because owning a listing is not
              // a partner-only thing.
              onOpenSurplus: (surplus) =>
                  context.push(AppRoutes.handoverFor(surplus.id)),
              onManageSurplus: (surplus) =>
                  context.push(AppRoutes.handoverFor(surplus.id)),
              // Add surplus needs the partner Give flow, so it stays inert.
            ),
            onRetry: () => ref.invalidate(partnerDashboardProvider),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => SignInScreen(
          onBack: () => context.canPop() ? context.pop() : null,
          onForgotPassword: () => context.push(AppRoutes.forgotPassword),
          onCreateAccount: () => context.push(AppRoutes.createAccount),
          onSignIn: (email, password) {
            _lastAttemptedEmail = email;
            _authenticateThen(
              context,
              ref,
              () => ref
                  .read(authControllerProvider.notifier)
                  .signIn(email: email, password: password),
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        builder: (context, state) => ForgotPasswordScreen(
          onBack: () => context.canPop() ? context.pop() : null,
          onBackToSignIn: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.login),
          // The backend answers identically whether or not the address is
          // registered, so this always moves on to the code screen. Doing
          // anything else here would leak exactly what that design hides.
          onSendResetLink: (email) async {
            final requested = await _authAction(context, () async {
              await ref
                  .read(authControllerProvider.notifier)
                  .forgotPassword(email);
            });
            if (!requested || !context.mounted) return;
            context.push(_resetPasswordFor(email));
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        name: 'resetPassword',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return ResetPasswordScreen(
            email: email,
            onBack: () => context.canPop() ? context.pop() : null,
            onBackToSignIn: () => context.go(AppRoutes.login),
            onSubmit: (code, newPassword) async {
              final reset = await _authAction(
                context,
                () => ref
                    .read(authControllerProvider.notifier)
                    .resetPassword(
                      email: email,
                      code: code,
                      newPassword: newPassword,
                    ),
                successMessage: 'Password updated. Sign in to continue.',
              );
              if (reset && context.mounted) {
                // Every session was revoked server-side, so there is nothing
                // to return to except sign-in.
                context.go(AppRoutes.login);
              }
              return reset;
            },
            onResend: () async {
              await _authAction(
                context,
                () => ref
                    .read(authControllerProvider.notifier)
                    .forgotPassword(email),
                successMessage: 'If that account exists, a new code is on '
                    'its way.',
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.health,
        name: 'health',
        builder: (context, state) => const HealthScreen(),
      ),
    ],
  );
});

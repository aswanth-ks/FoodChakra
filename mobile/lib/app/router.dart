import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/account_role.dart';
import '../features/auth/presentation/create_account_screen.dart';
import '../features/auth/presentation/email_verification_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
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
import '../features/partner/data/sample_partner.dart';
import '../features/partner/presentation/partner_home_screen.dart';
import '../features/partner/presentation/partner_surplus_screen.dart';
import '../features/onboarding/presentation/location_setup_screen.dart';
import '../features/onboarding/presentation/share_surplus_screen.dart';
import '../features/onboarding/presentation/welcome_screen.dart';
import '../features/rescue/data/sample_listings.dart';
import '../features/rescue/presentation/active_rescue_screen.dart';
import '../features/rescue/presentation/activity_screen.dart';
import '../features/rescue/presentation/explore_screen.dart';
import '../features/rescue/presentation/food_details_screen.dart';
import '../features/rescue/presentation/my_impact_screen.dart';
import '../features/rescue/presentation/profile_screen.dart';
import '../features/rescue/presentation/rescue_complete_screen.dart';
import '../features/rescue/presentation/rescuer_found_screen.dart';
import '../features/rescue/presentation/widgets/rescue_confirmation_sheet.dart';
import '../features/splash/presentation/splash_screen.dart';
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

  static String foodDetailsFor(String id) => '/food/$id';
  static String activeRescueFor(String id) => '/rescue/$id';
  static String rescuerFoundFor(String id) => '/rescue/$id/found';
  static String rescueCompleteFor(String id) => '/rescue/$id/complete';

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

/// App router.
///
/// Phase 3 adds a `redirect` here that reads the auth provider and sends
/// unauthenticated users to `/login`, then routes authenticated users to the
/// home screen matching their role.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) =>
            SplashScreen(onComplete: () => context.go(AppRoutes.welcome)),
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
          // The form validates locally, then hands off to email verification.
          // Nothing is persisted until the Phase 3 auth service exists.
          onCreateAccount: (_, email, _) => context.push(
            Uri(
              path: AppRoutes.verifyEmail,
              queryParameters: {'email': email},
            ).toString(),
          ),
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
          // The code is not checked against anything yet; entering six digits
          // lands on Home so the consumer flow is reachable. Phase 3 replaces
          // this with a real verification call.
          onVerify: (_) => context.go(
            homeForRole(roleForEmail(state.uri.queryParameters['email'] ?? '')),
          ),
          // onResend stays null until the Phase 3 auth service exists.
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => HomeScreen(
          onOpenListing: (listing) =>
              context.push(AppRoutes.foodDetailsFor(listing.id)),
          // All three routes into discovery land on Explore.
          onRescueFood: () => context.go(AppRoutes.explore),
          onExploreNearby: () => context.go(AppRoutes.explore),
          onSeeAll: () => context.go(AppRoutes.explore),
          onGiveFood: () => context.push(AppRoutes.give),
          onViewImpact: () => context.push(AppRoutes.myImpact),
          onSelectTab: (tab) => onConsumerTab(context, tab),
          // Give food, the notification bell and the Activity / Impact /
          // Profile tabs need screens that do not exist yet.
        ),
      ),
      GoRoute(
        path: AppRoutes.explore,
        name: 'explore',
        builder: (context, state) => ExploreScreen(
          onOpenListing: (listing) =>
              context.push(AppRoutes.foodDetailsFor(listing.id)),
          onSelectTab: (tab) => onConsumerTab(context, tab),
          // Filters and Change location need Phase 5 query support.
        ),
      ),
      GoRoute(
        path: AppRoutes.foodDetails,
        name: 'foodDetails',
        builder: (context, state) {
          final listing = SampleListings.byId(listingId(state));
          return FoodDetailsScreen(
            listing: listing,
            onBack: () => context.canPop() ? context.pop() : null,
            onRescue: () async {
              final confirmed = await showRescueConfirmationSheet(
                context,
                listing: listing,
              );
              if (confirmed ?? false) {
                if (!context.mounted) return;
                context.push(AppRoutes.rescuerFoundFor(listing.id));
              }
            },
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
          // A published post goes straight to its live matching screen. The
          // form steps are dropped from the stack so Back leaves the flow.
          onPublished: (draft) =>
              context.go(AppRoutes.giveMatching, extra: draft),
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
          // There is no session to end until Phase 3, so signing out just
          // returns to the start of the flow. The screen confirms first.
          onSignOut: () => context.go(AppRoutes.welcome),
          // Every settings row needs a screen that does not exist yet, so
          // they stay inert rather than pointing at placeholders.
        ),
      ),
      GoRoute(
        path: AppRoutes.myImpact,
        name: 'myImpact',
        builder: (context, state) => MyImpactScreen(
          // Reached from Home's "View impact" as well as the nav tab; the
          // back arrow only appears when there is something to pop.
          onBack: context.canPop() ? () => context.pop() : null,
          onViewAll: () => context.go(AppRoutes.activity),
          onSelectTab: (tab) => onConsumerTab(context, tab),
          // The methodology note needs copy that does not exist yet.
        ),
      ),
      GoRoute(
        path: AppRoutes.activity,
        name: 'activity',
        builder: (context, state) => ActivityScreen(
          onSelectTab: (tab) => onConsumerTab(context, tab),
          // A rescue in flight opens Active Rescue; the user's own share
          // opens its live matching screen. Until Phase 5 there is no stored
          // draft behind an activity entry, so the matching screen falls back
          // to its defaults.
          onOpenActivity: (item) => switch (item.kind) {
            ActivityKind.rescue => context.push(
              AppRoutes.activeRescueFor(item.id),
            ),
            ActivityKind.share => context.push(AppRoutes.giveMatching),
          },
          // Filter needs Phase 5 query support.
        ),
      ),
      GoRoute(
        path: AppRoutes.rescuerFound,
        name: 'rescuerFound',
        builder: (context, state) => RescuerFoundScreen(
          listing: SampleListings.byId(listingId(state)),
          onBack: () => context.canPop() ? context.pop() : null,
          onViewActiveRescue: () =>
              context.push(AppRoutes.activeRescueFor(listingId(state))),
          // "Done" leaves the rescue running in the background, so the whole
          // stack is dropped rather than popped one screen at a time.
          onDone: () => context.go(AppRoutes.home),
          // Help needs the Phase 5 support surface, so it stays inert.
        ),
      ),
      GoRoute(
        path: AppRoutes.activeRescue,
        name: 'activeRescue',
        builder: (context, state) => ActiveRescueScreen(
          listing: SampleListings.byId(listingId(state)),
          onBack: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
          // Stands in for the partner's handover confirmation until Phase 5.
          onCollected: () =>
              context.push(AppRoutes.rescueCompleteFor(listingId(state))),
          // Start navigation / View route hand off to the device's maps app
          // from inside the screen. Help / Something wrong? / Cancel rescue
          // need the Phase 5 rescue service, so they stay inert.
        ),
      ),
      GoRoute(
        path: AppRoutes.rescueComplete,
        name: 'rescueComplete',
        builder: (context, state) => RescueCompleteScreen(
          listing: SampleListings.byId(listingId(state)),
          onBack: () => context.canPop() ? context.pop() : null,
          // Home is the start of the flow, so the whole rescue stack is
          // dropped rather than pushed on top of.
          onBackToHome: () => context.go(AppRoutes.home),
          // View my impact needs the Impact screen, which is not built yet.
        ),
      ),
      GoRoute(
        path: AppRoutes.partnerHome,
        name: 'partnerHome',
        builder: (context, state) => PartnerHomeScreen(
          dashboard: SamplePartner.dashboard,
          onSelectTab: (tab) => onPartnerTab(context, tab),
          // Both shortcuts and "View all" open the Surplus screen, which is
          // where every batch lives.
          onViewAllSurplus: () => context.go(AppRoutes.partnerSurplus),
          onRescueHistory: () => context.go(AppRoutes.partnerSurplus),
          // Add surplus, the pickup alert, the surplus cards, notifications
          // and Activity need partner screens that do not exist yet, so they
          // stay inert rather than pointing at placeholders.
        ),
      ),
      GoRoute(
        path: AppRoutes.partnerSurplus,
        name: 'partnerSurplus',
        builder: (context, state) => PartnerSurplusScreen(
          dashboard: SamplePartner.dashboard,
          onBack: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.partnerHome),
          onSelectTab: (tab) => onPartnerTab(context, tab),
          // Add surplus, Manage and each card's action need the rest of the
          // partner set, so they stay inert.
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => SignInScreen(
          onBack: () => context.canPop() ? context.pop() : null,
          onForgotPassword: () => context.push(AppRoutes.forgotPassword),
          onCreateAccount: () => context.push(AppRoutes.createAccount),
          // Nothing is authenticated yet: the password is not checked, and
          // the email's domain stands in for the partner grant the ops
          // console issues. Phase 3 replaces this with the role claim on the
          // authenticated session — see `roleForEmail`.
          onSignIn: (email, _) => context.go(homeForRole(roleForEmail(email))),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        builder: (context, state) => ForgotPasswordScreen(
          onBack: () => context.canPop() ? context.pop() : null,
          onBackToSignIn: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.login),
          // onSendResetLink stays null until the Phase 3 auth service exists.
        ),
      ),
      GoRoute(
        path: AppRoutes.health,
        name: 'health',
        builder: (context, state) => const HealthScreen(),
      ),
    ],
  );
});

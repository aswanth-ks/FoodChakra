import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/sign_in_screen.dart';
import '../features/health/presentation/health_screen.dart';
import '../features/onboarding/presentation/impact_screen.dart';
import '../features/onboarding/presentation/location_setup_screen.dart';
import '../features/onboarding/presentation/share_surplus_screen.dart';
import '../features/onboarding/presentation/welcome_screen.dart';
import '../features/splash/presentation/splash_screen.dart';

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

  // Phase 5-7 role home routes
  static const String donorHome = '/donor';
  static const String receiverHome = '/receiver';
  static const String volunteerHome = '/volunteer';
}

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
        builder: (context, state) => SplashScreen(
          onComplete: () => context.go(AppRoutes.welcome),
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
          // Skip / Enable location / Not now all continue past onboarding,
          // which needs account creation (not yet implemented).
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => SignInScreen(
          onBack: () => context.canPop() ? context.pop() : null,
          onForgotPassword: () {},
          onCreateAccount: () {},
          // onSignIn stays null until the auth service exists (Phase 3).
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

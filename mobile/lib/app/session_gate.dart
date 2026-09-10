import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the splash screen has finished its entrance animation.
///
/// The router needs this because two independent things must both finish
/// before the first real screen can be chosen: the Stitch splash animation,
/// and the session restore. Whichever lands second is the one that moves the
/// app on, so neither is allowed to cut the other short.
class SplashGate extends Notifier<bool> {
  @override
  bool build() => false;

  void markComplete() => state = true;
}

final splashGateProvider = NotifierProvider<SplashGate, bool>(SplashGate.new);

/// Routes reachable without a session.
///
/// This is an allow-list rather than a list of protected routes on purpose: a
/// route added later is protected by default, which is the safe direction to
/// fail. Anything not named here requires a session.
const Set<String> kPublicRoutes = {
  '/',
  '/health',
  '/onboarding/welcome',
  '/onboarding/share',
  '/onboarding/impact',
  '/onboarding/location',
  '/login',
  '/register',
  '/create-account',
  '/forgot-password',
  '/reset-password',
  '/verify-email',
};

/// Public routes an already-authenticated user should not be sitting on.
///
/// `/verify-email` and `/forgot-password` are deliberately absent: the first
/// is reached *while* authenticated, immediately after registering, and the
/// second is a legitimate detour.
const Set<String> kUnauthenticatedOnlyRoutes = {
  '/onboarding/welcome',
  '/onboarding/share',
  '/onboarding/impact',
  '/onboarding/location',
  '/login',
  '/register',
  '/create-account',
};

bool isPublicRoute(String location) => kPublicRoutes.contains(location);

bool isProtectedRoute(String location) => !isPublicRoute(location);

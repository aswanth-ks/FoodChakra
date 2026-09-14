import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'resume_refresher.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// Root widget. Holds only wiring — no business logic, no layout.
class FoodLoopApp extends ConsumerWidget {
  const FoodLoopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Wraps the router rather than sitting inside it: the refresher must
    // outlive every screen, because what goes stale while the app is away is
    // shared data, not one page's copy of it.
    return ResumeRefresher(
      child: MaterialApp.router(
        title: 'FoodLoop',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}

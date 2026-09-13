import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/diagnostics/perf_trace.dart';
import 'core/error/retry_policy.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PerfTrace.mark('main() — Dart entrypoint reached');
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => PerfTrace.mark('first frame rasterised'),
  );
  runApp(
    const ProviderScope(
      // Riverpod's default retries a failed provider ten times. That turned a
      // refused location permission into a re-prompting loop on a real
      // device; see `foodloopRetry`.
      retry: foodloopRetry,
      child: FoodLoopApp(),
    ),
  );
}

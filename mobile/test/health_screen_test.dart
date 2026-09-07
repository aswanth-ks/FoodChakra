import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodloop/app/theme/app_theme.dart';
import 'package:foodloop/core/error/failures.dart';
import 'package:foodloop/features/health/domain/health_repository.dart';
import 'package:foodloop/features/health/domain/health_status.dart';
import 'package:foodloop/features/health/presentation/health_providers.dart';
import 'package:foodloop/features/health/presentation/health_screen.dart';

/// Fake repository — proves the presentation layer depends only on the
/// interface, so no HTTP call is made in tests.
class _FakeHealthRepository implements HealthRepository {
  _FakeHealthRepository({this.result, this.error});

  final HealthStatus? result;
  final Object? error;

  @override
  Future<HealthStatus> fetchHealth() async {
    if (error != null) throw error!;
    return result!;
  }
}

Widget _harness(HealthRepository repository) {
  return ProviderScope(
    overrides: [healthRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(theme: AppTheme.light, home: const HealthScreen()),
  );
}

const _healthy = HealthStatus(
  status: 'ok',
  app: 'FoodLoop API',
  environment: 'local',
  databaseConnected: true,
  databaseVersion: '8.0.0',
);

void main() {
  testWidgets('shows the loading state before the request resolves', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_FakeHealthRepository(result: _healthy)));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('shows connected details on success', (tester) async {
    await tester.pumpWidget(_harness(_FakeHealthRepository(result: _healthy)));
    await tester.pumpAndSettle();

    expect(find.text('All systems connected'), findsOneWidget);
    expect(find.text('8.0.0'), findsOneWidget);
  });

  testWidgets('shows the empty state when the database is unreachable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _FakeHealthRepository(
          result: const HealthStatus(
            status: 'degraded',
            app: 'FoodLoop API',
            environment: 'local',
            databaseConnected: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backend reachable, database is not'), findsOneWidget);
  });

  testWidgets('shows the failure message and a retry action on error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(_FakeHealthRepository(error: const NetworkFailure())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('No internet connection.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
  });
}

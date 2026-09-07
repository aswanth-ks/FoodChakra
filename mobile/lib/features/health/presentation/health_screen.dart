import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/config/env.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/loader_view.dart';
import '../domain/health_status.dart';
import 'health_providers.dart';

/// Phase 0 connectivity proof.
///
/// This screen exists to demonstrate the full chain
/// Flutter -> Dio -> FastAPI -> Service -> Repository -> MongoDB
/// and to exercise every required UI state. It is removed once the real Stitch
/// screens land in Phase 4.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FoodLoop'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(healthStatusProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(healthStatusProvider.future),
        child: health.when(
          loading: () => const LoaderView(message: 'Contacting the backend…'),
          error: (error, _) => ListView(
            children: [
              SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
              ErrorStateView(
                error: error,
                onRetry: () => ref.invalidate(healthStatusProvider),
              ),
            ],
          ),
          data: (status) => _HealthDetails(status: status),
        ),
      ),
    );
  }
}

class _HealthDetails extends StatelessWidget {
  const _HealthDetails({required this.status});

  final HealthStatus status;

  @override
  Widget build(BuildContext context) {
    // The backend is reachable but its database is not: a successful response
    // that still has nothing useful behind it -> the empty state.
    if (!status.databaseConnected) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
          const EmptyStateView(
            icon: Icons.storage_outlined,
            title: 'Backend reachable, database is not',
            message:
                'The API responded but could not reach MongoDB. Set MONGO_URI '
                'in backend/.env to your Atlas connection string.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.secondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'All systems connected',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _Row(label: 'API', value: status.app),
                _Row(label: 'Environment', value: status.environment),
                _Row(label: 'MongoDB', value: status.databaseVersion ?? '—'),
                _Row(label: 'Endpoint', value: Env.apiUrl),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

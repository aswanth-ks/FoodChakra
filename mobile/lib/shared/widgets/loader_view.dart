import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// The single loading indicator for the whole app.
class LoaderView extends StatelessWidget {
  const LoaderView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

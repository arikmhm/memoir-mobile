import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/core/theme/app_colors.dart';
import '../../../shared/core/theme/app_spacing.dart';

/// Placeholder photo session screen.
///
/// TODO: Integrate camera preview and capture flow.
class PhotoSessionScreen extends StatelessWidget {
  final String templateId;

  const PhotoSessionScreen({super.key, required this.templateId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 80,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Photo Session',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Template: $templateId',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                ElevatedButton(
                  onPressed: () => context.go('/screensaver'),
                  child: const Text('Kembali ke Screensaver'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

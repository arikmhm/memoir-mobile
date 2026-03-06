import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/core/theme/app_colors.dart';
import '../../../../shared/core/theme/app_spacing.dart';
import '../../bloc/settings_cubit.dart';
import '../../bloc/settings_state.dart';

/// Camera test card section.
///
/// Shows a button to start camera test, displays live preview on success,
/// and shows error messages on failure.
class CameraTestSection extends StatelessWidget {
  const CameraTestSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (previous, current) =>
          current is SettingsInitial ||
          current is CameraTestInProgress ||
          current is CameraTestSuccess ||
          current is CameraTestError,
      builder: (context, state) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.camera_alt_outlined, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Test Kamera',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _buildStatusBadge(context, state),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Memastikan kamera device dapat diakses oleh aplikasi.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),

              // Camera preview area
              if (state is CameraTestSuccess) ...[
                _buildCameraPreview(context),
                const SizedBox(height: AppSpacing.md),
              ],

              // Error message
              if (state is CameraTestError) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          state.message,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Actions
              Row(
                children: [
                  if (state is! CameraTestSuccess)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: state is CameraTestInProgress
                            ? null
                            : () => context
                                  .read<SettingsCubit>()
                                  .startCameraTest(),
                        icon: state is CameraTestInProgress
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow, size: 18),
                        label: Text(
                          state is CameraTestInProgress
                              ? 'Menginisialisasi...'
                              : 'Mulai Test',
                        ),
                      ),
                    ),
                  if (state is CameraTestSuccess)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.read<SettingsCubit>().stopCameraTest(),
                        icon: const Icon(Icons.stop, size: 18),
                        label: const Text('Stop Kamera'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCameraPreview(BuildContext context) {
    final controller = context.read<SettingsCubit>().cameraController;

    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: CameraPreview(controller),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, SettingsState state) {
    if (state is CameraTestSuccess) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 14),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Kamera Aktif',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (state is CameraTestError) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cancel, color: AppColors.error, size: 14),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Gagal',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (state is CameraTestInProgress) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return const SizedBox.shrink();
  }
}

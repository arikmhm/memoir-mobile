import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/core/theme/app_colors.dart';
import '../../../../shared/core/theme/app_spacing.dart';
import '../../../../shared/widgets/memoir_button.dart';
import '../../../../shared/widgets/memoir_section_card.dart';
import '../../bloc/settings_cubit.dart';
import '../../bloc/settings_state.dart';

/// Camera test section — dashboard card style.
///
/// White card, subtle border, uppercase label, custom button + loading.
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
        final cubit = context.read<SettingsCubit>();
        final isTesting = state is CameraTestInProgress;
        final isActive = state is CameraTestSuccess;

        return MemoirSectionCard(
          label: 'Kamera',
          subtitle: 'Kamera depan (selfie) dengan resolusi tertinggi.',
          icon: Icons.camera_alt_outlined,
          trailing: _StatusBadge(state: state),
          children: [
            // ── Camera preview ──
            if (isActive) ...[
              _CameraPreview(controller: cubit.cameraController),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Error message ──
            if (state is CameraTestError) ...[
              _ErrorBanner(message: state.message),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Actions ──
            if (!isActive)
              MemoirButton.filled(
                label: isTesting ? 'Menginisialisasi...' : 'Test Kamera',
                icon: isTesting ? null : Icons.play_arrow,
                isLoading: isTesting,
                onPressed: isTesting ? null : () => cubit.startCameraTest(),
              ),
            if (isActive)
              MemoirButton.outlined(
                label: 'Stop Kamera',
                icon: Icons.stop,
                onPressed: () => cubit.stopCameraTest(),
              ),
          ],
        );
      },
    );
  }
}

// ─── Private widgets ────────────────────────────────────────────

class _CameraPreview extends StatelessWidget {
  final CameraController? controller;

  const _CameraPreview({this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: controller!.value.previewSize!.height,
            height: controller!.value.previewSize!.width,
            child: CameraPreview(controller!),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final SettingsState state;

  const _StatusBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state is CameraTestSuccess) {
      return _badge('Aktif', AppColors.success);
    }
    if (state is CameraTestError) {
      return _badge('Gagal', AppColors.error);
    }
    if (state is CameraTestInProgress) {
      return const MemoirLoadingIndicator(size: 20);
    }
    return const SizedBox.shrink();
  }

  Widget _badge(String label, Color color) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

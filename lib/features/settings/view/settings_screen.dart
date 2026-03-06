import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/core/theme/app_colors.dart';
import '../../../shared/core/theme/app_spacing.dart';
import '../bloc/settings_cubit.dart';
import '../bloc/settings_state.dart';
import 'widgets/camera_test_section.dart';
import 'widgets/printer_test_section.dart';

/// Settings (Operator) screen — device diagnostic page.
///
/// Per PRD-05 FEAT-MR-10:
/// - Hidden access from screensaver (5x tap, < 2s, bottom-left corner)
/// - Camera test with live preview
/// - Printer test with BLE scan + test print
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Settings (Operator)'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.screenVertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Row(
                children: [
                  const Icon(Icons.build_outlined, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Device Diagnostic',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Pastikan kamera dan printer berfungsi sebelum memulai sesi.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Camera test
              const CameraTestSection(),
              const SizedBox(height: AppSpacing.lg),

              // Printer test
              BlocBuilder<SettingsCubit, SettingsState>(
                builder: (context, state) {
                  return const PrinterTestSection();
                },
              ),
              const SizedBox(height: AppSpacing.xxl),

              // App info
              Center(
                child: Text(
                  'memoir. Mobile Runner v1.0.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/core/theme/app_colors.dart';
import '../../../shared/core/theme/app_spacing.dart';
import '../../app/bloc/app_cubit.dart';
import '../bloc/startup_cubit.dart';
import '../bloc/startup_state.dart';

/// Startup / Loading Screen.
///
/// Per PRD-05 FEAT-MR-02: Menampilkan progress startup sequence.
/// Light monochrome, receipt aesthetic.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    context.read<StartupCubit>().runStartup();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: BlocListener<StartupCubit, StartupState>(
        listener: (context, state) {
          if (state is StartupComplete) {
            context.read<AppCubit>().onStartupComplete(
              templates: state.templates,
            );
          }
        },
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: BlocBuilder<StartupCubit, StartupState>(
              builder: (context, state) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand
                    Text(
                      'memoir.',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w300,
                        letterSpacing: 4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),

                    // Progress indicator
                    if (state is! StartupError && state is! StartupComplete)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    if (state is StartupComplete)
                      const Icon(
                        Icons.check,
                        size: 24,
                        color: AppColors.success,
                      ),
                    if (state is StartupError)
                      const Icon(
                        Icons.close,
                        size: 24,
                        color: AppColors.error,
                      ),
                    const SizedBox(height: AppSpacing.lg),

                    // Step progress
                    _buildStepList(context, state),

                    // Error message
                    if (state is StartupError) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.wifi_off_rounded,
                              size: 36,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              state.message,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textPrimary,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        height: AppSpacing.touchTarget,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            context.read<StartupCubit>().runStartup();
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('COBA LAGI'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepList(BuildContext context, StartupState state) {
    final theme = Theme.of(context);
    final steps = [
      (
        'Verifikasi device',
        _resolveStepStatus(state, _Step.deviceCheck),
      ),
      (
        'Sinkronisasi template',
        _resolveStepStatus(state, _Step.templateSync),
      ),
    ];

    return Column(
      children: steps.map((step) {
        final (label, status) = step;
        final color = switch (status) {
          _StepStatus.pending => AppColors.textDisabled,
          _StepStatus.inProgress => AppColors.textPrimary,
          _StepStatus.done => AppColors.success,
          _StepStatus.error => AppColors.error,
        };
        final icon = switch (status) {
          _StepStatus.pending => Icons.circle_outlined,
          _StepStatus.inProgress => Icons.more_horiz,
          _StepStatus.done => Icons.check,
          _StepStatus.error => Icons.close,
        };

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  _StepStatus _resolveStepStatus(StartupState state, _Step step) {
    return switch (state) {
      StartupInitial() => _StepStatus.pending,
      StartupCheckingDevice() => switch (step) {
        _Step.deviceCheck => _StepStatus.inProgress,
        _Step.templateSync => _StepStatus.pending,
      },
      StartupSyncingTemplates() => switch (step) {
        _Step.deviceCheck => _StepStatus.done,
        _Step.templateSync => _StepStatus.inProgress,
      },
      StartupComplete() => _StepStatus.done,
      StartupError() => switch (step) {
        _Step.deviceCheck => state is StartupCheckingDevice
            ? _StepStatus.error
            : _StepStatus.done,
        _Step.templateSync => _StepStatus.error,
      },
    };
  }
}

enum _Step { deviceCheck, templateSync }
enum _StepStatus { pending, inProgress, done, error }

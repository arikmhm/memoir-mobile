import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/core/theme/app_colors.dart';
import '../../../shared/core/theme/app_spacing.dart';
import '../../app/bloc/app_cubit.dart';
import '../bloc/pairing_cubit.dart';
import '../bloc/pairing_state.dart';
import 'widgets/pairing_code_input.dart';

/// Pairing screen — 6-digit code input for device pairing.
///
/// Light monochrome, receipt aesthetic. Tipografi bersih, spacing lega.
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _inputKey = GlobalKey<PairingCodeInputState>();
  String _currentCode = '';

  bool get _isCodeComplete => _currentCode.length == 6;

  void _submitCode() {
    if (_isCodeComplete) {
      context.read<PairingCubit>().submitPairingCode(_currentCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<PairingCubit, PairingState>(
          listener: (context, state) {
            if (state is PairingSuccess) {
              context.read<AppCubit>().onPairingComplete();
            }
            if (state is PairingError) {
              _inputKey.currentState?.clear();
              _currentCode = '';
            }
          },
          builder: (context, state) {
            final isLoading = state is PairingLoading;
            final isError = state is PairingError;
            final isSuccess = state is PairingSuccess;

            return Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                      vertical: AppSpacing.screenVertical,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Brand ──
                        Text(
                          'memoir.',
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontWeight: FontWeight.w300,
                            letterSpacing: 4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'MOBILE RUNNER',
                          style: theme.textTheme.labelMedium?.copyWith(
                            letterSpacing: 6,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),

                        // ── Divider ──
                        Container(
                          width: 40,
                          height: 1,
                          color: AppColors.border,
                        ),
                        const SizedBox(height: AppSpacing.xxxl),

                        // ── Title ──
                        Text(
                          'PAIRING DEVICE',
                          style: theme.textTheme.titleMedium?.copyWith(
                            letterSpacing: 3,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ── Instructions ──
                        Text(
                          'Masukkan 6-digit kode pairing\ndari Owner Dashboard',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xxl),

                        // ── 6-digit code input ──
                        PairingCodeInput(
                          key: _inputKey,
                          enabled: !isLoading && !isSuccess,
                          hasError: isError,
                          onChanged: (code) {
                            setState(() => _currentCode = code);
                            if (isError) {
                              context.read<PairingCubit>().reset();
                            }
                          },
                          onCompleted: (_) => _submitCode(),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ── Inline feedback ──
                        SizedBox(
                          height: 24,
                          child: _buildFeedback(context, state),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // ── Submit button ──
                        SizedBox(
                          width: 360,
                          child: ElevatedButton(
                            onPressed: isLoading || !_isCodeComplete
                                ? null
                                : _submitCode,
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('PAIR DEVICE'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Loading overlay
                if (isLoading)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeedback(BuildContext context, PairingState state) {
    if (state is PairingError) {
      return Text(
        state.message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.error,
        ),
      );
    }

    if (state is PairingSuccess) {
      return Text(
        'Pairing berhasil',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.success,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

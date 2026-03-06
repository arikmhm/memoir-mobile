import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/core/theme/app_colors.dart';
import '../../../shared/core/theme/app_spacing.dart';
import '../../../shared/ui/widgets/app_loading.dart';
import '../../app/bloc/app_cubit.dart';
import '../bloc/pairing_cubit.dart';
import '../bloc/pairing_state.dart';

/// Pairing screen — 6-digit code input for device pairing.
///
/// Per PRD-05 FEAT-MR-01:
/// - Text field for 6-digit code
/// - Submit button
/// - Loading/error/success states
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<PairingCubit, PairingState>(
          listener: (context, state) {
            if (state is PairingSuccess) {
              // Notify AppCubit that pairing is complete
              context.read<AppCubit>().onPairingComplete();
            }
            if (state is PairingError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is PairingLoading) {
              return const AppLoading(message: 'Memproses pairing...');
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      'memoir.',
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Mobile Runner',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // Instructions
                    Text(
                      'Masukkan 6-digit kode pairing dari Owner Dashboard',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Code input
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                        decoration: const InputDecoration(
                          hintText: '______',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Submit button
                    SizedBox(
                      width: 300,
                      child: ElevatedButton(
                        onPressed: () {
                          context.read<PairingCubit>().submitPairingCode(
                            _codeController.text,
                          );
                        },
                        child: const Text('Pair Device'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

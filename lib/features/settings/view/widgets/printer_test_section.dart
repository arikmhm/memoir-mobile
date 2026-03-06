import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/core/theme/app_colors.dart';
import '../../../../shared/core/theme/app_spacing.dart';
import '../../bloc/settings_cubit.dart';
import '../../bloc/settings_state.dart';

/// Printer test card section.
///
/// Shows paired Bluetooth printers, allows test printing,
/// and saving a default printer for auto-connect.
class PrinterTestSection extends StatelessWidget {
  const PrinterTestSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listenWhen: (previous, current) =>
          current is PrinterTestSuccess || current is PrinterTestError,
      listener: (context, state) {
        if (state is PrinterTestSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Test print berhasil!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        if (state is PrinterTestError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      buildWhen: (previous, current) =>
          current is SettingsInitial ||
          current is PrinterScanInProgress ||
          current is PrinterScanComplete ||
          current is PrinterTestInProgress ||
          current is PrinterTestSuccess ||
          current is PrinterTestError,
      builder: (context, state) {
        final cubit = context.read<SettingsCubit>();
        final printers = _extractPrinters(state);
        final isScanning = state is PrinterScanInProgress;
        final isTesting = state is PrinterTestInProgress;
        final savedPrinter = cubit.savedPrinter;

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
                  const Icon(Icons.print_outlined, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Test Printer',
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
                'Tampilkan device Bluetooth yang sudah di-pair, lalu test print.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),

              // Saved default printer card
              if (savedPrinter != null) ...[
                const SizedBox(height: AppSpacing.md),
                _SavedPrinterCard(savedPrinter: savedPrinter),
              ],

              const SizedBox(height: AppSpacing.md),

              // Scan button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isScanning || isTesting
                      ? null
                      : () => context.read<SettingsCubit>().scanPrinters(),
                  icon: isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bluetooth_searching, size: 18),
                  label: Text(isScanning ? 'Scanning...' : 'Scan Printer'),
                ),
              ),

              // Printer list
              if (printers != null && printers.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Printer Ditemukan (${printers.length})',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...printers.map(
                  (printer) => _PrinterTile(
                    printer: printer,
                    isTesting: isTesting,
                    isDefault: savedPrinter?.address == printer.address,
                  ),
                ),
              ],

              // Empty state after scan
              if (printers != null && printers.isEmpty && !isScanning) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.print_disabled,
                        size: 32,
                        color: AppColors.textDisabled,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Tidak ada printer ditemukan',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Pastikan printer Bluetooth sudah dinyalakan dan dipair.',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textDisabled,
                                ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<PrinterInfo>? _extractPrinters(SettingsState state) {
    if (state is PrinterScanComplete) return state.printers;
    if (state is PrinterTestInProgress) return state.printers;
    if (state is PrinterTestSuccess) return state.printers;
    if (state is PrinterTestError) return state.printers;
    return null;
  }

  Widget _buildStatusBadge(BuildContext context, SettingsState state) {
    if (state is PrinterTestSuccess) {
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
              'Berhasil',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      );
    }

    if (state is PrinterTestError) {
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

    if (state is PrinterScanInProgress || state is PrinterTestInProgress) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Card showing the currently saved default printer.
class _SavedPrinterCard extends StatelessWidget {
  final PrinterInfo savedPrinter;

  const _SavedPrinterCard({required this.savedPrinter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.star, color: AppColors.success, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Printer Default',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  savedPrinter.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                Text(
                  savedPrinter.address,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textDisabled,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () =>
                context.read<SettingsCubit>().clearDefaultPrinter(),
            icon: const Icon(Icons.close, size: 16),
            tooltip: 'Hapus default',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Individual printer list tile with test print + save default buttons.
class _PrinterTile extends StatelessWidget {
  final PrinterInfo printer;
  final bool isTesting;
  final bool isDefault;

  const _PrinterTile({
    required this.printer,
    required this.isTesting,
    this.isDefault = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDefault
            ? AppColors.success.withValues(alpha: 0.05)
            : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: isDefault
            ? Border.all(color: AppColors.success.withValues(alpha: 0.2))
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isDefault ? Icons.star : Icons.print,
                size: 20,
                color: isDefault ? AppColors.success : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            printer.name,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'DEFAULT',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      printer.address,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textDisabled,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: isTesting
                      ? null
                      : () =>
                          context.read<SettingsCubit>().testPrint(printer),
                  child: isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Test Print'),
                ),
              ),
              if (!isDefault) ...[
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: isTesting
                      ? null
                      : () => context
                          .read<SettingsCubit>()
                          .saveDefaultPrinter(printer),
                  icon: const Icon(Icons.star_outline, size: 16),
                  label: const Text('Set Default'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

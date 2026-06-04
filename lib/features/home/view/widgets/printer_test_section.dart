import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/core/theme/app_colors.dart';
import '../../../../shared/core/theme/app_spacing.dart';
import '../../../../shared/data/services/print_channel.dart';
import '../../../../shared/widgets/memoir_banner.dart';
import '../../../../shared/widgets/memoir_button.dart';
import '../../../../shared/widgets/memoir_section_card.dart';
import '../../../../shared/widgets/memoir_tab_toggle.dart';
import '../../bloc/home_cubit.dart';
import '../../bloc/home_state.dart';

/// Printer section — dashboard card style.
///
/// Custom toggle replaces SegmentedButton. Inline banner replaces SnackBar.
/// GestureDetector + opacity replaces InkWell ripple.
class PrinterTestSection extends StatefulWidget {
  const PrinterTestSection({super.key});

  @override
  State<PrinterTestSection> createState() => _PrinterTestSectionState();
}

class _PrinterTestSectionState extends State<PrinterTestSection> {
  PrinterConnectionType _selectedType = PrinterConnectionType.bluetooth;

  // Inline banner state
  String? _bannerMessage;
  MemoirBannerType? _bannerType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HomeCubit>().verifyPrinterOnPageOpen();
    });
  }

  void _showBanner(String message, MemoirBannerType type) {
    setState(() {
      _bannerMessage = message;
      _bannerType = type;
    });
  }

  void _dismissBanner() {
    if (mounted) setState(() => _bannerMessage = null);
  }

  void _syncTab(PrinterConnectionType type) {
    if (mounted && _selectedType != type) {
      setState(() => _selectedType = type);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeCubit, HomeState>(
      listenWhen: (_, current) =>
          current is PrinterTestSuccess ||
          current is PrinterTestError ||
          current is PrinterValidationFailed ||
          current is PrinterSaved ||
          current is PrinterCheckingConnection,
      listener: (context, state) {
        if (state is PrinterTestSuccess) {
          _showBanner('Test print berhasil!', MemoirBannerType.success);
        }
        if (state is PrinterTestError) {
          _showBanner(state.message, MemoirBannerType.error);
        }
        if (state is PrinterValidationFailed) {
          _showBanner(state.message, MemoirBannerType.error);
        }
        // Keep the connection tab in sync with the active printer so a
        // freshly detected/saved printer (e.g. USB auto-detected on page open)
        // isn't hidden behind the wrong tab — the saved card follows the tab.
        if (state is PrinterSaved) {
          _syncTab(state.printer.connectionType);
        }
        if (state is PrinterCheckingConnection) {
          _syncTab(state.printer.connectionType);
        }
      },
      buildWhen: (_, current) =>
          current is HomeInitial ||
          current is PrinterCheckingConnection ||
          current is PrinterScanInProgress ||
          current is PrinterScanComplete ||
          current is PrinterValidating ||
          current is PrinterValidationFailed ||
          current is PrinterSaved ||
          current is PrinterTestInProgress ||
          current is PrinterTestSuccess ||
          current is PrinterTestError,
      builder: (context, state) {
        final cubit = context.read<HomeCubit>();
        final isScanning = state is PrinterScanInProgress;
        final isValidating = state is PrinterValidating;
        final isChecking = state is PrinterCheckingConnection;

        // Decide whether to surface the saved-printer card.
        // - While checking (page-open verification) always show the in-progress
        //   card so the "MEMERIKSA..." indicator is visible.
        // - Otherwise the card follows the active tab AND must be usable: a USB
        //   entry in storage is always currently-connected (cleared on unplug
        //   at page open); a BT entry only shows when verified reachable, so an
        //   off / out-of-range printer stays saved but hidden until reachable.
        final PrinterInfo? savedPrinter;
        if (state is PrinterCheckingConnection) {
          savedPrinter = state.printer;
        } else {
          final configured = _activePrinter(state) ?? cubit.savedPrinter;
          final usable = configured != null &&
              configured.connectionType == _selectedType &&
              (configured.connectionType == PrinterConnectionType.usb ||
                  cubit.savedBluetoothReachable);
          savedPrinter = usable ? configured : null;
        }
        final isBusy = isScanning || state is PrinterTestInProgress || isValidating;

        // Scan results visible across scan-complete, validating, and failed states.
        final scanPrinters = switch (state) {
          PrinterScanComplete(:final printers) => printers,
          PrinterValidating(:final scanResults) => scanResults,
          PrinterValidationFailed(:final printers) => printers,
          _ => null,
        };
        final validatingPrinter =
            state is PrinterValidating ? state.printer : null;

        return MemoirSectionCard(
          label: 'Printer',
          subtitle: 'Pilih koneksi, pilih printer, lalu test print.',
          icon: Icons.print_outlined,
          trailing: _StatusBadge(state: state),
          children: [
            // ── Inline banner (replaces SnackBar) ──
            if (_bannerMessage != null) ...[
              MemoirBanner(
                message: _bannerMessage!,
                type: _bannerType ?? MemoirBannerType.info,
                onDismiss: _dismissBanner,
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Saved printer card ──
            if (savedPrinter != null) ...[
              _SavedPrinterCard(
                printer: savedPrinter,
                isTesting: state is PrinterTestInProgress,
                isChecking: isChecking,
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Connection type toggle ──
            // Always visible so user can scan a different type even when
            // a printer of another type is already saved.
            if (!isChecking) ...[
              MemoirTabToggle<PrinterConnectionType>(
                items: const [
                  MemoirTabItem(
                    value: PrinterConnectionType.bluetooth,
                    label: 'Bluetooth',
                    icon: Icons.bluetooth,
                  ),
                  MemoirTabItem(
                    value: PrinterConnectionType.usb,
                    label: 'USB (OTG)',
                    icon: Icons.usb,
                  ),
                ],
                selected: _selectedType,
                onChanged: isBusy
                    ? null
                    : (type) => setState(() => _selectedType = type),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Scan button ──
            if (!isChecking) ...[
              MemoirButton.filled(
                label: isScanning
                    ? 'Memuat...'
                    : _selectedType == PrinterConnectionType.usb
                        ? 'Scan USB Printer'
                        : 'Scan Bluetooth Printer',
                icon: isScanning
                    ? null
                    : _selectedType == PrinterConnectionType.usb
                        ? Icons.usb
                        : Icons.bluetooth_searching,
                isLoading: isScanning,
                onPressed: isBusy
                    ? null
                    : () {
                        if (_selectedType == PrinterConnectionType.usb) {
                          cubit.scanUsbPrinters();
                        } else {
                          cubit.scanPrinters();
                        }
                      },
              ),
            ],

            // ── Printer list (scan complete / validating / validation failed) ──
            if (scanPrinters != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'DITEMUKAN (${scanPrinters.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (scanPrinters.isEmpty)
                _EmptyState(connectionType: _selectedType)
              else
                ...scanPrinters.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _PrinterSelectTile(
                      printer: p,
                      isValidating: validatingPrinter?.address == p.address,
                      isDisabled: isBusy &&
                          validatingPrinter?.address != p.address,
                      onTap: () => cubit.validateAndSelectPrinter(p),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  PrinterInfo? _activePrinter(HomeState state) {
    if (state is PrinterSaved) return state.printer;
    if (state is PrinterTestInProgress) return state.printer;
    if (state is PrinterTestSuccess) return state.printer;
    if (state is PrinterTestError) return state.printer;
    return null;
  }
}

// ─── Private widgets ────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final HomeState state;
  const _StatusBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state is PrinterTestSuccess) {
      return _badge('Berhasil', AppColors.success);
    }
    if (state is PrinterTestError) {
      return _badge('Gagal', AppColors.error);
    }
    if (state is PrinterScanInProgress || state is PrinterTestInProgress) {
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

class _SavedPrinterCard extends StatelessWidget {
  final PrinterInfo printer;
  final bool isTesting;
  final bool isChecking;

  const _SavedPrinterCard({
    required this.printer,
    required this.isTesting,
    this.isChecking = false,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HomeCubit>();
    final isUsb = printer.connectionType == PrinterConnectionType.usb;
    final busy = isTesting || isChecking;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: isChecking
            ? AppColors.textSecondary.withValues(alpha: 0.04)
            : AppColors.success.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isChecking
              ? AppColors.border
              : AppColors.success.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUsb ? Icons.usb : Icons.print_outlined,
                color: isChecking ? AppColors.textSecondary : AppColors.success,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isChecking ? 'MEMERIKSA...' : 'TERSIMPAN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isChecking
                                ? AppColors.textSecondary
                                : AppColors.success,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isUsb ? 'USB' : 'BT',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (isChecking) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      printer.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      isChecking
                          ? 'Memeriksa koneksi...'
                          : printer.address,
                      style: TextStyle(
                        fontSize: 11,
                        color: isChecking
                            ? AppColors.textSecondary
                            : AppColors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: busy ? null : () => cubit.clearDefaultPrinter(),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: busy
                        ? AppColors.textDisabled
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (!isChecking) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            MemoirButton.outlined(
              label: isTesting ? 'Printing...' : 'Test Print',
              icon: isTesting ? null : Icons.print_outlined,
              isLoading: isTesting,
              onPressed: isTesting ? null : () => cubit.testPrint(printer),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrinterSelectTile extends StatefulWidget {
  final PrinterInfo printer;
  final VoidCallback onTap;
  final bool isValidating;
  final bool isDisabled;

  const _PrinterSelectTile({
    required this.printer,
    required this.onTap,
    this.isValidating = false,
    this.isDisabled = false,
  });

  @override
  State<_PrinterSelectTile> createState() => _PrinterSelectTileState();
}

class _PrinterSelectTileState extends State<_PrinterSelectTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final canTap = !widget.isValidating && !widget.isDisabled;

    return GestureDetector(
      onTapDown: canTap ? (_) => setState(() => _pressed = true) : null,
      onTapUp: canTap
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel: canTap ? () => setState(() => _pressed = false) : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        opacity: widget.isDisabled ? 0.4 : (_pressed ? 0.6 : 1.0),
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: widget.isValidating
                ? AppColors.brandPrimary.withValues(alpha: 0.05)
                : const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isValidating
                  ? AppColors.brandPrimary.withValues(alpha: 0.3)
                  : AppColors.border.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.printer.connectionType == PrinterConnectionType.usb
                    ? Icons.usb
                    : Icons.print_outlined,
                size: 20,
                color: widget.isValidating
                    ? AppColors.brandPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.printer.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.isValidating
                          ? 'Menghubungkan...'
                          : widget.printer.address,
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isValidating
                            ? AppColors.brandPrimary
                            : AppColors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isValidating)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brandPrimary,
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textDisabled,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final PrinterConnectionType connectionType;

  const _EmptyState({this.connectionType = PrinterConnectionType.bluetooth});

  @override
  Widget build(BuildContext context) {
    final isUsb = connectionType == PrinterConnectionType.usb;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            isUsb ? Icons.usb_off : Icons.print_disabled,
            size: 28,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Tidak ada printer ditemukan',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isUsb
                ? 'Pastikan printer USB terhubung melalui kabel OTG.'
                : 'Printer tidak muncul? Pair printer terlebih dahulu melalui Pengaturan Bluetooth Android, lalu scan ulang.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textDisabled,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../../shared/core/theme/app_colors.dart';
import '../../../../../shared/core/theme/app_spacing.dart';
import '../../../../../shared/data/datasources/storage_service.dart';
import '../../../../../shared/widgets/memoir_section_card.dart';
import 'timeout_chips.dart';

class BoothSettingsSection extends StatefulWidget {
  final StorageService storageService;
  const BoothSettingsSection({super.key, required this.storageService});

  @override
  State<BoothSettingsSection> createState() => _BoothSettingsSectionState();
}

class _BoothSettingsSectionState extends State<BoothSettingsSection> {
  int _defaultPrintCount = 1;
  bool _softcopyEnabled = true;
  String _paymentMethod = 'CASH';
  String _operationMode = 'normal';
  bool _receiptPrintEnabled = false;

  @override
  void initState() {
    super.initState();
    _operationMode = widget.storageService.boothOperationMode;
    _paymentMethod = widget.storageService.paymentActiveMode;
    _defaultPrintCount = widget.storageService.defaultPrintCount;
    _softcopyEnabled = widget.storageService.isSoftcopyEnabled;
    _receiptPrintEnabled = widget.storageService.isReceiptPrintEnabled;
    // Normalize: event mode always uses Cash
    if (_operationMode == 'event' && _paymentMethod != 'CASH') {
      _paymentMethod = 'CASH';
      widget.storageService.setPaymentActiveMode('CASH');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Mode Selection Card ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mode Operasi',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tentukan cara kerja photobooth untuk sesi ini.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: ['normal', 'event'].map((mode) {
                  final isSelected = _operationMode == mode;
                  final label = mode == 'normal' ? 'Normal' : 'Event';
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: mode == 'event' ? 0 : AppSpacing.xs,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _operationMode = mode;
                            if (mode == 'event') _paymentMethod = 'CASH';
                          });
                          widget.storageService.setBoothOperationMode(mode);
                          if (mode == 'event') {
                            widget.storageService.setPaymentActiveMode('CASH');
                          }
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.brandPrimary
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.brandPrimary
                                  : AppColors.border,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            label.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _operationMode == 'normal'
                      ? 'Pengunjung bebas memilih jumlah cetak dan opsi softfile di halaman konfirmasi'
                      : 'Pengaturan cetak dan pembayaran sudah ditentukan. Langsung cetak setelah foto tanpa konfirmasi',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── Metode Pembayaran ──
        MemoirSectionCard(
          label: 'Metode Pembayaran',
          subtitle: _operationMode == 'event'
              ? 'Mode event otomatis menggunakan Cash.'
              : 'Pilih metode pembayaran yang tersedia.',
          icon: Icons.payment_outlined,
          children: [
            Row(
              children: [
                ('CASH', 'Cash'),
                ('STATIC_QRIS', 'QRIS Statis'),
                ('PG', 'Payment Gateway'),
              ].map((entry) {
                final (value, label) = entry;
                final isSelected = _paymentMethod == value;
                final isDisabled = _operationMode == 'event';
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: value == 'PG' ? 0 : AppSpacing.xs,
                    ),
                    child: GestureDetector(
                      onTap: isDisabled
                          ? null
                          : () {
                              setState(() => _paymentMethod = value);
                              widget.storageService.setPaymentActiveMode(value);
                            },
                      behavior: HitTestBehavior.opaque,
                      child: Opacity(
                        opacity: isDisabled && !isSelected ? 0.35 : 1.0,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.brandPrimary
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.brandPrimary
                                  : AppColors.border,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── ALWAYS SHOWN ──
        MemoirSectionCard(
          label: 'Total Cetak Default',
          subtitle: _operationMode == 'event'
              ? 'Jumlah cetak yang otomatis diterapkan tiap sesi.'
              : 'Jumlah default saat pelanggan konfirmasi.',
          icon: Icons.print_outlined,
          children: [
            Row(
              children: [1, 2, 3, 5].map((count) {
                final isSelected = _defaultPrintCount == count;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: count == 5 ? 0 : AppSpacing.xs,
                    ),
                    child: TimeoutChip(
                      label: '$count',
                      isActive: isSelected,
                      onTap: () {
                        setState(() => _defaultPrintCount = count);
                        widget.storageService.setDefaultPrintCount(count);
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        MemoirSectionCard(
          label: 'Softcopy',
          subtitle: _operationMode == 'event'
              ? 'File digital otomatis dikirim setiap sesi.'
              : 'Izinkan pelanggan menerima file digital.',
          icon: Icons.file_download_outlined,
          trailing: Switch(
            value: _softcopyEnabled,
            onChanged: (val) {
              setState(() => _softcopyEnabled = val);
              widget.storageService.setSoftcopyEnabled(val);
            },
            activeThumbColor: AppColors.brandPrimary,
          ),
          children: const [],
        ),
        const SizedBox(height: AppSpacing.md),
        MemoirSectionCard(
          label: 'Cetak Struk',
          subtitle: 'Cetak 1 lembar struk ringkasan setelah semua foto selesai dicetak.',
          icon: Icons.receipt_outlined,
          trailing: Switch(
            value: _receiptPrintEnabled,
            onChanged: (val) {
              setState(() => _receiptPrintEnabled = val);
              widget.storageService.setReceiptPrintEnabled(val);
            },
            activeThumbColor: AppColors.brandPrimary,
          ),
          children: const [],
        ),
      ],
    );
  }
}


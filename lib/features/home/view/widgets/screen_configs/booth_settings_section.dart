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

  @override
  void initState() {
    super.initState();
    _defaultPrintCount = widget.storageService.defaultPrintCount;
    _softcopyEnabled = widget.storageService.isSoftcopyEnabled;
    _paymentMethod = widget.storageService.paymentActiveMode;
    _operationMode = widget.storageService.boothOperationMode;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Alert Card ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outlined,
                size: 20,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Pilih mode operasi terlebih dahulu, ini menentukan alur sesi photobooth',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

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
                          setState(() => _operationMode = mode);
                          widget.storageService.setBoothOperationMode(mode);
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

        // ── NORMAL MODE ONLY ──
        if (_operationMode == 'normal') ...[
          MemoirSectionCard(
            label: 'Metode Pembayaran',
            subtitle: 'Pilih metode pembayaran yang tersedia.',
            icon: Icons.payment_outlined,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ('CASH', 'Cash'),
                  ('STATIC_QRIS', 'QRIS Statis'),
                  ('PG', 'Payment Gateway'),
                ].map((entry) {
                  final (value, label) = entry;
                  final isSelected = _paymentMethod == value;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: value == 'PG' ? 0 : AppSpacing.xs,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _paymentMethod = value);
                        widget.storageService.setPaymentActiveMode(value);
                      },
                      behavior: HitTestBehavior.opaque,
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
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
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
        ],

        // ── EVENT MODE ONLY ──
        if (_operationMode == 'event') ...[
          MemoirSectionCard(
            label: 'Metode Pembayaran',
            subtitle: 'Pilih metode pembayaran untuk event ini.',
            icon: Icons.payment_outlined,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ('CASH', 'Cash'),
                  ('STATIC_QRIS', 'QRIS Statis'),
                ].map((entry) {
                  final (value, label) = entry;
                  final isSelected = _paymentMethod == value;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: value == 'STATIC_QRIS' ? 0 : AppSpacing.xs,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _paymentMethod = value);
                        widget.storageService.setPaymentActiveMode(value);
                      },
                      behavior: HitTestBehavior.opaque,
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
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
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
        ],

        // ── ALWAYS SHOWN ──
        MemoirSectionCard(
          label: 'Total Cetak Default',
          subtitle: 'Jumlah default saat pelanggan konfirmasi.',
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
          subtitle: 'Izinkan pelanggan menerima file digital.',
          icon: Icons.file_download_outlined,
          children: [
            GestureDetector(
              onTap: () {
                setState(() => _softcopyEnabled = !_softcopyEnabled);
                widget.storageService.setSoftcopyEnabled(_softcopyEnabled);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: _softcopyEnabled
                      ? AppColors.brandPrimary.withValues(alpha: 0.1)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _softcopyEnabled
                        ? AppColors.brandPrimary
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.md),
                      child: Text(
                        _softcopyEnabled ? 'Diaktifkan' : 'Dinonaktifkan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _softcopyEnabled
                              ? AppColors.brandPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.md),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _softcopyEnabled
                              ? AppColors.brandPrimary
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: _softcopyEnabled
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

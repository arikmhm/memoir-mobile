import 'package:flutter/material.dart';

import '../../../../../shared/core/theme/app_colors.dart';
import '../../../../../shared/core/theme/app_spacing.dart';
import '../../../../../shared/data/datasources/storage_service.dart';
import '../../../../../shared/widgets/memoir_section_card.dart';
import 'timeout_chips.dart';

class ProcessingSettingsSection extends StatefulWidget {
  final StorageService storageService;
  const ProcessingSettingsSection({super.key, required this.storageService});

  @override
  State<ProcessingSettingsSection> createState() =>
      _ProcessingSettingsSectionState();
}

class _ProcessingSettingsSectionState extends State<ProcessingSettingsSection> {
  late int _errorDuration;
  late bool _receiptPrintEnabled;

  @override
  void initState() {
    super.initState();
    _errorDuration = widget.storageService.processingErrorDuration;
    _receiptPrintEnabled = widget.storageService.isReceiptPrintEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MemoirSectionCard(
          label: 'Cetak Struk',
          subtitle:
              'Cetak 1 lembar struk ringkasan setelah semua foto selesai dicetak.',
          icon: Icons.receipt_outlined,
          trailing: Switch(
            value: _receiptPrintEnabled,
            onChanged: (val) {
              setState(() => _receiptPrintEnabled = val);
              widget.storageService.setReceiptPrintEnabled(val);
            },
            activeThumbColor: AppColors.brandPrimary,
          ),
          children: [
            if (_receiptPrintEnabled)
              const Text(
                'Struk berisi: nama booth, tanggal & jam, jumlah cetak, '
                'metode bayar, total, dan QR softcopy (jika dipilih).',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        MemoirSectionCard(
          label: 'Error Display Duration',
          subtitle: 'Durasi menampilkan error sebelum auto-action (retry/back).',
          icon: Icons.warning_outlined,
          children: [
            Row(
              children: [5, 10, 15, 20].map((seconds) {
                final isSelected = _errorDuration == seconds;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: seconds == 20 ? 0 : AppSpacing.xs,
                    ),
                    child: TimeoutChip(
                      label: '${seconds}d',
                      isActive: isSelected,
                      onTap: () {
                        setState(() => _errorDuration = seconds);
                        widget.storageService
                            .setProcessingErrorDuration(seconds);
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ],
    );
  }
}

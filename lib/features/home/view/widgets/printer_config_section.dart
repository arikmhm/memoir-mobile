import 'package:flutter/material.dart';

import '../../../../shared/core/theme/app_colors.dart';
import '../../../../shared/core/theme/app_spacing.dart';
import '../pages/image_processing_page.dart';

/// Tappable entry card in the Devices page that opens the printer output
/// configuration — thermal print tuning (density, dither, brightness,
/// sharpen) plus the live image-processing test.
///
/// Styled to sit alongside the other device sections (white card, subtle
/// border, uppercase label) but acts as a navigation tile with a chevron.
class PrinterConfigSection extends StatefulWidget {
  const PrinterConfigSection({super.key});

  @override
  State<PrinterConfigSection> createState() => _PrinterConfigSectionState();
}

class _PrinterConfigSectionState extends State<PrinterConfigSection> {
  bool _pressed = false;

  void _open() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ImageProcessingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        _open();
      },
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md + 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.tune_outlined,
                  size: 20,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KONFIGURASI PRINTER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Atur pemrosesan gambar & hasil cetak thermal.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right,
                size: 22,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../../shared/core/theme/app_colors.dart';
import '../../../../shared/core/theme/app_spacing.dart';
import '../../../../shared/data/datasources/storage_service.dart';
import '../../../../shared/widgets/memoir_button.dart';
import '../../../../shared/widgets/memoir_section_card.dart';

/// Payment method configuration section — dashboard card style.
///
/// Matches memoir dashboard web design: white card, uppercase label,
/// custom radio tiles, custom buttons (no Material ripple).
class PaymentMethodSection extends StatefulWidget {
  final StorageService storageService;

  const PaymentMethodSection({
    super.key,
    required this.storageService,
  });

  @override
  State<PaymentMethodSection> createState() => _PaymentMethodSectionState();
}

class _PaymentMethodSectionState extends State<PaymentMethodSection> {
  late String _activeMode;
  late String? _qrisImagePath;

  @override
  void initState() {
    super.initState();
    _activeMode = widget.storageService.paymentActiveMode;
    _qrisImagePath = widget.storageService.staticQrisImagePath;
  }

  Future<void> _setMode(String mode) async {
    setState(() => _activeMode = mode);
    await widget.storageService.setPaymentActiveMode(mode);
  }

  Future<void> _pickQrisImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'static_qris${p.extension(picked.path)}';
    final savedFile = await File(picked.path).copy(
      p.join(appDir.path, fileName),
    );

    await widget.storageService.setStaticQrisImagePath(savedFile.path);
    setState(() => _qrisImagePath = savedFile.path);
  }

  Future<void> _removeQrisImage() async {
    if (_qrisImagePath != null) {
      final file = File(_qrisImagePath!);
      if (file.existsSync()) {
        await file.delete();
      }
    }
    await widget.storageService.clearStaticQrisImage();
    setState(() => _qrisImagePath = null);
  }

  @override
  Widget build(BuildContext context) {
    return MemoirSectionCard(
      label: 'Metode Pembayaran',
      subtitle: 'Pilih metode pembayaran yang digunakan di kiosk ini.',
      icon: Icons.payment_outlined,
      children: [
        // ── Payment method options ──
        _PaymentOption(
          label: 'Tunai (Cash)',
          subtitle: 'Pembayaran langsung ke petugas',
          icon: Icons.payments_outlined,
          isSelected: _activeMode == 'CASH',
          onTap: () => _setMode('CASH'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _PaymentOption(
          label: 'QRIS Statis',
          subtitle: 'QR code milik owner yang tidak berubah',
          icon: Icons.qr_code_2,
          isSelected: _activeMode == 'STATIC_QRIS',
          onTap: () => _setMode('STATIC_QRIS'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _PaymentOption(
          label: 'QRIS Dinamis (Payment Gateway)',
          subtitle: 'QR code otomatis via Xendit',
          icon: Icons.credit_card_outlined,
          isSelected: _activeMode == 'PG',
          onTap: () => _setMode('PG'),
        ),

        // ── Static QRIS upload ──
        if (_activeMode == 'STATIC_QRIS') ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'UPLOAD QRIS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                if (_qrisImagePath != null &&
                    File(_qrisImagePath!).existsSync()) ...[
                  // Show uploaded QRIS image
                  Center(
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.5),
                        ),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Image.file(
                        File(_qrisImagePath!),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  Row(
                    children: [
                      Expanded(
                        child: MemoirButton.outlined(
                          label: 'Ganti',
                          icon: Icons.swap_horiz,
                          onPressed: _pickQrisImage,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: MemoirButton.outlined(
                          label: 'Hapus',
                          icon: Icons.delete_outline,
                          color: AppColors.error,
                          onPressed: _removeQrisImage,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // No image — show upload placeholder
                  Center(
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_2,
                            size: 40,
                            color: AppColors.textDisabled,
                          ),
                          SizedBox(height: AppSpacing.sm),
                          Text(
                            'Belum ada QRIS',
                            style: TextStyle(
                              color: AppColors.textDisabled,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  MemoirButton.filled(
                    label: 'Upload QRIS',
                    icon: Icons.upload_outlined,
                    onPressed: _pickQrisImage,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Payment Option Radio Tile ──────────────────────────────────

class _PaymentOption extends StatefulWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PaymentOption> createState() => _PaymentOptionState();
}

class _PaymentOptionState extends State<_PaymentOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.textPrimary.withValues(alpha: 0.04)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.textPrimary
                  : AppColors.border.withValues(alpha: 0.6),
              width: widget.isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: widget.isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Custom radio indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isSelected
                        ? AppColors.textPrimary
                        : AppColors.textDisabled,
                    width: 1.5,
                  ),
                ),
                child: widget.isSelected
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../di.dart';
import '../../../../shared/core/theme/app_colors.dart';
import '../../../../shared/core/theme/app_spacing.dart';
import '../../../../shared/data/datasources/storage_service.dart';
import '../../../../shared/widgets/menu_header_card.dart';
import '../widgets/screen_configs/booth_settings_section.dart';

class PaymentPage extends StatelessWidget {
  const PaymentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        title: Text(
          'Pembayaran',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MenuHeaderCard(
              icon: Icons.payment_outlined,
              title: 'Pembayaran',
              description:
                  'Konfigurasi metode pembayaran (Cash, QRIS, Payment Gateway).',
            ),
            const SizedBox(height: AppSpacing.lg),
            BoothSettingsSection(storageService: sl<StorageService>()),
          ],
        ),
      ),
    );
  }
}

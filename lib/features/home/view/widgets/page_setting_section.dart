import 'package:flutter/material.dart';

import '../../../../shared/core/theme/app_colors.dart';
import '../../../../shared/core/theme/app_spacing.dart';
import '../pages/screen_config_page.dart';

class PageSettingSection extends StatelessWidget {
  const PageSettingSection({super.key});

  static const _screens = [
    (label: 'Screensaver', icon: Icons.image_outlined, route: 'screensaver'),
    (label: 'Select Template', icon: Icons.grid_3x3_outlined, route: 'select-template'),
    (label: 'Photo Session', icon: Icons.photo_camera_outlined, route: 'photo-session'),
    (label: 'Preview', icon: Icons.preview_outlined, route: 'preview'),
    (label: 'Confirmation', icon: Icons.done_all_outlined, route: 'confirmation'),
    (label: 'Processing', icon: Icons.hourglass_bottom_outlined, route: 'processing'),
    (label: 'Thank You', icon: Icons.favorite_outlined, route: 'thank-you'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Centered header ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.border,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pages_outlined,
                  size: 28,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Pengaturan Halaman',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Atur timing dan pengaturan untuk setiap halaman',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Screen Submenu ──
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _screens.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              color: AppColors.border,
              indent: AppSpacing.lg,
              endIndent: AppSpacing.lg,
            ),
            itemBuilder: (context, index) {
              final screen = _screens[index];
              return _ScreenCard(
                icon: screen.icon,
                label: screen.label,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ScreenConfigPage(
                      screenLabel: screen.label,
                      route: screen.route,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Screen Card (iOS Settings style) ───────────────────────────

class _ScreenCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ScreenCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
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
              child: Icon(
                icon,
                size: 20,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

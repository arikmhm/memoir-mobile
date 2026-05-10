import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../di.dart';
import '../../../shared/core/theme/app_colors.dart';
import '../../../shared/core/theme/app_spacing.dart';
import '../../../shared/core/utils/formatters.dart';
import '../../../shared/data/datasources/storage_service.dart';
import '../../../shared/data/models/kiosk_config.dart';
import 'pages/booth_mode_page.dart';
import 'pages/devices_page.dart';
import 'pages/page_setting_page.dart';
import 'pages/payment_page.dart';
import 'pages/template_page.dart';
import 'widgets/template_list_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _tabs = [
    _TabDef(icon: Icons.dashboard_outlined, label: 'Template'),
    _TabDef(icon: Icons.tune_outlined, label: 'Mode Booth'),
    _TabDef(icon: Icons.display_settings_outlined, label: 'Page Setting'),
    _TabDef(icon: Icons.devices_outlined, label: 'Perangkat'),
    _TabDef(icon: Icons.payment_outlined, label: 'Pembayaran'),
  ];

  void _navigateToMenu(int index) {
    final page = switch (index) {
      0 => const TemplatePage(),
      1 => const BoothModePage(),
      2 => const PageSettingPage(),
      3 => const DevicesPage(),
      4 => const PaymentPage(),
      _ => null,
    };
    if (page == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Brand top bar ──
          Container(
            decoration: const BoxDecoration(color: Colors.white),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              MediaQuery.of(context).padding.top + AppSpacing.screenVertical,
              AppSpacing.screenHorizontal,
              AppSpacing.screenVertical,
            ),
            child: Row(
              children: [
                Text(
                  'memoir.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),
              ],
            ),
          ),

          // ── Menu Cards Grid & Content area ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
                vertical: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Booth info
                  const _BoothInfoCard(),
                  const SizedBox(height: AppSpacing.md),

                  // Menu Card Container
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 90,
                          mainAxisSpacing: AppSpacing.md,
                          crossAxisSpacing: AppSpacing.md,
                          childAspectRatio: 0.85,
                        ),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _tabs.length,
                        itemBuilder: (context, index) {
                          final entry = _tabs[index];
                          return _MenuCard(
                            icon: entry.icon,
                            label: entry.label,
                            onTap: () => _navigateToMenu(index),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const TemplateListSection(),
                  const SizedBox(height: AppSpacing.xxl),
                  Center(
                    child: Text(
                      'memoir. Mobile Runner v1.0.0',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textDisabled,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),

          // ── Start Booth Button (sticky) ──
          Container(
            decoration: const BoxDecoration(color: Colors.white),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.screenVertical,
              AppSpacing.screenHorizontal,
              AppSpacing.screenVertical + MediaQuery.of(context).padding.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/screensaver'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Start Booth',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Booth Info Card ────────────────────────────────────────────

class _BoothInfoCard extends StatelessWidget {
  const _BoothInfoCard();

  @override
  Widget build(BuildContext context) {
    final configJson = sl<StorageService>().kioskConfigJson;
    if (configJson == null) return const SizedBox.shrink();

    final config = KioskConfig.fromJsonString(configJson);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Name ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Text(
              config.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const Divider(height: 1, thickness: 1, color: AppColors.border),

          // ── Price row ──
          IntrinsicHeight(
            child: Row(
              children: [
                _PriceItem(
                  label: 'Sesi',
                  value: Formatters.formatRupiah(config.priceBaseSession),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.border,
                ),
                _PriceItem(
                  label: 'Cetak Ekstra',
                  value: Formatters.formatRupiah(config.pricePerExtraPrint),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.border,
                ),
                _PriceItem(
                  label: 'Softcopy',
                  value: Formatters.formatRupiah(config.priceDigitalCopy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceItem extends StatelessWidget {
  final String label;
  final String value;

  const _PriceItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab definition ─────────────────────────────────────────────

class _TabDef {
  final IconData icon;
  final String label;

  const _TabDef({required this.icon, required this.label});
}

// ─── Menu Card widget ──────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, size: 28, color: AppColors.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 10,
                color: AppColors.textPrimary,
              ),
        ),
      ],
    );
  }
}

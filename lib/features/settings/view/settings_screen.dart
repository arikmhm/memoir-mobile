import 'package:flutter/material.dart';

import '../../../di.dart';
import '../../../shared/core/theme/app_colors.dart';
import '../../../shared/core/theme/app_spacing.dart';
import '../../../shared/data/datasources/storage_service.dart';
import 'widgets/camera_test_section.dart';
import 'widgets/payment_method_section.dart';
import 'widgets/printer_test_section.dart';
import 'widgets/screensaver_config_section.dart';
import 'widgets/session_timer_section.dart';
import 'widgets/template_list_section.dart';

/// Settings (Operator) screen — device configuration & diagnostics.
///
/// Dashboard-style layout: custom header, sticky horizontal tabs,
/// content area switches per tab. No Material AppBar or TabBar.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _activeTab = 0;

  static const _tabs = [
    _TabDef(icon: Icons.dashboard_outlined, label: 'Template'),
    _TabDef(icon: Icons.camera_alt_outlined, label: 'Kamera'),
    _TabDef(icon: Icons.print_outlined, label: 'Printer'),
    _TabDef(icon: Icons.payment_outlined, label: 'Pembayaran'),
    _TabDef(icon: Icons.timer_outlined, label: 'Waktu Sesi'),
    _TabDef(icon: Icons.wallpaper_outlined, label: 'Screensaver'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Brand top bar ──
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
              ),
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
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 2,
                    ),
                    child: Text(
                      '|',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w300,
                            color: AppColors.textDisabled,
                          ),
                    ),
                  ),
                  Text(
                    'runner app configuration',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_back_ios_new,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Kembali',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Tabs bar (separate) ──
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF6F6F6),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  child: Row(
                    children: _tabs.asMap().entries.map((entry) {
                      return Padding(
                        padding: EdgeInsets.only(
                          right: entry.key < _tabs.length - 1
                              ? AppSpacing.xs
                              : 0,
                        ),
                        child: _Tab(
                          icon: entry.value.icon,
                          label: entry.value.label,
                          isActive: _activeTab == entry.key,
                          onTap: () =>
                              setState(() => _activeTab = entry.key),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // ── Content area ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  children: [
                    _buildContent(),
                    const SizedBox(height: AppSpacing.xxl),
                    Center(
                      child: Text(
                        'memoir. Mobile Runner v1.0.0',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
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
          ],
      ),
    );
  }

  Widget _buildContent() {
    return switch (_activeTab) {
      0 => const TemplateListSection(),
      1 => const CameraTestSection(),
      2 => const PrinterTestSection(),
      3 => PaymentMethodSection(storageService: sl<StorageService>()),
      4 => SessionTimerSection(storageService: sl<StorageService>()),
      5 => ScreensaverConfigSection(storageService: sl<StorageService>()),
      _ => const SizedBox.shrink(),
    };
  }
}

// ─── Tab definition ─────────────────────────────────────────────

class _TabDef {
  final IconData icon;
  final String label;

  const _TabDef({required this.icon, required this.label});
}

// ─── Single tab widget ──────────────────────────────────────────

class _Tab extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _Tab({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
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
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.isActive
                    ? AppColors.textPrimary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.isActive
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      widget.isActive ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isActive
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

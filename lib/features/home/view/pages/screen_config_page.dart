import 'package:flutter/material.dart';

import '../../../../di.dart';
import '../../../../shared/core/theme/app_colors.dart';
import '../../../../shared/core/theme/app_spacing.dart';
import '../../../../shared/data/datasources/storage_service.dart';
import '../widgets/screen_configs/page_bg_section.dart';
import '../widgets/screen_configs/processing_settings_section.dart';
import '../widgets/screen_configs/screensaver_config_section.dart';

class ScreenConfigPage extends StatelessWidget {
  final String screenLabel;
  final String route;

  const ScreenConfigPage({
    required this.screenLabel,
    required this.route,
    super.key,
  });

  Widget _withBg(String pageKey, Widget? topSection) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (topSection != null) ...[
          topSection,
          const SizedBox(height: AppSpacing.md),
        ],
        PageBgSection(
          storageService: sl<StorageService>(),
          pageKey: pageKey,
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (route) {
      case 'screensaver':
        return ScreensaverConfigSection(storageService: sl<StorageService>());
      case 'select-template':
        return _withBg('selectTemplate', null);
      case 'photo-session':
        return _withBg('photoSession', null);
      case 'preview':
        return _withBg('preview', null);
      case 'confirmation':
        return _withBg('confirmation', null);
      case 'processing':
        return _withBg('processing', ProcessingSettingsSection(storageService: sl<StorageService>()));
      case 'thank-you':
        return _withBg('thankYou', null);
      default:
        return Center(child: Text('$screenLabel configuration coming soon'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        leadingWidth: 160,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    'Page Setting',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        title: Text(
          screenLabel,
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
        child: _buildContent(),
      ),
    );
  }
}

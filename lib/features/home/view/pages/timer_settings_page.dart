import 'package:flutter/material.dart';

import '../../../../di.dart';
import '../../../../shared/core/theme/app_colors.dart';
import '../../../../shared/core/theme/app_spacing.dart';
import '../../../../shared/data/datasources/storage_service.dart';
import '../../../../shared/widgets/memoir_section_card.dart';
import '../../../../shared/widgets/menu_header_card.dart';
import '../widgets/screen_configs/timeout_chips.dart';

/// Consolidated timer settings page.
///
/// All session-related timers in one place:
/// - Global session timeout (from "Start Booth" tap until auto-return to screensaver)
/// - Photo capture countdown (3, 2, 1, ...)
/// - Thank you screen duration
class TimerSettingsPage extends StatelessWidget {
  const TimerSettingsPage({super.key});

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
          'Pengaturan Timer',
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
        child: _TimerSettingsBody(storageService: sl<StorageService>()),
      ),
    );
  }
}

class _TimerSettingsBody extends StatefulWidget {
  final StorageService storageService;
  const _TimerSettingsBody({required this.storageService});

  @override
  State<_TimerSettingsBody> createState() => _TimerSettingsBodyState();
}

class _TimerSettingsBodyState extends State<_TimerSettingsBody> {
  late int _globalSession;
  late int _captureCountdown;
  late int _thankYouDuration;

  @override
  void initState() {
    super.initState();
    _globalSession = widget.storageService.globalSessionTimeout;
    _captureCountdown = widget.storageService.captureCountdown;
    _thankYouDuration = widget.storageService.thankYouDuration;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const MenuHeaderCard(
          icon: Icons.timer_outlined,
          title: 'Pengaturan Timer',
          description:
              'Atur durasi sesi global, countdown foto, dan halaman terimakasih.',
        ),
        const SizedBox(height: AppSpacing.lg),
        MemoirSectionCard(
          label: 'Sesi Global',
          subtitle:
              'Total durasi sesi dari tap Start Booth sampai otomatis kembali ke screensaver.',
          icon: Icons.hourglass_top_outlined,
          children: [
            TimeoutOptionChips(
              options: const [300, 600, 900, 1200],
              selected: _globalSession,
              onSelected: (v) {
                setState(() => _globalSession = v);
                widget.storageService.setGlobalSessionTimeout(v);
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        MemoirSectionCard(
          label: 'Countdown Foto',
          subtitle: 'Hitungan mundur sebelum kamera mengambil foto.',
          icon: Icons.camera_alt_outlined,
          children: [
            Row(
              children: [3, 5, 7, 10].map((seconds) {
                final isSelected = _captureCountdown == seconds;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: seconds == 10 ? 0 : AppSpacing.xs,
                    ),
                    child: TimeoutChip(
                      label: '${seconds}d',
                      isActive: isSelected,
                      onTap: () {
                        setState(() => _captureCountdown = seconds);
                        widget.storageService.setCaptureCountdown(seconds);
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
          label: 'Durasi Thank You',
          subtitle:
              'Berapa lama halaman thank you ditampilkan sebelum kembali ke screensaver.',
          icon: Icons.favorite_outline,
          children: [
            Row(
              children: [15, 20, 30, 45].map((seconds) {
                final isSelected = _thankYouDuration == seconds;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: seconds == 45 ? 0 : AppSpacing.xs,
                    ),
                    child: TimeoutChip(
                      label: '${seconds}d',
                      isActive: isSelected,
                      onTap: () {
                        setState(() => _thankYouDuration = seconds);
                        widget.storageService.setThankYouDuration(seconds);
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

import 'package:flutter/material.dart';

import '../../../../../shared/core/theme/app_spacing.dart';
import '../../../../../shared/data/datasources/storage_service.dart';
import '../../../../../shared/widgets/memoir_section_card.dart';
import 'timeout_chips.dart';

class PhotoSessionSettingsSection extends StatefulWidget {
  final StorageService storageService;
  const PhotoSessionSettingsSection({super.key, required this.storageService});

  @override
  State<PhotoSessionSettingsSection> createState() =>
      _PhotoSessionSettingsSectionState();
}

class _PhotoSessionSettingsSectionState
    extends State<PhotoSessionSettingsSection> {
  late int _captureCountdown;
  late int _photoSessionTimeout;

  @override
  void initState() {
    super.initState();
    _captureCountdown = widget.storageService.captureCountdown;
    _photoSessionTimeout = widget.storageService.photoSessionTimeout;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
          label: 'Waktu Timeout',
          subtitle: 'Otomatis kembali ke screensaver jika tidak ada input.',
          icon: Icons.timer_outlined,
          children: [
            TimeoutOptionChips(
              options: const [60, 120, 180, 300],
              selected: _photoSessionTimeout,
              onSelected: (v) {
                setState(() => _photoSessionTimeout = v);
                widget.storageService.setPhotoSessionTimeout(v);
              },
            ),
          ],
        ),
      ],
    );
  }
}

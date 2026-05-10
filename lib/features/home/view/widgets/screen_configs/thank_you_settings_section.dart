import 'package:flutter/material.dart';

import '../../../../../shared/core/theme/app_spacing.dart';
import '../../../../../shared/data/datasources/storage_service.dart';
import '../../../../../shared/widgets/memoir_section_card.dart';
import 'timeout_chips.dart';

class ThankYouSettingsSection extends StatefulWidget {
  final StorageService storageService;
  const ThankYouSettingsSection({super.key, required this.storageService});

  @override
  State<ThankYouSettingsSection> createState() =>
      _ThankYouSettingsSectionState();
}

class _ThankYouSettingsSectionState extends State<ThankYouSettingsSection> {
  late int _duration;

  @override
  void initState() {
    super.initState();
    _duration = widget.storageService.thankYouDuration;
  }

  @override
  Widget build(BuildContext context) {
    return MemoirSectionCard(
      label: 'Waktu Tampil',
      subtitle: 'Durasi halaman thank you sebelum kembali ke screensaver.',
      icon: Icons.timer_outlined,
      children: [
        Row(
          children: [15, 20, 30, 45].map((seconds) {
            final isSelected = _duration == seconds;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: seconds == 45 ? 0 : AppSpacing.xs,
                ),
                child: TimeoutChip(
                  label: '${seconds}d',
                  isActive: isSelected,
                  onTap: () {
                    setState(() => _duration = seconds);
                    widget.storageService.setThankYouDuration(seconds);
                  },
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

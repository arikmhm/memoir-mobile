import 'package:flutter/material.dart';

import '../../../../../shared/core/theme/app_spacing.dart';
import '../../../../../shared/data/datasources/storage_service.dart';
import '../../../../../shared/widgets/memoir_section_card.dart';
import 'timeout_chips.dart';

class ProcessingSettingsSection extends StatefulWidget {
  final StorageService storageService;
  const ProcessingSettingsSection({super.key, required this.storageService});

  @override
  State<ProcessingSettingsSection> createState() =>
      _ProcessingSettingsSectionState();
}

class _ProcessingSettingsSectionState extends State<ProcessingSettingsSection> {
  late int _errorDuration;

  @override
  void initState() {
    super.initState();
    _errorDuration = widget.storageService.processingErrorDuration;
  }

  @override
  Widget build(BuildContext context) {
    return MemoirSectionCard(
      label: 'Error Display Duration',
      subtitle: 'Durasi menampilkan error sebelum auto-action (retry/back).',
      icon: Icons.warning_outlined,
      children: [
        Row(
          children: [5, 10, 15, 20].map((seconds) {
            final isSelected = _errorDuration == seconds;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: seconds == 20 ? 0 : AppSpacing.xs,
                ),
                child: TimeoutChip(
                  label: '${seconds}d',
                  isActive: isSelected,
                  onTap: () {
                    setState(() => _errorDuration = seconds);
                    widget.storageService.setProcessingErrorDuration(seconds);
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

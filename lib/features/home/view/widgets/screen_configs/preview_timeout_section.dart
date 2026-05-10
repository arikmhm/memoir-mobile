import 'package:flutter/material.dart';

import '../../../../../shared/data/datasources/storage_service.dart';
import '../../../../../shared/widgets/memoir_section_card.dart';
import 'timeout_chips.dart';

class PreviewTimeoutSection extends StatefulWidget {
  final StorageService storageService;
  const PreviewTimeoutSection({super.key, required this.storageService});

  @override
  State<PreviewTimeoutSection> createState() => _PreviewTimeoutSectionState();
}

class _PreviewTimeoutSectionState extends State<PreviewTimeoutSection> {
  late int _timeout;

  @override
  void initState() {
    super.initState();
    _timeout = widget.storageService.previewTimeout;
  }

  @override
  Widget build(BuildContext context) {
    return MemoirSectionCard(
      label: 'Waktu Timeout',
      subtitle: 'Otomatis kembali ke screensaver jika tidak ada input.',
      icon: Icons.timer_outlined,
      children: [
        TimeoutOptionChips(
          options: const [60, 120, 180, 300],
          selected: _timeout,
          onSelected: (v) {
            setState(() => _timeout = v);
            widget.storageService.setPreviewTimeout(v);
          },
        ),
      ],
    );
  }
}

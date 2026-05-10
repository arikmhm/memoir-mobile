import 'package:flutter/material.dart';

import '../../../../../shared/data/datasources/storage_service.dart';
import '../../../../../shared/widgets/memoir_section_card.dart';
import 'timeout_chips.dart';

class SelectTemplateTimeoutSection extends StatefulWidget {
  final StorageService storageService;
  const SelectTemplateTimeoutSection({super.key, required this.storageService});

  @override
  State<SelectTemplateTimeoutSection> createState() =>
      _SelectTemplateTimeoutSectionState();
}

class _SelectTemplateTimeoutSectionState
    extends State<SelectTemplateTimeoutSection> {
  late int _timeout;

  @override
  void initState() {
    super.initState();
    _timeout = widget.storageService.selectTemplateTimeout;
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
            widget.storageService.setSelectTemplateTimeout(v);
          },
        ),
      ],
    );
  }
}

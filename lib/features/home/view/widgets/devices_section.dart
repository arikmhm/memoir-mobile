import 'package:flutter/material.dart';

import '../../../../shared/core/theme/app_spacing.dart';
import 'camera_test_section.dart';
import 'printer_config_section.dart';
import 'printer_test_section.dart';

class DevicesSection extends StatelessWidget {
  const DevicesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        CameraTestSection(),
        SizedBox(height: AppSpacing.md),
        PrinterTestSection(),
        SizedBox(height: AppSpacing.md),
        PrinterConfigSection(),
      ],
    );
  }
}

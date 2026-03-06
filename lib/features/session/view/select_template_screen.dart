import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/core/theme/app_colors.dart';
import '../../../shared/core/theme/app_spacing.dart';
import '../../../shared/data/models/template.dart';

/// Template selection screen — grid of available templates.
///
/// Per PRD-05 FEAT-MR-04: Grid browsing of templates.
/// Currently displays mock template data.
class SelectTemplateScreen extends StatelessWidget {
  const SelectTemplateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock templates for demonstration
    final mockTemplates = _generateMockTemplates();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              child: Text(
                'Pilih Template',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),

            // Template grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.75,
                ),
                itemCount: mockTemplates.length,
                itemBuilder: (context, index) {
                  final template = mockTemplates[index];
                  return _TemplateCard(template: template);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final Template template;

  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.go('/photo-session/${template.id}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Template preview placeholder
            const Expanded(
              child: ColoredBox(
                color: AppColors.surfaceVariant,
                child: Center(
                  child: Icon(
                    Icons.photo_library_outlined,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            // Template name
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                template.name,
                style: Theme.of(context).textTheme.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Generate mock templates for demo purposes.
List<Template> _generateMockTemplates() => [
  Template(
    id: 'tmpl_001',
    name: 'Classic 2x2',
    width: 1200,
    height: 1800,
    elements: [
      const TemplateElement(
        id: 'el_001',
        type: 'photo_slot',
        x: 50,
        y: 50,
        width: 500,
        height: 400,
        sequence: 1,
        properties: {'captureOrder': 1},
      ),
      const TemplateElement(
        id: 'el_002',
        type: 'photo_slot',
        x: 650,
        y: 50,
        width: 500,
        height: 400,
        sequence: 2,
        properties: {'captureOrder': 2},
      ),
      const TemplateElement(
        id: 'el_003',
        type: 'photo_slot',
        x: 50,
        y: 500,
        width: 500,
        height: 400,
        sequence: 3,
        properties: {'captureOrder': 3},
      ),
      const TemplateElement(
        id: 'el_004',
        type: 'photo_slot',
        x: 650,
        y: 500,
        width: 500,
        height: 400,
        sequence: 4,
        properties: {'captureOrder': 4},
      ),
    ],
    updatedAt: DateTime.now(),
  ),
  Template(
    id: 'tmpl_002',
    name: 'Strip 4',
    width: 600,
    height: 1800,
    elements: [
      const TemplateElement(
        id: 'el_005',
        type: 'photo_slot',
        x: 50,
        y: 50,
        width: 500,
        height: 375,
        sequence: 1,
        properties: {'captureOrder': 1},
      ),
      const TemplateElement(
        id: 'el_006',
        type: 'photo_slot',
        x: 50,
        y: 475,
        width: 500,
        height: 375,
        sequence: 2,
        properties: {'captureOrder': 2},
      ),
      const TemplateElement(
        id: 'el_007',
        type: 'photo_slot',
        x: 50,
        y: 900,
        width: 500,
        height: 375,
        sequence: 3,
        properties: {'captureOrder': 3},
      ),
      const TemplateElement(
        id: 'el_008',
        type: 'photo_slot',
        x: 50,
        y: 1325,
        width: 500,
        height: 375,
        sequence: 4,
        properties: {'captureOrder': 4},
      ),
    ],
    updatedAt: DateTime.now(),
  ),
  Template(
    id: 'tmpl_003',
    name: 'Single Wide',
    width: 1800,
    height: 1200,
    elements: [
      const TemplateElement(
        id: 'el_009',
        type: 'photo_slot',
        x: 100,
        y: 100,
        width: 1600,
        height: 1000,
        sequence: 1,
        properties: {'captureOrder': 1},
      ),
    ],
    updatedAt: DateTime.now(),
  ),
  Template(
    id: 'tmpl_004',
    name: 'Collage 3',
    width: 1200,
    height: 1800,
    elements: [
      const TemplateElement(
        id: 'el_010',
        type: 'photo_slot',
        x: 50,
        y: 50,
        width: 1100,
        height: 550,
        sequence: 1,
        properties: {'captureOrder': 1},
      ),
      const TemplateElement(
        id: 'el_011',
        type: 'photo_slot',
        x: 50,
        y: 650,
        width: 525,
        height: 525,
        sequence: 2,
        properties: {'captureOrder': 2},
      ),
      const TemplateElement(
        id: 'el_012',
        type: 'photo_slot',
        x: 625,
        y: 650,
        width: 525,
        height: 525,
        sequence: 3,
        properties: {'captureOrder': 3},
      ),
    ],
    updatedAt: DateTime.now(),
  ),
  Template(
    id: 'tmpl_005',
    name: 'Duo',
    width: 1200,
    height: 900,
    elements: [
      const TemplateElement(
        id: 'el_013',
        type: 'photo_slot',
        x: 50,
        y: 50,
        width: 525,
        height: 800,
        sequence: 1,
        properties: {'captureOrder': 1},
      ),
      const TemplateElement(
        id: 'el_014',
        type: 'photo_slot',
        x: 625,
        y: 50,
        width: 525,
        height: 800,
        sequence: 2,
        properties: {'captureOrder': 2},
      ),
    ],
    updatedAt: DateTime.now(),
  ),
  Template(
    id: 'tmpl_006',
    name: 'Vintage Frame',
    width: 1200,
    height: 1800,
    elements: [
      const TemplateElement(
        id: 'el_015',
        type: 'photo_slot',
        x: 150,
        y: 200,
        width: 900,
        height: 700,
        sequence: 2,
        properties: {'captureOrder': 1},
      ),
      const TemplateElement(
        id: 'el_016',
        type: 'text',
        x: 300,
        y: 1000,
        width: 600,
        height: 80,
        sequence: 3,
        properties: {
          'text': 'memoir.',
          'fontSize': 48,
          'fontWeight': 'bold',
          'color': '#FFFFFF',
        },
      ),
    ],
    updatedAt: DateTime.now(),
  ),
];

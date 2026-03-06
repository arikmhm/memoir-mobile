import 'package:equatable/equatable.dart';

/// Template model matching `GET /kiosk/templates` response.
///
/// Per PRD-05 Section 8: 4 element types (`photo_slot`, `image`, `text`, `shape`)
/// with spatial attributes and polymorphic properties.
class Template extends Equatable {
  final String id;
  final String name;
  final int width;
  final int height;
  final String? backgroundUrl;
  final String? localBackgroundPath;
  final List<TemplateElement> elements;
  final DateTime updatedAt;

  const Template({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    this.backgroundUrl,
    this.localBackgroundPath,
    required this.elements,
    required this.updatedAt,
  });

  factory Template.fromJson(Map<String, dynamic> json) => Template(
    id: json['id'] as String,
    name: json['name'] as String,
    width: json['width'] as int,
    height: json['height'] as int,
    backgroundUrl: json['backgroundUrl'] as String?,
    localBackgroundPath: json['localBackgroundPath'] as String?,
    elements: (json['elements'] as List<dynamic>)
        .map((e) => TemplateElement.fromJson(e as Map<String, dynamic>))
        .toList(),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'width': width,
    'height': height,
    'backgroundUrl': backgroundUrl,
    'localBackgroundPath': localBackgroundPath,
    'elements': elements.map((e) => e.toJson()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [id, name, width, height, updatedAt];
}

/// A single element within a template.
///
/// Types: `photo_slot`, `image`, `text`, `shape`.
/// Sorted by `sequence` (z-order).
class TemplateElement extends Equatable {
  final String id;
  final String type; // photo_slot, image, text, shape
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final double opacity;
  final int sequence;
  final Map<String, dynamic> properties;

  const TemplateElement({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.opacity = 1.0,
    required this.sequence,
    required this.properties,
  });

  factory TemplateElement.fromJson(Map<String, dynamic> json) =>
      TemplateElement(
        id: json['id'] as String,
        type: json['type'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
        sequence: json['sequence'] as int,
        properties: json['properties'] as Map<String, dynamic>,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'rotation': rotation,
    'opacity': opacity,
    'sequence': sequence,
    'properties': properties,
  };

  @override
  List<Object?> get props => [id, type, sequence];
}

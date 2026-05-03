import 'package:equatable/equatable.dart';

/// Template model matching `GET /kiosk/templates` response.
///
/// Element types: `PHOTO_SLOT`, `IMAGE`, `TEXT`.
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

  /// Parse from GET /kiosk/templates response item.
  ///
  /// API returns: `{ "template": {...}, "elements": [...], "updatedAt": "..." }`
  factory Template.fromApiJson(Map<String, dynamic> json) {
    final tmpl = json['template'] as Map<String, dynamic>;
    final elements = json['elements'] as List<dynamic>? ?? [];
    return Template(
      id: tmpl['id'] as String,
      name: tmpl['name'] as String,
      width: tmpl['width'] as int,
      height: tmpl['height'] as int,
      backgroundUrl: tmpl['backgroundUrl'] as String?,
      elements: elements
          .map((e) => TemplateElement.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Parse from flat JSON (e.g. cached data).
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

  /// Create a copy with optional field overrides.
  Template copyWith({
    String? localBackgroundPath,
  }) =>
      Template(
        id: id,
        name: name,
        width: width,
        height: height,
        backgroundUrl: backgroundUrl,
        localBackgroundPath: localBackgroundPath ?? this.localBackgroundPath,
        elements: elements,
        updatedAt: updatedAt,
      );

  /// Number of PHOTO_SLOT elements in this template.
  int get photoSlotCount =>
      elements.where((e) => e.type == 'PHOTO_SLOT').length;

  @override
  List<Object?> get props => [id, name, width, height, updatedAt, localBackgroundPath];
}

/// A single element within a template.
///
/// Types: `PHOTO_SLOT`, `IMAGE`, `TEXT`.
/// Sorted by `sequence` (z-order).
class TemplateElement extends Equatable {
  final String id;
  final String type; // PHOTO_SLOT, IMAGE, TEXT
  final int x;
  final int y;
  final int width;
  final int height;
  final int rotation;
  final int opacity; // 0-100
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
    this.opacity = 100,
    required this.sequence,
    required this.properties,
  });

  factory TemplateElement.fromJson(Map<String, dynamic> json) =>
      TemplateElement(
        id: json['id'] as String,
        type: (json['elementType'] ?? json['type']) as String,
        x: (json['x'] as num).toInt(),
        y: (json['y'] as num).toInt(),
        width: (json['width'] as num).toInt(),
        height: (json['height'] as num).toInt(),
        rotation: (json['rotation'] as num?)?.toInt() ?? 0,
        opacity: (json['opacity'] as num?)?.toInt() ?? 100,
        sequence: json['sequence'] as int,
        properties: json['properties'] as Map<String, dynamic>,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'elementType': type,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'rotation': rotation,
    'opacity': opacity,
    'sequence': sequence,
    'properties': properties,
  };

  /// Normalized opacity for rendering (0.0 - 1.0).
  double get normalizedOpacity => opacity / 100;

  /// Capture order for PHOTO_SLOT elements.
  int? get captureOrder => properties['captureOrder'] as int?;

  @override
  List<Object?> get props => [id, type, sequence];
}

import 'dart:convert';

class LocalSession {
  final String id;
  final DateTime savedAt;
  final String templateId;
  final String templateName;
  final Map<int, String> photoPaths;

  const LocalSession({
    required this.id,
    required this.savedAt,
    required this.templateId,
    required this.templateName,
    required this.photoPaths,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'savedAt': savedAt.toIso8601String(),
    'templateId': templateId,
    'templateName': templateName,
    'photoPaths': photoPaths.map((k, v) => MapEntry(k.toString(), v)),
  };

  factory LocalSession.fromJson(Map<String, dynamic> json) => LocalSession(
    id: json['id'] as String,
    savedAt: DateTime.parse(json['savedAt'] as String),
    templateId: json['templateId'] as String,
    templateName: json['templateName'] as String,
    photoPaths: (json['photoPaths'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(int.parse(k), v as String),
    ),
  );

  static LocalSession fromJsonString(String raw) =>
      LocalSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

import 'package:equatable/equatable.dart';

/// Session model — digital copy upload result.
///
/// Maps to POST /kiosk/sessions → data.session
class Session extends Equatable {
  final String id;
  final String transactionId;
  final String resultImageUrl;
  final String? deletionScheduledAt;
  final String createdAt;

  const Session({
    required this.id,
    required this.transactionId,
    required this.resultImageUrl,
    this.deletionScheduledAt,
    required this.createdAt,
  });

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    id: json['id'] as String,
    transactionId: json['transactionId'] as String,
    resultImageUrl: json['resultImageUrl'] as String,
    deletionScheduledAt: json['deletionScheduledAt'] as String?,
    createdAt: json['createdAt'] as String,
  );

  @override
  List<Object?> get props => [id, transactionId];
}

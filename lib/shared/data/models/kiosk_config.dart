import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Kiosk configuration model.
///
/// Maps to API responses:
/// - POST /kiosk/pair → data.kioskConfig
/// - GET /kiosk/me → data.kiosk + subscription info
///
/// Field names match backend API exactly.
class KioskConfig extends Equatable {
  final String id;
  final String name;
  final String ownerId;
  final int priceBaseSession;
  final int pricePerExtraPrint;
  final int priceDigitalCopy;
  /// Subscription status: ACTIVE, PENDING_PAYMENT, EXPIRED, CANCELLED.
  final String? subscriptionStatus;
  final String? sessionPreviewUrl;

  const KioskConfig({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.priceBaseSession,
    required this.pricePerExtraPrint,
    required this.priceDigitalCopy,
    this.subscriptionStatus,
    this.sessionPreviewUrl,
  });

  /// Parse from POST /kiosk/pair → data.kioskConfig
  factory KioskConfig.fromPairJson(Map<String, dynamic> json) => KioskConfig(
    id: json['id'] as String,
    name: json['name'] as String,
    ownerId: json['ownerId'] as String,
    priceBaseSession: json['priceBaseSession'] as int,
    pricePerExtraPrint: json['pricePerExtraPrint'] as int,
    priceDigitalCopy: json['priceDigitalCopy'] as int,
  );

  /// Parse from GET /kiosk/me → full response data
  factory KioskConfig.fromMeJson(Map<String, dynamic> json) {
    final kiosk = json['kiosk'] as Map<String, dynamic>;
    return KioskConfig(
      id: kiosk['id'] as String,
      name: kiosk['name'] as String,
      ownerId: kiosk['ownerId'] as String? ?? '',
      priceBaseSession: kiosk['priceBaseSession'] as int,
      pricePerExtraPrint: kiosk['pricePerExtraPrint'] as int,
      priceDigitalCopy: kiosk['priceDigitalCopy'] as int,
      subscriptionStatus: json['subscriptionStatus'] as String?,
      sessionPreviewUrl: json['sessionPreviewUrl'] as String?,
    );
  }

  /// Parse from cached JSON string.
  factory KioskConfig.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return KioskConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      priceBaseSession: json['priceBaseSession'] as int,
      pricePerExtraPrint: json['pricePerExtraPrint'] as int,
      priceDigitalCopy: json['priceDigitalCopy'] as int,
      subscriptionStatus: json['subscriptionStatus'] as String?,
      sessionPreviewUrl: json['sessionPreviewUrl'] as String?,
    );
  }

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ownerId': ownerId,
    'priceBaseSession': priceBaseSession,
    'pricePerExtraPrint': pricePerExtraPrint,
    'priceDigitalCopy': priceDigitalCopy,
    'subscriptionStatus': subscriptionStatus,
    'sessionPreviewUrl': sessionPreviewUrl,
  };

  /// Serialize to JSON string for storage.
  String toJsonString() => jsonEncode(toJson());

  /// Whether this kiosk can operate (subscription ACTIVE).
  bool get canOperate => subscriptionStatus == 'ACTIVE';

  @override
  List<Object?> get props => [
    id,
    name,
    ownerId,
    priceBaseSession,
    pricePerExtraPrint,
    priceDigitalCopy,
    subscriptionStatus,
    sessionPreviewUrl,
  ];
}

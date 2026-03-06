import 'package:equatable/equatable.dart';

/// Kiosk configuration model.
///
/// Matches the response shape from `GET /kiosk/me`.
/// Per PRD-05: cached in Hive `kioskConfigBox`.
class KioskConfig extends Equatable {
  final String id;
  final String name;
  final String ownerId;
  final String status; // 'ACTIVE', 'INACTIVE', 'EXPIRED'
  final PricingConfig pricing;

  const KioskConfig({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.status,
    required this.pricing,
  });

  factory KioskConfig.fromJson(Map<String, dynamic> json) => KioskConfig(
    id: json['id'] as String,
    name: json['name'] as String,
    ownerId: json['ownerId'] as String,
    status: json['status'] as String,
    pricing: PricingConfig.fromJson(json['pricing'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ownerId': ownerId,
    'status': status,
    'pricing': pricing.toJson(),
  };

  @override
  List<Object?> get props => [id, name, ownerId, status, pricing];
}

/// Pricing configuration for a kiosk.
class PricingConfig extends Equatable {
  final int basePrintPrice;
  final int additionalPrintPrice;
  final int digitalCopyPrice;

  const PricingConfig({
    required this.basePrintPrice,
    required this.additionalPrintPrice,
    required this.digitalCopyPrice,
  });

  factory PricingConfig.fromJson(Map<String, dynamic> json) => PricingConfig(
    basePrintPrice: json['basePrintPrice'] as int,
    additionalPrintPrice: json['additionalPrintPrice'] as int,
    digitalCopyPrice: json['digitalCopyPrice'] as int,
  );

  Map<String, dynamic> toJson() => {
    'basePrintPrice': basePrintPrice,
    'additionalPrintPrice': additionalPrintPrice,
    'digitalCopyPrice': digitalCopyPrice,
  };

  @override
  List<Object?> get props => [
    basePrintPrice,
    additionalPrintPrice,
    digitalCopyPrice,
  ];
}

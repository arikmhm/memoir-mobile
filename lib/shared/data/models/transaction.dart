import 'package:equatable/equatable.dart';

/// Transaction model.
///
/// Maps to POST /kiosk/transactions → data.transaction
class Transaction extends Equatable {
  final String id;
  final String orderId;
  final String status;
  final String paymentMethod;
  final String? qrString;
  final String? paymentExpiresAt;
  final int printQty;
  final bool hasDigitalCopy;
  final int totalAmount;
  final String? paidAt;

  /// Price snapshot fields — set at transaction creation from kiosk config.
  final int? appliedBasePrice;
  final int? appliedExtraPrintPrice;
  final int? appliedDigitalCopyPrice;

  const Transaction({
    required this.id,
    required this.orderId,
    required this.status,
    required this.paymentMethod,
    this.qrString,
    this.paymentExpiresAt,
    required this.printQty,
    required this.hasDigitalCopy,
    required this.totalAmount,
    this.paidAt,
    this.appliedBasePrice,
    this.appliedExtraPrintPrice,
    this.appliedDigitalCopyPrice,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    orderId: json['orderId'] as String,
    status: json['status'] as String,
    paymentMethod: json['paymentMethod'] as String,
    qrString: json['qrString'] as String?,
    paymentExpiresAt: json['paymentExpiresAt'] as String?,
    printQty: json['printQty'] as int,
    hasDigitalCopy: json['hasDigitalCopy'] as bool,
    totalAmount: json['totalAmount'] as int,
    paidAt: json['paidAt'] as String?,
    appliedBasePrice: json['appliedBasePrice'] as int?,
    appliedExtraPrintPrice: json['appliedExtraPrintPrice'] as int?,
    appliedDigitalCopyPrice: json['appliedDigitalCopyPrice'] as int?,
  );

  bool get isPaid => status == 'PAID';
  bool get isPending => status == 'PENDING';
  bool get isFailed => status == 'FAILED';
  bool get isExpired => status == 'EXPIRED';

  @override
  List<Object?> get props => [
    id,
    orderId,
    status,
    paymentMethod,
    qrString,
    paymentExpiresAt,
    printQty,
    hasDigitalCopy,
    totalAmount,
    paidAt,
    appliedBasePrice,
    appliedExtraPrintPrice,
    appliedDigitalCopyPrice,
  ];
}

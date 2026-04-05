import 'package:equatable/equatable.dart';

/// Transaction model.
///
/// Maps to API responses:
/// - POST /kiosk/transactions → data.transaction
/// - POST /kiosk/transactions/:id/confirm-cash → data.transaction
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
  ];
}

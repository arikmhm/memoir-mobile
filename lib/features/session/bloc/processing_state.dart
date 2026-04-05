import 'package:equatable/equatable.dart';

import '../../../../shared/data/models/transaction.dart';

/// Processing states for the session processing flow.
///
/// Flow: Initial → CreatingTransaction → AwaitingPayment → Rendering → Printing → Uploading → Complete
/// Error states allow retry at each step.
sealed class ProcessingState extends Equatable {
  const ProcessingState();

  @override
  List<Object?> get props => [];
}

/// Initial state before processing begins.
final class ProcessingInitial extends ProcessingState {
  const ProcessingInitial();
}

/// Creating transaction on server.
final class ProcessingCreatingTransaction extends ProcessingState {
  const ProcessingCreatingTransaction();
}

/// Awaiting payment — shows different UI per payment method.
///
/// - CASH: instruction to pay at counter + [SUDAH BAYAR] button
/// - STATIC_QRIS: shows static QR image + [SUDAH BAYAR] button
/// - PG: shows dynamic QR from Xendit + [CEK PEMBAYARAN] button + expiry
final class ProcessingAwaitingPayment extends ProcessingState {
  final Transaction transaction;
  final String paymentMethod;

  /// For PG: the QRIS string from Xendit to render as QR code.
  final String? qrString;

  /// For STATIC_QRIS: local file path of the uploaded static QRIS image.
  final String? staticQrisImagePath;

  /// For PG: expiry timestamp (ISO 8601).
  final String? paymentExpiresAt;

  const ProcessingAwaitingPayment({
    required this.transaction,
    required this.paymentMethod,
    this.qrString,
    this.staticQrisImagePath,
    this.paymentExpiresAt,
  });

  @override
  List<Object?> get props => [
    transaction,
    paymentMethod,
    qrString,
    staticQrisImagePath,
    paymentExpiresAt,
  ];
}

/// Checking PG payment status (loading indicator).
final class ProcessingCheckingPayment extends ProcessingState {
  const ProcessingCheckingPayment();
}

/// PG payment check returned FAILED or EXPIRED.
final class ProcessingPaymentFailed extends ProcessingState {
  final Transaction transaction;
  final String message;

  const ProcessingPaymentFailed({
    required this.transaction,
    required this.message,
  });

  @override
  List<Object?> get props => [transaction, message];
}

/// Composite rendering in progress (after payment confirmed).
final class ProcessingRendering extends ProcessingState {
  final Transaction transaction;

  const ProcessingRendering({required this.transaction});

  @override
  List<Object?> get props => [transaction];
}

/// Printing in progress.
final class ProcessingPrinting extends ProcessingState {
  final Transaction transaction;
  final int currentCopy;
  final int totalCopies;

  const ProcessingPrinting({
    required this.transaction,
    required this.currentCopy,
    required this.totalCopies,
  });

  @override
  List<Object?> get props => [transaction, currentCopy, totalCopies];
}

/// Print error — retry or skip.
final class ProcessingPrintError extends ProcessingState {
  final Transaction transaction;
  final int currentCopy;
  final int totalCopies;
  final String message;

  const ProcessingPrintError({
    required this.transaction,
    required this.currentCopy,
    required this.totalCopies,
    required this.message,
  });

  @override
  List<Object?> get props => [transaction, currentCopy, totalCopies, message];
}

/// Uploading digital copy.
final class ProcessingUploading extends ProcessingState {
  final Transaction transaction;

  const ProcessingUploading({required this.transaction});

  @override
  List<Object?> get props => [transaction];
}

/// Upload error — retry available.
final class ProcessingUploadError extends ProcessingState {
  final Transaction transaction;
  final String message;

  const ProcessingUploadError({
    required this.transaction,
    required this.message,
  });

  @override
  List<Object?> get props => [transaction, message];
}

/// All processing complete — navigate to thank you.
final class ProcessingComplete extends ProcessingState {
  final Transaction transaction;

  const ProcessingComplete({required this.transaction});

  @override
  List<Object?> get props => [transaction];
}

/// Fatal error — retry available if transaction was already created.
final class ProcessingError extends ProcessingState {
  /// Non-null when the error happened after transaction creation.
  /// Allows retryProcessing() to resume without creating a duplicate.
  final Transaction? transaction;
  final String message;

  const ProcessingError({required this.message, this.transaction});

  @override
  List<Object?> get props => [transaction, message];
}

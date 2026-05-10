import 'package:dio/dio.dart';

import '../../../../shared/core/constants/api_constants.dart';
import '../../../../shared/data/datasources/api_client.dart';
import '../../../../shared/data/models/transaction.dart';

/// Transaction datasource — API calls for transaction lifecycle.
///
/// Endpoints:
/// - POST /kiosk/transactions — create transaction (CASH/STATIC_QRIS auto-PAID on creation)
/// - POST /kiosk/transactions/:id/check-payment — poll PG payment status
class TransactionDatasource {
  final ApiClient _apiClient;
  final bool useMock;

  TransactionDatasource({
    required ApiClient apiClient,
    this.useMock = ApiConstants.useMock,
  }) : _apiClient = apiClient;

  /// Create a new transaction.
  ///
  /// Returns [CreateTransactionResult] with transaction + optional paymentUrl.
  /// Throws [TransactionException] on failure.
  Future<CreateTransactionResult> createTransaction({
    required String templateId,
    required String paymentMethod,
    required String transactionType,
    required int printQty,
    required bool hasDigitalCopy,
    required int totalAmount,
  }) async {
    if (useMock) {
      return _mockCreateTransaction(
        templateId: templateId,
        paymentMethod: paymentMethod,
        transactionType: transactionType,
        printQty: printQty,
        hasDigitalCopy: hasDigitalCopy,
        totalAmount: totalAmount,
      );
    }

    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.transactionsEndpoint,
        data: {
          'templateId': templateId,
          'paymentMethod': paymentMethod,
          'transactionType': transactionType,
          'printQty': printQty,
          'hasDigitalCopy': hasDigitalCopy,
          'totalAmount': totalAmount,
        },
      );

      final data = response.data?['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw const TransactionException('Respons tidak valid dari server');
      }

      final txJson = data['transaction'] as Map<String, dynamic>;
      return CreateTransactionResult(
        transaction: Transaction.fromJson(txJson),
        qrString: txJson['qrString'] as String?,
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Check PG payment status.
  ///
  /// Returns payment status string: 'PAID', 'PENDING', or 'FAILED'.
  /// Throws [TransactionException] on failure.
  Future<String> checkPayment(String transactionId) async {
    if (useMock) return _mockCheckPayment();

    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.checkPaymentEndpoint(transactionId),
        data: <String, dynamic>{},
      );

      final data = response.data?['data'] as Map<String, dynamic>?;
      final status = data?['status'] as String?;
      if (status == null) {
        throw const TransactionException('Respons tidak valid dari server');
      }

      return status;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  // ─── Mock ──────────────────────────────────────────────────────

  Future<CreateTransactionResult> _mockCreateTransaction({
    required String templateId,
    required String paymentMethod,
    required String transactionType,
    required int printQty,
    required bool hasDigitalCopy,
    required int totalAmount,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final tx = Transaction(
      id: 'mock-tx-001',
      orderId: 'MEM-${DateTime.now().millisecondsSinceEpoch}-mock',
      status: paymentMethod == 'PG' ? 'PENDING' : 'PAID',
      paymentMethod: paymentMethod,
      qrString: paymentMethod == 'PG'
          ? '00020101021226680016COM.XENDIT.WWW011893600916000000001802180000000000000001530336054071000005802ID5911MOCK KIOSK6007JAKARTA610512345626'
          : null,
      paymentExpiresAt: paymentMethod == 'PG'
          ? DateTime.now().add(const Duration(minutes: 15)).toIso8601String()
          : null,
      printQty: printQty,
      hasDigitalCopy: hasDigitalCopy,
      totalAmount: totalAmount,
    );
    return CreateTransactionResult(
      transaction: tx,
      qrString: tx.qrString,
    );
  }

  Future<String> _mockCheckPayment() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return 'PAID';
  }

  // ─── Error mapping ─────────────────────────────────────────────

  TransactionException _mapDioError(DioException e) {
    final statusCode = e.response?.statusCode;

    // Client-definite errors — no retry will help.
    if (statusCode != null) {
      return switch (statusCode) {
        400 => TransactionException(
          _extractMessage(e) ?? 'Data transaksi tidak valid',
          isPriceMismatch: _extractCode(e) == 'PRICE_MISMATCH',
          isPaymentConfigRequired:
              _extractCode(e) == 'PAYMENT_CONFIG_REQUIRED',
        ),
        404 => const TransactionException('Transaksi tidak ditemukan'),
        422 => TransactionException(
          _extractMessage(e) ?? 'Transaksi tidak dapat diproses',
        ),
        _ when statusCode >= 500 => TransactionException(
          'Server sedang bermasalah ($statusCode). Silakan coba lagi.',
          isRetryable: true,
        ),
        _ => TransactionException(
          _extractMessage(e) ?? 'Terjadi kesalahan ($statusCode).',
        ),
      };
    }

    // No response — network / timeout issues.
    return const TransactionException(
      'Gagal menghubungi server. Periksa koneksi internet Anda.',
      isRetryable: true,
    );
  }

  String? _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return data['message'] as String?;
    }
    return null;
  }

  String? _extractCode(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      // API error format: { "error": "ERROR_CODE", "message": "..." }
      return data['error'] as String?;
    }
    return null;
  }
}

/// Result of creating a transaction.
class CreateTransactionResult {
  final Transaction transaction;
  final String? qrString;

  const CreateTransactionResult({
    required this.transaction,
    this.qrString,
  });
}

/// Exception for transaction API errors.
class TransactionException implements Exception {
  final String message;

  /// Whether the caller should retry the operation.
  final bool isRetryable;

  /// Whether the error is a price mismatch (totalAmount != server calculation).
  final bool isPriceMismatch;

  /// Whether the error is due to missing payment gateway config on the owner account.
  final bool isPaymentConfigRequired;

  const TransactionException(
    this.message, {
    this.isRetryable = false,
    this.isPriceMismatch = false,
    this.isPaymentConfigRequired = false,
  });

  @override
  String toString() => message;
}

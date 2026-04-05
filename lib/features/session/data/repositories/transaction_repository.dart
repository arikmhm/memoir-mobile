import '../../../../shared/data/models/transaction.dart';
import '../datasources/session_datasource.dart';
import '../datasources/transaction_datasource.dart';

/// Transaction repository — orchestrates transaction lifecycle.
///
/// Flow: create → confirm payment → processing proceeds via cubit.
class TransactionRepository {
  final TransactionDatasource _transactionDatasource;
  final SessionDatasource _sessionDatasource;

  TransactionRepository({
    required TransactionDatasource transactionDatasource,
    required SessionDatasource sessionDatasource,
  }) : _transactionDatasource = transactionDatasource,
       _sessionDatasource = sessionDatasource;

  /// Create a new transaction.
  Future<CreateTransactionResult> createTransaction({
    required String templateId,
    required String paymentMethod,
    required int printQty,
    required bool hasDigitalCopy,
    required int totalAmount,
  }) =>
      _transactionDatasource.createTransaction(
        templateId: templateId,
        paymentMethod: paymentMethod,
        printQty: printQty,
        hasDigitalCopy: hasDigitalCopy,
        totalAmount: totalAmount,
      );

  /// Confirm CASH/STATIC_QRIS payment.
  ///
  /// Retries once on retryable errors because the endpoint is idempotent —
  /// calling it again after the server already committed is safe.
  Future<Transaction> confirmCash(String transactionId) async {
    try {
      return await _transactionDatasource.confirmCash(transactionId);
    } on TransactionException catch (e) {
      if (!e.isRetryable) rethrow;
      // Single retry after a short delay — endpoint is idempotent.
      await Future<void>.delayed(const Duration(seconds: 1));
      return _transactionDatasource.confirmCash(transactionId);
    }
  }

  /// Check PG payment status.
  Future<String> checkPayment(String transactionId) =>
      _transactionDatasource.checkPayment(transactionId);

  /// Upload digital copy and return download URL.
  Future<UploadResult> uploadDigitalCopy({
    required String transactionId,
    required String filePath,
  }) =>
      _sessionDatasource.uploadDigitalCopy(
        transactionId: transactionId,
        filePath: filePath,
      );
}

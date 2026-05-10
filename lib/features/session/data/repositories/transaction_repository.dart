import '../datasources/session_datasource.dart';
import '../datasources/transaction_datasource.dart';

/// Transaction repository — orchestrates transaction lifecycle.
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
    required String transactionType,
    required int printQty,
    required bool hasDigitalCopy,
    required int totalAmount,
  }) =>
      _transactionDatasource.createTransaction(
        templateId: templateId,
        paymentMethod: paymentMethod,
        transactionType: transactionType,
        printQty: printQty,
        hasDigitalCopy: hasDigitalCopy,
        totalAmount: totalAmount,
      );

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

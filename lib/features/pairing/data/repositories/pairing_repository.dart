import '../../../../shared/data/datasources/storage_service.dart';
import '../datasources/pairing_datasource.dart';

/// Pairing repository — orchestrates pairing flow.
///
/// 1. Call datasource to exchange code for token
/// 2. Store token securely via StorageService
class PairingRepository {
  final PairingDatasource _datasource;
  final StorageService _storageService;

  PairingRepository({
    required PairingDatasource datasource,
    required StorageService storageService,
  }) : _datasource = datasource,
       _storageService = storageService;

  /// Exchange 6-digit pairing code for device token.
  ///
  /// Stores the received token in secure storage.
  Future<void> pair(String pairingCode) async {
    final token = await _datasource.pair(pairingCode);
    await _storageService.setDeviceToken(token);
  }
}

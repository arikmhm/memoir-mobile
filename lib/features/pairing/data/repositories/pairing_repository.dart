import '../../../../shared/data/datasources/storage_service.dart';
import '../../../../shared/data/models/kiosk_config.dart';
import '../datasources/pairing_datasource.dart';

/// Pairing repository — orchestrates pairing flow.
///
/// 1. Validate code format (6 digits)
/// 2. Call datasource to exchange code for token + kioskConfig
/// 3. Store token securely via StorageService
/// 4. Cache kioskConfig for startup
class PairingRepository {
  final PairingDatasource _datasource;
  final StorageService _storageService;

  static final _sixDigitRegex = RegExp(r'^\d{6}$');

  PairingRepository({
    required PairingDatasource datasource,
    required StorageService storageService,
  }) : _datasource = datasource,
       _storageService = storageService;

  /// Validates that the code is exactly 6 digits.
  bool isValidCode(String code) => _sixDigitRegex.hasMatch(code);

  /// Whether a device token already exists.
  Future<bool> isAlreadyPaired() => _storageService.hasDeviceToken();

  /// Exchange 6-digit pairing code for device token.
  ///
  /// Validates format, calls API, stores token + caches kioskConfig.
  /// Throws [PairingException] on API failure.
  /// Throws [FormatException] if code format is invalid.
  Future<void> pair(String pairingCode) async {
    if (!isValidCode(pairingCode)) {
      throw const FormatException('Kode pairing harus 6 digit angka');
    }

    final result = await _datasource.pair(pairingCode);
    await _storageService.setDeviceToken(result.deviceToken);

    // Cache kioskConfig from pair response for faster startup
    if (result.kioskConfig != null) {
      final config = KioskConfig.fromPairJson(result.kioskConfig!);
      await _storageService.setKioskConfig(config.toJsonString());
    }
  }
}

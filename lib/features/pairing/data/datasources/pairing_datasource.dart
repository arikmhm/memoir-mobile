/// Pairing datasource — API calls for device pairing.
///
/// Currently returns mock data. Replace with real Dio calls later.
class PairingDatasource {
  /// Simulate POST /kiosk/pair with a 6-digit code.
  ///
  /// Returns a mock device_token on success.
  /// Throws on invalid code.
  Future<String> pair(String pairingCode) async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(seconds: 1));

    // Mock: accept any 6-digit code except '000000'
    if (pairingCode == '000000') {
      throw Exception('Kode pairing tidak valid');
    }

    // Return mock device token
    return 'mock_device_token_${DateTime.now().millisecondsSinceEpoch}';
  }
}

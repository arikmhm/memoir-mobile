/// Formatting utilities for memoir. Mobile Runner.
///
/// Rupiah currency format and date/time formatters.
/// No external dependencies — uses simple Dart formatting.
class Formatters {
  Formatters._();

  /// Format number as Indonesian Rupiah.
  ///
  /// Example: `formatRupiah(150000)` → `'Rp 150.000'`
  static String formatRupiah(int amount) {
    final parts = <String>[];
    var remaining = amount.abs();

    if (remaining == 0) return 'Rp 0';

    while (remaining > 0) {
      final chunk = remaining % 1000;
      remaining = remaining ~/ 1000;
      if (remaining > 0) {
        parts.insert(0, chunk.toString().padLeft(3, '0'));
      } else {
        parts.insert(0, chunk.toString());
      }
    }

    final formatted = parts.join('.');
    return amount < 0 ? 'Rp -$formatted' : 'Rp $formatted';
  }

  /// Format duration as countdown string.
  ///
  /// Example: `formatCountdown(Duration(seconds: 65))` → `'01:05'`
  static String formatCountdown(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:memoir_v1/shared/core/utils/formatters.dart';

void main() {
  group('Formatters', () {
    group('formatRupiah', () {
      test('formats zero', () {
        expect(Formatters.formatRupiah(0), 'Rp 0');
      });

      test('formats small number', () {
        expect(Formatters.formatRupiah(500), 'Rp 500');
      });

      test('formats thousands with dot separator', () {
        expect(Formatters.formatRupiah(15000), 'Rp 15.000');
      });

      test('formats large number', () {
        expect(Formatters.formatRupiah(150000), 'Rp 150.000');
      });

      test('formats millions', () {
        expect(Formatters.formatRupiah(1500000), 'Rp 1.500.000');
      });
    });

    group('formatCountdown', () {
      test('formats simple seconds', () {
        expect(Formatters.formatCountdown(const Duration(seconds: 5)), '00:05');
      });

      test('formats minutes and seconds', () {
        expect(
          Formatters.formatCountdown(const Duration(seconds: 65)),
          '01:05',
        );
      });

      test('formats exact minute', () {
        expect(Formatters.formatCountdown(const Duration(minutes: 5)), '05:00');
      });
    });
  });
}

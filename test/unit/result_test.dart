import 'package:flutter_test/flutter_test.dart';
import 'package:memoir_v1/shared/core/utils/result.dart';

void main() {
  group('Result', () {
    test('Ok holds a value', () {
      final result = Result.ok(42);

      switch (result) {
        case Ok():
          expect(result.value, 42);
        case Error():
          fail('Expected Ok, got Error');
      }
    });

    test('Error holds an exception', () {
      final exception = Exception('test error');
      final result = Result<int>.error(exception);

      switch (result) {
        case Ok():
          fail('Expected Error, got Ok');
        case Error():
          expect(result.error, exception);
      }
    });

    test('asOk convenience method works', () {
      final result = Result.ok('hello');
      expect(result.asOk.value, 'hello');
    });

    test('asError convenience method works', () {
      final exception = Exception('fail');
      final result = Result<String>.error(exception);
      expect(result.asError.error, exception);
    });

    test('Ok toString', () {
      final result = Result.ok(42);
      expect(result.toString(), 'Result<int>.ok(42)');
    });

    test('Error toString', () {
      final result = Result<int>.error(Exception('fail'));
      expect(result.toString(), contains('Result<int>.error'));
    });
  });
}

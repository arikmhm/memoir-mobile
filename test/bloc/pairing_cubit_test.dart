import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memoir_v1/features/pairing/bloc/pairing_cubit.dart';
import 'package:memoir_v1/features/pairing/bloc/pairing_state.dart';
import 'package:memoir_v1/features/pairing/data/datasources/pairing_datasource.dart';
import 'package:memoir_v1/features/pairing/data/repositories/pairing_repository.dart';

class MockPairingRepository extends Mock implements PairingRepository {}

void main() {
  late MockPairingRepository mockRepository;

  setUp(() {
    mockRepository = MockPairingRepository();
  });

  group('PairingCubit', () {
    test('initial state is PairingInitial', () {
      final cubit = PairingCubit(repository: mockRepository);
      expect(cubit.state, isA<PairingInitial>());
      cubit.close();
    });

    blocTest<PairingCubit, PairingState>(
      'emits [Loading, Success] when pairing succeeds',
      setUp: () {
        when(() => mockRepository.isValidCode(any())).thenReturn(true);
        when(() => mockRepository.pair(any())).thenAnswer((_) async {});
      },
      build: () => PairingCubit(repository: mockRepository),
      act: (cubit) => cubit.submitPairingCode('123456'),
      expect: () => [isA<PairingLoading>(), isA<PairingSuccess>()],
    );

    blocTest<PairingCubit, PairingState>(
      'emits [Error] when code is not 6 digits',
      setUp: () {
        when(() => mockRepository.isValidCode(any())).thenReturn(false);
      },
      build: () => PairingCubit(repository: mockRepository),
      act: (cubit) => cubit.submitPairingCode('123'),
      expect: () => [isA<PairingError>()],
    );

    blocTest<PairingCubit, PairingState>(
      'emits [Error] when code contains non-digits',
      setUp: () {
        when(() => mockRepository.isValidCode(any())).thenReturn(false);
      },
      build: () => PairingCubit(repository: mockRepository),
      act: (cubit) => cubit.submitPairingCode('12ab56'),
      expect: () => [isA<PairingError>()],
    );

    blocTest<PairingCubit, PairingState>(
      'emits [Loading, Error] when PairingException is thrown',
      setUp: () {
        when(() => mockRepository.isValidCode(any())).thenReturn(true);
        when(
          () => mockRepository.pair(any()),
        ).thenThrow(const PairingException('Kode pairing tidak valid'));
      },
      build: () => PairingCubit(repository: mockRepository),
      act: (cubit) => cubit.submitPairingCode('000000'),
      expect: () => [
        isA<PairingLoading>(),
        isA<PairingError>().having(
          (e) => e.message,
          'message',
          'Kode pairing tidak valid',
        ),
      ],
    );

    blocTest<PairingCubit, PairingState>(
      'emits [Loading, Error] with generic message on unexpected exception',
      setUp: () {
        when(() => mockRepository.isValidCode(any())).thenReturn(true);
        when(
          () => mockRepository.pair(any()),
        ).thenThrow(Exception('Network error'));
      },
      build: () => PairingCubit(repository: mockRepository),
      act: (cubit) => cubit.submitPairingCode('123456'),
      expect: () => [
        isA<PairingLoading>(),
        isA<PairingError>().having(
          (e) => e.message,
          'message',
          'Terjadi kesalahan. Silakan coba lagi.',
        ),
      ],
    );

    blocTest<PairingCubit, PairingState>(
      'reset emits PairingInitial',
      build: () => PairingCubit(repository: mockRepository),
      act: (cubit) => cubit.reset(),
      expect: () => [isA<PairingInitial>()],
    );

    blocTest<PairingCubit, PairingState>(
      'trims whitespace from code before validation',
      setUp: () {
        when(() => mockRepository.isValidCode('123456')).thenReturn(true);
        when(() => mockRepository.pair('123456')).thenAnswer((_) async {});
      },
      build: () => PairingCubit(repository: mockRepository),
      act: (cubit) => cubit.submitPairingCode(' 123456 '),
      expect: () => [isA<PairingLoading>(), isA<PairingSuccess>()],
    );
  });
}

import 'package:bloc_test/bloc_test.dart';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:memoir_v1/features/settings/bloc/settings_cubit.dart';
import 'package:memoir_v1/features/settings/bloc/settings_state.dart';
import 'package:memoir_v1/features/settings/data/services/camera_test_service.dart';
import 'package:memoir_v1/features/settings/data/services/printer_test_service.dart';
import 'package:memoir_v1/shared/data/datasources/storage_service.dart';

// ─── Mocks ──────────────────────────────────────────────────────────

class MockCameraTestService extends Mock implements CameraTestService {}

class MockPrinterTestService extends Mock implements PrinterTestService {}

class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockCameraTestService mockCameraService;
  late MockPrinterTestService mockPrinterService;
  late MockStorageService mockStorageService;

  setUp(() {
    mockCameraService = MockCameraTestService();
    mockPrinterService = MockPrinterTestService();
    mockStorageService = MockStorageService();

    // Stub dispose methods — called by SettingsCubit.close().
    when(() => mockCameraService.dispose()).thenAnswer((_) async {});
    when(() => mockPrinterService.dispose()).thenAnswer((_) async {});

    // Stub storage — no default printer initially.
    when(() => mockStorageService.hasDefaultPrinter).thenReturn(false);
    when(() => mockStorageService.defaultPrinterName).thenReturn(null);
    when(() => mockStorageService.defaultPrinterMac).thenReturn(null);
  });

  SettingsCubit buildCubit() => SettingsCubit(
        cameraService: mockCameraService,
        printerService: mockPrinterService,
        storageService: mockStorageService,
      );

  group('SettingsCubit', () {
    test('initial state is SettingsInitial', () {
      final cubit = buildCubit();
      expect(cubit.state, equals(const SettingsInitial()));
      cubit.close();
    });

    // ─── Camera Test ─────────────────────────────────────────────

    group('startCameraTest', () {
      blocTest<SettingsCubit, SettingsState>(
        'emits [CameraTestInProgress, CameraTestSuccess] on success',
        build: () {
          when(() => mockCameraService.initialize()).thenAnswer((_) async {});
          return buildCubit();
        },
        act: (cubit) => cubit.startCameraTest(),
        expect: () =>
            [const CameraTestInProgress(), const CameraTestSuccess()],
        verify: (_) {
          verify(() => mockCameraService.initialize()).called(1);
        },
      );

      blocTest<SettingsCubit, SettingsState>(
        'emits [CameraTestInProgress, CameraTestError] on CameraException',
        build: () {
          when(() => mockCameraService.initialize()).thenThrow(
            CameraException('CameraAccessDenied', 'Permission denied'),
          );
          return buildCubit();
        },
        act: (cubit) => cubit.startCameraTest(),
        expect: () => [
          const CameraTestInProgress(),
          const CameraTestError(message: 'Permission denied'),
        ],
      );

      blocTest<SettingsCubit, SettingsState>(
        'emits [CameraTestInProgress, CameraTestError] on generic exception',
        build: () {
          when(
            () => mockCameraService.initialize(),
          ).thenThrow(Exception('unexpected'));
          return buildCubit();
        },
        act: (cubit) => cubit.startCameraTest(),
        expect: () => [
          const CameraTestInProgress(),
          const CameraTestError(
              message: 'Kamera error: Exception: unexpected'),
        ],
      );
    });

    group('stopCameraTest', () {
      blocTest<SettingsCubit, SettingsState>(
        'emits [SettingsInitial] after stopping camera',
        build: () {
          when(() => mockCameraService.dispose()).thenAnswer((_) async {});
          return buildCubit();
        },
        act: (cubit) => cubit.stopCameraTest(),
        expect: () => [const SettingsInitial()],
        verify: (_) {
          verify(
            () => mockCameraService.dispose(),
          ).called(greaterThanOrEqualTo(1));
        },
      );
    });

    // ─── Printer Test ────────────────────────────────────────────

    group('scanPrinters', () {
      blocTest<SettingsCubit, SettingsState>(
        'emits [PrinterScanInProgress, PrinterScanComplete] on success',
        build: () {
          when(() => mockPrinterService.scanPrinters()).thenAnswer(
            (_) async => [
              const PrinterInfo(
                name: 'Test Printer',
                address: 'AA:BB:CC:DD:EE:FF',
              ),
            ],
          );
          return buildCubit();
        },
        act: (cubit) => cubit.scanPrinters(),
        expect: () => [
          const PrinterScanInProgress(),
          const PrinterScanComplete(
            printers: [
              PrinterInfo(name: 'Test Printer', address: 'AA:BB:CC:DD:EE:FF'),
            ],
          ),
        ],
      );

      blocTest<SettingsCubit, SettingsState>(
        'emits [PrinterScanInProgress, PrinterTestError] on failure',
        build: () {
          when(
            () => mockPrinterService.scanPrinters(),
          ).thenThrow(Exception('BLE unavailable'));
          return buildCubit();
        },
        act: (cubit) => cubit.scanPrinters(),
        expect: () => [
          const PrinterScanInProgress(),
          const PrinterTestError(
            message: 'Scan gagal: Exception: BLE unavailable',
            printers: [],
          ),
        ],
      );
    });

    group('testPrint', () {
      const printer = PrinterInfo(
        name: 'Test Printer',
        address: 'AA:BB:CC:DD:EE:FF',
      );

      blocTest<SettingsCubit, SettingsState>(
        'emits [PrinterTestInProgress, PrinterTestSuccess] on success',
        build: () {
          when(
            () => mockPrinterService.testPrint(printer),
          ).thenAnswer((_) async {});
          return buildCubit();
        },
        seed: () => const PrinterScanComplete(printers: [printer]),
        act: (cubit) => cubit.testPrint(printer),
        expect: () => [
          const PrinterTestInProgress(printers: [printer]),
          const PrinterTestSuccess(printers: [printer]),
        ],
      );

      blocTest<SettingsCubit, SettingsState>(
        'emits [PrinterTestInProgress, PrinterTestError] on failure',
        build: () {
          when(
            () => mockPrinterService.testPrint(printer),
          ).thenThrow(Exception('Print failed'));
          return buildCubit();
        },
        seed: () => const PrinterScanComplete(printers: [printer]),
        act: (cubit) => cubit.testPrint(printer),
        expect: () => [
          const PrinterTestInProgress(printers: [printer]),
          const PrinterTestError(
            message: 'Test print gagal: Exception: Print failed',
            printers: [printer],
          ),
        ],
      );
    });

    // ─── Default Printer ─────────────────────────────────────────

    group('saveDefaultPrinter', () {
      const printer = PrinterInfo(
        name: 'EPPOS EP600',
        address: 'AA:BB:CC:DD:EE:FF',
      );

      blocTest<SettingsCubit, SettingsState>(
        'saves printer to storage and re-emits state',
        build: () {
          when(
            () => mockStorageService.setDefaultPrinter(
              name: any(named: 'name'),
              mac: any(named: 'mac'),
            ),
          ).thenAnswer((_) async {});
          return buildCubit();
        },
        seed: () => const PrinterScanComplete(printers: [printer]),
        act: (cubit) => cubit.saveDefaultPrinter(printer),
        verify: (_) {
          verify(
            () => mockStorageService.setDefaultPrinter(
              name: 'EPPOS EP600',
              mac: 'AA:BB:CC:DD:EE:FF',
            ),
          ).called(1);
        },
      );
    });

    group('clearDefaultPrinter', () {
      blocTest<SettingsCubit, SettingsState>(
        'clears saved printer from storage',
        build: () {
          when(
            () => mockStorageService.clearDefaultPrinter(),
          ).thenAnswer((_) async {});
          return buildCubit();
        },
        seed: () => const PrinterScanComplete(printers: []),
        act: (cubit) => cubit.clearDefaultPrinter(),
        verify: (_) {
          verify(() => mockStorageService.clearDefaultPrinter()).called(1);
        },
      );
    });

    // ─── Reset ───────────────────────────────────────────────────

    group('reset', () {
      blocTest<SettingsCubit, SettingsState>(
        'emits [SettingsInitial] when reset is called',
        build: buildCubit,
        act: (cubit) => cubit.reset(),
        expect: () => [const SettingsInitial()],
      );
    });
  });
}

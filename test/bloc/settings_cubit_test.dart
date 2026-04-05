import 'package:bloc_test/bloc_test.dart';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:memoir_v1/features/app/bloc/app_cubit.dart';
import 'package:memoir_v1/features/settings/bloc/settings_cubit.dart';
import 'package:memoir_v1/features/settings/bloc/settings_state.dart';
import 'package:memoir_v1/features/settings/data/services/camera_test_service.dart';
import 'package:memoir_v1/features/settings/data/services/printer_test_service.dart';
import 'package:memoir_v1/features/startup/data/repositories/startup_repository.dart';
import 'package:memoir_v1/shared/data/datasources/storage_service.dart';

// ─── Mocks ──────────────────────────────────────────────────────────

class MockCameraTestService extends Mock implements CameraTestService {}

class MockPrinterTestService extends Mock implements PrinterTestService {}

class MockStorageService extends Mock implements StorageService {}

class MockStartupRepository extends Mock implements StartupRepository {}

class MockAppCubit extends Mock implements AppCubit {}

void main() {
  late MockCameraTestService mockCameraService;
  late MockPrinterTestService mockPrinterService;
  late MockStorageService mockStorageService;
  late MockStartupRepository mockStartupRepository;
  late MockAppCubit mockAppCubit;

  setUp(() {
    mockCameraService = MockCameraTestService();
    mockPrinterService = MockPrinterTestService();
    mockStorageService = MockStorageService();
    mockStartupRepository = MockStartupRepository();
    mockAppCubit = MockAppCubit();

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
        startupRepository: mockStartupRepository,
        appCubit: mockAppCubit,
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
          when(() => mockCameraService.initialize())
              .thenAnswer((_) async {});
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
          when(() => mockCameraService.initialize())
              .thenThrow(Exception('unexpected'));
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
          when(() => mockPrinterService.scanBluetoothPrinters()).thenAnswer(
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
            () => mockPrinterService.scanBluetoothPrinters(),
          ).thenThrow(Exception('BLE unavailable'));
          return buildCubit();
        },
        act: (cubit) => cubit.scanPrinters(),
        expect: () => [
          const PrinterScanInProgress(),
          isA<PrinterTestError>().having(
            (s) => s.message,
            'message',
            contains('BLE unavailable'),
          ),
        ],
      );
    });

    group('selectPrinter', () {
      const printer = PrinterInfo(
        name: 'Test Printer',
        address: 'AA:BB:CC:DD:EE:FF',
      );

      blocTest<SettingsCubit, SettingsState>(
        'saves printer and emits PrinterSaved',
        build: () {
          when(
            () => mockStorageService.setDefaultPrinter(
              name: any(named: 'name'),
              mac: any(named: 'mac'),
              connectionType: any(named: 'connectionType'),
            ),
          ).thenAnswer((_) async {});
          return buildCubit();
        },
        act: (cubit) => cubit.selectPrinter(printer),
        expect: () => [const PrinterSaved(printer: printer)],
        verify: (_) {
          verify(
            () => mockStorageService.setDefaultPrinter(
              name: 'Test Printer',
              mac: 'AA:BB:CC:DD:EE:FF',
              connectionType: 'bluetooth',
            ),
          ).called(1);
        },
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
        act: (cubit) => cubit.testPrint(printer),
        expect: () => [
          const PrinterTestInProgress(printer: printer),
          const PrinterTestSuccess(printer: printer),
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
        act: (cubit) => cubit.testPrint(printer),
        expect: () => [
          const PrinterTestInProgress(printer: printer),
          const PrinterTestError(
            message: 'Test print gagal: Exception: Print failed',
            printer: printer,
          ),
        ],
      );
    });

    // ─── Default Printer ─────────────────────────────────────────

    group('clearDefaultPrinter', () {
      blocTest<SettingsCubit, SettingsState>(
        'clears saved printer and emits SettingsInitial',
        build: () {
          when(
            () => mockStorageService.clearDefaultPrinter(),
          ).thenAnswer((_) async {});
          return buildCubit();
        },
        act: (cubit) => cubit.clearDefaultPrinter(),
        expect: () => [const SettingsInitial()],
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

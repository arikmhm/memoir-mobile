import 'package:bloc_test/bloc_test.dart';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:memoir_v1/features/app/bloc/app_cubit.dart';
import 'package:memoir_v1/features/home/bloc/home_cubit.dart';
import 'package:memoir_v1/features/home/bloc/home_state.dart';
import 'package:memoir_v1/features/home/data/services/camera_test_service.dart';
import 'package:memoir_v1/features/home/data/services/printer_test_service.dart';
import 'package:memoir_v1/features/session/data/services/composite_render_service.dart';
import 'package:memoir_v1/features/startup/data/repositories/startup_repository.dart';
import 'package:memoir_v1/shared/data/datasources/storage_service.dart';
import 'package:memoir_v1/shared/data/services/print_channel.dart';

// ─── Mocks ──────────────────────────────────────────────────────────

class MockCameraTestService extends Mock implements CameraTestService {}

class MockPrinterTestService extends Mock implements PrinterTestService {}

class MockCompositeRenderService extends Mock
    implements CompositeRenderService {}

class MockStorageService extends Mock implements StorageService {}

class MockStartupRepository extends Mock implements StartupRepository {}

class MockAppCubit extends Mock implements AppCubit {}

void main() {
  late MockCameraTestService mockCameraService;
  late MockPrinterTestService mockPrinterService;
  late MockCompositeRenderService mockRenderService;
  late MockStorageService mockStorageService;
  late MockStartupRepository mockStartupRepository;
  late MockAppCubit mockAppCubit;

  setUpAll(() {
    registerFallbackValue(
      const PrinterInfo(name: '', address: ''),
    );
  });

  setUp(() {
    mockCameraService = MockCameraTestService();
    mockPrinterService = MockPrinterTestService();
    mockRenderService = MockCompositeRenderService();
    mockStorageService = MockStorageService();
    mockStartupRepository = MockStartupRepository();
    mockAppCubit = MockAppCubit();

    // Stub dispose methods — called by HomeCubit.close().
    when(() => mockCameraService.dispose()).thenAnswer((_) async {});
    when(() => mockPrinterService.dispose()).thenAnswer((_) async {});

    // Stub storage — no default printer initially.
    when(() => mockStorageService.hasDefaultPrinter).thenReturn(false);
    when(() => mockStorageService.defaultPrinterName).thenReturn(null);
    when(() => mockStorageService.defaultPrinterMac).thenReturn(null);

  });

  HomeCubit buildCubit() => HomeCubit(
        cameraService: mockCameraService,
        printerService: mockPrinterService,
        renderService: mockRenderService,
        storageService: mockStorageService,
        startupRepository: mockStartupRepository,
        appCubit: mockAppCubit,
      );

  group('HomeCubit', () {
    test('initial state is HomeInitial', () {
      final cubit = buildCubit();
      expect(cubit.state, equals(const HomeInitial()));
      cubit.close();
    });

    // ─── Camera Test ─────────────────────────────────────────────

    group('startCameraTest', () {
      blocTest<HomeCubit, HomeState>(
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

      blocTest<HomeCubit, HomeState>(
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

      blocTest<HomeCubit, HomeState>(
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
      blocTest<HomeCubit, HomeState>(
        'emits [HomeInitial] after stopping camera',
        build: () {
          when(() => mockCameraService.dispose()).thenAnswer((_) async {});
          return buildCubit();
        },
        act: (cubit) => cubit.stopCameraTest(),
        expect: () => [const HomeInitial()],
        verify: (_) {
          verify(
            () => mockCameraService.dispose(),
          ).called(greaterThanOrEqualTo(1));
        },
      );
    });

    // ─── Printer Test ────────────────────────────────────────────

    group('scanPrinters', () {
      blocTest<HomeCubit, HomeState>(
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

      blocTest<HomeCubit, HomeState>(
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

      blocTest<HomeCubit, HomeState>(
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

    // ─── Page-open verification ───────────────────────────────────

    group('verifyPrinterOnPageOpen', () {
      const btPrinter = PrinterInfo(
        name: 'BT Printer',
        address: 'AA:BB:CC:DD:EE:FF',
        connectionType: PrinterConnectionType.bluetooth,
      );

      void stubSavedBluetooth() {
        when(() => mockStorageService.hasDefaultPrinter).thenReturn(true);
        when(() => mockStorageService.defaultPrinterName)
            .thenReturn(btPrinter.name);
        when(() => mockStorageService.defaultPrinterMac)
            .thenReturn(btPrinter.address);
        when(() => mockStorageService.defaultPrinterConnectionType)
            .thenReturn('bluetooth');
        when(() => mockPrinterService.findConnectedUsbPrinter())
            .thenAnswer((_) async => null);
      }

      blocTest<HomeCubit, HomeState>(
        'reachable BT → shows saved card and flags reachable, keeps config',
        build: () {
          stubSavedBluetooth();
          when(() => mockPrinterService.quickPingBluetooth(any()))
              .thenAnswer((_) async => true);
          return buildCubit();
        },
        act: (cubit) => cubit.verifyPrinterOnPageOpen(),
        expect: () => [
          const PrinterCheckingConnection(printer: btPrinter),
          const PrinterSaved(printer: btPrinter),
        ],
        verify: (cubit) {
          expect(cubit.savedBluetoothReachable, isTrue);
          verifyNever(() => mockStorageService.clearDefaultPrinter());
        },
      );

      blocTest<HomeCubit, HomeState>(
        'unreachable BT → hides card (HomeInitial) but keeps config',
        build: () {
          stubSavedBluetooth();
          when(() => mockPrinterService.quickPingBluetooth(any()))
              .thenAnswer((_) async => false);
          return buildCubit();
        },
        act: (cubit) => cubit.verifyPrinterOnPageOpen(),
        expect: () => [
          const PrinterCheckingConnection(printer: btPrinter),
          const HomeInitial(),
        ],
        verify: (cubit) {
          expect(cubit.savedBluetoothReachable, isFalse);
          verifyNever(() => mockStorageService.clearDefaultPrinter());
        },
      );

      blocTest<HomeCubit, HomeState>(
        'unverifiable BT (null: BT off / no permission) → hides card, keeps config',
        build: () {
          stubSavedBluetooth();
          when(() => mockPrinterService.quickPingBluetooth(any()))
              .thenAnswer((_) async => null);
          return buildCubit();
        },
        act: (cubit) => cubit.verifyPrinterOnPageOpen(),
        expect: () => [
          const PrinterCheckingConnection(printer: btPrinter),
          const HomeInitial(),
        ],
        verify: (cubit) {
          expect(cubit.savedBluetoothReachable, isFalse);
          verifyNever(() => mockStorageService.clearDefaultPrinter());
        },
      );
    });

    group('testPrint', () {
      const printer = PrinterInfo(
        name: 'Test Printer',
        address: 'AA:BB:CC:DD:EE:FF',
      );

      blocTest<HomeCubit, HomeState>(
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

      blocTest<HomeCubit, HomeState>(
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
      blocTest<HomeCubit, HomeState>(
        'clears saved printer and emits HomeInitial',
        build: () {
          when(
            () => mockStorageService.clearDefaultPrinter(),
          ).thenAnswer((_) async {});
          return buildCubit();
        },
        act: (cubit) => cubit.clearDefaultPrinter(),
        expect: () => [const HomeInitial()],
        verify: (_) {
          verify(() => mockStorageService.clearDefaultPrinter()).called(1);
        },
      );
    });

    // ─── Reset ───────────────────────────────────────────────────

    group('reset', () {
      blocTest<HomeCubit, HomeState>(
        'emits [HomeInitial] when reset is called',
        build: buildCubit,
        act: (cubit) => cubit.reset(),
        expect: () => [const HomeInitial()],
      );
    });
  });
}

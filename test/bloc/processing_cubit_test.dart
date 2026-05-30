import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memoir_v1/features/session/bloc/processing_cubit.dart';
import 'package:memoir_v1/features/session/bloc/processing_state.dart';
import 'package:memoir_v1/features/session/data/datasources/transaction_datasource.dart';
import 'package:memoir_v1/features/session/data/repositories/transaction_repository.dart';
import 'package:memoir_v1/features/session/data/services/composite_print_service.dart';
import 'package:memoir_v1/features/session/data/services/composite_render_service.dart';
import 'package:memoir_v1/shared/data/datasources/storage_service.dart';
import 'package:memoir_v1/shared/data/models/template.dart';
import 'package:memoir_v1/shared/data/models/transaction.dart';
import 'package:memoir_v1/shared/data/services/print_channel.dart';

class MockTransactionRepository extends Mock
    implements TransactionRepository {}

class MockCompositePrintService extends Mock
    implements CompositePrintService {}

class MockCompositeRenderService extends Mock
    implements CompositeRenderService {}

class MockStorageService extends Mock implements StorageService {}

class FakePrintChannel extends Fake implements PrintChannel {}

const _mockTransaction = Transaction(
  id: 'tx-001',
  orderId: 'MEM-mock-001',
  status: 'PAID',
  paymentMethod: 'CASH',
  printQty: 2,
  hasDigitalCopy: true,
  totalAmount: 35000,
  paidAt: '2025-01-01T00:00:00Z',
);

const _mockTransactionNoDigital = Transaction(
  id: 'tx-002',
  orderId: 'MEM-mock-002',
  status: 'PAID',
  paymentMethod: 'CASH',
  printQty: 1,
  hasDigitalCopy: false,
  totalAmount: 25000,
  paidAt: '2025-01-01T00:00:00Z',
);

const _mockPendingTransaction = Transaction(
  id: 'tx-003',
  orderId: 'MEM-mock-003',
  status: 'PENDING',
  paymentMethod: 'CASH',
  printQty: 1,
  hasDigitalCopy: false,
  totalAmount: 25000,
);

const _mockPgTransaction = Transaction(
  id: 'tx-pg',
  orderId: 'MEM-pg',
  status: 'PENDING',
  paymentMethod: 'PG',
  qrString: '00020101021226680016COM.XENDIT.WWW01189360091600000000180218000000000000000',
  paymentExpiresAt: '2026-01-01T01:00:00Z',
  printQty: 1,
  hasDigitalCopy: false,
  totalAmount: 25000,
);

final _mockTemplate = Template(
  id: 'tmpl-1',
  name: 'Test Template',
  width: 576,
  height: 864,
  elements: const [
    TemplateElement(
      id: 'slot-1',
      type: 'PHOTO_SLOT',
      x: 50, y: 50,
      width: 200, height: 300,
      sequence: 1,
      properties: {},
    ),
  ],
  updatedAt: DateTime(2025, 1, 1),
);

const _mockPhotos = <int, String>{0: '/tmp/test_photo.jpg'};

void main() {
  late MockTransactionRepository mockRepository;
  late MockCompositePrintService mockPrintService;
  late MockCompositeRenderService mockRenderService;
  late MockStorageService mockStorageService;

  setUp(() {
    mockRepository = MockTransactionRepository();
    mockPrintService = MockCompositePrintService();
    mockRenderService = MockCompositeRenderService();
    mockStorageService = MockStorageService();

    registerFallbackValue(Uint8List(0));
    registerFallbackValue(<Uint8List>[]);
    registerFallbackValue(_mockTemplate);
    registerFallbackValue(_mockPhotos);
    registerFallbackValue(FakePrintChannel());
    registerFallbackValue(PrinterConnectionType.bluetooth);
    registerFallbackValue(const ProcessingSettings());

    // Default: normal mode (not event mode).
    when(() => mockStorageService.isEventMode).thenReturn(false);

    // Default processing settings — match service defaults.
    when(() => mockStorageService.thermalDensity).thenReturn(2);
    when(() => mockStorageService.ditherAlgorithm).thenReturn('fs');
    when(() => mockStorageService.sharpenAmount).thenReturn(0.25);
    when(() => mockStorageService.brightness).thenReturn(8.0);
  });

  ProcessingCubit buildCubit() => ProcessingCubit(
    repository: mockRepository,
    printService: mockPrintService,
    renderService: mockRenderService,
    storageService: mockStorageService,
  );

  void stubRenderAndPrint() {
    when(
      () => mockRenderService.render(
        template: any(named: 'template'),
        capturedPhotos: any(named: 'capturedPhotos'),
        hasDigitalCopy: any(named: 'hasDigitalCopy'),
        settings: any(named: 'settings'),
      ),
    ).thenAnswer((_) async => CompositeResult(
      printBands: [Uint8List.fromList([0x1B, 0x40])],
    ));
    when(() => mockPrintService.setChannel(any())).thenReturn(null);
    when(
      () => mockPrintService.connectPrinter(
        printerAddress: any(named: 'printerAddress'),
        printerName: any(named: 'printerName'),
        connectionType: any(named: 'connectionType'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockPrintService.sendData(bands: any(named: 'bands')),
    ).thenAnswer((_) async {});
    when(() => mockPrintService.disconnectPrinter()).thenAnswer((_) async {});
  }

  void stubPrinterSettings({bool isEventMode = false}) {
    when(() => mockStorageService.isEventMode).thenReturn(isEventMode);
    when(() => mockStorageService.defaultPrinterMac)
        .thenReturn('AA:BB:CC:DD:EE:FF');
    when(() => mockStorageService.defaultPrinterName)
        .thenReturn('Test Printer');
    when(() => mockStorageService.defaultPrinterConnectionType)
        .thenReturn('bluetooth');
  }

  group('ProcessingCubit', () {
    test('initial state is ProcessingInitial', () {
      final cubit = buildCubit();
      expect(cubit.state, isA<ProcessingInitial>());
      cubit.close();
    });

    group('startProcessing — creates transaction then awaits payment', () {
      blocTest<ProcessingCubit, ProcessingState>(
        'CASH: emits [CreatingTransaction, Rendering, Printing, Complete]',
        setUp: () {
          when(
            () => mockRepository.createTransaction(
              templateId: any(named: 'templateId'),
              paymentMethod: any(named: 'paymentMethod'),
              transactionType: any(named: 'transactionType'),
              printQty: any(named: 'printQty'),
              hasDigitalCopy: any(named: 'hasDigitalCopy'),
              totalAmount: any(named: 'totalAmount'),
            ),
          ).thenAnswer(
            (_) async => const CreateTransactionResult(
              transaction: _mockTransactionNoDigital,
            ),
          );
          stubRenderAndPrint();
          stubPrinterSettings();
        },
        build: buildCubit,
        act: (cubit) => cubit.startProcessing(
          template: _mockTemplate,
          capturedPhotos: _mockPhotos,
          paymentMethod: 'CASH',
          printQty: 1,
          hasDigitalCopy: false,
          totalAmount: 25000,
        ),
        expect: () => [
          isA<ProcessingCreatingTransaction>(),
          isA<ProcessingRendering>(),
          isA<ProcessingPrinting>(),
          isA<ProcessingComplete>(),
        ],
      );

      blocTest<ProcessingCubit, ProcessingState>(
        'PG: emits [CreatingTransaction, AwaitingPayment] with qrString',
        setUp: () {
          when(
            () => mockRepository.createTransaction(
              templateId: any(named: 'templateId'),
              paymentMethod: any(named: 'paymentMethod'),
              transactionType: any(named: 'transactionType'),
              printQty: any(named: 'printQty'),
              hasDigitalCopy: any(named: 'hasDigitalCopy'),
              totalAmount: any(named: 'totalAmount'),
            ),
          ).thenAnswer(
            (_) async => CreateTransactionResult(
              transaction: _mockPgTransaction,
              qrString: _mockPgTransaction.qrString,
            ),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.startProcessing(
          template: _mockTemplate,
          capturedPhotos: _mockPhotos,
          paymentMethod: 'PG',
          printQty: 1,
          hasDigitalCopy: false,
          totalAmount: 25000,
        ),
        expect: () => [
          isA<ProcessingCreatingTransaction>(),
          isA<ProcessingAwaitingPayment>()
              .having((s) => s.paymentMethod, 'paymentMethod', 'PG')
              .having((s) => s.qrString, 'qrString', isNotNull),
        ],
      );

      blocTest<ProcessingCubit, ProcessingState>(
        'STATIC_QRIS: emits [CreatingTransaction, Rendering, Printing, Complete]',
        setUp: () {
          when(
            () => mockRepository.createTransaction(
              templateId: any(named: 'templateId'),
              paymentMethod: any(named: 'paymentMethod'),
              transactionType: any(named: 'transactionType'),
              printQty: any(named: 'printQty'),
              hasDigitalCopy: any(named: 'hasDigitalCopy'),
              totalAmount: any(named: 'totalAmount'),
            ),
          ).thenAnswer(
            (_) async => const CreateTransactionResult(
              transaction: _mockTransactionNoDigital,
            ),
          );
          stubRenderAndPrint();
          stubPrinterSettings();
        },
        build: buildCubit,
        act: (cubit) => cubit.startProcessing(
          template: _mockTemplate,
          capturedPhotos: _mockPhotos,
          paymentMethod: 'STATIC_QRIS',
          printQty: 1,
          hasDigitalCopy: false,
          totalAmount: 25000,
        ),
        expect: () => [
          isA<ProcessingCreatingTransaction>(),
          isA<ProcessingRendering>(),
          isA<ProcessingPrinting>(),
          isA<ProcessingComplete>(),
        ],
      );

      blocTest<ProcessingCubit, ProcessingState>(
        'emits [CreatingTransaction, Error] when creation fails',
        setUp: () {
          when(
            () => mockRepository.createTransaction(
              templateId: any(named: 'templateId'),
              paymentMethod: any(named: 'paymentMethod'),
              transactionType: any(named: 'transactionType'),
              printQty: any(named: 'printQty'),
              hasDigitalCopy: any(named: 'hasDigitalCopy'),
              totalAmount: any(named: 'totalAmount'),
            ),
          ).thenThrow(
            const TransactionException('Data transaksi tidak valid'),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.startProcessing(
          template: _mockTemplate,
          capturedPhotos: _mockPhotos,
          paymentMethod: 'CASH',
          printQty: 1,
          hasDigitalCopy: false,
          totalAmount: 25000,
        ),
        expect: () => [
          isA<ProcessingCreatingTransaction>(),
          isA<ProcessingError>(),
        ],
      );
    });

    group('CASH/STATIC_QRIS — auto-proceed without awaiting payment', () {
      test('CASH: startProcessing proceeds directly to Complete', () async {
        when(
          () => mockRepository.createTransaction(
            templateId: any(named: 'templateId'),
            paymentMethod: any(named: 'paymentMethod'),
            transactionType: any(named: 'transactionType'),
            printQty: any(named: 'printQty'),
            hasDigitalCopy: any(named: 'hasDigitalCopy'),
            totalAmount: any(named: 'totalAmount'),
          ),
        ).thenAnswer(
          (_) async => const CreateTransactionResult(
            transaction: _mockTransactionNoDigital,
          ),
        );
        stubRenderAndPrint();
        stubPrinterSettings();

        final cubit = buildCubit();

        await cubit.startProcessing(
          template: _mockTemplate,
          capturedPhotos: _mockPhotos,
          paymentMethod: 'CASH',
          printQty: 1,
          hasDigitalCopy: false,
          totalAmount: 25000,
        );
        expect(cubit.state, isA<ProcessingComplete>());

        cubit.close();
      });

      test('STATIC_QRIS: startProcessing proceeds directly to Complete', () async {
        when(
          () => mockRepository.createTransaction(
            templateId: any(named: 'templateId'),
            paymentMethod: any(named: 'paymentMethod'),
            transactionType: any(named: 'transactionType'),
            printQty: any(named: 'printQty'),
            hasDigitalCopy: any(named: 'hasDigitalCopy'),
            totalAmount: any(named: 'totalAmount'),
          ),
        ).thenAnswer(
          (_) async => const CreateTransactionResult(
            transaction: _mockTransactionNoDigital,
          ),
        );
        stubRenderAndPrint();
        stubPrinterSettings();

        final cubit = buildCubit();

        await cubit.startProcessing(
          template: _mockTemplate,
          capturedPhotos: _mockPhotos,
          paymentMethod: 'STATIC_QRIS',
          printQty: 1,
          hasDigitalCopy: false,
          totalAmount: 25000,
        );
        expect(cubit.state, isA<ProcessingComplete>());

        cubit.close();
      });
    });

    group('checkPgPayment — PG manual check', () {
      Future<ProcessingCubit> buildPgCubit() async {
        when(
          () => mockRepository.createTransaction(
            templateId: any(named: 'templateId'),
            paymentMethod: any(named: 'paymentMethod'),
            transactionType: any(named: 'transactionType'),
            printQty: any(named: 'printQty'),
            hasDigitalCopy: any(named: 'hasDigitalCopy'),
            totalAmount: any(named: 'totalAmount'),
          ),
        ).thenAnswer(
          (_) async => const CreateTransactionResult(
            transaction: _mockPgTransaction,
          ),
        );

        final cubit = buildCubit();
        await cubit.startProcessing(
          template: _mockTemplate,
          capturedPhotos: _mockPhotos,
          paymentMethod: 'PG',
          printQty: 1,
          hasDigitalCopy: false,
          totalAmount: 25000,
        );
        expect(cubit.state, isA<ProcessingAwaitingPayment>());
        return cubit;
      }

      test('proceeds to render when PAID', () async {
        stubRenderAndPrint();
        stubPrinterSettings();

        final cubit = await buildPgCubit();

        when(() => mockRepository.checkPayment(any()))
            .thenAnswer((_) async => 'PAID');

        await cubit.checkPgPayment();
        expect(cubit.state, isA<ProcessingComplete>());

        cubit.close();
      });

      test('emits PaymentFailed when FAILED', () async {
        final cubit = await buildPgCubit();

        when(() => mockRepository.checkPayment(any()))
            .thenAnswer((_) async => 'FAILED');

        await cubit.checkPgPayment();
        expect(cubit.state, isA<ProcessingPaymentFailed>());
        expect(
          (cubit.state as ProcessingPaymentFailed).message,
          contains('gagal'),
        );

        cubit.close();
      });

      test('emits PaymentFailed when EXPIRED', () async {
        final cubit = await buildPgCubit();

        when(() => mockRepository.checkPayment(any()))
            .thenAnswer((_) async => 'EXPIRED');

        await cubit.checkPgPayment();
        expect(cubit.state, isA<ProcessingPaymentFailed>());
        expect(
          (cubit.state as ProcessingPaymentFailed).message,
          contains('kedaluwarsa'),
        );

        cubit.close();
      });

      test('stays on AwaitingPayment when PENDING', () async {
        final cubit = await buildPgCubit();

        when(() => mockRepository.checkPayment(any()))
            .thenAnswer((_) async => 'PENDING');

        await cubit.checkPgPayment();
        // No state change — still on AwaitingPayment
        expect(cubit.state, isA<ProcessingAwaitingPayment>());

        cubit.close();
      });
    });

    group('print errors', () {
      test('emits PrintError when printer not configured', () async {
        when(
          () => mockRepository.createTransaction(
            templateId: any(named: 'templateId'),
            paymentMethod: any(named: 'paymentMethod'),
            transactionType: any(named: 'transactionType'),
            printQty: any(named: 'printQty'),
            hasDigitalCopy: any(named: 'hasDigitalCopy'),
            totalAmount: any(named: 'totalAmount'),
          ),
        ).thenAnswer(
          (_) async => const CreateTransactionResult(
            transaction: _mockPendingTransaction,
          ),
        );
        when(() => mockStorageService.defaultPrinterMac).thenReturn(null);
        when(() => mockStorageService.defaultPrinterName).thenReturn(null);
        stubRenderAndPrint();

        final cubit = buildCubit();

        await cubit.startProcessing(
          template: _mockTemplate,
          capturedPhotos: _mockPhotos,
          paymentMethod: 'CASH',
          printQty: 1,
          hasDigitalCopy: false,
          totalAmount: 25000,
        );

        expect(cubit.state, isA<ProcessingPrintError>());
        expect(
          (cubit.state as ProcessingPrintError).message,
          contains('Printer'),
        );

        cubit.close();
      });
    });

    group('skipPrint', () {
      blocTest<ProcessingCubit, ProcessingState>(
        'completes immediately without blocking on upload',
        seed: () => const ProcessingPrintError(
          transaction: _mockTransactionNoDigital,
          currentCopy: 1,
          totalCopies: 1,
          message: 'Test error',
        ),
        build: buildCubit,
        act: (cubit) => cubit.skipPrint(),
        expect: () => [
          isA<ProcessingComplete>(),
        ],
      );
    });

    group('retryProcessing', () {
      test('does nothing when no transaction in error state', () async {
        final cubit = buildCubit();
        cubit.emit(const ProcessingError(message: 'No tx'));
        await cubit.retryProcessing();
        expect(cubit.state, isA<ProcessingError>());
        cubit.close();
      });

      test('resumes from render when transaction exists in error', () async {
        when(
          () => mockRepository.createTransaction(
            templateId: any(named: 'templateId'),
            paymentMethod: any(named: 'paymentMethod'),
            transactionType: any(named: 'transactionType'),
            printQty: any(named: 'printQty'),
            hasDigitalCopy: any(named: 'hasDigitalCopy'),
            totalAmount: any(named: 'totalAmount'),
          ),
        ).thenAnswer(
          (_) async => const CreateTransactionResult(
            transaction: _mockPendingTransaction,
          ),
        );
        stubRenderAndPrint();
        stubPrinterSettings();

        final cubit = buildCubit();

        // Start → AwaitingPayment → confirm → rendering fails
        await cubit.startProcessing(
          template: _mockTemplate,
          capturedPhotos: _mockPhotos,
          paymentMethod: 'CASH',
          printQty: 1,
          hasDigitalCopy: false,
          totalAmount: 25000,
        );

        // Simulate error after payment
        cubit.emit(const ProcessingError(
          message: 'Render failed',
          transaction: _mockPendingTransaction,
        ));

        await cubit.retryProcessing();
        expect(cubit.state, isA<ProcessingComplete>());

        cubit.close();
      });
    });
  });

  group('Transaction model', () {
    test('fromJson parses qrString and paymentExpiresAt', () {
      final json = {
        'id': 'tx-001',
        'orderId': 'MEM-1234',
        'status': 'PAID',
        'paymentMethod': 'PG',
        'qrString': '000201...',
        'paymentExpiresAt': '2026-01-01T01:00:00Z',
        'printQty': 2,
        'hasDigitalCopy': true,
        'totalAmount': 35000,
        'paidAt': '2025-01-01T00:00:00Z',
      };
      final tx = Transaction.fromJson(json);
      expect(tx.id, 'tx-001');
      expect(tx.isPaid, isTrue);
      expect(tx.qrString, '000201...');
      expect(tx.paymentExpiresAt, '2026-01-01T01:00:00Z');
    });

    test('isPaid/isPending/isFailed/isExpired helpers', () {
      expect(_mockTransaction.isPaid, isTrue);
      expect(_mockTransaction.isPending, isFalse);

      const pending = Transaction(
        id: 'tx', orderId: 'MEM', status: 'PENDING',
        paymentMethod: 'PG', printQty: 1,
        hasDigitalCopy: false, totalAmount: 25000,
      );
      expect(pending.isPending, isTrue);

      const failed = Transaction(
        id: 'tx', orderId: 'MEM', status: 'FAILED',
        paymentMethod: 'PG', printQty: 1,
        hasDigitalCopy: false, totalAmount: 25000,
      );
      expect(failed.isFailed, isTrue);

      const expired = Transaction(
        id: 'tx', orderId: 'MEM', status: 'EXPIRED',
        paymentMethod: 'PG', printQty: 1,
        hasDigitalCopy: false, totalAmount: 25000,
      );
      expect(expired.isExpired, isTrue);
    });

    test('Equatable equality', () {
      expect(_mockTransaction, _mockTransaction);
      expect(_mockTransaction == _mockTransactionNoDigital, isFalse);
    });
  });
}

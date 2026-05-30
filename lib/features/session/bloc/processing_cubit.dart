import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/data/datasources/storage_service.dart';
import '../../../shared/data/models/kiosk_config.dart';
import '../../../shared/data/models/template.dart';
import '../../../shared/data/models/transaction.dart';
import '../../../shared/data/services/print_channel.dart';
import '../data/datasources/transaction_datasource.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/services/composite_print_service.dart';
import '../data/services/composite_render_service.dart';
import '../data/services/native_bluetooth_channel.dart';
import '../data/services/native_usb_channel.dart';
import 'processing_state.dart';

/// Processing Cubit — sequential payment-first flow.
///
/// Flow:
/// 1. Create transaction (API)
/// 2. Await payment per method:
///    - CASH / STATIC_QRIS: transaction already marked paid on creation → proceed directly
///    - PG: show dynamic QR → auto-poll or user taps "CEK PEMBAYARAN" → checkPayment()
/// 3. After PAID → render composite in background isolate
/// 4. Print × printQty via Bluetooth/USB
/// 5. Upload digital copy if hasDigitalCopy
/// 6. Complete → Thank You
class ProcessingCubit extends Cubit<ProcessingState> {
  final TransactionRepository _repository;
  final CompositePrintService _printService;
  final CompositeRenderService _renderService;
  final StorageService _storageService;

  String? _digitalFilePath;
  List<Uint8List>? _printBands;
  Uint8List? _softfileQrBytes;

  // Retained for rendering after payment
  Template? _template;
  Map<int, String>? _capturedPhotos;
  bool _hasDigitalCopy = false;

  Timer? _pgPollingTimer;

  ProcessingCubit({
    required TransactionRepository repository,
    required CompositePrintService printService,
    required CompositeRenderService renderService,
    required StorageService storageService,
  }) : _repository = repository,
       _printService = printService,
       _renderService = renderService,
       _storageService = storageService,
       super(const ProcessingInitial());

  /// Retained template — exposed so views can render the composite preview
  /// during rendering/printing steps.
  Template? get template => _template;

  /// Retained captured photos — exposed for preview rendering in views.
  Map<int, String>? get capturedPhotos => _capturedPhotos;

  /// Start the processing flow — creates transaction then awaits payment.
  Future<void> startProcessing({
    required Template template,
    required Map<int, String> capturedPhotos,
    required String paymentMethod,
    required int printQty,
    required bool hasDigitalCopy,
    required int totalAmount,
  }) async {
    // Retain for later rendering
    _template = template;
    _capturedPhotos = capturedPhotos;
    _hasDigitalCopy = hasDigitalCopy;

    emit(const ProcessingCreatingTransaction());

    try {
      // ── Step 1: Create transaction ──
      final transactionType =
          _storageService.isEventMode ? 'EVENT' : 'NORMAL';
      final result = await _repository.createTransaction(
        templateId: template.id,
        paymentMethod: paymentMethod,
        transactionType: transactionType,
        printQty: printQty,
        hasDigitalCopy: hasDigitalCopy,
        totalAmount: totalAmount,
      );

      final transaction = result.transaction;
      // Transaction retained for retry scenarios.

      // ── Step 2: Await payment or proceed directly ──
      if (paymentMethod == 'CASH' || paymentMethod == 'STATIC_QRIS') {
        // Transaction already paid on creation — skip payment screen.
        await _renderAndPrint(transaction: transaction);
      } else {
        _emitAwaitingPayment(
          transaction: transaction,
          paymentMethod: paymentMethod,
        );
      }
    } on TransactionException catch (e) {
      emit(ProcessingError(message: e.message));
    } catch (e) {
      emit(ProcessingError(message: 'Gagal membuat transaksi: $e'));
    }
  }

  /// Emit the awaiting payment state with method-specific data.
  ///
  /// For PG, also starts background polling every 4 seconds.
  void _emitAwaitingPayment({
    required Transaction transaction,
    required String paymentMethod,
  }) {
    emit(ProcessingAwaitingPayment(
      transaction: transaction,
      paymentMethod: paymentMethod,
      qrString: paymentMethod == 'PG' ? transaction.qrString : null,
      staticQrisImagePath:
          paymentMethod == 'STATIC_QRIS'
              ? _storageService.staticQrisImagePath
              : null,
      paymentExpiresAt:
          paymentMethod == 'PG' ? transaction.paymentExpiresAt : null,
    ));

    if (paymentMethod == 'PG') {
      _startPgPolling(transaction);
    }
  }

  void _startPgPolling(Transaction transaction) {
    _pgPollingTimer?.cancel();
    _pgPollingTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _autoPollPayment(transaction),
    );
  }

  void _stopPgPolling() {
    _pgPollingTimer?.cancel();
    _pgPollingTimer = null;
  }

  /// Silent background poll — no loading state emitted.
  ///
  /// Resolves the payment if PAID/FAILED/EXPIRED; ignores network errors
  /// so polling continues on the next tick.
  Future<void> _autoPollPayment(Transaction transaction) async {
    if (isClosed || state is! ProcessingAwaitingPayment) {
      _stopPgPolling();
      return;
    }

    String status;
    try {
      status = await _repository.checkPayment(transaction.id);
    } catch (_) {
      return; // Transient error — retry on next tick.
    }

    // Guard again after the async gap: manual checkPgPayment() may have
    // already changed the state while we were awaiting.
    if (isClosed || state is! ProcessingAwaitingPayment) return;

    if (status == 'PAID') {
      _stopPgPolling();
      await _renderAndPrint(transaction: transaction);
    } else if (status == 'FAILED' || status == 'EXPIRED') {
      _stopPgPolling();
      if (!isClosed) {
        emit(ProcessingPaymentFailed(
          transaction: transaction,
          message: status == 'EXPIRED'
              ? 'Pembayaran telah kedaluwarsa.'
              : 'Pembayaran gagal.',
        ));
      }
    }
    // PENDING — do nothing, next tick will check again.
  }

  /// Called when user taps "CEK PEMBAYARAN" for PG.
  ///
  /// Stops auto-polling, does an immediate check with a loading indicator,
  /// then restarts polling if still PENDING.
  /// Returns the payment status string so the UI can show feedback.
  Future<String?> checkPgPayment() async {
    final s = state;
    if (s is! ProcessingAwaitingPayment) return null;

    _stopPgPolling();

    final transaction = s.transaction;

    // Show loading immediately so user gets feedback.
    emit(const ProcessingCheckingPayment());

    try {
      final status = await _repository.checkPayment(transaction.id);

      if (status == 'PAID') {
        await _renderAndPrint(transaction: transaction);
      } else if (status == 'FAILED' || status == 'EXPIRED') {
        emit(ProcessingPaymentFailed(
          transaction: transaction,
          message: status == 'EXPIRED'
              ? 'Pembayaran telah kedaluwarsa.'
              : 'Pembayaran gagal.',
        ));
      } else {
        // PENDING — restore awaiting payment state.
        _emitAwaitingPayment(
          transaction: transaction,
          paymentMethod: transaction.paymentMethod,
        );
      }

      return status;
    } on TransactionException catch (e) {
      emit(ProcessingError(
        message: e.message,
        transaction: transaction,
      ));
      return null;
    } catch (e) {
      emit(ProcessingError(
        message: 'Gagal memeriksa pembayaran: $e',
        transaction: transaction,
      ));
      return null;
    }
  }

  /// Retry from payment failed — go back to awaiting payment.
  ///
  /// For PG: recreates the transaction to get a new QR code.
  Future<void> retryPayment() async {
    final s = state;
    if (s is! ProcessingPaymentFailed) return;

    if (_template == null || _capturedPhotos == null) return;

    // Restart the full flow with a new transaction
    await startProcessing(
      template: _template!,
      capturedPhotos: _capturedPhotos!,
      paymentMethod: s.transaction.paymentMethod,
      printQty: s.transaction.printQty,
      hasDigitalCopy: s.transaction.hasDigitalCopy,
      totalAmount: s.transaction.totalAmount,
    );
  }

  /// After payment confirmed: render → start upload + print in parallel.
  Future<void> _renderAndPrint({required Transaction transaction}) async {
    if (_template == null || _capturedPhotos == null) {
      emit(ProcessingError(
        message: 'Data sesi tidak tersedia.',
        transaction: transaction,
      ));
      return;
    }

    try {
      // ── Step 3: Render composite ──
      emit(ProcessingRendering(transaction: transaction));

      final composite = await _renderService.render(
        template: _template!,
        capturedPhotos: _capturedPhotos!,
        hasDigitalCopy: _hasDigitalCopy,
        settings: ProcessingSettings(
          thermalDensity: _storageService.thermalDensity,
          dither: DitherAlgorithm.fromKey(_storageService.ditherAlgorithm),
          sharpenAmount: _storageService.sharpenAmount,
          brightness: _storageService.brightness,
        ),
      );

      _printBands = composite.printBands;
      _digitalFilePath = composite.digitalFilePath;

      // Pre-build softfile QR band so it can be appended after each photo copy.
      _softfileQrBytes = null;
      if (_hasDigitalCopy) {
        final configJson = _storageService.kioskConfigJson;
        if (configJson != null) {
          final config = KioskConfig.fromJsonString(configJson);
          final base = config.sessionPreviewUrl;
          if (base != null && base.isNotEmpty) {
            final trimmed = base.endsWith('/')
                ? base.substring(0, base.length - 1)
                : base;
            _softfileQrBytes = await _printService.buildSoftfileQrBand(
              '$trimmed/${transaction.id}',
            );
          }
        }
      }

      // ── Step 4: Start upload in background (parallel with printing) ──
      if (_hasDigitalCopy && _digitalFilePath != null) {
        _uploadDigitalCopy(transaction: transaction);
      }

      // ── Step 5: Print (upload runs in parallel) ──
      await _printAll(transaction: transaction);
    } on PrintException catch (e) {
      emit(ProcessingError(
        message: e.message,
        transaction: transaction,
      ));
    } catch (e) {
      emit(ProcessingError(
        message: 'Terjadi kesalahan: $e',
        transaction: transaction,
      ));
    }
  }

  /// Upload digital copy to server.
  ///
  /// On failure, schedules background retry so customer eventually
  /// gets their photos via web preview.
  Future<void> _uploadDigitalCopy({
    required Transaction transaction,
  }) async {
    try {
      await _repository.uploadDigitalCopy(
        transactionId: transaction.id,
        filePath: _digitalFilePath!,
      );
    } catch (_) {
      // First attempt failed — retry in background.
      _retryInBackground(
        () async {
          await _repository.uploadDigitalCopy(
            transactionId: transaction.id,
            filePath: _digitalFilePath!,
          );
        },
      );
    }
  }

  /// Retry from the point of failure after a fatal error.
  ///
  /// If a transaction was already created, resumes from render → print → upload.
  Future<void> retryProcessing() async {
    final s = state;
    if (s is! ProcessingError || s.transaction == null) return;

    final transaction = s.transaction!;

    await _renderAndPrint(transaction: transaction);
  }

  @override
  Future<void> close() {
    _stopPgPolling();
    return super.close();
  }

  /// Fire-and-forget: retry [action] up to 10 times with exponential backoff.
  ///
  /// Delay: 2s → 4s → 8s → 16s → 32s → 60s → 60s → ... (cap 60s)
  /// Total retry window: ~6 minutes.
  void _retryInBackground(Future<void> Function() action) {
    Future<void>(() async {
      for (var attempt = 1; attempt <= 10; attempt++) {
        final delaySec = min<int>(2 * pow(2, attempt - 1).toInt(), 60);
        await Future<void>.delayed(Duration(seconds: delaySec));
        try {
          await action();
          return; // Success — stop retrying.
        } catch (_) {
          // Will retry on next iteration.
        }
      }
    });
  }

  /// Print composite × printQty copies using pre-built ESC/POS bytes.
  Future<void> _printAll({required Transaction transaction}) async {
    final printerAddress = _storageService.defaultPrinterMac;
    final printerName = _storageService.defaultPrinterName ?? 'Printer';
    final connectionType = PrinterConnectionType.fromKey(
      _storageService.defaultPrinterConnectionType,
    );
    final totalCopies = transaction.printQty;

    if (printerAddress == null || printerAddress.isEmpty) {
      emit(ProcessingPrintError(
        transaction: transaction,
        currentCopy: 1,
        totalCopies: totalCopies,
        message: 'Printer belum diatur. Silakan atur printer di Settings.',
      ));
      return;
    }

    if (_printBands == null || _printBands!.isEmpty) {
      emit(ProcessingPrintError(
        transaction: transaction,
        currentCopy: 1,
        totalCopies: totalCopies,
        message: 'Gambar cetak tidak tersedia.',
      ));
      return;
    }

    // Set the transport channel (BT or USB) based on saved preference.
    final PrintChannel channel = connectionType == PrinterConnectionType.usb
        ? NativeUsbChannel()
        : NativeBluetoothChannel();
    _printService.setChannel(channel);

    try {
      await _printService.connectPrinter(
        printerAddress: printerAddress,
        printerName: printerName,
        connectionType: connectionType,
      );
    } catch (e) {
      emit(ProcessingPrintError(
        transaction: transaction,
        currentCopy: 1,
        totalCopies: totalCopies,
        message: e.toString(),
      ));
      return;
    }

    try {
      for (var i = 1; i <= totalCopies; i++) {
        emit(ProcessingPrinting(
          transaction: transaction,
          currentCopy: i,
          totalCopies: totalCopies,
        ));

        try {
          await _printService.sendData(bands: _printBands!);
          // Softfile: append QR band (with cut) after each photo copy.
          if (_softfileQrBytes != null) {
            await _printService.sendData(bands: [_softfileQrBytes!]);
          }
        } catch (e) {
          emit(ProcessingPrintError(
            transaction: transaction,
            currentCopy: i,
            totalCopies: totalCopies,
            message: e.toString(),
          ));
          return; // Wait for retryPrint() or skipPrint()
        }
      }

      // Print receipt after all copies — non-fatal if fails.
      try {
        await _printReceipt(transaction: transaction);
      } catch (_) {}
    } finally {
      try {
        await _printService.disconnectPrinter();
      } catch (_) {
        // Ignore disconnect errors — print data is already sent.
      }
    }

    _afterPrint(transaction: transaction);
  }

  /// Retry printing from the failed copy.
  Future<void> retryPrint() async {
    final s = state;
    if (s is! ProcessingPrintError) return;

    final printerAddress = _storageService.defaultPrinterMac;
    final printerName = _storageService.defaultPrinterName ?? 'Printer';
    final connectionType = PrinterConnectionType.fromKey(
      _storageService.defaultPrinterConnectionType,
    );
    if (printerAddress == null || printerAddress.isEmpty) return;

    // ESC/POS bands are pre-encoded in the render isolate.
    if (_printBands == null || _printBands!.isEmpty) return;

    // Set the transport channel (BT or USB) based on saved preference.
    final PrintChannel channel = connectionType == PrinterConnectionType.usb
        ? NativeUsbChannel()
        : NativeBluetoothChannel();
    _printService.setChannel(channel);

    // Connect once for all remaining copies.
    try {
      await _printService.connectPrinter(
        printerAddress: printerAddress,
        printerName: printerName,
        connectionType: connectionType,
      );
    } catch (e) {
      emit(ProcessingPrintError(
        transaction: s.transaction,
        currentCopy: s.currentCopy,
        totalCopies: s.totalCopies,
        message: e.toString(),
      ));
      return;
    }

    try {
      for (var i = s.currentCopy; i <= s.totalCopies; i++) {
        emit(ProcessingPrinting(
          transaction: s.transaction,
          currentCopy: i,
          totalCopies: s.totalCopies,
        ));

        try {
          await _printService.sendData(bands: _printBands!);
          if (_softfileQrBytes != null) {
            await _printService.sendData(bands: [_softfileQrBytes!]);
          }
        } catch (e) {
          emit(ProcessingPrintError(
            transaction: s.transaction,
            currentCopy: i,
            totalCopies: s.totalCopies,
            message: e.toString(),
          ));
          return;
        }
      }
    } finally {
      try {
        await _printService.disconnectPrinter();
      } catch (_) {}
    }

    _afterPrint(transaction: s.transaction);
  }

  /// Skip remaining prints and proceed to complete.
  void skipPrint() {
    final s = state;
    if (s is! ProcessingPrintError) return;
    // Upload continues in background — don't block.
    emit(ProcessingComplete(transaction: s.transaction));
  }

  /// Print a simple text receipt after all photo copies.
  ///
  /// Skipped silently if receipt printing is disabled in settings,
  /// or if kiosk config is unavailable. Printer must already be connected.
  Future<void> _printReceipt({required Transaction transaction}) async {
    if (!_storageService.isReceiptPrintEnabled) return;

    final configJson = _storageService.kioskConfigJson;
    if (configJson == null) return;

    final config = KioskConfig.fromJsonString(configJson);

    String? previewUrl;
    if (transaction.hasDigitalCopy) {
      final base = config.sessionPreviewUrl;
      if (base != null && base.isNotEmpty) {
        final trimmed = base.endsWith('/')
            ? base.substring(0, base.length - 1)
            : base;
        previewUrl = '$trimmed/${transaction.id}';
      }
    }

    final receiptBytes = await _printService.buildReceiptBytes(
      boothName: config.name,
      transactionId: transaction.id,
      paidAt: transaction.paidAt,
      printQty: transaction.printQty,
      hasDigitalCopy: transaction.hasDigitalCopy,
      paymentMethod: transaction.paymentMethod,
      totalAmount: transaction.totalAmount,
      previewUrl: previewUrl,
    );

    await _printService.sendData(bands: [receiptBytes]);
  }

  /// After printing, complete immediately.
  ///
  /// Upload runs in background (started during rendering) and doesn't
  /// block navigation. QR URL is built from sessionPreviewUrl + transactionId,
  /// not from uploadDigitalCopy response.
  void _afterPrint({required Transaction transaction}) {
    emit(ProcessingComplete(transaction: transaction));
  }
}

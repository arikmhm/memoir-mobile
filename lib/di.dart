import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/app/bloc/app_cubit.dart';
import 'features/pairing/data/datasources/pairing_datasource.dart';
import 'features/pairing/data/repositories/pairing_repository.dart';
import 'features/pairing/bloc/pairing_cubit.dart';
import 'features/session/bloc/processing_cubit.dart';
import 'features/session/bloc/session_cubit.dart';
import 'features/session/data/datasources/session_datasource.dart';
import 'features/session/data/datasources/transaction_datasource.dart';
import 'features/session/data/repositories/transaction_repository.dart';
import 'features/session/data/services/composite_print_service.dart';
import 'features/session/data/services/composite_render_service.dart';
import 'features/settings/bloc/settings_cubit.dart';
import 'features/settings/data/services/camera_test_service.dart';
import 'features/settings/data/services/printer_test_service.dart';
import 'features/startup/bloc/startup_cubit.dart';
import 'features/startup/data/datasources/startup_datasource.dart';
import 'features/startup/data/repositories/startup_repository.dart';
import 'shared/data/datasources/api_client.dart';
import 'shared/data/datasources/storage_service.dart';
import 'shared/data/services/template_cache_service.dart';
import 'config/routes.dart';

/// Service locator instance.
final sl = GetIt.instance;

/// Register all dependencies in the service locator.
///
/// Call this once in main() before runApp().
Future<void> initDependencies() async {
  // ─── External ────────────────────────────────────────────────

  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  sl.registerSingleton<FlutterSecureStorage>(const FlutterSecureStorage());

  // ─── Services ────────────────────────────────────────────────

  sl.registerSingleton<StorageService>(
    StorageService(
      secureStorage: sl<FlutterSecureStorage>(),
      prefs: sl<SharedPreferences>(),
    ),
  );

  sl.registerSingleton<ApiClient>(
    ApiClient(
      getToken: () => sl<StorageService>().getDeviceToken(),
      onAuthError: () async {
        sl<AppCubit>().onAuthError();
      },
    ),
  );

  sl.registerSingleton<TemplateCacheService>(
    TemplateCacheService(
      prefs: sl<SharedPreferences>(),
      dio: sl<ApiClient>().dio,
    ),
  );

  // ─── Datasources ─────────────────────────────────────────────

  sl.registerFactory<PairingDatasource>(
    () => PairingDatasource(
      apiClient: sl<ApiClient>(),
    ),
  );

  sl.registerFactory<StartupDatasource>(
    () => StartupDatasource(
      apiClient: sl<ApiClient>(),
    ),
  );

  // ─── Repositories ────────────────────────────────────────────

  sl.registerFactory<PairingRepository>(
    () => PairingRepository(
      datasource: sl<PairingDatasource>(),
      storageService: sl<StorageService>(),
    ),
  );

  sl.registerFactory<StartupRepository>(
    () => StartupRepository(
      datasource: sl<StartupDatasource>(),
      storageService: sl<StorageService>(),
      cacheService: sl<TemplateCacheService>(),
    ),
  );

  // ─── Cubits ──────────────────────────────────────────────────

  sl.registerSingleton<AppCubit>(
    AppCubit(storageService: sl<StorageService>()),
  );

  sl.registerFactory<PairingCubit>(
    () => PairingCubit(repository: sl<PairingRepository>()),
  );

  sl.registerFactory<StartupCubit>(
    () => StartupCubit(repository: sl<StartupRepository>()),
  );

  sl.registerFactory<SessionCubit>(() => SessionCubit());

  // ─── Transaction / Processing ─────────────────────────────────

  sl.registerFactory<TransactionDatasource>(
    () => TransactionDatasource(apiClient: sl<ApiClient>()),
  );

  sl.registerFactory<SessionDatasource>(
    () => SessionDatasource(apiClient: sl<ApiClient>()),
  );

  sl.registerFactory<TransactionRepository>(
    () => TransactionRepository(
      transactionDatasource: sl<TransactionDatasource>(),
      sessionDatasource: sl<SessionDatasource>(),
    ),
  );

  sl.registerLazySingleton<CompositePrintService>(
    () => CompositePrintService(),
  );

  sl.registerLazySingleton<CompositeRenderService>(
    () => CompositeRenderService(),
  );

  sl.registerFactory<ProcessingCubit>(
    () => ProcessingCubit(
      repository: sl<TransactionRepository>(),
      printService: sl<CompositePrintService>(),
      renderService: sl<CompositeRenderService>(),
      storageService: sl<StorageService>(),
    ),
  );

  // ─── Settings ─────────────────────────────────────────────────

  sl.registerLazySingleton<CameraTestService>(() => CameraTestService());
  sl.registerLazySingleton<PrinterTestService>(() => PrinterTestService());

  sl.registerFactory<SettingsCubit>(
    () => SettingsCubit(
      cameraService: sl<CameraTestService>(),
      printerService: sl<PrinterTestService>(),
      storageService: sl<StorageService>(),
      startupRepository: sl<StartupRepository>(),
      appCubit: sl<AppCubit>(),
    ),
  );

  // ─── Router ──────────────────────────────────────────────────

  sl.registerSingleton<AppRouter>(AppRouter(appCubit: sl<AppCubit>()));
}

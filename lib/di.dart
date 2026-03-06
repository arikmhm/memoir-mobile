import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/app/bloc/app_cubit.dart';
import 'features/pairing/data/datasources/pairing_datasource.dart';
import 'features/pairing/data/repositories/pairing_repository.dart';
import 'features/pairing/bloc/pairing_cubit.dart';
import 'features/session/bloc/session_cubit.dart';
import 'features/settings/bloc/settings_cubit.dart';
import 'features/settings/data/services/camera_test_service.dart';
import 'features/settings/data/services/printer_test_service.dart';
import 'shared/data/datasources/api_client.dart';
import 'shared/data/datasources/storage_service.dart';
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

  // ─── Datasources ─────────────────────────────────────────────

  sl.registerFactory<PairingDatasource>(() => PairingDatasource());

  // ─── Repositories ────────────────────────────────────────────

  sl.registerFactory<PairingRepository>(
    () => PairingRepository(
      datasource: sl<PairingDatasource>(),
      storageService: sl<StorageService>(),
    ),
  );

  // ─── Cubits ──────────────────────────────────────────────────

  sl.registerSingleton<AppCubit>(
    AppCubit(storageService: sl<StorageService>()),
  );

  sl.registerFactory<PairingCubit>(
    () => PairingCubit(repository: sl<PairingRepository>()),
  );

  sl.registerFactory<SessionCubit>(() => SessionCubit());

  // ─── Settings ─────────────────────────────────────────────────

  sl.registerLazySingleton<CameraTestService>(() => CameraTestService());
  sl.registerLazySingleton<PrinterTestService>(() => PrinterTestService());

  sl.registerFactory<SettingsCubit>(
    () => SettingsCubit(
      cameraService: sl<CameraTestService>(),
      printerService: sl<PrinterTestService>(),
      storageService: sl<StorageService>(),
    ),
  );

  // ─── Router ──────────────────────────────────────────────────

  sl.registerSingleton<AppRouter>(AppRouter(appCubit: sl<AppCubit>()));
}

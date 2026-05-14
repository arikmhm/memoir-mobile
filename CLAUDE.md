# memoir. Mobile Runner

Flutter kiosk app untuk Android tablet — menjalankan sesi photo booth, pembayaran, dan printing.

## Quick Commands

```bash
flutter run                                          # run (dev environment, default)
flutter run --dart-define=APP_ENV=prod \
  --dart-define=API_BASE_URL=https://backend-memoir-production.up.railway.app/api/v1  # run (prod)
flutter run --dart-define=USE_MOCK=true              # run dengan mock mode
flutter test                                         # run all tests
flutter test test/bloc/                              # run bloc tests only
flutter analyze                                      # static analysis
```

### Environment Management

Aplikasi mendukung **dev** dan **prod** environments via `AppConfig` (lib/config/app_config.dart).

**Development (default):**
- Automatic `flutter run` → hits dev backend (backend-memoir-development.up.railway.app)

**Production:**
- Copy-paste command di atas atau simpan alias
- `flutter run --dart-define=APP_ENV=prod --dart-define=API_BASE_URL=https://backend-memoir-production.up.railway.app/api/v1`

## Tech Stack

- **Flutter** (Dart ^3.11.1) — Android tablet target (min API 29)
- **State management:** flutter_bloc (Cubit, bukan Bloc events)
- **Routing:** go_router — redirect driven by AppCubit state
- **DI:** get_it (`sl` global instance, registered in `lib/di.dart`)
- **HTTP:** dio dengan Bearer device_token interceptor
- **Storage:** flutter_secure_storage (token), shared_preferences (settings), hive_ce (cache)
- **Testing:** bloc_test + mocktail

## Architecture

Feature-first clean architecture:

```
lib/
  di.dart                    # GetIt registration
  app.dart                   # Root widget (MultiBlocProvider)
  config/
    app_config.dart          # Environment config (dev/prod)
    routes.dart              # GoRouter definitions
  features/
    app/bloc/                # AppCubit — app lifecycle (pairing/startup/ready/locked)
    pairing/                 # 6-digit pairing code → device token
    startup/                 # Fetch kiosk config + sync templates
    session/                 # Photo session, processing, payment, upload
    settings/                # Hidden settings (5-tap access)
  shared/
    core/constants/          # ApiConstants, AppConstants
    core/theme/              # AppTheme, AppColors, AppTypography, AppSpacing
    core/utils/              # Result<T> sealed class, formatters
    core/widgets/            # Shared UI components
    data/datasources/        # ApiClient, StorageService
    data/models/             # KioskConfig, Template, Transaction
    data/services/           # TemplateCacheService, PrintChannel
    widgets/                 # Memoir-branded reusable widgets
```

## Patterns & Conventions

- **Result type:** Repositories return `Result<T>` (sealed class: `Ok<T>` | `Error<T>`)
- **Cubit over Bloc:** Gunakan Cubit + methods, bukan Bloc events
- **Naming:** snake_case files, PascalCase classes, camelCase methods/variables
- **Barrel files:** Tiap feature punya file barrel (e.g., `pairing.dart`, `session.dart`)
- **State classes:** Extend Equatable, prefix dengan nama feature (e.g., `AppReady`, `PairingSuccess`)

## App Flow

```
Pairing → Startup (fetch config + sync) → Screensaver → Select Template → Photo Session
→ Preview → Confirmation → Processing (create tx, pay, render, print, upload) → Thank You
```

Settings diakses via 5x tap di screensaver.

## Do / Don't

- **DO** konfirmasi sebelum menambah package baru ke pubspec.yaml
- **DO** gunakan `sl<T>()` untuk dependency injection, jangan constructor injection di widget
- **DO** test cubits dengan `bloc_test` dan mock dependencies dengan `mocktail`
- **DON'T** hardcode API URLs — gunakan `ApiConstants` dan `--dart-define`
- **DON'T** commit file `.env`, credentials, atau device tokens

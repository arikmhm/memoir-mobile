# PRD-05: Mobile App Runner (Android)

> **Versi:** 1.0
> **Tanggal:** 6 Maret 2026
> **Status:** Draft — For Review
> **Audiens:** Internal dev team & AI coding agents
> **Parent:** [PRD-00-master.md](./PRD-00-master.md) (Platform Overview)
> **Backend:** [PRD-01-backend-api.md](./PRD-01-backend-api.md) (Backend API)
> **Desktop Version:** [PRD-04-desktop-runner.md](./PRD-04-desktop-runner.md) (Desktop Runner)

---

## 1. Executive Summary

### 1.1 Problem Statement

Tidak semua booth photobooth menggunakan PC/laptop. Banyak operator — terutama yang bergerak (event, wedding, pop-up booth) — membutuhkan solusi ringan yang berjalan di tablet Android. Desktop Runner (Electron) terlalu berat untuk hardware mobile, dan instalasi Electron di Android tidak memungkinkan.

### 1.2 Proposed Solution

**memoir. Mobile Runner** adalah aplikasi Android native berbasis **Flutter** yang merupakan versi mobile dari Kiosk Runner. Aplikasi ini menjalankan flow yang identik dengan Desktop Runner (PRD-04) — **foto dulu, bayar kemudian** — menggunakan backend API endpoints yang sama (`/api/v1/kiosk/*`), namun diadaptasi untuk platform mobile:

- **Native kamera** via `camera` plugin (bukan `getUserMedia`)
- **Bluetooth thermal printer** (bukan USB ESC/POS)
- **Android Kiosk/Lock Mode** untuk mencegah customer keluar app
- **Flutter Secure Storage** (bukan `electron-store` + `safeStorage`)
- **Optimasi battery & memory** untuk operasi sepanjang hari

Sama seperti Desktop Runner: **tidak ada login user**, autentikasi via `device_token` permanen dari proses pairing 6-digit code.

### 1.3 Success Criteria

| # | KPI | Target | Cara Ukur |
|---|-----|--------|-----------|
| 1 | **Time-to-first-session** | < 30 detik dari app launch sampai sesi foto siap | Manual testing |
| 2 | **Composite render time** | < 3 detik untuk template ≤ 20 elemen | Performance profiling |
| 3 | **Template sync time** | < 5 detik untuk ≤ 50 template | Network timing |
| 4 | **Offline CASH/QRIS** | 100% bisa berjalan tanpa internet setelah startup | Integration test |
| 5 | **Battery consumption** | < 15% per jam saat operasi aktif | Battery profiling |
| 6 | **Print success rate** | ≥ 99% saat printer Bluetooth paired & kertas tersedia | Error tracking |

---

## 2. User Experience & Functionality

### 2.1 User Personas

Sama dengan PRD-04 Desktop Runner:

#### P3 — Booth Operator
- Pair Mobile Runner ke akun owner via 6-digit code
- Konfigurasi device (kamera, printer Bluetooth, metode pembayaran)
- Konfirmasi pembayaran CASH/STATIC_QRIS manual
- Troubleshoot hardware (printer, kamera)

#### P4 — Customer / Pengunjung
- Pilih template → foto ("coba dulu") → preview → konfigurasi cetak/digital → bayar
- Terima cetakan dan/atau scan QR untuk digital copy

### 2.2 Feature Index

| Feature | ID | Priority | Deskripsi |
|---------|------|----------|-----------|
| Device Pairing | FEAT-MR-01 | P0 | Pair via 6-digit code → device_token |
| Startup Sequence | FEAT-MR-02 | P0 | Status check + template sync |
| Screensaver | FEAT-MR-03 | P0 | Idle attract screen (image/video) |
| Template Selection | FEAT-MR-04 | P0 | Grid template browsing |
| Photo Session | FEAT-MR-05 | P0 | Camera capture per photo_slot |
| Preview & Retake | FEAT-MR-06 | P0 | Composite preview + unlimited retake |
| Confirmation & Payment | FEAT-MR-07 | P0 | Qty, digital copy, CASH/QRIS/PG payment |
| Processing & Output | FEAT-MR-08 | P0 | Print (Bluetooth) + digital copy upload |
| Thank You & Loop | FEAT-MR-09 | P0 | QR download + session loop |
| Settings (Operator) | FEAT-MR-10 | P0 | Hidden access device configuration |
| Android Kiosk Mode | FEAT-MR-11 | P0 | Lock mode — prevent customer exit |

### 2.3 Non-Goals

| # | Non-Goal | Alasan |
|---|----------|--------|
| NG-01 | iOS support | Android-only untuk MVP |
| NG-02 | Login user (email/password) | Auth via device_token |
| NG-03 | WebSocket / push notification | On-demand via button |
| NG-04 | Auto-polling PG | Customer trigger manual |
| NG-05 | Multi-operator PIN | Single operator per device |
| NG-06 | Analytics di app | Data analytics di Owner Dashboard |
| NG-07 | Server-side composite | Composite di device |
| NG-08 | Webhook PG receiver | Polling-based |
| NG-09 | Refund otomatis | Manual di luar sistem |
| NG-10 | Template versioning | Full dump sync |
| NG-11 | Multi-language | Bahasa Indonesia only |
| NG-12 | Play Store distribution | Sideload APK (kiosk mode) |

---

## 3. Target Device Requirements

### 3.1 Minimum Specifications

| Aspek | Minimum | Recommended |
|-------|---------|-------------|
| **OS** | Android 10 (API 29) | Android 12+ (API 31+) |
| **RAM** | 4 GB | 6 GB+ |
| **Storage** | 4 GB free | 8 GB+ free |
| **Kamera** | 8 MP rear | 13 MP+ rear dengan autofocus |
| **Display** | 8" (tablet) | 10"+ tablet |
| **Bluetooth** | 4.0+ | 5.0+ (untuk printer thermal) |
| **WiFi** | 802.11n | 802.11ac |
| **Battery** | 5000 mAh | 7000 mAh+ / always plugged in |

### 3.2 Tested Devices

| Device | Display | Status |
|--------|---------|--------|
| Samsung Galaxy Tab A8 | 10.5" | Primary test device |
| Xiaomi Pad 6 | 11" | Secondary |
| Samsung Galaxy Tab S6 Lite | 10.4" | Secondary |

> **Catatan:** Aplikasi di-sideload (APK), bukan melalui Play Store. Device dikonfigurasi dalam kiosk/lock mode oleh operator.

---

## 4. Technical Specifications

### 4.1 Architecture Overview

```
┌──────────────────────────────────────────────────────┐
│              Mobile Runner (Flutter/Android)         │
│                                                      │
│  ┌──────────────────────────────────────────────┐    │
│  │                Flutter App                   │    │
│  │                                              │    │
│  │  ┌────────────┐  ┌────────────────────────┐  │    │
│  │  │   UI Layer │  │    State Management    │  │    │
│  │  │   Widgets  │  │    flutter_bloc (Cubit)│  │    │
│  │  │   Screens  │  │    + GoRouter          │  │    │
│  │  └────────────┘  └────────────────────────┘  │    │
│  │                                              │    │
│  │  ┌────────────┐  ┌────────────────────────┐  │    │
│  │  │  Services  │  │    Local Storage       │  │    │
│  │  │  API Client│  │    flutter_secure_stor.│  │    │
│  │  │  Camera    │  │    shared_preferences  │  │    │
│  │  │  Printer   │  │    Hive / SQLite       │  │    │
│  │  └────────────┘  └────────────────────────┘  │    │
│  └──────────────────────────────────────────────┘    │
│                                                      │
│  ┌──────────────────────────────────────────────┐    │
│  │              Native Platform Layer           │    │
│  │  Camera Plugin · Bluetooth · Kiosk Mode      │    │
│  │  File System · Secure Storage                │    │
│  └──────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────┘
                         │
                         │ REST API (HTTPS)
                         │ Authorization: Bearer {device_token}
                         ▼
             ┌────────────────────────────────┐
             │  memoir. Backend API           │
             │  (Fastify + Node.js)           │
             ├────────────────────────────────┤
             │  POST /kiosk/pair              │
             │  GET  /kiosk/me                │
             │  GET  /kiosk/templates         │
             │  POST /kiosk/transactions      │
             │  POST .../confirm-cash         │
             │  POST .../check-payment        │
             │  POST /kiosk/sessions          │
             └────────────────────────────────┘
```

### 4.2 Tech Stack

| Layer | Technology | Catatan |
|-------|-----------|---------|
| Framework | **Flutter** | Cross-platform, tapi fokus Android saja untuk MVP |
| Language | **Dart** | Null safety enabled |
| State Management | **flutter_bloc** (Cubit) | Predictable state, mirip konsep XState di Desktop |
| Navigation | **GoRouter** | Declarative routing + deep link support |
| HTTP Client | **Dio** | Interceptors, retry, timeout |
| Local Storage (config) | **shared_preferences** | Key-value simple (settings, timers) |
| Local Storage (data) | **Hive** | NoSQL box untuk template cache |
| Secure Storage | **flutter_secure_storage** | Encrypted `deviceToken` (Android Keystore) |
| Camera | **camera** plugin | Native camera access |
| Image Processing | **image** package + Isolate | Composite rendering di background Isolate |
| Printer | **esc_pos_bluetooth** / **blue_thermal_printer** | Bluetooth ESC/POS thermal printer |
| QR Code | **qr_flutter** | Generate QR code widget |
| Video Player | **video_player** | Screensaver video playback |
| File Picker | **file_picker** | Output folder, QR image |
| Kiosk Mode | **flutter_kiosk_mode** / custom `DevicePolicyManager` | Lock task mode (Android) |
| Package Manager | **pub** (pubspec.yaml) | Dart package manager |

### 4.3 Project Structure

```
mobile_runner/
├── pubspec.yaml
├── analysis_options.yaml
├── android/
│   └── app/
│       └── src/main/
│           └── AndroidManifest.xml   # Permissions, kiosk mode config
│
├── lib/
│   ├── main.dart                     # App entry, DI setup
│   ├── app.dart                      # MaterialApp + GoRouter
│   │
│   ├── config/
│   │   ├── routes.dart               # GoRouter route definitions
│   │   ├── theme.dart                # App theme (colors, typography)
│   │   └── constants.dart            # Timer defaults, API URL
│   │
│   ├── models/
│   │   ├── kiosk_config.dart         # KioskConfig model
│   │   ├── template.dart             # Template + TemplateElement
│   │   ├── transaction.dart          # Transaction model
│   │   └── session.dart              # Photo session model
│   │
│   ├── services/
│   │   ├── api_service.dart          # Dio HTTP client wrapper
│   │   ├── storage_service.dart      # Secure storage + shared_preferences
│   │   ├── template_cache_service.dart # Hive-based template cache
│   │   ├── camera_service.dart       # Camera plugin wrapper
│   │   ├── printer_service.dart      # Bluetooth thermal printer
│   │   ├── composite_service.dart    # Image composite (Isolate)
│   │   └── kiosk_mode_service.dart   # Android kiosk lock mode
│   │
│   ├── blocs/
│   │   ├── app/
│   │   │   ├── app_cubit.dart        # App lifecycle (startup, pairing)
│   │   │   └── app_state.dart
│   │   ├── session/
│   │   │   ├── session_cubit.dart    # Photo session state
│   │   │   └── session_state.dart
│   │   └── payment/
│   │       ├── payment_cubit.dart    # Payment flow state
│   │       └── payment_state.dart
│   │
│   ├── screens/
│   │   ├── pairing_screen.dart
│   │   ├── screensaver_screen.dart
│   │   ├── select_template_screen.dart
│   │   ├── photo_session_screen.dart
│   │   ├── photo_preview_screen.dart
│   │   ├── confirmation_screen.dart
│   │   ├── processing_screen.dart
│   │   ├── thank_you_screen.dart
│   │   ├── settings_screen.dart
│   │   └── lock_screen.dart          # Expired / inactive
│   │
│   ├── widgets/
│   │   ├── countdown_timer.dart
│   │   ├── price_summary.dart
│   │   ├── template_grid.dart
│   │   ├── camera_preview.dart
│   │   └── status_badge.dart
│   │
│   └── utils/
│       ├── price_calculator.dart     # Price resolution + formula
│       └── formatters.dart           # Rupiah, date formatters
│
└── test/
    ├── unit/
    │   └── price_calculator_test.dart
    └── widget/
```

### 4.4 Local Storage

| Storage | Key/Box | Deskripsi |
|---------|---------|-----------|
| **flutter_secure_storage** | `deviceToken` | JWT encrypted via Android Keystore |
| **shared_preferences** | `payment.activeMode` | CASH / STATIC_QRIS / PG |
| **shared_preferences** | `payment.staticConfig.qrImagePath` | Path QR statis |
| **shared_preferences** | `cameraConfig.cameraId` | Selected camera ID |
| **shared_preferences** | `cameraConfig.isMirrored` | Mirror toggle |
| **shared_preferences** | `printerConfig.address` | Bluetooth MAC address printer |
| **shared_preferences** | `printerConfig.name` | Bluetooth device name |
| **shared_preferences** | `appearance.screensaver.*` | isEnabled, assetPath, mediaType |
| **shared_preferences** | `timers.*` | retakeCountdown, paymentTimeout, thankYouDuration, idleTimeout |
| **shared_preferences** | `appSettings.outputFolderPath` | Path output folder |
| **Hive** | `kioskConfigBox` | Cached KioskConfig (id, name, harga) |
| **Hive** | `templatesBox` | Cached templates + elements + local background path |

> **Harga tidak di-cache independen.** `kioskConfig` di-overwrite dari response `/kiosk/me` saat startup.

---

## 5. Application Flow

### 5.1 Flow Identik dengan PRD-04

Flow utama **100% identik** dengan Desktop Runner (PRD-04):

```
[App Launch]
    │
    ▼
deviceToken ada?
    ├── TIDAK ──► [Pairing Screen]
    └── YA ──► Startup Sequence
                    │
              GET /kiosk/me → status check
                    │
              Sync Templates → GET /kiosk/templates
                    │
              [SCREENSAVER] ──(tap)──► [SELECT TEMPLATE]
                    │
              [PHOTO SESSION] → per photo_slot capture
                    │
              [PREVIEW] → retake / lanjut
                    │
              [CONFIRMATION] → qty + digital + payment
                    │
              [PROCESSING] → print + upload
                    │
              [THANK YOU] → QR + loop
```

Untuk detail lengkap setiap screen dan flow, lihat **PRD-04 Section 4 & 5**. Dokumen ini hanya mendokumentasikan **perbedaan** dari Desktop Runner.

### 5.2 State Management (flutter_bloc)

```dart
// AppCubit states (mirip XState di Desktop)
sealed class AppState {}
class AppInitial extends AppState {}
class AppStartup extends AppState {}
class AppPairing extends AppState {}
class AppLocked extends AppState { final String reason; }
class AppReady extends AppState {}  // → GoRouter handles screen routing

// SessionCubit states
sealed class SessionState {}
class SessionIdle extends SessionState {}
class SessionTemplateSelected extends SessionState {}
class SessionCapturing extends SessionState { final int currentSlot; }
class SessionPreviewing extends SessionState {}
class SessionConfirming extends SessionState {}
class SessionProcessing extends SessionState {}
class SessionComplete extends SessionState {}
```

> **Perbedaan dari Desktop:** Desktop menggunakan XState (FSM eksplisit, no routing). Mobile menggunakan flutter_bloc Cubit + GoRouter — lebih idiomatic Flutter. Logic flow dan transisi state tetap identik.

---

## 6. Features — Perbedaan dari Desktop Runner

> [!NOTE]
> Semua fitur (FEAT-MR-01 sampai FEAT-MR-10) mengikuti spesifikasi identik dengan PRD-04 (FEAT-KR-01 sampai FEAT-KR-10). Section ini hanya mendokumentasikan **perbedaan implementasi** karena platform berbeda.

### 6.1 Device Pairing (FEAT-MR-01) — Sama

- Flow identik: 6-digit code → `POST /kiosk/pair` → simpan `deviceToken`
- **Perbedaan:** Token disimpan di `flutter_secure_storage` (Android Keystore) bukan `electron-store` + `safeStorage`

### 6.2 Startup Sequence (FEAT-MR-02) — Sama

- Status check + template sync identik
- **Perbedaan:** Template background cached di app-specific directory (`getApplicationDocumentsDirectory()`)

### 6.3 Screensaver (FEAT-MR-03) — Adaptasi

- Screensaver identik (image/video)
- **Perbedaan:** Video playback via `video_player` Flutter plugin (bukan HTML `<video>` di Electron renderer)
- **Perbedaan:** Keep screen awake via `wakelock_plus` plugin

### 6.4 Photo Session (FEAT-MR-05) — Adaptasi

- Flow identik: per photo_slot, countdown, capture
- **Perbedaan:**
  - Kamera via `camera` Flutter plugin (bukan `getUserMedia`)
  - Rear camera default (bukan webcam)
  - Auto-focus support via plugin API
  - Preview: `CameraPreview` widget
  - Capture: `takePicture()` → `XFile` → local path

### 6.5 Preview & Composite (FEAT-MR-06) — Adaptasi

- Composite rules identik (4 tipe elemen, z-order by `sequence`)
- **Perbedaan:**
  - Composite rendering via Dart `image` package di **background Isolate** (bukan Canvas API / worker thread)
  - Alternative: `CustomPainter` + Canvas API untuk preview, lalu save via `toImage()`
  - Performance target sama: < 3 detik untuk ≤ 20 elemen

### 6.6 Confirmation & Payment (FEAT-MR-07) — Sama

- Flow dan kalkulasi harga 100% identik
- Price resolution, payment modes (CASH/STATIC_QRIS/PG) — sama

### 6.7 Processing & Output (FEAT-MR-08) — Adaptasi

- **Cetak: Bluetooth** (bukan USB)
  - Discover paired Bluetooth printer → connect → send ESC/POS commands
  - Library: `esc_pos_bluetooth` atau `blue_thermal_printer`
  - Operator pair printer via Android Bluetooth settings terlebih dahulu
- **Digital copy upload:** Identik — `POST /kiosk/sessions` multipart

### 6.8 Settings (FEAT-MR-10) — Adaptasi

- Hidden access identik (5x tap, < 2 detik, pojok kiri bawah)
- **Perbedaan konfigurasi:**

| Setting | Desktop (PRD-04) | Mobile (PRD-05) |
|---------|-------------------|------------------|
| Kamera | Dropdown device webcam | Front/rear camera selector |
| Printer | VID/PID hex (USB) | Bluetooth device picker (scan & pair) |
| Output folder | Folder picker dialog | Android storage path (internal/external) |
| Screensaver | Sama | Sama + wakelock toggle |

### 6.9 Android Kiosk Mode (FEAT-MR-11) — Mobile Only

Feature khusus mobile yang tidak ada di Desktop Runner:

- **Lock Task Mode (COSU — Corporate-Owned, Single-Use):**
  - App di-pin sebagai kiosk → customer tidak bisa akses home, recent apps, notification bar
  - Implementasi via `DevicePolicyManager` (DPC) atau `flutter_kiosk_mode` plugin
  - Operator set device sebagai Device Owner via ADB saat setup awal
  
- **Behaviors saat Kiosk Mode aktif:**
  - Navigation bar hidden
  - Status bar hidden
  - Back button disabled
  - Home button disabled
  - Recent apps disabled
  - Notification shade blocked

- **Exit kiosk mode:** Hanya dari Settings (operator) → tombol "Exit Kiosk Mode" → memerlukan device admin access

---

## 7. API Integration

### 7.1 Endpoints — Identik dengan PRD-04

Menggunakan endpoint yang **100% sama** dengan Desktop Runner. Lihat PRD-04 Section 6 untuk detail.

> [!NOTE]
> **📋 Dokumentasi API terpisah belum dibuat.** Endpoint mapping berdasarkan PRD-01 dan akan di-update seiring backend selesai.

| Endpoint | Method | Deskripsi |
|----------|--------|-----------|
| `/kiosk/pair` | POST | Tukarkan `pairingCode` → `deviceToken` |
| `/kiosk/me` | GET | Config kiosk + subscription status |
| `/kiosk/templates` | GET | Semua template aktif + elements |
| `/kiosk/transactions` | POST | Buat transaksi baru |
| `/kiosk/transactions/:id/confirm-cash` | POST | Konfirmasi CASH/QRIS |
| `/kiosk/transactions/:id/check-payment` | POST | Cek status PG |
| `/kiosk/sessions` | POST | Upload digital copy (multipart) |

### 7.2 API Client (Dio)

```dart
class ApiService {
  late final Dio _dio;

  ApiService({required String baseUrl, required StorageService storage}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 30),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.getDeviceToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await storage.clearDeviceToken();
          // Trigger pairing screen via AppCubit
        }
        handler.next(error);
      },
    ));
  }
}
```

---

## 8. Template Element Model

**Identik dengan PRD-04 Section 7.** Lihat PRD-04 untuk detail lengkap.

Ringkasan: 4 tipe elemen polymorphic (`photo_slot`, `image`, `text`, `shape`) dengan atribut spasial (`x`, `y`, `width`, `height`, `rotation`, `opacity`, `sequence`) dan `properties` JSONB per tipe.

**Perbedaan rendering:** Composite dilakukan di Dart `Isolate` menggunakan `image` package atau `Canvas` API, bukan Canvas API browser / node-canvas di Electron.

---

## 9. UI/UX Guidelines

### 9.1 Design Principles

| Principle | Detail |
|-----------|--------|
| **Touch-first** | Minimum 48×48dp touch target (Material Design guideline) |
| **Fullscreen immersive** | Hide status bar + navigation bar |
| **Large typography** | Minimum 16sp body, 24sp+ headings |
| **Responsive tablet** | Optimized untuk 10" tablet landscape |
| **Material Design 3** | Mengikuti MD3 guidelines untuk components |
| **Bahasa Indonesia** | Seluruh UI text |

### 9.2 Screen Dimensions

- Target: Tablet 10" (1920×1200 / 2560×1600)
- Orientation: **Landscape locked**
- Density-independent: gunakan `dp` / `sp` bukan pixel
- Safe area: account for camera notch / rounded corners

### 9.3 Theming

```dart
// theme.dart
ThemeData kioskTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Color(0xFF1A1A2E), // memoir. brand
    brightness: Brightness.dark,  // default dark mode
  ),
  textTheme: GoogleFonts.interTextTheme(),
);
```

---

## 10. Security & Privacy

| Area | Implementasi |
|------|-------------|
| **Device Token** | `flutter_secure_storage` → Android Keystore encryption |
| **Token format** | JWT `{ kioskId, ownerId }`, long-lived |
| **Token invalidation** | Server 401 → clear token → Pairing screen |
| **API authorization** | `verifyDeviceToken` middleware backend |
| **Data isolation** | Server-side: scoped ke owner yang ter-pair |
| **Kiosk lock mode** | `DevicePolicyManager` — prevent app exit |
| **File storage** | Composite di app-specific directory; digital copy di Supabase |
| **No root required** | App berjalan normal tanpa root access |
| **Price validation** | Backend re-kalkulasi; mismatch → 400 |
| **Permissions** | Camera, Bluetooth, Storage — request saat runtime |

---

## 11. Business Rules & Edge Cases

### 11.1 Identik dengan PRD-04

Semua business rules dari PRD-04 Section 10 berlaku:
- Template sync (full dump, `updatedAt` signal, min 1 photo_slot)
- Pembayaran (price validation, idempotency, foto sebelum bayar)
- Subscription lockout (lazy status, check saat startup saja)
- CaptureOrder dari properties JSONB

### 11.2 Mobile-Specific Edge Cases

| Situasi | Handling |
|---------|---------|
| **Battery rendah (< 15%)** | Warning banner di layar. Jika < 5%: tampilkan Lock Screen "Charge device" |
| **Bluetooth printer disconnect** | Retry connect 3x. Jika gagal → opsi skip print / retry |
| **Camera permission denied** | Tampilkan instruksi buka Settings Android → grant permission |
| **Storage penuh** | Warning saat simpan composite. Operator bersihkan storage |
| **App killed by OS (low memory)** | Restart dari awal, re-check pairing. Sesi yang sedang berjalan hilang |
| **Kiosk mode bypass attempt** | Lock Task Mode prevent — home/recent/notification blocked |
| **Screen rotation** | Locked landscape — tidak berubah |
| **Notifikasi pop-up** | Blocked saat kiosk mode aktif |
| **Internet putus saat PG** | Sama dengan Desktop: pesan error, switch ke CASH |
| **Device token reset oleh owner** | Sama: 401 → hapus token → Pairing |

---

## 12. Performance & Non-Functional Requirements

| Aspek | Requirement |
|-------|-------------|
| **App launch** | Cold start < 5 detik; warm start < 2 detik |
| **Startup (termasuk sync)** | < 30 detik |
| **UI response** | 60 FPS, tidak jank/freeze |
| **Composite rendering** | < 3 detik (≤ 20 elemen) di background Isolate |
| **Upload digital copy** | < 10 detik untuk ≤ 10MB |
| **Print initiation** | < 3 detik setelah Bluetooth connect |
| **Battery** | < 15% per jam saat operasi aktif |
| **Memory** | < 300MB RAM usage |
| **Offline** | CASH/QRIS offline setelah startup. PG butuh koneksi |
| **Stability** | Tidak crash setelah 8 jam operasi kontinu |
| **Min Android** | Android 10 (API 29) |
| **Min Flutter** | Flutter 3.x (latest stable) |

---

## 13. Testing Strategy

| Layer | Target | Approach |
|-------|--------|----------|
| Unit | Price calculator, formatters, models | `flutter test` |
| Bloc | State transitions, guards | `bloc_test` package |
| Widget | Screen rendering, user interaction | `flutter test` + widget tests |
| Integration | API service, storage service | Mock API tests |
| Composite | 4 element types, z-order | Isolate unit test (image output) |
| Hardware | Printer, camera | Manual testing pada device fisik |
| E2E | Full session flow | Manual testing |
| Battery | Consumption profiling | Android Profiler / Battery Historian |

---

## 14. App Distribution

| Aspek | Detail |
|-------|--------|
| Build | `flutter build apk --release` |
| Distribution | **Sideload APK** — bukan Play Store |
| Versioning | SemVer; ditampilkan di Settings |
| Update | Manual: download APK baru → install over existing |
| Signing | Custom keystore (bukan Play App Signing) |
| Device setup | ADB command untuk set Device Owner (kiosk mode) |
| Kiosk mode setup | One-time: `adb shell dpm set-device-owner ...` |

> **Catatan:** Distribusi via Play Store adalah non-goal untuk MVP. App di-sideload ke device booth yang dikontrol operator.

---

## 15. Perbedaan dari Desktop Runner (PRD-04)

| Aspek | Desktop Runner (PRD-04) | Mobile Runner (PRD-05) |
|-------|------------------------|------------------------|
| **Platform** | Windows / Linux / macOS | Android (tablet) |
| **Framework** | Electron + electron-vite | Flutter |
| **UI** | React 19 + Tailwind CSS | Flutter Widgets + Material 3 |
| **State** | XState + Zustand | flutter_bloc (Cubit) + GoRouter |
| **Camera** | `getUserMedia` (webcam) | `camera` plugin (rear camera) |
| **Printer** | USB (ESC/POS via Node.js) | Bluetooth (ESC/POS via Flutter plugin) |
| **Token storage** | electron-store + safeStorage | flutter_secure_storage (Keystore) |
| **Template cache** | electron-store (JSON) | Hive (NoSQL box) |
| **Composite** | node-canvas / Sharp (worker) | Dart `image` package (Isolate) |
| **Kiosk lock** | Electron fullscreen (soft) | Android Lock Task Mode (hard) |
| **App size** | ~150MB (Electron bundle) | ~30-50MB (Flutter APK) |
| **Distribution** | Installer (NSIS/AppImage) | Sideload APK |
| **Package manager** | pnpm | pub (pubspec.yaml) |
| **Routing** | None (XState manages screens) | GoRouter (declarative) |
| **HTTP client** | fetch() wrapper | Dio (interceptors, retry) |
| **Flow** | Identik | Identik |
| **API endpoints** | Identik | Identik |
| **Business rules** | Identik | Identik |

---

## 16. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigasi |
|------|-----------|--------|----------|
| Android fragmentation (banyak versi/vendor) | HIGH | MEDIUM | Target Android 10+; test pada 3+ device populer |
| Bluetooth printer compatibility | MEDIUM | MEDIUM | ESC/POS standard; test 3+ model printer |
| Composite performance di low-end tablet | MEDIUM | MEDIUM | Isolate rendering; optimize image size |
| Battery drain saat operasi all-day | MEDIUM | LOW | Wakelock + power management; recommend plugged in |
| Kiosk mode bypass | LOW | HIGH | Device Owner via ADB; Lock Task Mode native |
| Camera quality inconsistency | MEDIUM | LOW | Recommend minimum 8MP; auto-focus required |
| App killed by OS (low memory) | LOW | MEDIUM | Keep memory < 300MB; handle restart gracefully |
| Backend API belum ready | MEDIUM | HIGH | Mock API; backend PRD sudah final |

---

## 17. Open Issues

| ID | Issue | Status |
|----|-------|--------|
| OI-01 | Photo slot capture order | ✅ **Resolved:** `captureOrder` di properties JSONB |
| OI-02 | Payment Gateway | ✅ **Resolved:** Xendit |

Semua open issues telah diputuskan — tidak ada blocker.

---

## 18. Roadmap

### MVP (v1.0) — Core Mobile Kiosk
- Pairing, startup, template sync (full dump)
- Flow foto-dulu-bayar-kemudian (screensaver → template → foto → preview/retake → konfirmasi+bayar → processing → thank you)
- Pembayaran (CASH/STATIC_QRIS/PG)
- Bluetooth thermal printer
- Digital copy upload
- Settings (hidden), screensaver, kiosk lock mode

### v1.1 — Polish & Improvements
- Delta sync template
- Better camera controls (flash, exposure, focus area)
- Print queue / retry management
- Battery optimization v2

### v2.0 — Advanced Features
- Play Store distribution (with kiosk mode setup wizard)
- Camera filters/effects
- Auto-update (in-app update API)
- Analytics dashboard integration
- iOS support (iPad)

---

## 19. Changelog

| Tanggal | Versi | Perubahan |
|---------|-------|-----------|
| 2026-03-05 | 0.1 | Initial skeleton created |
| 2026-03-06 | 1.0 | Full draft — Flutter/Android adaptation dari PRD-04 Desktop Runner. Sama: flow (foto dulu bayar kemudian), API endpoints, business rules, template model. Beda: Flutter + flutter_bloc, Bluetooth printer, camera plugin, Android Kiosk Mode, Hive cache, flutter_secure_storage. OI-01 & OI-02 resolved. |

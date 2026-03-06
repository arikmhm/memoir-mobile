# PRD-04: Desktop App Runner (Electron)

> **Versi:** 1.0
> **Tanggal:** 6 Maret 2026
> **Status:** Draft — For Review
> **Audiens:** Internal dev team & AI coding agents
> **Parent:** [PRD-00-master.md](./PRD-00-master.md) (Platform Overview)
> **Backend:** [PRD-01-backend-api.md](./PRD-01-backend-api.md) (Backend API)

---

## 1. Executive Summary

### 1.1 Problem Statement

Operator photobooth membutuhkan aplikasi desktop yang berjalan di perangkat booth fisik (PC/laptop) untuk menjalankan sesi foto, mencetak receipt thermal, dan memproses pembayaran tanpa perlu keahlian teknis. Tidak ada solusi kiosk out-of-the-box yang terintegrasi dengan sistem manajemen template, subscription, dan wallet milik platform memoir.

### 1.2 Proposed Solution

**memoir. Kiosk Runner** adalah aplikasi desktop berbasis **Electron** (dibangun dengan **electron-vite**) yang menjadi satu-satunya surface interaksi langsung dengan customer di lokasi booth. Aplikasi terhubung ke backend memoir. via REST API menggunakan `device_token` permanen (JWT) yang diperoleh melalui proses pairing 6-digit code.

Kiosk Runner menangani seluruh lifecycle sesi foto dengan flow **"foto dulu, bayar kemudian"**:

1. Pemilihan template → sesi foto → preview & retake
2. Konfigurasi cetak/digital → pembayaran (CASH/STATIC_QRIS/PG)
3. Composite rendering 4 tipe elemen → pencetakan thermal → upload digital copy

**Tidak ada login user.** Autentikasi dilakukan via `device_token` yang tersimpan terenkripsi di `electron-store` menggunakan `safeStorage`.

### 1.3 Success Criteria

| # | KPI | Target | Cara Ukur |
|---|-----|--------|-----------|
| 1 | **Time-to-first-session** | < 60 detik dari startup sampai sesi foto pertama siap | Manual testing + stopwatch |
| 2 | **Composite render time** | < 3 detik untuk template ≤ 20 elemen | Performance profiling di main process |
| 3 | **Template sync time** | < 5 detik untuk ≤ 50 template | Network timing + local cache delta |
| 4 | **Offline CASH/QRIS** | 100% bisa berjalan tanpa internet setelah startup | Integration test |
| 5 | **Print success rate** | ≥ 99% saat printer terkoneksi + kertas tersedia | Error tracking per sesi cetak |

---

## 2. User Experience & Functionality

### 2.1 User Personas

#### P3 — Booth Operator

Orang yang menjalankan booth fisik sehari-hari. Tidak memiliki akses ke dashboard web. Tanggung jawab:

- Pair Kiosk Runner ke akun owner menggunakan 6-digit pairing code
- Konfigurasi device (kamera, printer, metode pembayaran)
- Konfirmasi pembayaran CASH/STATIC_QRIS secara manual
- Troubleshoot masalah hardware (printer, kamera)
- Trigger manual sync template jika diperlukan

#### P4 — Customer / Pengunjung

Pengguna akhir di lokasi booth. Tidak berinteraksi langsung dengan API:

- Pilih template desain foto
- Berpose untuk foto ("coba dulu" sebelum bayar)
- Lihat preview hasil foto & retake jika perlu
- Konfigurasi jumlah cetak dan opsi digital copy
- Lakukan pembayaran
- Terima cetakan dan/atau scan QR untuk digital copy

### 2.2 Feature Index

| Feature | ID | Priority | Deskripsi |
|---------|------|----------|-----------|
| Device Pairing | FEAT-KR-01 | P0 | Pair via 6-digit code → device_token |
| Startup Sequence | FEAT-KR-02 | P0 | Status check + template sync |
| Screensaver | FEAT-KR-03 | P0 | Idle attract screen (image/video) |
| Template Selection | FEAT-KR-04 | P0 | Grid template browsing |
| Photo Session | FEAT-KR-05 | P0 | Camera capture per photo_slot |
| Preview & Retake | FEAT-KR-06 | P0 | Composite preview + unlimited retake |
| Confirmation & Payment | FEAT-KR-07 | P0 | Qty, digital copy, CASH/QRIS/PG payment |
| Processing & Output | FEAT-KR-08 | P0 | Print + digital copy upload |
| Thank You & Loop | FEAT-KR-09 | P0 | QR download + session loop |
| Settings (Operator) | FEAT-KR-10 | P0 | Hidden access device configuration |

### 2.3 Non-Goals

| # | Non-Goal | Alasan |
|---|----------|--------|
| NG-01 | Login user (email/password) di kiosk | Auth via device_token, bukan credential |
| NG-02 | WebSocket / push notification | MVP: on-demand via button |
| NG-03 | Auto-polling status pembayaran PG | Customer/operator trigger manual |
| NG-04 | Customer-facing download endpoint | Customer scan QR → direct Supabase URL |
| NG-05 | Multi-operator dengan PIN berbeda | Single operator per kiosk |
| NG-06 | Analitik / dashboard di kiosk | Data analytics di Owner Dashboard |
| NG-07 | Image processing server-side | Composite dilakukan di Electron |
| NG-08 | Webhook receiver dari PG | Polling-based via button check |
| NG-09 | Refund / chargeback otomatis | Manual di luar sistem |
| NG-10 | Template versioning / rollback | Full dump sync, no delta/history |
| NG-11 | Multi-language UI | Bahasa Indonesia only |

---

## 3. Technical Specifications

### 3.1 Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                  Kiosk Runner (Electron)                 │
│              Built with electron-vite + React            │
│                                                          │
│  ┌───────────────────┐    ┌───────────────────────────┐  │
│  │  Renderer Process │    │      Main Process         │  │
│  │                   │    │                           │  │
│  │  React + Tailwind │◄──►│  electron-store           │  │
│  │  XState (flow)    │ IPC│  (safeStorage)            │  │
│  │  Camera           │    │                           │  │
│  │  (getUserMedia)   │    │                           │  │
│  │  Template         │    │  ┌──────────────────────┐ │  │
│  │  Preview/Render   │    │  │  Composite Worker    │ │  │
│  │                   │    │  │  (4-type renderer)   │ │  │
│  └───────────────────┘    │  └──────────────────────┘ │  │
│                           │                           │  │
│                           │  ┌──────────────────────┐ │  │
│                           │  │  USB Printer Driver  │ │  │
│                           │  │  (ESC/POS)           │ │  │
│                           │  └──────────────────────┘ │  │
│                           └───────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
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

### 3.2 Tech Stack

| Layer | Technology | Catatan |
|-------|-----------|---------|
| Runtime | **Electron** | Desktop app, fullscreen kiosk mode |
| Build Tool | **electron-vite** (`@alex8088/electron-vite`) | Unified config main/preload/renderer, HMR |
| Language | **TypeScript** | Strict mode |
| UI Framework | **React 19** | Renderer process |
| Styling | **Tailwind CSS 4** + custom components | Fullscreen kiosk, no component library |
| Flow State Machine | **XState 5** | Navigasi antar layar, timeout, transisi strict |
| Data Store | **Zustand** | Template cache, config, session data |
| Persistent Storage | **electron-store** | JSON config tersimpan di device |
| Enkripsi Token | Electron `safeStorage` | OS-level encryption |
| Kamera | `getUserMedia` Web API | Renderer process |
| Printer | Node.js USB library (ESC/POS) | Main process |
| Composite | Canvas API / Sharp / node-canvas | Main process atau worker thread |
| HTTP Client | Native `fetch()` | Semua request ke backend |
| Routing | ❌ Tidak ada (XState manage layar) | Kiosk tidak butuh URL-based routing |
| Package Manager | pnpm | Konsisten dengan backend |

#### Mengapa XState + Zustand (Split Concern)

```
XState  → "Di layar mana saya sekarang? Transisi apa yang valid? Kapan timeout?"
Zustand → "Data apa yang saya punya? Template, config, foto session saat ini?"
```

- **XState** mengelola finite state machine flow kiosk: screensaver → template → foto → preview → bayar → thank you. Setiap state punya `entry`/`exit` actions, `after` delays (timeout), dan guarded transitions
- **Zustand** menyimpan data: `kioskConfig`, `templates`, `capturedPhotos[]`, `currentTransaction`
- **Tidak perlu React Router** — flow linear dan strict, XState enforce valid transitions

### 3.3 Project Structure

```
kiosk-runner/
├── electron.vite.config.ts          # Unified config (main + preload + renderer)
├── package.json
├── tsconfig.json
├── tsconfig.node.json
├── tsconfig.web.json
│
├── src/
│   ├── main/                        # Electron Main Process
│   │   ├── index.ts                 # App entry, BrowserWindow, IPC handlers
│   │   ├── services/
│   │   │   ├── printer.service.ts   # USB thermal printer (ESC/POS)
│   │   │   ├── composite.service.ts # Photo composite rendering (worker)
│   │   │   ├── storage.service.ts   # electron-store + safeStorage
│   │   │   └── api.service.ts       # Backend API client
│   │   └── ipc/
│   │       └── handlers.ts          # IPC handler registrations
│   │
│   ├── preload/                     # Preload Scripts (contextBridge)
│   │   └── index.ts                 # Expose safe APIs to renderer
│   │
│   └── renderer/                    # React UI (Renderer Process)
│       ├── index.html
│       └── src/
│           ├── App.tsx              # XState machine consumer
│           ├── main.tsx             # React entry
│           ├── machines/
│           │   └── kiosk.machine.ts # XState flow state machine
│           ├── pages/
│           │   ├── Screensaver.tsx
│           │   ├── Pairing.tsx
│           │   ├── SelectTemplate.tsx
│           │   ├── PhotoSession.tsx
│           │   ├── PhotoPreview.tsx  # Preview + retake
│           │   ├── Confirmation.tsx  # qty + digital copy + payment
│           │   ├── Processing.tsx    # print + upload
│           │   ├── ThankYou.tsx      # + QR jika digital copy
│           │   ├── Settings.tsx      # operator only (hidden access)
│           │   └── LockScreen.tsx    # expired / inactive / pairing
│           ├── components/
│           ├── hooks/
│           ├── stores/              # Zustand stores
│           │   ├── kiosk.store.ts   # Config, templates cache
│           │   └── session.store.ts # Current session data
│           ├── lib/
│           │   ├── api.ts           # IPC bridge to main process API
│           │   ├── price.ts         # Price calculation logic
│           │   └── camera.ts        # getUserMedia wrapper
│           └── assets/
│
├── resources/                       # App icons, installer assets
└── build/                           # electron-builder config
```

### 3.4 Penyimpanan Lokal (electron-store)

| Key | Tipe | Deskripsi |
|-----|------|-----------|
| `deviceToken` | string (encrypted) | JWT untuk autentikasi ke backend |
| `kioskConfig` | object | Cache config kiosk (id, name, ownerId, harga) — di-refresh saat startup |
| `printerConfig` | object | `{ vid: string, pid: string }` — VID/PID USB printer thermal |
| `cameraConfig` | object | `{ deviceId: string, isMirrored: boolean }` |
| `templates` | array | Cache template + semua `template_elements` + path file background lokal |
| `appSettings.outputFolderPath` | string | Path folder penyimpanan file sesi foto |
| `payment.activeMode` | enum | `CASH` / `STATIC_QRIS` / `PG` |
| `payment.staticConfig.qrImagePath` | string | Path gambar QR statis (jika STATIC_QRIS) |
| `appearance.screensaver` | object | `{ isEnabled, assetPath, mediaType }` |
| `timers.retakeCountdown` | number | Durasi countdown di Preview (default: 30s) |
| `timers.paymentTimeout` | number | Timeout layar pembayaran (default: 300s) |
| `timers.thankYouDuration` | number | Durasi layar Thank You (default: 30s) |
| `timers.idleTimeout` | number | Idle timeout ke Screensaver (default: 120s) |

> **Harga tidak di-cache independen.** `kioskConfig` disimpan tapi harga selalu di-overwrite dari response `/kiosk/me` saat startup.

---

## 4. Application Flow

### 4.1 Startup & Mode Aplikasi

```
[App Start]
    │
    ▼
deviceToken ada?
    ├── TIDAK ──► [Layar Pairing]
    │
    └── YA ──► Startup Sequence
                    │
                    ▼
              GET /kiosk/me
                    │
        ┌───────────┼───────────────┐───────────────┐
        ▼           ▼               ▼               ▼
      401        is_active:false  EXPIRED/       ACTIVE/
    (hapus       (Locked)        CANCELLED      GRACE_PERIOD
     token,                      (Locked)           │
     → Pairing)                                     ▼
                                              Sync Templates
                                              GET /kiosk/templates
                                                    │
                                                    ▼
                                              [SCREENSAVER]
```

### 4.2 Flow Utama — Foto Dulu, Bayar Kemudian

```
┌─── SESSION LOOP ─────────────────────────────────────────────────────┐
│                                                                      │
│  [SCREENSAVER] ──(tap)──► [SELECT TEMPLATE] ──(pilih)──► [SESI FOTO]│
│       ▲                        ▲                         per slot:   │
│       │                        │                         countdown   │
│       │                        │                         → capture   │
│     (timeout                   │                              │      │
│      selesai)              (sesi baru)                        ▼      │
│       │                        │                     [PREVIEW COMPOS]│
│       │                        │                     ┌───────┴─────┐ │
│       │                        │                     ▼             ▼ │
│       │                        │               "Foto Ulang"  "Lanjut"│
│       │                        │               (countdown       │    │
│       │                        │                timer)          │    │
│       │                        │                  │             ▼    │
│       │                        │                  ▼       [KONFIRM   │
│       │                        │             [SESI FOTO]  & BAYAR]   │
│       │                        │              (ulang)     qty,dgtl   │
│       │                        │                          payment    │
│       │                        │                              │      │
│       │                        │                    ┌─────────┤      │
│       │                        │                    ▼         ▼      │
│       │                        │              CASH/QRIS      PG     │
│       │                        │              confirm     check-pay  │
│       │                        │                    │(PAID)  │(PAID) │
│       │                        │                    └────┬───┘       │
│       │                        │                         ▼           │
│       │                        │                  [PROCESSING]       │
│       │                        │                  cetak + upload     │
│       │                        │                         │           │
│       │                        │                         ▼           │
│       │                        │                   [THANK YOU]       │
│       │                        │                   + QR download     │
│       │                        │              ┌──────────┴────────┐  │
│       │                        └──────── "Sesi Baru"       "Selesai" │
│       │                                                       │      │
│       └───────────────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────────────────┘
```

### 4.3 XState Machine — Kiosk States

```typescript
const kioskMachine = createMachine({
  id: "kiosk",
  initial: "startup",
  states: {
    startup: {
      /* → pairing | screensaver | locked */
    },
    pairing: {
      /* pair success → startup */
    },
    locked: {
      /* expired/inactive screen */
    },
    screensaver: {
      on: { TAP: "selectTemplate", SETTINGS: "settings" },
    },
    selectTemplate: {
      on: { SELECT: "photoSession", SETTINGS: "settings" },
      after: { IDLE_TIMEOUT: "screensaver" },
    },
    photoSession: {
      /* per-slot capture, auto-advance → photoPreview */
    },
    photoPreview: {
      on: { RETAKE: "photoSession", CONTINUE: "confirmation" },
      after: { RETAKE_TIMEOUT: "confirmation" },
    },
    confirmation: {
      on: { PAID: "processing" },
      after: { PAYMENT_TIMEOUT: "screensaver" },
    },
    processing: {
      /* print + upload → thankYou */
    },
    thankYou: {
      on: { NEW_SESSION: "selectTemplate" },
      after: { THANKYOU_TIMEOUT: "screensaver" },
    },
    settings: { on: { BACK: "screensaver" } },
  },
});
```

### 4.4 API Call Sequence (Per Sesi)

| Step | Layar | API Call | Catatan |
|------|-------|---------|---------|
| 1 | Screensaver | — | Tidak ada API call |
| 2 | Select Template | — | Data dari cache lokal |
| 3 | Sesi Foto | — | Kamera lokal |
| 4 | Preview | — | Composite render lokal |
| 5 | Konfirmasi | `POST /kiosk/transactions` | Buat transaksi saat customer siap bayar |
| 6a | Konfirmasi (CASH) | `POST .../confirm-cash` | Operator konfirmasi |
| 6b | Konfirmasi (PG) | `POST .../check-payment` | Customer cek status |
| 7 | Processing | — | Cetak lokal |
| 8 | Processing | `POST /kiosk/sessions` | Upload digital copy (jika ada) |
| 9 | Thank You | — | Tampilkan QR dari response step 8 |

> **Catatan:** Dengan flow "foto dulu, bayar kemudian", API call baru dipanggil di layar Konfirmasi (setelah foto selesai). Ini mengurangi abandoned transactions.

---

## 5. Features & User Stories

### 5.1 Device Pairing (FEAT-KR-01)

- Layar pairing tampil saat `deviceToken` tidak ada atau token invalid (401)
- Input 6-digit code → `POST /kiosk/pair` → sukses: simpan `deviceToken` + `kioskConfig`, lanjut startup
- Pairing code salah/expired → pesan error, tetap di layar pairing
- `deviceToken` tersimpan terenkripsi via Electron `safeStorage`

### 5.2 Startup Sequence (FEAT-KR-02)

**Config Check:**
- Cek `deviceToken` → jika tidak ada → layar Pairing
- Fetch `GET /kiosk/me` → handle responses:
  - 401 → hapus token, layar Pairing
  - `isActive: false` → layar "Kiosk Dinonaktifkan" (locked)
  - `subscriptionStatus: "EXPIRED"` → layar "Subscription Expired" (locked)
  - `subscriptionStatus: "CANCELLED"` → layar "Subscription Cancelled" (locked)
  - `subscriptionStatus: "GRACE_PERIOD"` → banner peringatan, tetap beroperasi
  - `subscriptionStatus: "ACTIVE"` → simpan `kioskConfig` (harga di-overwrite)

**Template Sync:**
- Fetch `GET /kiosk/templates` → daftar template + `updatedAt` + semua `elements`
- Template baru / `updatedAt` berbeda → download background ke lokal, update cache termasuk `template_elements` + `properties` JSONB
- Template tidak ada di response → hapus dari cache lokal
- Background gagal download → log error, tandai "belum tersync", jangan tampilkan ke customer

### 5.3 Screensaver (FEAT-KR-03)

- Layar pertama yang dilihat customer saat booth idle
- Konfigurasi: `isEnabled`, `assetPath`, `mediaType` (image/video)
- Aktif saat: startup selesai, sesi selesai + timeout, idle timeout
- Tap/klik di mana saja → dismiss → masuk Select Template
- Jika `isEnabled = false` → langsung Select Template

### 5.4 Template Selection (FEAT-KR-04)

- Grid template yang `isActive = true` dan tersync di cache lokal
- Preview thumbnail background per template
- Pilih template → **langsung ke Sesi Foto** (tanpa konfigurasi harga dulu)
- Idle timeout N menit → kembali ke Screensaver

> **Akses Settings:** Tap 5x cepat di area kecil pojok kiri bawah (~40x40px, tidak ada visual indicator) → masuk Menu Settings.

### 5.5 Photo Session (FEAT-KR-05)

- Filter `template_elements` cache → ambil `element_type = 'photo_slot'`
- Urutan capture foto mengikuti `captureOrder` dari `properties` JSONB (ascending)
- Per photo_slot:
  1. Tampilkan preview kamera (live feed) dengan overlay frame sesuai `x`, `y`, `width`, `height`, `rotation`
  2. Countdown (3-2-1) → capture otomatis
  3. Brief preview (1-2 detik)
  4. Lanjut ke photo_slot berikutnya
- Sesi foto terjadi **sebelum pembayaran** — customer "coba dulu"

### 5.6 Preview & Retake (FEAT-KR-06)

**Composite Preview:**
- Render background + semua elemen + overlay → urutan z-index dari `sequence` terkecil ke terbesar
- Rendering rules per element type:
  - `photo_slot`: foto capture di koordinat, `borderRadius`/`borderWidth`/`borderColor`
  - `image`: gambar statis dari `properties.imageUrl`, `properties.fit` (cover/contain/fill)
  - `text`: teks dari `properties.content` dengan styling (fontFamily, fontSize, fontWeight, color, textAlign, letterSpacing)
  - `shape`: bentuk dari `properties.shapeType` (rect/circle/line) dengan styling (fill, stroke, strokeWidth, borderRadius)
  - Overlay URL → layer paling atas
  - `element_type` tidak dikenali → log warning, skip, lanjutkan
- Composite di **main process** atau worker thread (bukan renderer)

**Retake:**
- Retake **unlimited** — tidak ada batas
- Countdown timer (configurable, default: 30 detik) di layar preview
- Timer habis → otomatis lanjut ke Konfirmasi
- "Foto Ulang" → semua photo_slot difoto ulang dari awal
- "Lanjut" → simpan composite ke `outputFolderPath` → Konfirmasi

### 5.7 Confirmation & Payment (FEAT-KR-07)

**Konfigurasi Session:**
- Preview composite (read-only, tidak bisa retake lagi)
- Jumlah print: default 1 (include base), bisa tambah extra
- Toggle Digital Copy dengan indikasi harga
- Ringkasan harga real-time:
  - Base price (include 1x print)
  - Extra print: `(print_qty - 1) × extra_print_price`
  - Digital copy: `digital_copy_price` (jika aktif)
  - **Total**

**Price Resolution:**
```
Priority: template.override_price_* (jika tidak null) → kioskConfig.price_* (fallback)

total = base_price
      + max(0, print_qty - 1) × extra_print_price
      + (has_digital_copy ? digital_copy_price : 0)
```

**Payment Flows:**

| Mode | Flow |
|------|------|
| **CASH** | Tampilkan total → instruksi "Bayar ke kasir" → tombol "Konfirmasi Pembayaran Diterima" (operator) → `POST /kiosk/transactions` → `POST .../confirm-cash` → PAID → Processing |
| **STATIC_QRIS** | Tampilkan QR statis + total → tombol "Konfirmasi Pembayaran Diterima" → flow sama seperti CASH |
| **PG** | `POST /kiosk/transactions` → tampilkan QR dari `paymentUrl` + nominal → "Saya Sudah Bayar — Cek Pembayaran" → `POST .../check-payment` → PAID/PENDING/FAILED |

- PG: tidak ada auto-polling, semua on-demand via tombol
- PG PENDING → pesan "Belum diterima", customer bisa tekan lagi
- PG FAILED → pesan "Gagal", opsi buat transaksi baru
- **Timeout:** N menit tanpa aksi → konfirmasi "Batalkan sesi?" → Screensaver

### 5.8 Processing & Output (FEAT-KR-08)

**Cetak:**
1. Kirim composite ke printer thermal via USB (ESC/POS) → cetak × `print_qty`
2. Printer tidak terdeteksi → pesan error, opsi retry atau skip
3. File composite tetap tersimpan lokal

**Digital Copy** (jika `hasDigitalCopy = true`):
1. Upload composite ke Supabase Storage via `POST /kiosk/sessions` (multipart: file + transactionId)
2. Backend return `downloadUrl`
3. Upload gagal → opsi retry; tetap gagal → informasikan customer

### 5.9 Thank You & Loop (FEAT-KR-09)

- Jika `hasDigitalCopy = true`: QR code besar dari `downloadUrl` + instruksi "Scan QR" + countdown (default: 30s)
- Jika `hasDigitalCopy = false`: hanya pesan "Terima Kasih!"
- Dua opsi: **"Sesi Baru"** (→ Select Template) / **"Selesai"** (→ Screensaver)
- Countdown habis tanpa aksi → Screensaver

### 5.10 Settings — Operator Only (FEAT-KR-10)

**Akses:** Tap 5x cepat berturut-turut (< 2 detik) di area pojok kiri bawah (~40x40px, invisible). Bisa dari Screensaver dan Select Template.

**Konfigurasi:**

| Section | Controls |
|---------|----------|
| **Kamera** | Dropdown pilih kamera, toggle mirror (isMirrored) |
| **Printer** | Input VID/PID (hex), tombol "Test Print" |
| **Pembayaran** | Radio CASH / STATIC_QRIS / PG; jika QRIS: upload QR image |
| **Output Folder** | Tampilkan path, tombol "Ganti Folder" (folder picker) |
| **Screensaver** | Toggle enable/disable, pilih asset (image/video), set idle timeout |
| **Timers** | Retake countdown, payment timeout, thank you duration |
| **Sync Template** | `updatedAt` terakhir, tombol "Sync Sekarang", status per template |
| **Info Kiosk** | Nama kiosk, owner ID, status subscription, versi app |
| **Reset Pairing** | Hapus deviceToken → kembali ke Pairing |

---

## 6. API Integration

### 6.1 Endpoints

> [!NOTE]
> **📋 Dokumentasi API terpisah belum dibuat.** Endpoint mapping di bawah berdasarkan PRD-01 dan akan di-update seiring backend selesai.

Semua endpoint prefix `/api/v1`. Header: `Authorization: Bearer {device_token}` (kecuali `/kiosk/pair`).

| Endpoint | Method | Deskripsi |
|----------|--------|-----------|
| `/kiosk/pair` | POST | Tukarkan `pairingCode` → `deviceToken` |
| `/kiosk/me` | GET | Config kiosk + subscription status |
| `/kiosk/templates` | GET | Semua template aktif + elements |
| `/kiosk/transactions` | POST | Buat transaksi baru (PENDING) |
| `/kiosk/transactions/:id/confirm-cash` | POST | Konfirmasi CASH/QRIS → PAID |
| `/kiosk/transactions/:id/check-payment` | POST | Cek status PG |
| `/kiosk/sessions` | POST | Upload digital copy (multipart) |

### 6.2 API Response Shapes

> [!WARNING]
> **⏳ Response shape bersifat preliminary.** Akan di-update seiring backend selesai.

**Pair Kiosk:**
```json
{
  "data": {
    "deviceToken": "eyJhbG...",
    "kioskConfig": {
      "id": "uuid", "name": "Booth Mall A", "ownerId": "uuid",
      "priceBaseSession": 25000, "pricePerExtraPrint": 5000, "priceDigitalCopy": 10000
    }
  }
}
```

**Get Kiosk Config:**
```json
{
  "data": {
    "kiosk": {
      "id": "uuid", "name": "Booth Mall A", "isActive": true,
      "priceBaseSession": 25000, "pricePerExtraPrint": 5000, "priceDigitalCopy": 10000
    },
    "subscriptionStatus": "ACTIVE",
    "gracePeriodDaysRemaining": 0
  }
}
```

**Create Transaction:**
```json
// Request
{
  "templateId": "uuid", "printQty": 2, "hasDigitalCopy": true,
  "totalAmount": 40000, "paymentMethod": "PG"
}

// Response 201
{
  "data": {
    "transaction": {
      "id": "uuid", "orderId": "MEM-1740576000-a3k9", "status": "PENDING",
      "totalAmount": 40000
    },
    "paymentUrl": "https://checkout.xendit.co/..."
  }
}
```

**Upload Session (multipart):**
```json
// Response 201
{
  "data": {
    "session": { "id": "uuid", "resultImageUrl": "https://..." },
    "downloadUrl": "https://..."
  }
}
```

---

## 7. Template Element Model

Setiap template terdiri dari elemen polymorphic 4 tipe, disimpan di `template_elements`.

### 7.1 Atribut Spasial (Semua Tipe)

`x`, `y`, `width`, `height` (px) · `rotation` (0-360°) · `opacity` (0-100) · `sequence` (z-index, ascending)

### 7.2 Properties Per Tipe (JSONB)

| Tipe | Properties |
|------|-----------|
| `photo_slot` | `{ captureOrder, borderRadius?, borderWidth?, borderColor? }` |
| `image` | `{ imageUrl, fit: "cover"|"contain"|"fill", borderRadius? }` |
| `text` | `{ content, fontFamily, fontSize, fontWeight, color, textAlign, letterSpacing? }` |
| `shape` | `{ shapeType: "rect"|"circle"|"line", fill?, stroke?, strokeWidth?, borderRadius? }` |

### 7.3 Rendering Order

1. Background image (dari `template.backgroundUrl`)
2. Semua elements ascending by `sequence` (terkecil = z-index paling bawah)
3. Overlay image (dari `template.overlayUrl`) sebagai layer paling atas

---

## 8. UI/UX Guidelines

### 8.1 Design Principles

| Principle | Detail |
|-----------|--------|
| **Touchscreen-first** | Semua elemen interaktif minimum 44×44px touch target |
| **Fullscreen kiosk** | Tidak ada title bar, address bar, OS chrome |
| **Large typography** | Minimum 16px body, 24px+ headings, high contrast |
| **Clear feedback** | Visual feedback setiap tap, countdown visible, loading states |
| **Minimal UI** | Customer hanya lihat yang relevan, operator controls tersembunyi |
| **Bahasa Indonesia** | Seluruh UI text dalam Bahasa Indonesia |

### 8.2 Layar Dimensions

- Target: 1280×800 minimum (common touchscreen kiosk)
- Responsive ke orientasi landscape
- Fullscreen mode (Electron `BrowserWindow` dengan `fullscreen: true`)

---

## 9. Security & Privacy

| Area | Implementasi |
|------|-------------|
| **Device Token** | `safeStorage` OS-level encryption; tidak pernah display di UI |
| **Token format** | JWT `{ kioskId, ownerId }`, expiry ~10 tahun |
| **Token invalidation** | Owner reset pairing → server null token → Electron 401 → Pairing |
| **API authorization** | Semua `/kiosk/*` dilindungi `verifyDeviceToken` middleware |
| **Data isolation** | Electron hanya akses data milik owner yang ter-pair (server-side) |
| **File storage** | Composite lokal di `outputFolderPath`; digital copy di Supabase |
| **No sensitive data** | `device_token` tidak ditampilkan; financial data tidak diakses |
| **Price validation** | Backend re-kalkulasi dan validasi server-side; mismatch → 400 |

---

## 10. Business Rules & Edge Cases

### 10.1 Template & Sync

| Rule | Detail |
|------|--------|
| **Full dump sync** | Tidak ada delta/incremental, selalu fetch semua template aktif |
| **`updatedAt` as signal** | Compare lokal vs server untuk detect perubahan |
| **Min 1 photo_slot** | Backend tolak tanpa photo_slot. Jika terjadi di cache → error, jangan izinkan pilih |
| **Elemen tidak dikenali** | Log warning, skip, lanjutkan composite |
| **Background belum tersync** | Template tidak ditampilkan sampai background didownload |
| **Unique captureOrder** | Setiap photo_slot wajib `captureOrder` unik (integer) — urutan capture foto |

### 10.2 Pembayaran

| Rule | Detail |
|------|--------|
| **Price server-side validation** | Backend re-kalkulasi totalAmount; mismatch → `400 PRICE_MISMATCH` |
| **Idempotency CASH** | Confirm kedua kali saat PAID → 200 tanpa side effect |
| **Idempotency PG** | Check saat PAID → 200 PAID tanpa PG call tambahan |
| **Abandoned PG** | Tetap PENDING selamanya — acceptable MVP |
| **Foto sebelum bayar** | Transaction dibuat di Konfirmasi (setelah foto) → fewer abandoned |

### 10.3 Subscription & Lockout

| Rule | Detail |
|------|--------|
| **Lazy status** | Dihitung on-the-fly, tidak ada cron |
| **Cek hanya saat startup** | Jika expired saat running, sesi berlanjut. Restart → locked |
| **Grace period** | Masih beroperasi dengan banner peringatan |
| **Lock states** | EXPIRED dan CANCELLED → booth terkunci |

### 10.4 Hardware Edge Cases

| Situasi | Handling |
|---------|---------|
| **Internet putus saat PG** | "Cek Pembayaran" gagal → pesan error. Operator switch ke CASH |
| **Printer tidak terdeteksi** | Error setelah sesi → retry atau skip. File composite tetap lokal |
| **Kamera tidak terdeteksi** | Error sebelum countdown → kembali Select Template. Tidak ada transaksi (foto sebelum bayar) |
| **Upload digital copy gagal** | Retry. Tetap gagal → informasikan customer, pertimbangkan refund manual |
| **Storage penuh** | Warning saat simpan composite. Operator bersihkan folder |
| **App crash** | Auto-restart via Electron crash handler / supervisor |

---

## 11. Performance & Non-Functional Requirements

| Aspek | Requirement |
|-------|-------------|
| **Startup time** | < 60 detik (termasuk sync) |
| **UI response** | Tidak freeze > 100ms saat transisi layar |
| **Composite rendering** | < 3 detik untuk ≤ 20 elemen |
| **Upload digital copy** | < 10 detik untuk file ≤ 10MB |
| **Print initiation** | < 2 detik setelah composite selesai |
| **Offline tolerance** | CASH/QRIS bisa offline setelah startup. PG butuh koneksi |
| **Storage** | Cache template di app data folder. Output folder bisa drive eksternal |
| **Stability** | Tidak crash setelah 8 jam operasi kontinu |
| **OS Support** | Windows 10+ (primary), Linux (secondary), macOS (nice-to-have) |
| **Auto-recovery** | Restart otomatis jika crash |

---

## 12. Testing Strategy

| Layer | Target | Approach |
|-------|--------|----------|
| State machine | XState transitions, guards, timeouts | Unit test (XState inspect) |
| Price calculation | Formula, edge cases (0 extra, override) | Pure unit test |
| Composite renderer | 4 element types, z-order, skip unknown | Integration test (Canvas output) |
| API integration | Pair, config, sync, transaction, upload | Mock API test |
| Hardware | Printer, camera | Manual testing (real hardware) |
| E2E flow | Full session loop | Manual testing |

---

## 13. Distribution & Update

| Aspek | Detail |
|-------|--------|
| Packaging | **electron-builder** — Windows (NSIS installer), Linux (AppImage), macOS (DMG) |
| Auto-update | v2.0 scope — MVP: manual installer |
| Versioning | SemVer; version displayed di Settings |
| Build | `pnpm build` → electron-vite build → electron-builder package |

---

## 14. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigasi |
|------|-----------|--------|----------|
| Composite performance (20+ elemen) | MEDIUM | MEDIUM | Worker thread; benchmark target < 3s |
| USB printer kompatibilitas | MEDIUM | MEDIUM | ESC/POS standard; test 3+ model populer |
| Electron app size (150MB+) | LOW | LOW | Tree-shaking, lazy loading |
| Offline mode terbatas | LOW | MEDIUM | Dokumentasikan: startup butuh internet |
| Cache corruption (crash saat write) | LOW | MEDIUM | Atomic write; re-sync saat startup |
| Kamera WebRTC compatibility | LOW | LOW | getUserMedia well-supported di Chromium (Electron) |
| Backend API belum ready | MEDIUM | HIGH | Mock API; backend PRD sudah final |

---

## 15. Open Issues

| ID | Issue | Status |
|----|-------|--------|
| OI-01 | Photo slot capture order | ✅ **Resolved:** `captureOrder` field di JSONB properties |
| OI-02 | Payment Gateway | ✅ **Resolved:** Xendit |

Semua open issues telah diputuskan — tidak ada blocker.

---

## 16. Roadmap

### MVP (v1.0) — Core Kiosk Operation
- Pairing, startup sequence, template sync (full dump)
- Flow foto-dulu-bayar-kemudian (screensaver → template → foto → preview/retake → konfirmasi+bayar → processing → thank you)
- Pembayaran (CASH/STATIC_QRIS/PG), cetak thermal, digital copy upload
- Settings (hidden access), screensaver
- XState flow management, Zustand data store

### v1.1 — Polish & Improvements
- Delta sync template, auto-reconnect after network drop
- Print queue management, session history lokal
- Multi-language UI

### v2.0 — Advanced Features
- Auto-update Electron
- Kamera filter/effects, video booth mode
- Webhook PG receiver (no manual check)
- Analytics dashboard di kiosk

---

## 17. Changelog

| Tanggal | Versi | Perubahan |
|---------|-------|-----------|
| 2026-03-05 | 0.1 | Initial skeleton created |
| 2026-03-06 | 1.0 | Full draft — synthesized dari reference1/memoir_APP_kiosk-runner.md (v1.2) dan reference4/PRD_KIOSK_RUNNER.md (v2.0). Flow diambil dari v2.0 (foto dulu bayar kemudian). OI-01 & OI-02 resolved. Tech stack: electron-vite + XState + Zustand + React + Tailwind. |

# PRD-02: Dashboard Owner Photobooth (Web)

> **Versi:** 1.0
> **Tanggal:** 6 Maret 2026
> **Status:** Draft — For Review
> **Audiens:** Internal dev team & AI coding agents
> **Parent:** [PRD-00-master.md](./PRD-00-master.md) (Platform Overview)
> **Backend:** [PRD-01-backend-api.md](./PRD-01-backend-api.md) (Backend API)

---

## 1. Executive Summary

### 1.1 Problem Statement

Studio owner yang berlangganan platform memoir. membutuhkan satu dashboard web terpusat untuk mengelola seluruh operasi booth mereka: setup template cetak (visual canvas editor), manajemen kiosk devices, pemantauan transaksi, pengelolaan wallet & withdrawal, dan subscription lifecycle. Tanpa dashboard ini, owner bergantung sepenuhnya pada admin untuk setiap operasi.

### 1.2 Proposed Solution

**memoir. Owner Dashboard** adalah aplikasi web **Next.js 16 (App Router)** yang menjadi single control panel bagi studio owner. Dashboard menyediakan:

- **Template Editor** : visual berbasis Konva canvas drag, resize, rotate elemen, snap guides, text variable system, preview mode
- **Kiosk Management** : CRUD booth devices dan pairing ke runner (Electron / Flutter)
- **Financial Overview** : wallet balance, mutation history, withdrawal request, riwayat transaksi
- **Subscription Management** : pilih plan, bayar, cek status invoice, upgrade

Dashboard berkomunikasi dengan memoir. Backend API (`/api/v1/owner/*` dan `/api/v1/auth/*`) menggunakan JWT auth. Semua data di-scope ke `owner_id` dari token zero cross-tenant leakage.

### 1.3 Success Criteria

| # | KPI | Target | Cara Ukur |
|---|-----|--------|-----------|
| 1 | **Time-to-first-template** | < 5 menit dari login sampai template tersimpan | Manual testing + user session |
| 2 | **Page load time** | LCP < 2.5s untuk semua halaman dashboard | Lighthouse / Web Vitals |
| 3 | **Canvas editor framerate** | Canvas interaction (drag/resize/rotate) < 16ms per frame (60fps) | Chrome DevTools Performance |
| 4 | **Accessibility** | Lighthouse Accessibility score ≥ 90 | Lighthouse audit |
| 5 | **Mobile usability** | Semua halaman non-editor usable di viewport ≥ 768px | Responsive testing |

---

## 2. User Experience & Functionality

### 2.1 User Persona

#### P2 — Studio Owner

Satu-satunya persona yang menggunakan Owner Dashboard. Studio owner yang mengelola satu atau lebih booth photobooth receipt. Mereka:

- Login menggunakan email & password (akun dibuat oleh admin, tidak ada self-registration)
- Mengelola kiosk devices, template desain cetak, pricing, dan subscription
- Memantau transaksi dan keuangan booth melalui wallet
- Menginginkan antarmuka yang simpel, tanpa background teknis
- Berbahasa Indonesia (seluruh UI dalam Bahasa Indonesia)

### 2.2 Epic & Feature Index

| Epic | Feature | ID | Priority |
|------|---------|------|----------|
| **EPIC-OD-01: Auth & Onboarding** | Login Page | FEAT-OD-01.1 | P0 |
| | Onboarding — Plan Selection & Payment | FEAT-OD-01.2 | P0 |
| **EPIC-OD-02: Dashboard Home** | Dashboard Summary Page | FEAT-OD-02.1 | P0 |
| **EPIC-OD-03: Kiosk Management** | Kiosk List & Cards | FEAT-OD-03.1 | P0 |
| | Kiosk Create / Edit | FEAT-OD-03.2 | P0 |
| | Generate / Reset Pairing Code | FEAT-OD-03.3 | P0 |
| **EPIC-OD-04: Template Management** | Template List & Grid | FEAT-OD-04.1 | P0 |
| | Template Create — Upload & Crop | FEAT-OD-04.2 | P0 |
| | Template Create / Edit — Canvas Editor | FEAT-OD-04.3 | P0 |
| | Template Element Editor (Konva Canvas) | FEAT-OD-04.4 | P0 |
| **EPIC-OD-05: Transactions** | Transaction History Page | FEAT-OD-05.1 | P0 |
| **EPIC-OD-06: Wallet & Finance** | Wallet Balance & Mutation History | FEAT-OD-06.1 | P0 |
| | Withdrawal Request | FEAT-OD-06.2 | P0 |
| **EPIC-OD-07: Subscription Management** | Active Subscription & Invoice History | FEAT-OD-07.1 | P0 |
| | Invoice Payment Check | FEAT-OD-07.2 | P0 |

### 2.3 Non-Goals (Apa yang TIDAK dibangun)

| # | Non-Goal | Alasan |
|---|----------|--------|
| NG-01 | Kiosk Runner UI (Electron / Flutter) | Aplikasi terpisah (PRD-04 / PRD-05) |
| NG-02 | Platform Admin dashboard | Aplikasi terpisah (PRD-03) |
| NG-03 | Mobile app (iOS/Android) | Scope: responsive web only |
| NG-04 | PWA / offline mode | Owner membutuhkan koneksi internet |
| NG-05 | Real-time push notification / WebSocket | MVP polling-based |
| NG-06 | Multi-language / i18n | Semua UI dalam Bahasa Indonesia |
| NG-07 | Export CSV / PDF | Tidak ada export di MVP |
| NG-08 | Self-registration owner | Akun dibuat oleh admin |
| NG-09 | Customer-facing pages | Customer berinteraksi via kiosk saja |
| NG-10 | Template editor di mobile (< 768px) | Canvas editing terlalu kompleks untuk mobile |
| NG-11 | Dark mode | Tidak prioritas untuk MVP |

---

## 3. Technical Specifications

### 3.1 Architecture Overview

```
┌───────────────────────────────────────────────────────────────┐
│                      Next.js App Router                       │
│                                                               │
│  Route Groups:                                                │
│    (auth)/     → /login                                       │
│    (dashboard)/ → /, /kiosks, /templates, /transactions,      │
│                   /wallet, /subscription                      │
│    onboarding/ → /onboarding                                  │
│                                                               │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐     │
│  │   Server    │  │   Client     │  │   Shared          │     │
│  │  Components │  │  Components  │  │                   │     │
│  │             │  │              │  │  lib/api.ts       │     │
│  │  page.tsx   │  │  Template    │  │  lib/auth-api.ts  │     │
│  │  layout.tsx │  │  Editor      │  │  lib/types.ts     │     │
│  │             │  │  (Konva)     │  │  lib/format.ts    │     │
│  │             │  │              │  │  lib/constants.ts │     │
│  └──────┬──────┘  └──────┬───────┘  └───────────────────┘     │
│         │                │                                    │
│         ▼                ▼                                    │
│  ┌──────────────────────────────────────────┐                 │
│  │           API Client (lib/api.ts)        │                 │
│  │  fetch() + JWT Authorization header      │                 │
│  │  + ApiError + token management           │                 │
│  └──────────────────┬───────────────────────┘                 │
│                     │                                         │
│  ┌──────────────────┴───────────────────────┐                 │
│  │      Auth Layer (auth-provider.tsx)      │                 │
│  │  Context: user, subscription, actions    │                 │
│  │  Route protection + onboarding redirect  │                 │
│  └──────────────────────────────────────────┘                 │
│                     │                                         │
└─────────────────────┼─────────────────────────────────────────┘
                      │ HTTPS
                      ▼
              memoir. Backend API
              /api/v1/owner/*
              /api/v1/auth/*
```

### 3.2 Rendering Strategy

| Route / Component | Rendering | Alasan |
|---|---|---|
| `(dashboard)/page.tsx` | Server Component → fetch data saat render | Halaman read-only, benefit SSR |
| `(dashboard)/kiosks` | Server + Client interactivity | List bisa SSR, modal form perlu client state |
| `(dashboard)/templates` | Client Component | Heavy interactivity (toggle, delete, state) |
| `templates/create` | Client Component | Konva canvas, file upload, multi-step wizard |
| `templates/:id/edit` | Client Component | Same as create |
| `(dashboard)/transactions` | Server + Client filters | Tabel bisa SSR, filter controls client state |
| `(dashboard)/wallet` | Server + Client modal | Read-only page, withdrawal form modal |
| `(dashboard)/subscription` | Server + Client payment check | Info display SSR, cek pembayaran client |
| `(auth)/login` | Server + Client form | Form submit perlu client logic |
| `onboarding` | Server + Client toggle | Plan cards SSR, billing toggle client |

### 3.3 Tech Stack

| Layer | Technology | Version | Catatan |
|---|---|---|---|
| Framework | **Next.js** (App Router) | 16.1.6 | Server & Client Components, route groups |
| UI Library | **React** | 19.2.3 | Concurrent features, hooks |
| Language | **TypeScript** | 5.x | Strict mode |
| Styling | **Tailwind CSS** | 4.x | Utility-first, `tw-animate-css` for animations |
| Component Library | **shadcn/ui** (via `shadcn` CLI) | 3.8.5 | Radix UI primitives, zinc base color |
| Icons | **lucide-react** | 0.575.0 | Consistent icon set |
| Canvas Editor | **Konva** + **react-konva** | 10.2 / 19.2 | 2D canvas for template editor |
| Image Cropping | **react-image-crop** | 11.x | Free-form crop for template backgrounds |
| CSS Utilities | clsx + tailwind-merge | latest | `cn()` helper |
| CVA | class-variance-authority | 0.7.1 | Component variant styling |
| API Client | Native `fetch()` wrapper | — | `lib/api.ts` (ApiError, token mgmt) |
| Auth State | React Context | — | `components/auth-provider.tsx` |
| Data Fetching | **TanStack Query** (React Query) | 5.x | Server state caching, mutations, optimistic updates, devtools |
| Form Validation | **Zod** + **react-hook-form** | zod 3.x / rhf 7.x | Schema validation matching backend Zod schemas; shadcn/ui `<Form>` integration |
| Package Manager | npm | — | Sesuai existing setup |

### 3.4 Route Map

| Route | File | Auth | Subscription | Page Title |
|---|---|:---:|:---:|---|
| `/login` | `(auth)/login/page.tsx` | ❌ | ❌ | Login |
| `/onboarding` | `onboarding/page.tsx` | ✅ | ❌ | Pilih Plan |
| `/` | `(dashboard)/page.tsx` | ✅ | ✅ | Dashboard |
| `/kiosks` | `(dashboard)/kiosks/page.tsx` | ✅ | ✅ | Kiosk |
| `/templates` | `(dashboard)/templates/page.tsx` | ✅ | ✅ | Template |
| `/templates/create` | `(dashboard)/templates/create/page.tsx` | ✅ | ✅ | Buat Template |
| `/templates/:id/edit` | `(dashboard)/templates/[id]/edit/page.tsx` | ✅ | ✅ | Edit Template |
| `/transactions` | `(dashboard)/transactions/page.tsx` | ✅ | ✅ | Transaksi |
| `/wallet` | `(dashboard)/wallet/page.tsx` | ✅ | ✅ | Wallet |
| `/subscription` | `(dashboard)/subscription/page.tsx` | ✅ | ✅ (view) | Subscription |

### 3.5 Project Structure

```
src/
├── app/
│   ├── globals.css
│   ├── layout.tsx              # Root layout: Inter font, AuthProvider, TooltipProvider
│   ├── (auth)/
│   │   └── login/
│   │       └── page.tsx        # Login form
│   ├── (dashboard)/
│   │   ├── layout.tsx          # Sidebar + main content wrapper
│   │   ├── page.tsx            # Dashboard home
│   │   ├── kiosks/
│   │   │   └── page.tsx        # Kiosk list
│   │   ├── templates/
│   │   │   ├── layout.tsx      # Templates metadata
│   │   │   ├── page.tsx        # Template grid
│   │   │   ├── create/
│   │   │   │   └── page.tsx    # 2-step template wizard
│   │   │   └── [id]/
│   │   │       └── edit/
│   │   │           └── page.tsx  # Edit template
│   │   ├── transactions/
│   │   │   └── page.tsx        # Transaction table
│   │   ├── wallet/
│   │   │   └── page.tsx        # Wallet + withdrawals
│   │   └── subscription/
│   │       └── page.tsx        # Subscription + invoices
│   └── onboarding/
│       └── page.tsx            # Plan selection
├── components/
│   ├── app-sidebar.tsx         # Collapsible sidebar navigation
│   ├── auth-provider.tsx       # Auth context (user, subscription, route protection)
│   ├── templates/
│   │   └── steps/
│   │       ├── step-upload-crop.tsx  # Upload & crop wizard step
│   │       ├── step-editor.tsx       # Canvas editor wrapper + tools panel
│   │       └── editor-canvas.tsx     # Konva canvas renderer
│   └── ui/                     # shadcn/ui components (10+ files)
├── hooks/
│   └── use-mobile.ts           # Mobile breakpoint hook
└── lib/
    ├── api.ts                  # API client (fetch wrapper, token mgmt, ApiError)
    ├── auth-api.ts             # Auth API functions (login, logout, subscription)
    ├── types.ts                # TypeScript interfaces (Auth, Subscription, etc.)
    ├── constants.ts            # Status configs, labels
    ├── format.ts               # Rupiah, date, datetime formatters
    ├── template-variables.ts   # 12 template variables + resolver
    └── utils.ts                # cn() utility
```

---

## 4. Authentication & Route Protection

### 4.1 Auth Flow

```
Login  → decode JWT → setUser → fetch subscription → redirect (/ or /onboarding)
Mount  → check localStorage token → decode → fetch subscription → route protect
401    → try refresh → if fail, clear token → redirect /login
```

### 4.2 Auth Details

| Aspek | Implementasi |
|-------|-------------|
| Login endpoint | `POST /api/v1/auth/login` → `{ data: { accessToken, user } }` + Set-Cookie `refresh_token` |
| Token storage | `accessToken` di `localStorage` via `lib/api.ts` (`getToken/setToken/removeToken`); `refresh_token` via HttpOnly cookie |
| Auth header | `Authorization: Bearer {accessToken}` otomatis via `apiFetch()` |
| Route protection | `AuthProvider` component — redirect ke `/login` jika token absent/expired |
| Subscription check | `AuthProvider` — cek status; jika EXPIRED → redirect `/onboarding` |
| Token refresh | `POST /api/v1/auth/refresh` — cookie (`credentials: 'include'`), response: `{ data: { accessToken } }` |
| Token expiry | Access token short-lived; `apiFetch()` handle 401 → try refresh → if fail, clear + redirect |
| Logout | `POST /api/v1/auth/logout` — revoke refresh token, clear cookie; client: `removeToken()` + redirect `/login` |

---

## 5. API Integration

### 5.1 API Client

- **Base URL:** `NEXT_PUBLIC_API_URL` env var (default: `http://localhost:3000/api/v1`)
- **Response format:** `{ data: ... }` sukses · `{ error: "CODE", message: "..." }` error · `{ data: [...], meta: { page, limit, total } }` paginated
- **Field naming:** Backend menggunakan `camelCase`

### 5.2 Endpoint Mapping per Page

> [!NOTE]
> **📋 Dokumentasi API terpisah belum dibuat.** File API contract (markdown) akan dibuat secara bertahap seiring dengan fitur/endpoint yang selesai di backend. Endpoint mapping di bawah ini adalah rencana berdasarkan PRD-01 dan akan di-update agar selalu sesuai dengan codebase aktual.

| Frontend Page | API Endpoint(s) |
|---|---|
| Login | `POST /auth/login` |
| Onboarding | `GET /admin/subscription-plans` (active only), `POST /owner/subscription` |
| Dashboard Home | `GET /owner/subscription`, `GET /owner/wallet`, `GET /owner/kiosks`, `GET /owner/transactions` |
| Kiosks | `GET/POST /owner/kiosks`, `PATCH /owner/kiosks/:id`, `POST /owner/kiosks/:id/generate-pairing` |
| Templates | `GET/POST/PATCH/DELETE /owner/templates[/:id]`, `GET/POST/PATCH/DELETE /owner/templates/:id/elements[/:elementId]` |
| Transactions | `GET /owner/transactions` (paginated + filtered) |
| Wallet | `GET /owner/wallet` (paginated), `GET/POST /owner/withdrawals` |
| Subscription | `GET/POST /owner/subscription`, `GET /owner/subscription/invoices`, `POST /owner/subscription/invoices/:id/check-payment` |

### 5.3 API Response Shape Reference

> [!WARNING]
> **⏳ Response shape di bawah ini bersifat preliminary.** Bentuk response aktual akan mengikuti implementasi backend. Section ini akan di-update berkala seiring endpoint backend selesai dibangun. Gunakan sebagai referensi awal untuk TypeScript interfaces, tapi selalu verifikasi dengan API contract terbaru.

#### Transaction
```json
{
  "id": "uuid", "orderId": "MEM-123-abc", "status": "PAID",
  "paymentMethod": "PG", "printQty": 2, "hasDigitalCopy": true,
  "appliedBasePrice": 25000, "appliedExtraPrintPrice": 5000,
  "appliedDigitalCopyPrice": 10000, "totalAmount": 40000,
  "createdAt": "ISO8601", "paidAt": "ISO8601"
}
```

#### Wallet
```json
{
  "data": {
    "balance": 1500000,
    "mutations": [{
      "type": "CREDIT", "category": "TRANSACTION_INCOME",
      "amount": 40000, "currentBalanceSnapshot": 1500000,
      "createdAt": "ISO8601"
    }]
  },
  "meta": { "page": 1, "limit": 20, "total": 50 }
}
```

#### Withdrawal
```json
{
  "data": {
    "withdrawal": {
      "id": "uuid", "amount": 500000, "status": "PENDING",
      "bankName": "BCA", "bankAccountNumber": "1234567890",
      "bankAccountName": "John Doe", "createdAt": "ISO8601"
    }
  }
}
```

#### Subscription
```json
{
  "data": {
    "subscription": {
      "billingPeriod": "MONTHLY", "status": "ACTIVE",
      "pricePaid": 99000, "currentPeriodEnd": "ISO8601"
    },
    "subscriptionStatus": "ACTIVE",
    "gracePeriodDaysRemaining": 0
  }
}
```

---

## 6. Features & Pages

### 6.1 Login (FEAT-OD-01.1)

- **Route:** `/login` — route group `(auth)`
- **Form:** Email + password → `POST /api/v1/auth/login`
- **Success:** Store `accessToken` di localStorage; redirect `/` atau `/onboarding`
- **Error handling:** 401 → "Email atau password salah"; 429 → "Terlalu banyak percobaan"
- **Route protection:** `AuthProvider` redirect non-authenticated ke `/login`

### 6.2 Onboarding — Plan Selection (FEAT-OD-01.2)

- **Route:** `/onboarding` — entry point saat subscription EXPIRED/absent
- **UI:** Plan comparison cards dengan toggle MONTHLY/YEARLY
- Plan cards: nama tier, max kiosks, harga, recommended highlight
- **Flow:** Pilih plan → `POST /owner/subscription` → redirect ke `payment_url` → kembali → "Cek Status Pembayaran" → jika PAID, redirect ke `/`
- **Bypass:** Onboarding di-bypass untuk development phase menggunakan seed owner dengan subscription aktif

### 6.3 Dashboard Home (FEAT-OD-02.1)

- **Route:** `/` — dashboard home
- **Components:**
  - Greeting: "Selamat datang, {nama owner}"
  - **Subscription banner:** Warna & pesan sesuai status:
    - ACTIVE → hijau "Plan {tier} aktif — {X} hari tersisa"
    - GRACE_PERIOD → kuning "Subscription berakhir. {X} hari grace period. Perpanjang →"
    - EXPIRED → merah "Subscription expired. Booth terkunci. Aktifkan →"
  - **4 Stat cards:** Saldo wallet, pendapatan bulan ini, transaksi hari ini, kiosk aktif (X/Y)
- **Data sources:** 4 parallel API calls (subscription, wallet, kiosks, transactions)
- **Loading:** Skeleton loaders pada semua stat cards

### 6.4 Kiosk Management (FEAT-OD-03.1, 03.2, 03.3)

#### Kiosk List & Cards (FEAT-OD-03.1)
- **Route:** `/kiosks`
- **Display:** Kartu per kiosk — nama, badge Aktif/Nonaktif, status pairing ("Terpair — {date}" / "Belum dipair"), harga default (Rupiah)
- **Header:** Counter "X / Y kiosk aktif" + tombol "Tambah Kiosk" (disabled saat X ≥ Y, dengan tooltip)
- **Empty state:** Ilustrasi + "Belum ada kiosk"

#### Kiosk Create / Edit (FEAT-OD-03.2)
- **Create:** Modal form — nama kiosk → `POST /owner/kiosks`; success → tampilkan pairing code
- **Edit:** Nama, harga default (base, extra print, digital copy), toggle aktif/nonaktif → `PATCH /owner/kiosks/:id`
- **Error:** 403 `MAX_KIOSKS_REACHED` → toast "Limit kiosk tercapai, upgrade plan"
- **Note:** "Perubahan harga berlaku untuk transaksi baru. Harga lama tersimpan di transaksi yang sudah ada."

#### Generate / Reset Pairing Code (FEAT-OD-03.3)
- **Trigger:** Tombol di detail kiosk — "Generate Pairing Code" (baru) atau "Reset Pairing" (re-pair)
- **Re-pair:** Konfirmasi dialog "Membuat pairing code baru akan memutuskan koneksi runner yang aktif."
- **Display:** 6 digit besar, monospace, dengan tombol "Salin" (clipboard)
- **API:** `POST /owner/kiosks/:id/generate-pairing`

### 6.5 Template Management (FEAT-OD-04.1, 04.2, 04.3, 04.4)

#### Template List & Grid (FEAT-OD-04.1)
- **Route:** `/templates`
- **Display:** Grid kartu — visual preview (miniatur background + photo_slot positions), nama, "X slot", badge aktif/nonaktif, indikator override price, dimensi
- **Quick actions:** Toggle aktif/nonaktif, Edit (→ `/templates/:id/edit`), Delete (→ konfirmasi dialog)
- **Delete guard:** 409 `CONFLICT` → toast "Template tidak bisa dihapus karena sudah digunakan dalam transaksi. Nonaktifkan saja."

#### Template Create — Upload & Crop (FEAT-OD-04.2)
- **Route:** `/templates/create` (step 1 dari wizard 2-step)
- **Upload:** Drag-drop / click-to-upload; accept JPG/PNG, max 5MB
- **Crop:** `react-image-crop` — free-form crop (default 2:3 ratio)
- **Output:** Scale ke `OUTPUT_WIDTH = 576px` via hidden canvas → `{ dataUrl, width: 576, height }`
- **100% client-side** — tidak ada server call di step ini

#### Template Canvas Editor (FEAT-OD-04.3)
- **Route:** `/templates/create` (step 2) atau `/templates/:id/edit`
- **Layout:** Split-pane — canvas kiri (flexible), tools panel kanan (280px fixed)
- **Tools panel sections:**
  1. Template Info: nama, dimensi (read-only), toggle `is_active`, override price fields (opsional)
  2. Overlay Upload: PNG transparent layer (opsional)
  3. Add Element: "Photo Slot" + "Text" buttons (Image & Shape → v2.0)
  4. Elements List: sorted by `sequence`, klik untuk select, delete per item
  5. Selected Element Properties: properties sesuai tipe
- **Canvas toolbar:** Zoom in/out/fit, snap toggle, preview toggle
- **Save:** Create → upload background + `POST /owner/templates` + elements; Edit → `PATCH /owner/templates/:id` + CRUD elements
- **Note:** "Perubahan template terlihat di kiosk setelah sync ulang (startup berikutnya / manual sync)."

#### Konva Canvas — Element Editor (FEAT-OD-04.4)
- **Canvas:** Konva Stage + Layer — dynamic import `ssr: false`
- **Element types:**
  - `photo_slot` → Rect dashed border (stroke: `#3b82f6`, dash: `[10, 5]`), label "Slot {sequence}"
  - `text` → Konva.Text dengan full font properties
  - `image` → Konva.Image (v2.0)
  - `shape` → Rect/Circle/Line (v2.0)
- **Transformer:** Drag (x, y), resize (min 20×20), rotate (snap 15°)
- **Snap-to-center:** Vertical & horizontal center guides (red dashed, threshold 8px)
- **Zoom:** In (×1.2) / Out (×0.8) / Fit-to-screen; range 0.1–3.0
- **Selected element properties:**
  - Common: x, y, width, height, rotation, opacity, sequence
  - photo_slot: `borderRadius`, `borderWidth`, `borderColor`
  - text: content (with `{{variable}}` insert), fontFamily (5 options), fontSize, fontWeight, color, textAlign, letterSpacing
- **Preview mode:** Resolve `{{variable}}` dengan dummy data; photo_slots → placeholder image; transformer hidden

#### Template Variable System

12 variabel yang bisa disisipkan di text element:

| Variable | Kategori | Contoh |
|----------|----------|--------|
| `{{tanggal}}` | Waktu | 02 Maret 2026 |
| `{{waktu}}` | Waktu | 14:30 |
| `{{tanggal_waktu}}` | Waktu | 02/03/2026 14:30 |
| `{{order_id}}` | Transaksi | MEM-1709382400-a1b2c3 |
| `{{kiosk_name}}` | Kiosk | Booth Utama |
| `{{template_name}}` | Template | Classic Frame |
| `{{print_qty}}` | Transaksi | 2 |
| `{{total_amount}}` | Transaksi | Rp 50.000 |
| `{{payment_method}}` | Transaksi | CASH |
| `{{customer_name}}` | Customer | — |
| `{{customer_phone}}` | Customer | — |
| `{{customer_email}}` | Customer | — |

### 6.6 Transaction History (FEAT-OD-05.1)

- **Route:** `/transactions`
- **Tabel kolom:** Tanggal, Order ID, Kiosk, Template, Qty Print, Digital Copy (icon), Metode Bayar, Total (Rupiah), Status (badge)
- **Filters:** Dropdown kiosk, status (PENDING/PAID/FAILED), payment method; date range picker; search by order_id (debounce 300ms)
- **Filter behavior:** Re-fetch on change; filters persisted di URL query params; clear filters button
- **Pagination:** "Halaman X dari Y" + previous/next; items per page: 10/25/50
- **Status badges:** PAID=hijau, PENDING=kuning, FAILED=merah
- **Detail row:** Klik baris → expand detail semua field + harga snapshot + link session foto
- **Empty states:** "Belum ada transaksi" / "Tidak ada transaksi yang cocok"
- **Sorted:** `created_at DESC` (terbaru di atas)

### 6.7 Wallet & Finance (FEAT-OD-06.1, 06.2)

#### Wallet Balance & Mutation History (FEAT-OD-06.1)
- **Route:** `/wallet`
- **Kartu saldo:** Font besar, format Rupiah, icon wallet
- **Tabel mutasi:** Tanggal, Kategori (badge), Deskripsi, Amount (hijau "+" CREDIT / merah "-" DEBIT), Saldo Setelah
- **Kategori labels:** "Pendapatan Transaksi" (TRANSACTION_INCOME), "Penarikan" (WITHDRAWAL), "Penyesuaian" (ADJUSTMENT)
- **Paginated** — same pattern as transactions

#### Withdrawal Request (FEAT-OD-06.2)
- **Trigger:** Tombol "Request Withdrawal" di `/wallet` — disabled jika saldo = 0 atau ada PENDING withdrawal
- **Form (modal):**
  - Jumlah penarikan (Rupiah), nama bank, nomor rekening, nama pemilik rekening
  - Client-side validation: semua terisi, jumlah > 0, jumlah ≤ saldo
- **API:** `POST /owner/withdrawals`
- **Error handling:**
  - 400 `BELOW_MINIMUM` → toast "Jumlah minimal withdrawal adalah Rp {amount}"
  - 400 `INSUFFICIENT_BALANCE` → toast "Saldo tidak mencukupi"
  - 409 `PENDING_WITHDRAWAL_EXISTS` → toast "Masih ada withdrawal yang sedang diproses"
- **Withdrawal history table:** Tanggal, Jumlah, Bank Tujuan, Status (badge), Tanggal Diproses
- **Status:** PENDING=kuning "Menunggu", PROCESSED=hijau "Diproses", REJECTED=merah "Ditolak"
- **REJECTED:** Expand row → `rejection_note`

### 6.8 Subscription Management (FEAT-OD-07.1, 07.2)

#### Active Subscription & Invoice History (FEAT-OD-07.1)
- **Route:** `/subscription`
- **Kartu subscription:** Nama tier, max kiosk, billing period, harga paid (Rupiah), periode (start—end), sisa hari, status badge
- **Warning colors:** Sisa hari < 7 → kuning; < 3 → merah
- **Actions:** "Perpanjang" (renewal same plan), "Upgrade Plan" (pilih plan lebih tinggi)
- **Invoice history table:** Periode, Amount, Billing Period, Metode, Status (badge), Tanggal Bayar
- **Invoice status:** PAID=hijau "Lunas", PENDING=kuning "Menunggu Pembayaran", FAILED=merah "Gagal"

#### Invoice Payment Check (FEAT-OD-07.2)
- **Trigger:** Tombol "Cek Status Pembayaran" pada invoice PENDING
- **API:** `POST /owner/subscription/invoices/:id/check-payment`
- **Results:**
  - `PAID` → badge→"Lunas"; toast sukses; refresh subscription card
  - `PENDING` → toast "Pembayaran belum terdeteksi, coba lagi dalam beberapa saat"
  - `FAILED` → badge→"Gagal"; toast; opsi "Buat Invoice Baru"

---

## 7. UI/UX Guidelines

### 7.1 Design System

| Aspek | Spesifikasi |
|-------|------------|
| Color palette | Zinc monochrome (shadcn/ui default new-york variant) |
| Typography | Inter font family via `next/font/google` |
| Spacing | Tailwind default scale (4px base unit) |
| Breakpoints | 768px (mobile), 1024px (tablet), 1280px (desktop) |
| Max content width | `max-w-6xl` (1152px) centered |
| Sidebar | Collapsible, 240px expanded / icon-only collapsed |
| Status badges | Color-coded: PAID/ACTIVE/PROCESSED=green, PENDING=yellow, FAILED/EXPIRED/REJECTED=red |
| Currency format | `Rp X.XXX.XXX` (id-ID locale, no decimals) |
| Date format | `dd MMMM yyyy` (id-ID locale) — e.g., "02 Maret 2026" |
| DateTime format | `dd MMMM yyyy, HH:mm` — e.g., "02 Maret 2026, 14:30" |
| Locale | `id-ID` everywhere |

### 7.2 Responsive Strategy

| Viewport | Behavior |
|----------|----------|
| ≥ 1280px (desktop) | Sidebar expanded, grid 3-4 columns, full editor |
| 768–1279px (tablet) | Sidebar collapsed, grid 2 columns, editor usable |
| < 768px (mobile) | Sidebar hidden (hamburger), grid 1 column, editor NOT available |

### 7.3 Accessibility

- Lighthouse Accessibility target: ≥ 90
- All forms: proper `<label>`, aria attributes, keyboard navigation
- Color contrast compliance (WCAG AA)
- Focus indicators pada interactive elements
- Semantic HTML elements

---

## 8. State Management

| Kategori | Pendekatan |
|----------|-----------|
| Server state (API) | **TanStack Query** — caching, revalidation, `useMutation` + `invalidateQueries`, optimistic updates, devtools |
| Form state | **react-hook-form** + **Zod** resolver — uncontrolled forms, schema validation, shadcn/ui `<Form>` integration |
| Template editor state | `useState` + `useReducer` lokal (elemen, selectedElement, zoom, tool mode) |
| Auth state | `AuthProvider` context (`auth-provider.tsx`) — user, subscription, login/logout/refresh |
| UI state (sidebar, modals) | `useState` lokal, shadcn/ui `SidebarProvider` |

---

## 9. Error Handling & Loading States

### 9.1 Error Handling Pattern

| HTTP Status | Error Code | Frontend Behavior |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Field-level error di form |
| 400 | `INSUFFICIENT_BALANCE` | Toast "Saldo tidak mencukupi" |
| 400 | `BELOW_MINIMUM` | Toast "Jumlah di bawah minimum withdrawal" |
| 401 | `UNAUTHORIZED` | Auto: clear token → redirect `/login` |
| 403 | `FORBIDDEN` / `MAX_KIOSKS_REACHED` | Toast + disable tombol relevan |
| 404 | `NOT_FOUND` | Redirect ke list page + toast |
| 409 | `CONFLICT` / `PENDING_WITHDRAWAL_EXISTS` | Toast pesan spesifik |
| 422 | `UNPROCESSABLE_ENTITY` | Toast pesan spesifik |
| 429 | `RATE_LIMITED` | Toast "Terlalu banyak percobaan" |
| 500 | `INTERNAL_SERVER_ERROR` | Toast generik "Terjadi kesalahan, coba lagi nanti" |

### 9.2 Loading States Pattern

| Komponen | Loading State |
|----------|-------------|
| Stat cards (dashboard) | `Skeleton` card rectangles |
| Table rows (transactions, mutations, invoices) | `Skeleton` row placeholders |
| Grid cards (kiosks, templates) | `Skeleton` card grid |
| Balance card (wallet) | `Skeleton` large text |
| Subscription card | `Skeleton` info card |
| Forms (submit) | Button disabled + spinner |

### 9.3 Empty States

| Page | Empty State Message |
|------|-------------------|
| Kiosks | "Belum ada kiosk. Tambahkan kiosk pertama Anda." |
| Templates | "Belum ada template. Buat template pertama Anda." |
| Transactions | "Belum ada transaksi" / "Tidak ada transaksi yang cocok" (filter) |
| Wallet mutations | "Belum ada mutasi" |
| Withdrawals | "Belum ada withdrawal" |

---

## 10. Security

| Aspek | Implementasi |
|-------|-------------|
| XSS prevention | React auto-escaping; no `dangerouslySetInnerHTML` |
| Input validation | Client-side sebagai UX aid; backend source of truth |
| File upload | Validasi MIME (JPG/PNG) + size (5MB) sebelum upload |
| JWT handling | Token di localStorage; auto-clear saat 401; tidak log ke console |
| API URL | Via `NEXT_PUBLIC_API_URL` env var, bukan hardcode |
| Sensitive data | Tidak display `device_token`, `password_hash`, atau internal IDs |
| 401 auto-handle | `apiFetch()` di `lib/api.ts` auto-clear + redirect login |
| Refresh token | Via HttpOnly cookie; `credentials: 'include'` pada auth requests |

---

## 11. Performance

| Optimization | Detail |
|---|---|
| Code splitting | Next.js automatic per-route splitting |
| Dynamic import | Konva canvas `ssr: false` (tidak load di server) |
| Image optimization | `next/image` untuk static assets; template backgrounds via Supabase URL |
| Font optimization | `next/font/google` (Inter) — auto-subsetting, no layout shift |
| Canvas performance | Target 60fps; Konva `destroy()` saat unmount; throttle transformer events jika perlu |
| Lazy loading | Non-critical components lazy loaded (modals, heavy editors) |
| API parallel fetch | Dashboard home: 4 fetch calls in parallel |
| Search debounce | 300ms debounce pada search input fields |

---

## 12. Testing Strategy

| Layer | Target | Approach |
|-------|--------|----------|
| Component | shadcn/ui components, forms, cards | Vitest + React Testing Library |
| Page | Routing, data display, filters | E2E or integration tests |
| Template editor | Konva canvas interaction | Manual testing (canvas sulit di-automate) |
| Auth flow | Login, redirect, token refresh | Integration test |
| API integration | Error handling, response mapping | Mock API tests |

---

## 13. Deployment

| Aspek | Detail |
|-------|--------|
| Platform | **Vercel** (Next.js native support) |
| Build | `npm run build` → automatik oleh Vercel |
| Preview | Vercel preview deployments per PR |
| Environment vars | `NEXT_PUBLIC_API_URL` — backend API base URL |
| Domain | Terpisah dari admin dashboard |

---

## 14. Business Rules & Edge Cases

| Area | Rule |
|------|------|
| **Data isolation** | Semua query di backend di-scope by `owner_id` dari JWT, owner tidak bisa akses data owner lain |
| **Subscription expired** | Halaman operasional (kiosks, templates) menampilkan banner lock + tombol disabled. Owner hanya bisa akses wallet dan subscription |
| **Max kiosks** | Tombol "Tambah Kiosk" disabled saat jumlah kiosk aktif ≥ `plan.max_kiosks` |
| **Template sync delay** | Perubahan template belum terasa di kiosk sampai sync ulang — tampilkan note di editor |
| **File upload** | Validasi client-side: max 5MB, JPG/PNG only. Apply juga untuk element `image` uploads |
| **Immutable price snapshot** | Transaksi menyimpan harga pada saat transaksi — display di detail sebagai "Harga saat transaksi" |
| **Single PENDING withdrawal** | Tombol withdrawal disabled jika ada withdrawal PENDING; tooltip menjelaskan |
| **Photo slot minimum** | Template wajib minimal 1 `photo_slot` — tolak delete yang terakhir |
| **Unique `captureOrder`** | Setiap `photo_slot` wajib punya `captureOrder` (integer), tidak boleh duplikat dalam template |
| **Template delete guard** | Tolak delete template yang punya transaksi (409 CONFLICT); sarankan nonaktifkan |

---

## 15. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigasi |
|------|-----------|--------|----------|
| Konva SSR incompatibility | LOW | HIGH | Dynamic import `ssr: false` sudah diimplementasi |
| Template editor slow dengan banyak elemen | MEDIUM | MEDIUM | Limit elemen per template (max 50); Konva caching |
| Backend API belum ready saat integration | MEDIUM | HIGH | MSW / API mock layer; backend PRD sudah final |
| Token expiry mid-session | MEDIUM | LOW | `apiFetch` auto-refresh; fallback redirect login saat 401 |
| Large file upload timeout | LOW | LOW | Client-side size validation (5MB); progress indicator |
| Browser compatibility (Canvas API) | LOW | MEDIUM | Konva cross-browser; minimum Chrome 90+, Firefox 90+, Safari 15+ |

---

## 16. Open Issues

| ID | Issue | Impacted Features | Status |
|----|-------|-------------------|--------|
| OI-01 | Photo slot capture order | FEAT-OD-04.3, 04.4 | ✅ **Resolved:** `captureOrder` field terpisah di JSONB properties |
| OI-02 | Payment Gateway | FEAT-OD-01.2, 07.1, 07.2 | ✅ **Resolved:** Xendit |
| DF-01 | Data fetching library | Semua features fetch data | ✅ **Resolved: TanStack Query** (mutation-heavy dashboard, built-in optimistic updates, devtools) |
| DF-02 | Form library | FEAT-OD-03.2, 06.2, 04.3 | ✅ **Resolved: Zod + react-hook-form** (backend Zod alignment, shadcn/ui integration, performance) |
| DF-03 | Auth token storage | Semua API calls | ✅ **Resolved:** localStorage |

---

## 17. Roadmap

### MVP (v1.0) — UI Complete ✅
- Semua 8 halaman dashboard dengan polished UI
- Template editor fully functional (upload, crop, Konva canvas, drag/resize/rotate, snap, text variable, zoom, preview)
- Sidebar navigation dengan collapse
- Responsive layout (min 768px)
- Semua data dari `dummy-data.ts`
- UI text dalam Bahasa Indonesia; formatting helpers (Rupiah, date, datetime)

### v1.1 — API Integration 🔄
- ✅ API client wrapper, auth API functions, auth context provider, TypeScript interfaces
- ✅ Data fetching library resolved: **TanStack Query**
- ✅ Form library resolved: **Zod + react-hook-form**
- **Remaining:** Setup TanStack Query provider, wire semua halaman ke API, implementasi Zod schemas per form, onboarding flow, real CRUD, hapus `dummy-data.ts`, update types ke camelCase

### v1.2 — Polish & UX
- Skeleton loaders, error states, optimistic updates, toast notifications
- Pagination controls, konfirmasi dialog, form reset, breadcrumb navigation

### v2.0 — Feature Complete
- Template edit route, Image & shape element types
- Advanced transaction filters, analytics charts
- Withdrawal timeline view, subscription upgrade comparison
- Keyboard shortcuts (Ctrl+Z, Delete), Export CSV/PDF

---

## 18. Changelog

| Tanggal | Versi | Perubahan |
|---------|-------|-----------|
| 2026-03-05 | 0.1 | Initial skeleton created |
| 2026-03-06 | 1.0 | Full draft — synthesized dari referensi frontend (reference3/PRD.md, reference3/FEATURES.md, reference1/memoir_APP_owner-dashboard.md) dan PRD-00/PRD-01 untuk alignment. OI-01 & OI-02 resolved. Context7 Next.js 16 best practices applied. |
| 2026-03-06 | 1.1 | Resolved DF-01 (TanStack Query) & DF-02 (Zod + react-hook-form). Added WIP notes to API Response Shape Reference (section 5.3) and Endpoint Mapping (section 5.2) — will be updated alongside backend implementation. |

# PRD-03: Dashboard Super Admin (Web)

> **Versi:** 1.0
> **Tanggal:** 6 Maret 2026
> **Status:** Draft — For Review
> **Audiens:** Internal dev team & AI coding agents
> **Parent:** [PRD-00-master.md](./PRD-00-master.md) (Platform Overview)
> **Backend:** [PRD-01-backend-api.md](./PRD-01-backend-api.md) (Backend API)

---

## 1. Executive Summary

### 1.1 Problem Statement

Tim internal memoir. membutuhkan dashboard admin terpusat untuk mengelola seluruh operasi platform: onboarding owner baru, mengelola tier subscription plan, memproses withdrawal requests, dan memonitor transaksi lintas semua owner. Tanpa dashboard ini, manajemen platform harus dilakukan langsung via database queries.

### 1.2 Proposed Solution

**memoir. Super Admin Dashboard** adalah aplikasi web **Next.js 16 (App Router)** yang terpisah dari Owner Dashboard URL dan deployment independen. Dashboard menyediakan:

- **Owner Management** : CRUD akun studio owner, assign plan, soft-delete
- **Subscription Plan Management** : CRUD tier langganan (nama, pricing, max kiosks)
- **Platform Config** : Key-value settings (grace period, minimum withdrawal, default plan)
- **Withdrawal Processing** : Approve / reject withdrawal requests dengan audit trail
- **Transaction Monitoring** : Read-only view semua transaksi lintas owner

Dashboard berkomunikasi dengan memoir. Backend API (`/api/v1/admin/*` dan `/api/v1/auth/*`) menggunakan JWT auth dengan role `platform_admin`. Semua endpoint admin memerlukan `requireRole('platform_admin')` middleware di backend.

### 1.3 Success Criteria

| # | KPI | Target | Cara Ukur |
|---|-----|--------|-----------|
| 1 | **Withdrawal processing time** | < 2 menit dari buka detail sampai approve/reject | Manual testing |
| 2 | **Page load time** | LCP < 2.5s untuk semua halaman | Lighthouse |
| 3 | **Data accuracy** | 0 error saldo setelah withdrawal approval | Integration test |
| 4 | **Onboarding owner** | < 3 menit dari mulai form sampai owner bisa login | Manual testing |

---

## 2. User Experience & Functionality

### 2.1 User Persona

#### P1 — Platform Admin

Satu-satunya persona yang menggunakan Super Admin Dashboard. Tim internal memoir. yang bertanggung jawab atas operasional platform:

- Login menggunakan email & password (role `platform_admin` di JWT payload)
- Mengelola owner accounts, subscription plans, dan platform settings
- Memproses withdrawal requests (approve/reject)
- Memonitor transaksi lintas owner untuk troubleshooting
- Jumlah user sedikit (1-5 admin) — tidak ada kebutuhan high concurrency

### 2.2 Feature Index

| Feature | ID | Priority | Deskripsi |
|---------|------|----------|-----------|
| Admin Login | FEAT-SA-01 | P0 | Login admin dengan role guard |
| Dashboard Home | FEAT-SA-02 | P0 | Ringkasan metrik platform |
| Owner Management | FEAT-SA-03 | P0 | CRUD studio owner |
| Subscription Plan Management | FEAT-SA-04 | P0 | CRUD tier plan |
| Platform Config | FEAT-SA-05 | P0 | Key-value config editor |
| Withdrawal Processing | FEAT-SA-06 | P0 | Approve / reject withdrawals |
| Transaction Monitoring | FEAT-SA-07 | P0 | Read-only cross-owner transactions |

### 2.3 Non-Goals

| # | Non-Goal | Alasan |
|---|----------|--------|
| NG-01 | Owner Dashboard features | Aplikasi terpisah (PRD-02) |
| NG-02 | Template / kiosk management | Dikelola oleh owner via Owner Dashboard |
| NG-03 | Direct wallet balance editing | Hanya via `wallet_mutations` (ADJUSTMENT) |
| NG-04 | Auto-email notification ke owner | Manual komunikasi (WhatsApp/email) di luar sistem |
| NG-05 | Analytics / charts | MVP: raw data tables only |
| NG-06 | Audit log halaman terpisah | Audit via `updated_by` field di platform_config dan withdrawal |
| NG-07 | Multi-admin role / permissions | MVP: semua admin punya akses penuh |
| NG-08 | Dark mode | Tidak prioritas untuk MVP |
| NG-09 | Export CSV / PDF | Tidak ada export di MVP |
| NG-10 | Push notification / WebSocket | MVP: request-response only |

---

## 3. Technical Specifications

### 3.1 Architecture Overview

```
┌───────────────────────────────────────────────────────────────┐
│                      Next.js App Router                       │
│                                                               │
│  Route Groups:                                                │
│    (auth)/     → /login                                       │
│    (dashboard)/ → /, /owners, /plans, /config,                │
│                   /withdrawals, /transactions                 │
│                                                               │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐     │
│  │   Server    │  │   Client     │  │   Shared          │     │
│  │  Components │  │  Components  │  │                   │     │
│  │             │  │              │  │  lib/api.ts       │     │
│  │  page.tsx   │  │  Forms       │  │  lib/auth-api.ts  │     │
│  │  layout.tsx │  │  Modals      │  │  lib/types.ts     │     │
│  │             │  │  Filters     │  │  lib/format.ts    │     │
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
│  │  Context: user (role=platform_admin)     │                 │
│  │  Route protection + role guard           │                 │
│  └──────────────────────────────────────────┘                 │
│                     │                                         │
└─────────────────────┼─────────────────────────────────────────┘
                      │ HTTPS
                      ▼
              memoir. Backend API
              /api/v1/admin/*
              /api/v1/auth/*
```

### 3.2 Tech Stack

| Layer | Technology | Version | Catatan |
|---|---|---|---|
| Framework | **Next.js** (App Router) | 16.1.6 | Stack identik dengan Owner Dashboard |
| UI Library | **React** | 19.2.3 | — |
| Language | **TypeScript** | 5.x | Strict mode |
| Styling | **Tailwind CSS** | 4.x | Utility-first |
| Component Library | **shadcn/ui** | 3.8.5 | Radix UI primitives |
| Icons | **lucide-react** | 0.575.0 | Consistent icon set |
| Data Fetching | **TanStack Query** (React Query) | 5.x | Server state caching, mutations |
| Form Validation | **Zod** + **react-hook-form** | zod 3.x / rhf 7.x | Schema validation |
| CSS Utilities | clsx + tailwind-merge | latest | `cn()` helper |
| API Client | Native `fetch()` wrapper | — | `lib/api.ts` (shared pattern dengan PRD-02) |
| Package Manager | npm | — | — |

> **Catatan:** Tech stack identik dengan Owner Dashboard (PRD-02) namun deployment dan repository terpisah. Potensi shared component library di masa depan.

### 3.3 Route Map

| Route | Auth | Page Title | Deskripsi |
|---|:---:|---|---|
| `/login` | ❌ | Login Admin | Login form, role guard `platform_admin` |
| `/` | ✅ | Dashboard | Platform metrics overview |
| `/owners` | ✅ | Studio Owner | Owner list + CRUD |
| `/owners/:id` | ✅ | Detail Owner | Owner detail + kiosks + transactions + wallet |
| `/plans` | ✅ | Subscription Plans | Plan list + CRUD |
| `/config` | ✅ | Platform Config | Key-value config editor |
| `/withdrawals` | ✅ | Penarikan | Withdrawal list + approve/reject |
| `/transactions` | ✅ | Transaksi | Cross-owner transaction monitoring |

### 3.4 Project Structure

```
src/
├── app/
│   ├── globals.css
│   ├── layout.tsx              # Root layout: Inter font, AuthProvider
│   ├── (auth)/
│   │   └── login/
│   │       └── page.tsx        # Admin login form
│   ├── (dashboard)/
│   │   ├── layout.tsx          # Sidebar + main content wrapper
│   │   ├── page.tsx            # Dashboard home (metrics)
│   │   ├── owners/
│   │   │   ├── page.tsx        # Owner list
│   │   │   └── [id]/
│   │   │       └── page.tsx    # Owner detail
│   │   ├── plans/
│   │   │   └── page.tsx        # Subscription plan list
│   │   ├── config/
│   │   │   └── page.tsx        # Platform config editor
│   │   ├── withdrawals/
│   │   │   └── page.tsx        # Withdrawal list
│   │   └── transactions/
│   │       └── page.tsx        # Transaction monitoring
├── components/
│   ├── app-sidebar.tsx         # Admin sidebar navigation
│   ├── auth-provider.tsx       # Auth context + role guard (platform_admin)
│   └── ui/                     # shadcn/ui components
├── hooks/
│   └── use-mobile.ts
└── lib/
    ├── api.ts                  # API client (fetch wrapper, token mgmt)
    ├── auth-api.ts             # Auth functions (login, logout)
    ├── types.ts                # TypeScript interfaces (admin-specific)
    ├── format.ts               # Rupiah, date formatters
    └── utils.ts                # cn() utility
```

---

## 4. Authentication & Access Control

### 4.1 Auth Flow

```
Login  → decode JWT → check role=platform_admin → setUser → redirect /
Mount  → check localStorage token → decode → role check → route protect
401    → try refresh → if fail, clear token → redirect /login
403    → role mismatch → redirect /login + toast "Akses tidak diizinkan"
```

### 4.2 Auth Details

| Aspek | Implementasi |
|-------|-------------|
| Login endpoint | `POST /api/v1/auth/login` — endpoint yang sama dengan owner |
| Role check | Decode JWT payload `{ id, role }` → reject jika `role !== 'platform_admin'` → 403 |
| Token storage | `accessToken` di `localStorage`; `refresh_token` via HttpOnly cookie |
| Route protection | `AuthProvider` — redirect `/login` jika token absent/expired/role mismatch |
| Session expiry | Access token short-lived; admin harus re-login setelah inaktivitas yang lama |

---

## 5. API Integration

### 5.1 API Client

- **Base URL:** `NEXT_PUBLIC_API_URL` env var
- **Response format:** `{ data: ... }` sukses · `{ error: "CODE", message: "..." }` error · `{ data: [...], meta: { page, limit, total } }` paginated
- **Field naming:** Backend menggunakan `camelCase`

### 5.2 Endpoint Mapping per Page

> [!NOTE]
> **📋 Dokumentasi API terpisah belum dibuat.** Endpoint mapping di bawah ini berdasarkan PRD-01 dan akan di-update seiring backend selesai dibangun.

| Frontend Page | API Endpoint(s) |
|---|---|
| Login | `POST /auth/login` (shared with owner) |
| Dashboard Home | `GET /admin/owners` (count), `GET /admin/withdrawals` (count PENDING), `GET /admin/transactions` (count today) |
| Owners | `GET /admin/owners`, `POST /admin/owners`, `PATCH /admin/owners/:id` |
| Owner Detail | `GET /admin/owners/:id` (+ kiosks, transactions, wallet data — via owner ID scoped endpoints or dedicated admin endpoint) |
| Plans | `GET/POST /admin/subscription-plans`, `PATCH /admin/subscription-plans/:id` |
| Config | `GET /admin/platform-config`, `PATCH /admin/platform-config/:id` |
| Withdrawals | `GET /admin/withdrawals`, `POST /admin/withdrawals/:id/approve`, `POST /admin/withdrawals/:id/reject` |
| Transactions | `GET /admin/transactions` (paginated + filtered) |

### 5.3 API Response Shape Reference

> [!WARNING]
> **⏳ Response shape di bawah ini bersifat preliminary.** Akan di-update seiring backend selesai dibangun.

#### Owner List Item
```json
{
  "id": "uuid", "email": "owner@example.com",
  "name": "Studio Andi", "role": "studio_owner",
  "walletBalance": 1500000, "deletedAt": null,
  "createdAt": "ISO8601"
}
```

#### Subscription Plan
```json
{
  "id": "uuid", "name": "Pro", "description": "...",
  "maxKiosks": 3, "priceMonthly": 249000, "priceYearly": 2490000,
  "isActive": true, "createdAt": "ISO8601"
}
```

#### Withdrawal
```json
{
  "id": "uuid", "amount": 500000, "status": "PENDING",
  "bankName": "BCA", "bankAccountNumber": "1234567890",
  "bankAccountName": "Andi", "rejectionNote": null,
  "processedAt": null, "createdAt": "ISO8601",
  "owner": { "id": "uuid", "email": "owner@example.com", "walletBalance": 1500000 }
}
```

#### Platform Config
```json
{
  "id": "uuid", "key": "grace_period_days",
  "value": "7", "description": "Jumlah hari grace period",
  "updatedBy": "uuid", "updatedAt": "ISO8601"
}
```

---

## 6. Features & Pages

### 6.1 Admin Login (FEAT-SA-01)

- **Route:** `/login`
- **Form:** Email + password → `POST /api/v1/auth/login`
- **Role guard:** Setelah decode JWT, cek `role === 'platform_admin'`. Jika bukan → toast "Akses tidak diizinkan" + redirect
- **Error handling:** 401 → "Email atau password salah"; 429 → "Terlalu banyak percobaan"
- **Out of scope:** OAuth, 2FA, self-registration admin (dibuat manual di DB)

### 6.2 Dashboard Home (FEAT-SA-02)

- **Route:** `/`
- **Deskripsi:** Ringkasan kondisi platform saat ini dalam stat cards
- **5 Stat Cards:**

| Metrik | Deskripsi | Sumber Data |
|--------|-----------|-------------|
| Studio Owner Aktif | Jumlah owner dengan subscription ACTIVE | `GET /admin/owners` (count filtered) |
| Owner Expired / Grace | Jumlah owner dengan status EXPIRED/GRACE_PERIOD | `GET /admin/owners` (count filtered) |
| Transaksi Hari Ini | Total transaksi semua owner hari ini | `GET /admin/transactions` (filter today) |
| Withdrawal Pending | Jumlah withdrawal menunggu diproses | `GET /admin/withdrawals` (count PENDING) |
| Total Saldo Platform | Agregat wallet balance seluruh owner | `GET /admin/owners` (sum walletBalance) |

- **Loading:** Skeleton loaders pada semua stat cards
- **Tidak ada grafik / analytics di MVP** — hanya angka summary

### 6.3 Owner Management (FEAT-SA-03)

#### Owner List (`/owners`)

- **Tabel kolom:** Email, Nama, Tanggal Daftar, Plan Aktif, Status Subscription (badge), Jumlah Kiosk, Saldo Wallet (Rupiah)
- **Filters:**
  - Status subscription: ACTIVE / GRACE_PERIOD / EXPIRED / Semua
  - Search by email (debounce 300ms)
- **Actions:** Tombol "Buat Owner Baru"
- **Row click:** Navigasi ke `/owners/:id`
- **Pagination:** Standard (10/25/50 per page)
- **Status badges:** ACTIVE=hijau, GRACE_PERIOD=kuning, EXPIRED=merah, CANCELLED=abu-abu

#### Create Owner (Modal)

- **Trigger:** Tombol "Buat Owner Baru"
- **Form fields:**
  - Email (required, validasi format email)
  - Password sementara (required, min 8 karakter)
  - Nama (optional)
- **API:** `POST /admin/owners` → `{ email, password, name }`
- **Success:** Toast "Owner berhasil dibuat"; refresh list; tampilkan reminder: "Kirimkan password sementara ke owner via WhatsApp/email"
- **Error:** 409 `CONFLICT` (email sudah ada) → toast "Email sudah terdaftar"

> **Catatan:** Tidak ada sistem kirim email otomatis — password sementara dikomunikasikan manual.

#### Owner Detail (`/owners/:id`)

- **Info dasar:** Email, nama, tanggal daftar, status subscription, plan aktif, `current_period_end`, saldo wallet
- **Daftar kiosk:** Nama, status aktif, tanggal paired
- **Histori transaksi terbaru:** 10 transaksi terakhir (tabel mini)
- **Saldo wallet + 10 mutasi terakhir:** Balance card + tabel mutasi
- **Info withdrawal PENDING:** Jika ada, tampilkan info dengan link ke `/withdrawals`
- **Action:** Tombol "Nonaktifkan Owner" → konfirmasi dialog → `PATCH /admin/owners/:id` dengan `{ deletedAt: now() }`
  - Pesan konfirmasi: "Owner tidak akan bisa login setelah dinonaktifkan. Data histori tetap tersimpan."
  - Success: Badge "Nonaktif" + toast sukses

### 6.4 Subscription Plan Management (FEAT-SA-04)

#### Plan List (`/plans`)

- **Tabel kolom:** Nama Tier, Max Kiosk, Harga Bulanan (Rupiah), Harga Tahunan (Rupiah), Status (badge Aktif/Nonaktif), Jumlah Owner Pengguna
- **Actions:** Tombol "Buat Plan Baru", Edit per row, Toggle aktifkan/nonaktifkan

#### Create Plan (Modal)

- **Form fields:**
  - Nama tier (required)
  - Deskripsi (optional)
  - Max kiosks (required, integer > 0)
  - Harga bulanan (required, Rupiah, > 0)
  - Harga tahunan (required, Rupiah, > 0)
- **API:** `POST /admin/subscription-plans`
- **Default:** `isActive = true`

#### Edit Plan (Modal)

- **Semua field bisa diubah** (nama, deskripsi, max kiosks, harga bulanan, harga tahunan)
- **API:** `PATCH /admin/subscription-plans/:id`
- **Note:** "Perubahan harga tidak mempengaruhi subscription yang sedang berjalan — harga lama tersimpan di `price_paid`."

#### Toggle Aktif/Nonaktif

- **Nonaktifkan:** Plan tidak bisa dipilih owner baru; owner existing tidak terganggu
- **Tidak ada hard delete** — mencegah referential integrity issues
- **API:** `PATCH /admin/subscription-plans/:id` dengan `{ isActive: false }`

### 6.5 Platform Config (FEAT-SA-05)

- **Route:** `/config`
- **Tabel kolom:** Key, Value, Deskripsi, Last Updated By, Updated At
- **Edit:** Inline input atau modal per row → `PATCH /admin/platform-config/:id` dengan `{ value }`
- **Perubahan dicatat:** `updated_by` (admin ID) dan `updated_at` otomatis oleh backend

#### Mandatory Keys

| Key | Contoh Value | Deskripsi |
|---|---|---|
| `grace_period_days` | `7` | Jumlah hari toleransi setelah subscription expired |
| `minimum_withdrawal_amount` | `50000` | Minimum nominal withdrawal (Rupiah) |
| `default_plan_id` | `uuid` | Plan default yang disarankan saat owner baru |

- **Validasi:** Backend melakukan validasi tipe sesuai key — frontend menampilkan input sesuai (number untuk angka, text untuk string/UUID)
- **Tidak ada tambah/hapus key** — key diinisialisasi via seed/migration

### 6.6 Withdrawal Processing (FEAT-SA-06)

- **Route:** `/withdrawals`

#### Withdrawal List

- **Default:** Tampilkan status PENDING (sorted FIFO — terlama di atas)
- **Filter:** Status: PENDING / PROCESSED / REJECTED / Semua
- **Tabel kolom:** Tanggal Request, Email Owner, Jumlah (Rupiah), Bank Tujuan, Status (badge), Aksi
- **Status badges:** PENDING=kuning "Menunggu", PROCESSED=hijau "Diproses", REJECTED=merah "Ditolak"
- **Pagination:** Standard

#### Withdrawal Detail (Expand Row / Modal)

- **Info owner:** Email, nama, saldo wallet saat ini
- **Info request:** Jumlah diminta (Rupiah), nama bank, nomor rekening, nama pemilik rekening, tanggal request
- **Action buttons:**
  - **"Approve"** → konfirmasi dialog → `POST /admin/withdrawals/:id/approve`
  - **"Reject"** → form `rejection_note` (wajib) → `POST /admin/withdrawals/:id/reject`

#### Approve Flow

1. Admin klik "Approve" → dialog konfirmasi: "Approve withdrawal Rp {amount} untuk {owner_email}?"
2. Submit → backend:
   - Re-cek saldo owner (jika tidak cukup → 400 `INSUFFICIENT_BALANCE`)
   - Buat `wallet_mutations` DEBIT (atomic)
   - Update `wallet_balance` owner
   - Update withdrawal status → PROCESSED
3. **Success:** Badge→"Diproses"; toast "Withdrawal berhasil di-approve"
4. **Error saldo:** Toast "Saldo owner tidak mencukupi untuk withdrawal ini"

> Transfer dana ke rekening dilakukan secara manual oleh tim memoir. di luar sistem. Sistem hanya mencatat status.

#### Reject Flow

1. Admin klik "Reject" → form muncul: textarea `rejection_note` (required)
2. Submit → `POST /admin/withdrawals/:id/reject` dengan `{ rejectionNote }`
3. **Success:** Badge→"Ditolak"; toast "Withdrawal ditolak"
4. Saldo owner **tidak berubah**
5. Owner bisa melihat `rejection_note` di dashboard mereka

### 6.7 Transaction Monitoring (FEAT-SA-07)

- **Route:** `/transactions`
- **Deskripsi:** Read-only view semua transaksi lintas owner
- **Tabel kolom:** Tanggal, Order ID, Nama Owner, Nama Kiosk, Template, Metode Bayar, Total (Rupiah), Status (badge)
- **Filters:**
  - Date range picker
  - Status: PENDING / PAID / FAILED / Semua
  - Payment method: PG / CASH / STATIC_QRIS / Semua
  - Search by email owner atau order ID (debounce 300ms)
- **Tidak ada aksi** — hanya monitoring / read-only
- **Status badges:** PAID=hijau, PENDING=kuning, FAILED=merah
- **Pagination:** Standard (10/25/50)
- **Sorted:** `created_at DESC`

---

## 7. UI/UX Guidelines

### 7.1 Design System

| Aspek | Spesifikasi |
|-------|------------|
| Color palette | Zinc monochrome (shadcn/ui new-york variant) — identik dengan Owner Dashboard |
| Typography | Inter font family via `next/font/google` |
| Spacing | Tailwind default scale (4px base) |
| Breakpoints | 768px (mobile), 1024px (tablet), 1280px (desktop) |
| Sidebar | Collapsible, navigation: Dashboard, Owners, Plans, Config, Withdrawals, Transaksi |
| Status badges | Color-coded: ACTIVE/PAID/PROCESSED=green, PENDING/GRACE_PERIOD=yellow, EXPIRED/FAILED/REJECTED=red |
| Currency format | `Rp X.XXX.XXX` (id-ID locale, no decimals) |
| Date format | `dd MMMM yyyy` (id-ID) |
| DateTime format | `dd MMMM yyyy, HH:mm` |
| Locale | `id-ID` everywhere |

### 7.2 Responsive Strategy

| Viewport | Behavior |
|----------|----------|
| ≥ 1280px | Sidebar expanded, full tables |
| 768–1279px | Sidebar collapsed, tables with horizontal scroll |
| < 768px | Sidebar hidden (hamburger), tables in card view |

### 7.3 Accessibility

- Lighthouse Accessibility ≥ 90
- All forms: proper labels, aria attributes, keyboard navigation
- Focus indicators, semantic HTML, color contrast WCAG AA

---

## 8. State Management

| Kategori | Pendekatan |
|----------|-----------|
| Server state | **TanStack Query** — queries + mutations + cache invalidation |
| Form state | **react-hook-form** + **Zod** resolver |
| Auth state | `AuthProvider` context (user, role, login/logout) |
| UI state | `useState` lokal (modals, filters, expanded rows) |

---

## 9. Error Handling & Loading States

### 9.1 Error Handling

| HTTP Status | Error Code | Frontend Behavior |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Field-level error di form |
| 400 | `INSUFFICIENT_BALANCE` | Toast "Saldo owner tidak mencukupi" (saat approve withdrawal) |
| 401 | `UNAUTHORIZED` | Clear token → redirect `/login` |
| 403 | `FORBIDDEN` | Toast "Akses tidak diizinkan" → redirect `/login` |
| 404 | `NOT_FOUND` | Redirect ke list + toast |
| 409 | `CONFLICT` | Toast "Email sudah terdaftar" (create owner) / pesan spesifik lainnya |
| 429 | `RATE_LIMITED` | Toast "Terlalu banyak percobaan" |
| 500 | `INTERNAL_SERVER_ERROR` | Toast generik |

### 9.2 Loading & Empty States

| Komponen | Loading | Empty State |
|----------|---------|-------------|
| Stat cards | Skeleton rectangles | — |
| Tables (owners, plans, etc.) | Skeleton rows | "Belum ada data" |
| Withdrawal list (PENDING) | Skeleton rows | "Tidak ada withdrawal yang menunggu diproses" |
| Transaction list | Skeleton rows | "Belum ada transaksi" / "Tidak ada transaksi yang cocok" |
| Forms (submit) | Button disabled + spinner | — |

---

## 10. Security

| Aspek | Implementasi |
|-------|-------------|
| Role guard | JWT payload `role === 'platform_admin'`; frontend AuthProvider + backend `requireRole` middleware |
| XSS prevention | React auto-escaping; no `dangerouslySetInnerHTML` |
| Input validation | Client-side (Zod) sebagai UX aid; backend source of truth |
| JWT handling | Token di localStorage; auto-clear saat 401; tidak log ke console |
| Sensitive data | Tidak display `password_hash`, `device_token`, atau internal secrets |
| Refresh token | HttpOnly cookie; `credentials: 'include'` pada auth requests |
| Session timeout | Admin token short-lived; re-login jika expired |
| Owner data access | Admin bisa akses data semua owner — ini by design (platform management) |

---

## 11. Performance

| Optimization | Detail |
|---|---|
| Code splitting | Next.js per-route automatic splitting |
| Font optimization | `next/font/google` (Inter) |
| API parallel fetch | Dashboard home: 3-5 fetch calls in parallel |
| Search debounce | 300ms debounce pada search inputs |
| Table pagination | Server-side pagination (10/25/50 per page) — tidak load semua data |

---

## 12. Testing Strategy

| Layer | Target | Approach |
|-------|--------|----------|
| Component | Forms, tables, modals, badges | Vitest + React Testing Library |
| Auth | Login + role guard + redirect | Integration test |
| Withdrawal flow | Approve/reject + error handling | Integration test |
| API integration | Error codes, response mapping | Mock API tests |

---

## 13. Deployment

| Aspek | Detail |
|-------|--------|
| Platform | **Vercel** (Next.js native) |
| Build | `npm run build` |
| Preview | Vercel preview deployments per PR |
| Environment vars | `NEXT_PUBLIC_API_URL` — backend API base URL |
| Domain | **Terpisah** dari Owner Dashboard |
| Repository | **Terpisah** dari Owner Dashboard |

> Admin Dashboard dan Owner Dashboard di-deploy sebagai 2 aplikasi Next.js terpisah. Keduanya berkomunikasi ke satu Backend API yang sama.

---

## 14. Business Rules & Edge Cases

| Area | Rule |
|------|------|
| **Role enforcement** | Backend `requireRole('platform_admin')` di semua `/admin/*` endpoints — frontend juga guard |
| **No direct wallet edit** | Admin tidak bisa edit `wallet_balance` langsung — harus via `wallet_mutations` (category: ADJUSTMENT). Fitur adjustment opsional di MVP |
| **Atomic withdrawal** | Approve withdrawal: re-cek saldo → debit → update status, dalam 1 DB transaction. Jika saldo tidak cukup → tolak tanpa debit |
| **Single PENDING rule** | Satu owner max 1 withdrawal PENDING — tampilkan info ini di detail owner jika ada |
| **Plan price immutability** | Perubahan harga plan tidak retroaktif — owner existing tetap pakai `price_paid` snapshot |
| **Soft delete owner** | Set `deleted_at` — owner tidak bisa login; data histori tetap ada |
| **No hard delete plan** | Plan hanya bisa dinonaktifkan (isActive=false) — mencegah referential integrity issues |
| **Config key fixed** | Key platform_config diinisialisasi via seed; admin hanya bisa edit value, tidak tambah/hapus |
| **Manual bank transfer** | Transfer dana ke rekening dilakukan manual di luar sistem; dashboard hanya mencatat status |
| **Rejection note required** | Reject withdrawal wajib isi `rejection_note` — owner harus tahu alasan penolakan |

---

## 15. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigasi |
|------|-----------|--------|----------|
| Admin approve insufficient balance | LOW | HIGH | Backend re-cek saldo atomically; frontend display saldo sebelum approve |
| Concurrent approve same withdrawal | LOW | HIGH | Backend: DB row lock (`SELECT FOR UPDATE`) |
| Admin account compromised | LOW | HIGH | Short-lived JWT; manual credential rotation |
| Wrong owner soft-deleted | LOW | MEDIUM | Konfirmasi dialog 2-step; soft-delete reversible via DB |
| Backend API belum ready | MEDIUM | HIGH | MSW / API mock; backend PRD sudah final |
| Config value typo | LOW | MEDIUM | Backend validation per key type; tampilkan deskripsi di UI |

---

## 16. Perbedaan dengan Owner Dashboard (PRD-02)

| Aspek | Owner Dashboard (PRD-02) | Super Admin Dashboard (PRD-03) |
|-------|-------------------------|-------------------------------|
| Persona | P2 — Studio Owner | P1 — Platform Admin |
| Data scope | Hanya data milik owner | Semua data platform (cross-owner) |
| Complexity | Tinggi (template editor Konva) | Rendah-medium (CRUD tables + forms) |
| Canvas / Konva | ✅ Ya | ❌ Tidak |
| Template management | ✅ Ya (full editor) | ❌ Tidak (owner manages) |
| Kiosk management | ✅ Ya | ❌ Tidak (view only di owner detail) |
| Financial actions | Request withdrawal | Approve/reject withdrawal |
| Subscription | Subscribe/upgrade | CRUD plans |
| Number of users | Banyak (owner) | Sedikit (1-5 admin) |
| Deployment | Vercel (separate domain) | Vercel (separate domain + repo) |

---

## 17. Open Issues

| ID | Issue | Status |
|----|-------|--------|
| — | Semua open issues telah diputuskan (DF-01: TanStack Query, DF-02: Zod + react-hook-form, OI-01/OI-02: resolved) | ✅ No open issues |

---

## 18. Changelog

| Tanggal | Versi | Perubahan |
|---------|-------|-----------|
| 2026-03-05 | 0.1 | Initial skeleton created |
| 2026-03-06 | 1.0 | Full draft — synthesized dari reference1/memoir_APP_platform-admin.md, PRD-01 admin endpoints (EPIC-06), dan PRD-00 platform context. Tech stack aligned dengan PRD-02 (Next.js 16, shadcn/ui, TanStack Query, Zod + rhf). Deployment terpisah dari Owner Dashboard. |

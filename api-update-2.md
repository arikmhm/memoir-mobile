# Dokumentasi API Kiosk — Transaksi & Session

Referensi integrasi untuk developer Frontend (kiosk device).

**Base URL:** `https://<host>/api/v1/kiosk`

**Autentikasi:** Semua endpoint di dokumen ini memerlukan device token:
```
Authorization: Bearer <deviceToken>
```

**Format error umum:**
```json
{ "error": "ERROR_CODE", "message": "Deskripsi error" }
```

---

## 1. Buat Transaksi

### `POST /transactions`

Membuat transaksi baru untuk satu sesi photobooth.

**Autentikasi:** Device token (Bearer)

**Request Body (JSON):**
```json
{
  "templateId": "uuid",
  "paymentMethod": "PG",
  "transactionType": "NORMAL",
  "printQty": 2,
  "hasDigitalCopy": true,
  "totalAmount": 40000
}
```

| Field | Tipe | Keterangan |
|-------|------|------------|
| `templateId` | `string` (UUID) | ID template yang dipilih |
| `paymentMethod` | `enum` | Metode pembayaran (lihat di bawah) |
| `transactionType` | `enum` | `NORMAL` (default) atau `EVENT` |
| `printQty` | `integer ≥ 1` | Jumlah cetak |
| `hasDigitalCopy` | `boolean` | Apakah termasuk digital copy |
| `totalAmount` | `integer ≥ 0` | Total harga yang ditampilkan ke pelanggan (Rupiah) |

**Nilai `paymentMethod`:**

| Nilai | Keterangan |
|-------|------------|
| `PG` | Dynamic QRIS via payment gateway (DOKU) — menghasilkan `qrString` |
| `CASH` | Bayar tunai on-site — langsung settled saat create |
| `STATIC_QRIS` | QRIS statis milik owner — langsung settled saat create |

**Response `201 Created`:**
```json
{
  "data": {
    "transaction": {
      "id": "uuid",
      "ownerId": "uuid",
      "kioskId": "uuid",
      "templateId": "uuid",
      "orderId": "MEM-xxxxxxxx",
      "transactionType": "NORMAL",
      "status": "PENDING",
      "paymentMethod": "PG",
      "qrString": "00020101021226...",
      "paymentExpiresAt": "2025-06-01T10:30:00.000Z",
      "printQty": 2,
      "hasDigitalCopy": true,
      "appliedBasePrice": 25000,
      "appliedExtraPrintPrice": 5000,
      "appliedDigitalCopyPrice": 10000,
      "totalAmount": 40000,
      "createdAt": "2025-06-01T10:00:00.000Z",
      "paidAt": null
    }
  }
}
```

| Field | Tipe | Keterangan |
|-------|------|------------|
| `status` | `enum` | `PENDING` (PG) atau `PAID` (CASH/STATIC_QRIS, langsung settled) |
| `qrString` | `string \| null` | String QRIS untuk di-render — hanya ada jika `paymentMethod: "PG"` |
| `paymentExpiresAt` | `string \| null` | Waktu expired QRIS (ISO 8601) — hanya ada jika `paymentMethod: "PG"` |
| `appliedBasePrice` | `number` | Harga dasar saat transaksi dibuat (snapshot dari config kiosk) |
| `appliedExtraPrintPrice` | `number` | Harga extra print saat transaksi dibuat |
| `appliedDigitalCopyPrice` | `number` | Harga digital copy saat transaksi dibuat |
| `paidAt` | `string \| null` | Waktu transaksi lunas — `null` jika masih `PENDING` |

**Error:**

| Status | `error` | Penyebab |
|--------|---------|---------|
| `401` | `UNAUTHORIZED` | Device token tidak valid |
| `404` | `NOT_FOUND` | `templateId` tidak ditemukan atau bukan milik owner ini |
| `400` | `PRICE_MISMATCH` | `totalAmount` tidak sesuai kalkulasi server |
| `400` | `PAYMENT_CONFIG_REQUIRED` | Owner belum punya payment config aktif (untuk metode `PG`) |
| `422` | `VALIDATION_ERROR` | Field tidak valid (mis. `printQty < 1`) |

> **Catatan penting:**
>
> - **Validasi harga wajib di sisi server.** Server selalu re-kalkulasi `totalAmount` berdasarkan config kiosk. Jika `totalAmount` dari client tidak cocok → `400 PRICE_MISMATCH`. Rumus: `priceBaseSession + max(0, printQty - 1) × pricePerExtraPrint + (hasDigitalCopy ? priceDigitalCopy : 0)`.
> - **`CASH` dan `STATIC_QRIS` langsung `PAID`** saat response diterima — tidak perlu polling. `qrString` dan `paymentExpiresAt` akan `null`.
> - **`PG`** — DOKU dipanggil sebelum record DB dibuat. Jika DOKU gagal, tidak ada transaksi orphan di DB. Gunakan `qrString` untuk render QR code ke layar.
> - Harga di-snapshot ke `appliedBasePrice/ExtraPrintPrice/DigitalCopyPrice` saat transaksi dibuat — nilainya bisa beda dari config kiosk saat ini jika owner mengubah harga di tengah jalan.

---

## 2. Cek Status Pembayaran (PG)

### `POST /transactions/:id/check-payment`

Mengecek status pembayaran transaksi PG. Bisa dipanggil secara polling dari kiosk sambil menunggu pelanggan scan QRIS.

**Autentikasi:** Device token (Bearer)

**URL Params:**

| Param | Keterangan |
|-------|------------|
| `id` | UUID transaksi |

**Request Body:** Tidak ada

**Response `200 OK`:**
```json
{
  "data": {
    "status": "PENDING"
  }
}
```

**Nilai `status`:**

| Nilai | Arti |
|-------|------|
| `PENDING` | Belum dibayar |
| `PAID` | Lunas |
| `FAILED` | Pembayaran gagal |
| `EXPIRED` | QRIS sudah expired |

**Error:**

| Status | `error` | Penyebab |
|--------|---------|---------|
| `401` | `UNAUTHORIZED` | Device token tidak valid |
| `404` | `NOT_FOUND` | Transaksi tidak ditemukan atau bukan milik kiosk ini |
| `422` | `UNPROCESSABLE_ENTITY` | Transaksi bukan metode `PG` (CASH/STATIC_QRIS sudah settled saat create) |

> **Catatan penting:**
>
> - Endpoint ini **hanya untuk transaksi `PG`**. Memanggil untuk transaksi `CASH`/`STATIC_QRIS` akan `422`.
> - Mekanisme: pertama cek status dari DB. Jika masih `PENDING`, server secara otomatis poll DOKU sebagai fallback (antisipasi jika webhook terlewat). Jika poll DOKU juga gagal (error network/provider), response tetap `PENDING` — tidak error.
> - Status `PAID`/`FAILED`/`EXPIRED` juga bisa diterima lebih awal via webhook DOKU tanpa perlu polling — siapkan handling di sisi kiosk untuk keduanya.
> - Disarankan polling setiap 3–5 detik, bukan lebih agresif.

---

## 3. Upload Session (Digital Copy)

### `POST /sessions`

Mengupload hasil foto sesi sebagai digital copy setelah transaksi lunas.

**Autentikasi:** Device token (Bearer)

**Request:** `multipart/form-data`

| Field | Tipe | Keterangan |
|-------|------|------------|
| file | `File` | Gambar hasil sesi. Format: JPEG, PNG, atau WebP. Maks 10 MB. |
| `transactionId` | `string` (form field) | UUID transaksi yang sudah `PAID` |

Contoh dengan `fetch`:
```js
const formData = new FormData();
formData.append('file', blob, 'session.jpg');
formData.append('transactionId', 'uuid-transaksi');

fetch('/api/v1/kiosk/sessions', {
  method: 'POST',
  headers: { Authorization: `Bearer ${deviceToken}` },
  body: formData,
});
```

**Response `201 Created`:**
```json
{
  "data": {
    "session": {
      "id": "uuid",
      "transactionId": "uuid",
      "resultImageUrl": "https://cdn.example.com/sessions/...",
      "deletionScheduledAt": "2025-07-01T10:00:00.000Z",
      "createdAt": "2025-06-01T10:00:00.000Z"
    },
    "downloadUrl": "https://cdn.example.com/sessions/..."
  }
}
```

| Field | Tipe | Keterangan |
|-------|------|------------|
| `session.resultImageUrl` | `string` | URL permanen hasil upload |
| `session.deletionScheduledAt` | `string` | Waktu file dijadwalkan dihapus — 30 hari dari upload |
| `downloadUrl` | `string` | URL yang bisa langsung dibuka pelanggan (sama dengan `resultImageUrl`) |

**Error:**

| Status | `error` | Penyebab |
|--------|---------|---------|
| `401` | `UNAUTHORIZED` | Device token tidak valid |
| `400` | `VALIDATION_ERROR` | Format file tidak didukung atau ukuran > 10 MB |
| `404` | `NOT_FOUND` | Transaksi tidak ditemukan atau bukan milik kiosk ini |
| `422` | `UNPROCESSABLE_ENTITY` | Transaksi belum `PAID`, atau `hasDigitalCopy: false` pada transaksi |
| `409` | `CONFLICT` | Session untuk transaksi ini sudah pernah diupload sebelumnya |

> **Catatan penting:**
>
> - Upload session **hanya valid** jika: (1) transaksi berstatus `PAID`, dan (2) transaksi dibuat dengan `hasDigitalCopy: true`.
> - Setiap transaksi hanya boleh punya satu session — upload kedua kali ke transaksi yang sama akan `409 CONFLICT`.
> - File dihapus otomatis 30 hari setelah upload (`deletionScheduledAt`). Informasikan ini ke pelanggan jika relevan.
> - Format yang diterima: `image/jpeg`, `image/png`, `image/webp`.
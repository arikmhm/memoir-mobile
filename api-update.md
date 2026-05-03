# Dokumentasi API Kiosk — memoir.

Referensi integrasi untuk developer Frontend (kiosk device).

**Base URL:** `https://<host>/api/v1/kiosk`

**Format error umum:**
```json
{ "error": "ERROR_CODE", "message": "Deskripsi error" }
```

**Autentikasi device token:**
Endpoint yang memerlukan device token menggunakan header:
```
Authorization: Bearer <deviceToken>
```
Token diperoleh dari endpoint `/pair`.

---

## 1. Kiosk Pairing

### `POST /pair`

Melakukan pairing antara device dengan kiosk menggunakan pairing code 6 digit yang di-generate dari Dashboard Owner.

**Autentikasi:** Tidak diperlukan (publik)

**Rate limit:** 5 request per menit per IP

**Request Body:**
```json
{
  "pairingCode": "123456"
}
```

| Field | Tipe | Keterangan |
|-------|------|------------|
| `pairingCode` | `string` | Tepat 6 karakter, angka |

**Response `200 OK`:**
```json
{
  "data": {
    "deviceToken": "eyJhbGci...",
    "kioskConfig": {
      "id": "uuid",
      "name": "Kiosk Lantai 1",
      "ownerId": "uuid",
      "priceBaseSession": 25000,
      "pricePerExtraPrint": 5000,
      "priceDigitalCopy": 10000
    }
  }
}
```

| Field | Tipe | Keterangan |
|-------|------|------------|
| `deviceToken` | `string` | JWT untuk autentikasi semua request berikutnya — simpan secara permanen |
| `kioskConfig.priceBaseSession` | `number` | Harga dasar 1 sesi (Rupiah) |
| `kioskConfig.pricePerExtraPrint` | `number` | Harga per cetak tambahan (>1 print) |
| `kioskConfig.priceDigitalCopy` | `number` | Harga digital copy |

**Error:**

| Status | `error` | Penyebab |
|--------|---------|---------|
| `404` | `NOT_FOUND` | Pairing code tidak ditemukan atau sudah expired (masa berlaku 7 hari sejak di-generate) |
| `422` | `VALIDATION_ERROR` | `pairingCode` bukan tepat 6 karakter |
| `429` | `RATE_LIMIT_EXCEEDED` | Melebihi 5 percobaan per menit |

> **Catatan:**
> - Pairing code expired dan code tidak valid mengembalikan error yang sama (`NOT_FOUND`) — tidak dibedakan secara eksplisit.
> - Setelah pairing berhasil, pairing code langsung dihapus dari sistem. Pairing code yang sama tidak bisa digunakan dua kali.
> - Simpan `deviceToken` secara persisten di device. Token ini tidak expire secara waktu, tapi akan tidak valid jika owner melakukan re-generate pairing dari Dashboard.

---

## 2. Kiosk "Me" — Identitas & Konfigurasi

### `GET /me`

Mengambil identitas, konfigurasi harga, dan status subscription kiosk yang sudah paired.

**Autentikasi:** Device token (Bearer)

**Request:** Tidak ada parameter

**Response `200 OK`:**
```json
{
  "data": {
    "kiosk": {
      "id": "uuid",
      "ownerId": "uuid",
      "name": "Kiosk Lantai 1",
      "priceBaseSession": 25000,
      "pricePerExtraPrint": 5000,
      "priceDigitalCopy": 10000
    },
    "subscriptionStatus": "ACTIVE",
    "sessionPreviewUrl": "https://preview.example.com" 
  }
}
```

| Field | Tipe | Keterangan |
|-------|------|------------|
| `kiosk.priceBaseSession` | `number` | Harga dasar 1 sesi (Rupiah) |
| `kiosk.pricePerExtraPrint` | `number` | Harga per print tambahan |
| `kiosk.priceDigitalCopy` | `number` | Harga digital copy |
| `subscriptionStatus` | `enum` | Status subscription owner (lihat di bawah) |
| `sessionPreviewUrl` | `string \| null` | URL preview session jika dikonfigurasi, atau `null` |

**Nilai `subscriptionStatus`:**

| Nilai | Arti | Kiosk bisa beroperasi? |
|-------|------|------------------------|
| `ACTIVE` | Subscription aktif dan belum habis | Ya |
| `PENDING_PAYMENT` | Subscription menunggu pembayaran | Tidak |
| `EXPIRED` | Subscription sudah habis masa berlaku | Tidak |
| `CANCELLED` | Subscription dibatalkan | Tidak |

**Error:**

| Status | `error` | Penyebab |
|--------|---------|---------|
| `401` | `UNAUTHORIZED` | Device token tidak ada atau tidak valid |
| `404` | `NOT_FOUND` | Data kiosk tidak ditemukan di database |

> **Catatan:**
> - Endpoint ini tetap bisa dipanggil meski `subscriptionStatus` bukan `ACTIVE` — kiosk bisa menampilkan pesan "tidak aktif" ke pengguna berdasarkan nilai ini.
> - Endpoint ini **tidak** mengembalikan data payment config (metode pembayaran yang tersedia). Data tersebut digunakan secara internal saat kiosk membuat transaksi.
> - Panggil endpoint ini saat startup atau sebelum memulai sesi untuk memastikan status terkini.

---

## 3. Kiosk Templates

### `GET /templates`

Mengambil daftar template aktif milik owner beserta semua elemen-elemennya.

**Autentikasi:** Device token (Bearer)

**Request:** Tidak ada parameter

**Response `200 OK`:**
```json
{
  "data": [
    {
      "template": {
        "id": "uuid",
        "ownerId": "uuid",
        "name": "Template Vintage",
        "width": 1200,
        "height": 1800,
        "backgroundUrl": "https://...",
        "createdAt": "2025-01-01T00:00:00.000Z",
        "updatedAt": "2025-06-01T00:00:00.000Z"
      },
      "elements": [
        {
          "id": "uuid",
          "templateId": "uuid",
          "elementType": "PHOTO_SLOT",
          "sequence": 0,
          "x": 100,
          "y": 200,
          "width": 400,
          "height": 300,
          "rotation": 0,
          "properties": {},
          "createdAt": "2025-01-01T00:00:00.000Z"
        }
      ],
      "updatedAt": "2025-06-01T00:00:00.000Z"
    }
  ]
}
```

**Field `template`:**

| Field | Tipe | Keterangan |
|-------|------|------------|
| `width`, `height` | `number` | Dimensi canvas template dalam piksel |
| `backgroundUrl` | `string` | URL gambar background template |

**Field `element`:**

| Field | Tipe | Keterangan |
|-------|------|------------|
| `elementType` | `enum` | Tipe elemen (lihat di bawah) |
| `sequence` | `number` | Urutan rendering — nilai lebih kecil di bawah (z-index) |
| `x`, `y` | `number` | Posisi sudut kiri atas elemen dalam piksel |
| `width`, `height` | `number` | Ukuran elemen dalam piksel |
| `rotation` | `number` | Rotasi dalam derajat |
| `properties` | `object` | Metadata tambahan spesifik per tipe elemen |

**Nilai `elementType`:**

| Nilai | Keterangan |
|-------|------------|
| `PHOTO_SLOT` | Area tempat foto pengguna ditempatkan |
| `IMAGE` | Gambar statis (overlay, dekorasi, dll) |
| `TEXT` | Elemen teks |

**Error:**

| Status | `error` | Penyebab |
|--------|---------|---------|
| `401` | `UNAUTHORIZED` | Device token tidak ada atau tidak valid |

> **Catatan:**
> - Hanya template yang aktif (tidak di-soft-delete) yang dikembalikan.
> - Template di-sort secara alfabetis berdasarkan nama.
> - Response ini bisa di-cache di device, tapi disarankan melakukan sync ulang saat startup atau setelah idle lama untuk mendapatkan template terbaru.
> - Field `updatedAt` di level item (di luar `template`) sama dengan `template.updatedAt` — bisa digunakan untuk deteksi perubahan.
# Modul Pesanan API

Base URL mengikuti environment backend, contoh:

```text
http://127.0.0.1:8000/api
```

Semua endpoint di bawah ini membutuhkan header auth Sanctum:

```http
Authorization: Bearer {token}
Accept: application/json
Content-Type: application/json
```

## Ringkasan Endpoint

| Method | Endpoint | Keterangan |
| --- | --- | --- |
| `GET` | `/pesanan` | Ambil list pesanan |
| `POST` | `/pesanan` | Buat pesanan baru |
| `GET` | `/pesanan/{id}` | Ambil detail 1 pesanan |
| `PUT` | `/pesanan/{id}` | Ubah pesanan |
| `DELETE` | `/pesanan/{id}` | Hapus pesanan draft |
| `POST` | `/pesanan/{id}/assign-cleaner` | Assign ulang / assign cleaner |

## Struktur Data Penting

### Field pesanan utama

| Field | Tipe | Catatan |
| --- | --- | --- |
| `pelanggan_id` | number | wajib |
| `cabang_id` | number | wajib |
| `cs_id` | number | wajib |
| `tanggal_input` | datetime | diisi otomatis backend saat create |
| `status_pesanan` | string | contoh: `draft`, `assigned`, `finished_by_cleaner` |
| `chat_dari` | string/null | enum: `organik`, `ads`, `lama` |
| `tipe_customer` | string/null | enum: `lama`, `baru` |
| `keterangan_order` | string/null | opsional |
| `subtotal` | number | total gabungan semua item detail pesanan |

### Field detail pesanan

| Field | Tipe | Catatan |
| --- | --- | --- |
| `layanan_id` | number | wajib |
| `qty` | string | wajib, sekarang berupa teks bebas. Contoh: `3 jam 2 cleaner` |
| `harga` | number | wajib, diinput manual dari frontend |
| `tanggal_pengerjaan` | date/null | format `YYYY-MM-DD` |
| `waktu_pengerjaan` | string/null | format `HH:mm` |
| `bonus_layanan` | number/null | opsional |

## 1. List Pesanan

### Request

```http
GET /api/pesanan
```

### Query Params

Semua query param opsional.

| Param | Tipe | Keterangan |
| --- | --- | --- |
| `status_pesanan` | string | filter status pesanan |
| `cabang_id` | number | filter cabang |
| `chat_dari` | string | filter source chat |
| `tipe_customer` | string | filter tipe customer |

### Contoh

```http
GET /api/pesanan?cabang_id=2&status_pesanan=draft
```

### Contoh Response

```json
{
  "status": true,
  "message": "Data pesanan berhasil diambil",
  "data": {
    "current_page": 1,
    "data": [
      {
        "id": 1,
        "pelanggan_id": 5,
        "cabang_id": 2,
        "cs_id": 4,
        "tanggal_input": "2026-06-16T07:10:00.000000Z",
        "status_pesanan": "draft",
        "chat_dari": "organik",
        "tipe_customer": "baru",
        "keterangan_order": "Cuci sofa dan karpet",
        "file_invoice": null,
        "update_invoice": null,
        "created_at": "2026-06-16T07:10:00.000000Z",
        "updated_at": "2026-06-16T07:10:00.000000Z",
        "subtotal": 425000,
        "pelanggan": {
          "id": 5,
          "nama_pelanggan": "Ibu Sari"
        },
        "cabang": {
          "id": 2,
          "nama_cabang": "Surabaya"
        },
        "cs": {
          "id": 4,
          "nama": "CS Surabaya"
        },
        "details": [
          {
            "id": 11,
            "pesanan_id": 1,
            "layanan_id": 2,
            "qty": "3 jam 2 cleaner",
            "harga": 300000,
            "tanggal_pengerjaan": "2026-06-20",
            "waktu_pengerjaan": "10:00:00",
            "bonus_layanan": 15000,
            "layanan": {
              "id": 2,
              "nama_layanan": "Cuci Sofa"
            }
          }
        ],
        "cleaners": []
      }
    ]
  }
}
```

## 2. Buat Pesanan

### Request

```http
POST /api/pesanan
```

### Body

```json
{
  "pelanggan_id": 5,
  "cabang_id": 2,
  "cs_id": 4,
  "chat_dari": "organik",
  "tipe_customer": "baru",
  "keterangan_order": "Pesanan baru dari WhatsApp",
  "details": [
    {
      "layanan_id": 2,
      "qty": "3 jam 2 cleaner",
      "harga": 300000,
      "tanggal_pengerjaan": "2026-06-20",
      "waktu_pengerjaan": "10:00",
      "bonus_layanan": 15000
    },
    {
      "layanan_id": 3,
      "qty": "1 karpet ruang tamu",
      "harga": 125000,
      "tanggal_pengerjaan": "2026-06-20",
      "waktu_pengerjaan": "10:00",
      "bonus_layanan": 5000
    }
  ]
}
```

### Catatan

- `status_pesanan` otomatis dibuat `draft`.
- `tanggal_input` otomatis diisi backend.
- `subtotal` tidak perlu dikirim dari frontend.
- `subtotal` di level pesanan otomatis merupakan total gabungan semua item detail.

### Contoh Response

```json
{
  "status": true,
  "message": "Pesanan berhasil dibuat",
  "data": {
    "id": 12,
    "status_pesanan": "draft",
    "subtotal": 425000,
    "details": [
      {
        "layanan_id": 2,
        "qty": "3 jam 2 cleaner",
        "harga": 300000
      },
      {
        "layanan_id": 3,
        "qty": "1 karpet ruang tamu",
        "harga": 125000
      }
    ]
  }
}
```

## 3. Detail Pesanan

### Request

```http
GET /api/pesanan/{id}
```

### Contoh

```http
GET /api/pesanan/12
```

### Contoh Response

```json
{
  "status": true,
  "message": "Detail pesanan berhasil diambil",
  "data": {
    "id": 12,
    "pelanggan_id": 5,
    "cabang_id": 2,
    "cs_id": 4,
    "status_pesanan": "draft",
    "chat_dari": "organik",
    "tipe_customer": "baru",
    "keterangan_order": "Pesanan baru dari WhatsApp",
    "subtotal": 425000,
    "details": [
      {
        "qty": "3 jam 2 cleaner",
        "harga": 300000
      },
      {
        "qty": "1 karpet ruang tamu",
        "harga": 125000
      }
    ]
  }
}
```

## 4. Update Pesanan

### Request

```http
PUT /api/pesanan/{id}
```

### Body

Body mirip dengan create, dan `details` dikirim ulang penuh.

```json
{
  "pelanggan_id": 5,
  "cabang_id": 2,
  "cs_id": 4,
  "chat_dari": "ads",
  "tipe_customer": "lama",
  "keterangan_order": "Update order",
  "details": [
    {
      "layanan_id": 2,
      "qty": "2 sesi deep cleaning",
      "harga": 275000,
      "tanggal_pengerjaan": "2026-06-21",
      "waktu_pengerjaan": "14:00",
      "bonus_layanan": 12000
    }
  ]
}
```

### Catatan

- Update hanya bisa jika `status_pesanan` masih `draft` atau `assigned`.
- Saat update, backend akan menghapus detail lama lalu membuat ulang dari `details` yang dikirim sekarang.

### Contoh Response

```json
{
  "status": true,
  "message": "Pesanan berhasil diperbarui",
  "data": {
    "id": 12,
    "status_pesanan": "draft",
    "subtotal": 275000,
    "details": [
      {
        "qty": "2 sesi deep cleaning",
        "harga": 275000
      }
    ]
  }
}
```

### Error Jika Status Sudah Berjalan

```json
{
  "status": false,
  "message": "Pesanan tidak bisa diubah karena status sudah berjalan"
}
```

## 5. Hapus Pesanan

### Request

```http
DELETE /api/pesanan/{id}
```

### Catatan

- Hanya bisa dipakai jika `status_pesanan = draft`.
- Jika bukan `draft`, backend akan menolak.

### Success Response

```json
{
  "status": true,
  "message": "Pesanan berhasil dihapus"
}
```

### Error Response

```json
{
  "status": false,
  "message": "Pesanan hanya bisa dihapus saat status masih draft"
}
```

## 6. Assign Cleaner

### Request

```http
POST /api/pesanan/{id}/assign-cleaner
```

### Body

```json
{
  "cleaner_ids": [7, 8]
}
```

### Catatan

- Hanya bisa jika `status_pesanan` masih `draft` atau `assigned`.
- Endpoint ini akan:
  - menghapus assignment cleaner lama
  - membuat assignment cleaner baru
  - mengubah `status_pesanan` menjadi `assigned`
- Endpoint ini tidak lagi otomatis membuat bonus cleaner.
- Bonus layanan dan bonus non-layanan sekarang dikelola lewat endpoint bonus cleaner terpisah.

### Contoh Response

```json
{
  "status": true,
  "message": "Cleaner berhasil ditugaskan",
  "data": {
    "id": 12,
    "status_pesanan": "assigned",
    "subtotal": 425000,
    "cleaners": [
      {
        "id": 1,
        "cleaner_id": 7,
        "status_pengerjaan": "assigned",
        "cleaner": {
          "id": 7,
          "nama": "Cleaner Budi"
        },
        "bonuses": []
      }
    ]
  }
}
```

### Error Response

```json
{
  "status": false,
  "message": "Cleaner tidak bisa diubah karena pesanan sudah berjalan"
}
```

## Enum yang Dipakai

### status_pesanan

- `draft`
- `assigned`
- `in_progress`
- `finished_by_cleaner`
- `waiting_payment_approval`
- `waiting_cancel_approval`
- `completed`
- `cancelled`

### chat_dari

- `organik`
- `ads`
- `lama`

### tipe_customer

- `lama`
- `baru`

## Catatan Frontend

- `qty` sekarang `string`, bukan angka.
- `harga` diisi manual dari frontend per detail layanan.
- `subtotal` sekarang dibaca di level pesanan, bukan di level item detail.
- Kalau user edit item detail, kirim ulang semua `details` yang terbaru saat `PUT /pesanan/{id}`.

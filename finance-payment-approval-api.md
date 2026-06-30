# Finance Payment Approval API

Dokumentasi ini menjelaskan endpoint khusus Finance untuk approval pembayaran dari CS, daftar pesanan dibatalkan, dan daftar pesanan yang sudah diproses Finance.

Base URL:

```text
http://127.0.0.1:8000/api
```

## Auth dan Role

Semua endpoint berada di middleware:

- `auth:sanctum`
- `role:finance`

Role dicek dari relasi `karyawans.jabatan.nama_jabatan`. User yang login harus punya jabatan `Finance`.

Gunakan header:

```http
Authorization: Bearer {token}
Accept: application/json
```

## Ringkasan Endpoint

| Method | Endpoint | Keterangan |
| --- | --- | --- |
| `PATCH` | `/finance/pembayaran/{pembayaran}/approval` | Approve atau reject pembayaran pending |
| `GET` | `/finance/pembatalan` | Daftar pesanan yang masuk flow pembatalan |
| `GET` | `/finance/pesanan/processed` | Daftar pesanan yang sudah diproses Finance |

Implementasi utama:

- `routes/api.php`
- `app/Http/Controllers/Api/FinanceController.php`
- `app/Http/Middleware/RoleMiddleware.php`
- `app/Models/Pembayaran.php`

## Status yang Dipakai

Status pembayaran:

- `pending`
- `approved`
- `rejected`

Status pesanan terkait Finance:

- `waiting_payment_approval`: pembayaran sudah diajukan CS dan menunggu Finance
- `completed`: pembayaran disetujui Finance
- `finished_by_cleaner`: pembayaran ditolak Finance, sehingga CS bisa submit ulang pembayaran
- `waiting_cancel_approval`: pembatalan sudah diajukan CS
- `cancelled`: pesanan dibatalkan final

Jika pembayaran ditolak, alasan disimpan di field:

```text
pembayarans.alasan_penolakan
```

## 1. Approval Pembayaran

Endpoint ini dipakai Finance untuk menyetujui atau menolak pembayaran yang diajukan CS.

```http
PATCH /api/finance/pembayaran/{pembayaran}/approval
```

### Request Body

```json
{
  "status_approval": "approved"
}
```

Atau untuk reject:

```json
{
  "status_approval": "rejected",
  "alasan_penolakan": "Nominal transfer tidak sesuai."
}
```

### Validasi

| Field | Wajib | Rule |
| --- | --- | --- |
| `status_approval` | ya | `approved` atau `rejected` |
| `alasan_penolakan` | ya jika rejected | string, max 1000 |

### Rule Bisnis

- pembayaran harus ada
- pesanan dari pembayaran harus ada
- `status_pembayaran` harus `pending`
- `pesanan.status_pesanan` harus `waiting_payment_approval`
- jika approved:
  - `pembayarans.status_pembayaran = approved`
  - `pembayarans.approved_by = id Finance login`
  - `pembayarans.approved_at = now()`
  - `pesanans.status_pesanan = completed`
- jika rejected:
  - `pembayarans.status_pembayaran = rejected`
  - `pembayarans.alasan_penolakan` diisi
  - `pembayarans.approved_by = id Finance login`
  - `pembayarans.approved_at = now()`
  - `pesanans.status_pesanan = finished_by_cleaner`

### Contoh cURL Approve

```bash
curl -X PATCH "http://127.0.0.1:8000/api/finance/pembayaran/5/approval" \
  -H "Authorization: Bearer {token}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{"status_approval":"approved"}'
```

### Contoh cURL Reject

```bash
curl -X PATCH "http://127.0.0.1:8000/api/finance/pembayaran/5/approval" \
  -H "Authorization: Bearer {token}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{"status_approval":"rejected","alasan_penolakan":"Nominal transfer tidak sesuai."}'
```

### Contoh Success Response

```json
{
  "status": true,
  "message": "Pembayaran berhasil disetujui",
  "data": {
    "id": 5,
    "pesanan_id": 12,
    "status_pembayaran": "approved",
    "approved_by": 8,
    "approved_at": "2026-06-30T10:00:00.000000Z",
    "catatan_pembayaran": "Customer bayar via transfer BCA",
    "alasan_penolakan": null,
    "pesanan": {
      "id": 12,
      "status_pesanan": "completed",
      "pelanggan": {},
      "cabang": {},
      "cs": {},
      "details": []
    },
    "approved_by": {}
  }
}
```

### Error Umum

Pembayaran tidak ditemukan:

```json
{
  "status": false,
  "message": "Pembayaran tidak ditemukan",
  "data": {}
}
```

Pembayaran sudah diproses:

```json
{
  "status": false,
  "message": "Pembayaran sudah diproses Finance",
  "data": {}
}
```

Pesanan tidak sedang menunggu approval:

```json
{
  "status": false,
  "message": "Pesanan tidak sedang menunggu approval pembayaran",
  "data": {}
}
```

Role bukan Finance:

```json
{
  "status": false,
  "message": "Akses hanya untuk role yang diizinkan",
  "data": {}
}
```

## 2. Daftar Pembayaran atau Pesanan yang Dibatalkan

Endpoint ini menampilkan pesanan yang masuk status pembatalan.

```http
GET /api/finance/pembatalan
```

Status yang ditampilkan default:

- `waiting_cancel_approval`
- `cancelled`

### Query Filter

| Query | Contoh | Keterangan |
| --- | --- | --- |
| `status_pesanan` | `cancelled` | `waiting_cancel_approval` atau `cancelled` |
| `cabang_id` | `2` | filter cabang |
| `tanggal_mulai` | `2026-06-01` | filter `tanggal_input >= tanggal_mulai` |
| `tanggal_selesai` | `2026-06-30` | filter `tanggal_input <= tanggal_selesai` |

### Contoh cURL

```bash
curl "http://127.0.0.1:8000/api/finance/pembatalan?status_pesanan=cancelled&cabang_id=2" \
  -H "Authorization: Bearer {token}" \
  -H "Accept: application/json"
```

### Relasi yang Disertakan

- `pelanggan`
- `cabang`
- `cs`
- `details.layanan`
- `pembayaran.approvedBy`
- `pembatalan.canceller`

### Contoh Response

```json
{
  "status": true,
  "message": "Daftar pembayaran atau pesanan dibatalkan berhasil diambil",
  "data": [
    {
      "id": 12,
      "status_pesanan": "cancelled",
      "pelanggan": {},
      "cabang": {},
      "cs": {},
      "details": [],
      "pembayaran": null,
      "pembatalan": {
        "id": 3,
        "alasan_cancel": "Customer cancel.",
        "canceller": {}
      }
    }
  ]
}
```

## 3. Daftar Semua Pesanan yang Sudah Diproses Finance

Endpoint ini menampilkan pesanan yang sudah melalui proses Finance:

- pembayaran `approved`
- pembayaran `rejected`
- pesanan `cancelled`

```http
GET /api/finance/pesanan/processed
```

### Query Filter

| Query | Contoh | Keterangan |
| --- | --- | --- |
| `status_approval` | `approved` | `approved`, `rejected`, atau `cancelled` |
| `cabang_id` | `2` | filter cabang |
| `tanggal_mulai` | `2026-06-01` | filter `tanggal_input >= tanggal_mulai` |
| `tanggal_selesai` | `2026-06-30` | filter `tanggal_input <= tanggal_selesai` |

### Contoh cURL

```bash
curl "http://127.0.0.1:8000/api/finance/pesanan/processed?status_approval=approved&tanggal_mulai=2026-06-01&tanggal_selesai=2026-06-30" \
  -H "Authorization: Bearer {token}" \
  -H "Accept: application/json"
```

### Contoh Response

```json
{
  "status": true,
  "message": "Daftar pesanan yang sudah diproses Finance berhasil diambil",
  "data": [
    {
      "id": 12,
      "status_pesanan": "completed",
      "pelanggan": {},
      "cabang": {},
      "cs": {},
      "details": [],
      "pembayaran": {
        "id": 5,
        "status_pembayaran": "approved",
        "approved_by": {}
      },
      "pembatalan": null
    }
  ]
}
```

## Catatan Untuk Frontend

- Untuk approval, gunakan `PATCH /finance/pembayaran/{id}/approval`.
- Saat reject, selalu kirim `alasan_penolakan`.
- Setelah approve, pesanan menjadi `completed`.
- Setelah reject, pesanan kembali ke `finished_by_cleaner`, jadi CS bisa submit pembayaran baru.
- List pembatalan memakai status pesanan, bukan status pembayaran.
- List processed Finance memakai status pembayaran `approved/rejected` dan status pesanan `cancelled`.

## Test

Test terkait ada di:

- `tests/Feature/FinanceApiTest.php`

Coverage utama:

- approve pembayaran pending
- reject pembayaran dan simpan alasan
- validasi alasan reject
- proteksi role Finance
- daftar pesanan dibatalkan
- daftar pesanan processed dengan filter status approval

# Notify Cleaner API

Dokumentasi ini khusus untuk endpoint notify cleaner pada modul pesanan.

Base URL mengikuti environment backend, contoh:

```text
http://127.0.0.1:8000/api
```

Endpoint ini membutuhkan auth Sanctum:

```http
Authorization: Bearer {token}
Accept: application/json
Content-Type: application/json
```

## Endpoint

```http
POST /api/pesanan/{pesanan}/notify-cleaner
```

Contoh:

```http
POST /api/pesanan/12/notify-cleaner
```

## Tujuan Endpoint

Endpoint ini dipakai ketika CS atau admin ingin mengirim notifikasi dummy ke semua cleaner yang sudah di-assign ke pesanan tertentu.

Saat endpoint dipanggil, backend akan:

1. Mengecek `status_pesanan` harus `assigned`
2. Mengambil semua `pesanan_cleaners` dengan `status_pengerjaan = assigned`
3. Mengubah `status_pengerjaan` menjadi `notified`
4. Mengisi `notified_at = now()`
5. Dispatch queue job `SendCleanerJobNotification`
6. Job akan membuat dummy log ke tabel `notification_logs`

## Request Body

Tidak perlu body.

```json
{}
```

## Syarat Supaya Berhasil

- `pesanan.status_pesanan` harus `assigned`
- minimal ada 1 cleaner dengan `status_pengerjaan = assigned`

## Success Response

```json
{
  "status": true,
  "message": "Cleaner berhasil dinotifikasi",
  "data": {
    "id": 12,
    "pelanggan_id": 5,
    "cabang_id": 2,
    "cs_id": 4,
    "tanggal_input": "2026-06-16T08:00:00.000000Z",
    "status_pesanan": "assigned",
    "chat_dari": "organik",
    "tipe_customer": "baru",
    "keterangan_order": "Notify cleaner test",
    "subtotal": 300000,
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
        "id": 21,
        "pesanan_id": 12,
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
    "cleaners": [
      {
        "id": 31,
        "pesanan_id": 12,
        "cleaner_id": 7,
        "status_pengerjaan": "notified",
        "notified_at": "2026-06-16T08:30:00.000000Z",
        "started_at": null,
        "finished_at": null,
        "total_bonus": 15000,
        "cleaner": {
          "id": 7,
          "nama": "Cleaner Budi"
        },
        "bonuses": [
          {
            "id": 1,
            "nominal": 15000,
            "keterangan": "Bonus default dari cabang"
          }
        ]
      },
      {
        "id": 32,
        "pesanan_id": 12,
        "cleaner_id": 8,
        "status_pengerjaan": "notified",
        "notified_at": "2026-06-16T08:30:00.000000Z",
        "started_at": null,
        "finished_at": null,
        "total_bonus": 15000,
        "cleaner": {
          "id": 8,
          "nama": "Cleaner Andi"
        },
        "bonuses": [
          {
            "id": 2,
            "nominal": 15000,
            "keterangan": "Bonus default dari cabang"
          }
        ]
      }
    ]
  }
}
```

## Error Response: Status Pesanan Bukan Assigned

```json
{
  "status": false,
  "message": "Cleaner hanya bisa dinotifikasi saat status pesanan assigned"
}
```

HTTP status:

```text
422 Unprocessable Entity
```

## Error Response: Tidak Ada Cleaner Assigned

```json
{
  "status": false,
  "message": "Tidak ada cleaner dengan status assigned untuk dinotifikasi"
}
```

HTTP status:

```text
422 Unprocessable Entity
```

## Perilaku Backend Setelah Success

Untuk setiap cleaner yang tadinya `assigned`:

- `status_pengerjaan` diubah menjadi `notified`
- `notified_at` diisi waktu saat endpoint dipanggil

Lalu backend dispatch queue job:

```text
SendCleanerJobNotification
```

Job ini belum mengirim WhatsApp asli dan belum mengirim FCM asli. Untuk sekarang job hanya membuat dummy log ke tabel `notification_logs`.

## Isi Dummy Notification Log

Untuk setiap cleaner akan dibuat 2 baris log:

1. Channel `whatsapp_dummy` dengan status `success`
2. Channel `fcm_dummy` dengan status `success`

Contoh isi tabel `notification_logs`:

| pesanan_id | pesanan_cleaner_id | cleaner_id | channel | status |
| --- | --- | --- | --- | --- |
| 12 | 31 | 7 | `whatsapp_dummy` | `success` |
| 12 | 31 | 7 | `fcm_dummy` | `success` |

## Catatan Frontend

- Tombol notify sebaiknya hanya ditampilkan saat `status_pesanan = assigned`
- Setelah success, frontend sebaiknya refresh detail pesanan karena status cleaner akan berubah dari `assigned` menjadi `notified`
- Endpoint ini tidak butuh body
- Endpoint ini aman dipakai untuk banyak cleaner sekaligus dalam 1 pesanan
- Kalau semua cleaner sudah `notified`, endpoint akan mengembalikan error `422`

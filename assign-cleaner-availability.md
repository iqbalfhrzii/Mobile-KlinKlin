# Assign Cleaner Availability

Dokumentasi ini menjelaskan perubahan rule saat assign cleaner di project `klinklin-api`.

Dokumen ini dibuat khusus supaya frontend tahu kapan cleaner boleh dipilih dan kapan harus diblok saat user assign cleaner ke pesanan.

## Tujuan Perubahan

Sekarang backend sudah mengecek bentrok jadwal cleaner saat endpoint assign cleaner dipanggil.

Tujuannya:

- cleaner yang sudah benar-benar punya job aktif di slot yang sama tidak bisa dipilih lagi
- cleaner yang baru `assigned` masih boleh dipilih, karena pesanan itu belum tentu lanjut

## Endpoint yang Terdampak

```http
POST /api/pesanan/{pesanan}/assign-cleaner
```

## Dasar Cek Bentrok

Backend membandingkan:

- `detail_pesanans.tanggal_pengerjaan`
- `detail_pesanans.waktu_pengerjaan`

Jadi bentrok dihitung berdasarkan:

```text
tanggal yang sama + jam yang sama
```

Kalau slot berbeda, cleaner tetap bisa dipilih.

## Status Cleaner yang Dianggap Aktif dan Memblok

Cleaner akan ditolak jika pada pesanan lain di slot yang sama status `pesanan_cleaners.status_pengerjaan` adalah:

- `notified`
- `in_progress`

Artinya dua status ini dianggap job aktif yang bisa bentrok.

## Status Cleaner yang Tidak Memblok

Cleaner tetap boleh dipilih walaupun di pesanan lain pada slot yang sama statusnya:

- `assigned`
- `finished`

Alasannya:

- `assigned` belum tentu lanjut
- `finished` berarti job lama sudah selesai

## Status `free` Ada atau Tidak?

Di tabel `pesanan_cleaners` tidak ada status `free`.

Status yang ada tetap hanya:

- `assigned`
- `notified`
- `in_progress`
- `finished`

Jadi konsep "free" di frontend harus dianggap sebagai:

```text
cleaner yang tidak punya job lain di slot yang sama dengan status notified atau in_progress
```

## Request Assign Cleaner

### Endpoint

```http
POST /api/pesanan/{pesanan}/assign-cleaner
```

### Body

```json
{
  "cleaner_ids": [7, 8]
}
```

## Success Response

Contoh jika semua cleaner aman:

```json
{
  "status": true,
  "message": "Cleaner berhasil ditugaskan",
  "data": {
    "id": 12,
    "status_pesanan": "assigned",
    "cleaners": [
      {
        "id": 31,
        "cleaner_id": 7,
        "status_pengerjaan": "assigned"
      },
      {
        "id": 32,
        "cleaner_id": 8,
        "status_pengerjaan": "assigned"
      }
    ]
  }
}
```

## Error Response Jika Bentrok

Kalau ada cleaner yang sedang punya job aktif di tanggal dan jam yang sama, backend akan menolak dengan `422`.

Contoh:

```json
{
  "status": false,
  "message": "Cleaner sedang memiliki job aktif di tanggal dan jam yang sama: Busy Notified"
}
```

HTTP status:

```text
422 Unprocessable Entity
```

Kalau lebih dari satu cleaner bentrok, nama cleaner akan digabung di message.

## Skenario yang Harus Dipahami Frontend

### Skenario 1. Cleaner status `assigned` di pesanan lain

Hasil:

- masih boleh dipilih

### Skenario 2. Cleaner status `notified` di pesanan lain, slot sama

Hasil:

- tidak boleh dipilih
- backend akan balas `422`

### Skenario 3. Cleaner status `in_progress` di pesanan lain, slot sama

Hasil:

- tidak boleh dipilih
- backend akan balas `422`

### Skenario 4. Cleaner status `finished` di pesanan lain, slot sama

Hasil:

- masih boleh dipilih

## Rekomendasi Untuk Frontend

### 1. Jangan menganggap semua cleaner yang pernah di-assign otomatis tidak tersedia

Karena status `assigned` masih boleh dipilih lagi.

### 2. Jika frontend belum punya endpoint availability khusus

Tetap kirim `assign-cleaner` seperti biasa, lalu tangani error `422` dari backend.

### 3. Kalau UI ingin lebih rapi

Frontend bisa menampilkan pesan seperti:

```text
Cleaner ini sedang memiliki job aktif di jam yang sama.
```

berdasarkan response `message` dari backend.

### 4. Pastikan tanggal dan jam pengerjaan terisi

Cek bentrok backend sekarang berbasis:

- `tanggal_pengerjaan`
- `waktu_pengerjaan`

Kalau slot ini belum diisi, bentrok jadwal tidak akan terdeteksi secara akurat.

## Catatan Teknis Backend

Rule ini sudah diimplementasikan di:

- [app/Http/Controllers/Api/PesananController.php](/c:/Users/L13%20yoga/klinklin/klinklin-api/app/Http/Controllers/Api/PesananController.php)

Logic utamanya:

- backend ambil slot tanggal + waktu dari detail pesanan target
- backend cari pesanan lain milik cleaner yang sama
- backend hanya cek status `notified` dan `in_progress`
- kalau ada bentrok, assign ditolak

## Referensi Test Otomatis

Rule ini sudah dites di:

- [tests/Feature/PesananApiTest.php](/c:/Users/L13%20yoga/klinklin/klinklin-api/tests/Feature/PesananApiTest.php)

Case yang sudah dicakup:

- cleaner `notified` pada slot sama ditolak
- cleaner `in_progress` pada slot sama ditolak
- cleaner `assigned` pada slot sama tetap boleh
- cleaner `finished` pada slot sama tetap boleh

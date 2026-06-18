# Pelanggan API

Dokumentasi ini khusus untuk endpoint pelanggan pada project `klinklin-api`, terutama perilaku list dan filter `status` yang dipakai aplikasi mobile.

Dokumen ini ditulis supaya developer manusia maupun GPT lain cepat paham perilaku backend tanpa harus bongkar controller dan test satu per satu.

Base URL mengikuti environment backend, contoh:

```text
http://127.0.0.1:8000/api
```

## Kebutuhan Auth

Endpoint pelanggan saat ini berada di dalam middleware `auth:sanctum`.

Gunakan header:

```http
Authorization: Bearer {token}
Accept: application/json
Content-Type: application/json
```

## Tujuan Utama Modul Ini

Modul pelanggan di backend tidak memakai konsep delete permanen untuk workflow frontend.

Artinya:

- pelanggan bisa tetap tersimpan walaupun statusnya nonaktif
- frontend harus tetap bisa melihat pelanggan nonaktif di daftar
- filtering dilakukan lewat field `status`, bukan dengan menyembunyikan data di level model

## Ringkasan Endpoint

| Method | Endpoint | Keterangan |
| --- | --- | --- |
| `GET` | `/pelanggans` | Ambil daftar pelanggan |
| `POST` | `/pelanggans` | Buat pelanggan |
| `GET` | `/pelanggans/{pelanggan}` | Ambil detail pelanggan |
| `PUT` | `/pelanggans/{pelanggan}` | Update pelanggan |

Implementasi utamanya ada di:

- [app/Http/Controllers/Api/PelangganController.php](/c:/Users/L13%20yoga/klinklin/klinklin-api/app/Http/Controllers/Api/PelangganController.php)
- [app/Models/Pelanggan.php](/c:/Users/L13%20yoga/klinklin/klinklin-api/app/Models/Pelanggan.php)
- [tests/Feature/PelangganApiTest.php](/c:/Users/L13%20yoga/klinklin/klinklin-api/tests/Feature/PelangganApiTest.php)

## Struktur Data Penting

### Tabel `pelanggans`

| Field | Tipe | Catatan |
| --- | --- | --- |
| `cabang_id` | number | relasi ke cabang |
| `nama_pelanggan` | string | nama pelanggan |
| `no_wa` | string/null | nomor WhatsApp |
| `alamat` | string/null | alamat pelanggan |
| `status` | string | enum: `aktif`, `nonaktif` |

### Key JSON yang Penting Untuk Frontend

Field status pada response JSON selalu bernama persis:

```json
"status"
```

Bukan:

- `status_pelanggan`
- `is_active`
- `active`

Nilai `status` juga berbentuk string, yaitu:

- `aktif`
- `nonaktif`

Frontend mobile membaca field ini secara langsung. Kalau key atau nilainya berubah, frontend bisa salah menganggap semua pelanggan sebagai aktif.

## Perilaku List Pelanggan

### Tidak Ada Default Filter Aktif

Endpoint:

```http
GET /api/pelanggans
```

secara default akan mengembalikan semua pelanggan:

- pelanggan aktif
- pelanggan nonaktif

Backend saat ini tidak memakai default scope yang menyembunyikan pelanggan nonaktif.

Di controller, query list juga sengaja memakai pendekatan aman:

```php
Pelanggan::withoutGlobalScopes()->with('cabang')->latest()
```

Tujuannya supaya kalau nanti ada developer menambahkan Global Scope seperti:

```php
where('status', 'aktif')
```

endpoint list tetap bisa mengembalikan data `nonaktif` saat dibutuhkan, terutama untuk `status=all`.

## Query Parameter yang Didukung

Endpoint list pelanggan mendukung parameter berikut:

| Param | Tipe | Keterangan |
| --- | --- | --- |
| `search` | string | cari berdasarkan nama, no WA, atau alamat |
| `cabang_id` | number | filter berdasarkan cabang |
| `status` | string | filter status pelanggan |

## Aturan Filter `status`

### 1. `status=all`

```http
GET /api/pelanggans?status=all
```

Mengembalikan semua pelanggan:

- aktif
- nonaktif

`all` artinya backend tidak menambahkan where status.

### 2. `status=aktif`

```http
GET /api/pelanggans?status=aktif
```

Mengembalikan pelanggan aktif saja.

### 3. `status=nonaktif`

```http
GET /api/pelanggans?status=nonaktif
```

Mengembalikan pelanggan nonaktif saja.

### 4. Variasi Input yang Dinormalisasi

Backend juga menormalkan beberapa variasi input supaya frontend lebih aman:

- `non aktif` -> `nonaktif`
- `non_aktif` -> `nonaktif`
- `ALL` -> `all`
- `Aktif` -> `aktif`

Normalisasi dilakukan di method private `normalizeStatus()`.

## Contoh Response List

### Request Default

```http
GET /api/pelanggans
```

### Contoh Response

```json
{
  "message": "Data pelanggan berhasil diambil",
  "data": [
    {
      "id": 10,
      "cabang_id": 2,
      "nama_pelanggan": "Budi",
      "no_wa": "081234567890",
      "alamat": "Surabaya",
      "status": "aktif",
      "created_at": "2026-06-17T03:00:00.000000Z",
      "updated_at": "2026-06-17T03:00:00.000000Z",
      "cabang": {
        "id": 2,
        "nama_cabang": "Surabaya"
      }
    },
    {
      "id": 11,
      "cabang_id": 2,
      "nama_pelanggan": "Sari",
      "no_wa": "081234567891",
      "alamat": "Sidoarjo",
      "status": "nonaktif",
      "created_at": "2026-06-17T03:10:00.000000Z",
      "updated_at": "2026-06-17T03:10:00.000000Z",
      "cabang": {
        "id": 2,
        "nama_cabang": "Surabaya"
      }
    }
  ]
}
```

## Contoh Request Filter

### Semua pelanggan

```http
GET /api/pelanggans?status=all
```

### Hanya aktif

```http
GET /api/pelanggans?status=aktif
```

### Hanya nonaktif

```http
GET /api/pelanggans?status=nonaktif
```

### Variasi dengan spasi

```http
GET /api/pelanggans?status=non aktif
```

### Gabungan dengan search

```http
GET /api/pelanggans?status=all&search=budi
```

### Gabungan dengan cabang

```http
GET /api/pelanggans?cabang_id=2&status=aktif
```

## Perilaku Update Status

Pelanggan bisa diaktifkan atau dinonaktifkan lewat endpoint update:

```http
PUT /api/pelanggans/{pelanggan}
```

Contoh payload mengaktifkan ulang:

```json
{
  "status": "aktif"
}
```

Contoh payload menonaktifkan:

```json
{
  "status": "nonaktif"
}
```

Backend juga akan menormalkan variasi input status pada `store` dan `update`.

Yang penting:

- update status ini memakai SQL update biasa melalui model Eloquent
- backend tidak memanggil `$pelanggan->delete()` pada flow `PUT`
- row pelanggan tetap ada di database setelah status diubah ke `nonaktif`

## Catatan Tentang Delete

Saat ini route pelanggan terdaftar dengan:

```php
Route::apiResource('pelanggans', PelangganController::class)->except(['destroy']);
```

Artinya endpoint delete tidak dibuka untuk API publik frontend saat ini.

Kalau nanti ingin menonaktifkan pelanggan, lakukan lewat `PUT` dengan mengubah field `status`, bukan `DELETE`.

Jadi flow yang benar untuk nonaktifkan pelanggan adalah:

1. frontend panggil `PUT /api/pelanggans/{id}`
2. kirim payload `{ "status": "nonaktif" }`
3. backend menjalankan update status
4. data pelanggan tetap ada dan masih bisa muncul di list `status=all`

## Catatan Frontend

- Jangan asumsikan list pelanggan default hanya menampilkan data aktif
- Selalu baca field `status` dari JSON secara langsung
- Gunakan `status=all` kalau UI filter ingin menampilkan semua data
- Gunakan `status=aktif` dan `status=nonaktif` untuk filter eksplisit
- Jangan mapping sendiri `nonaktif` menjadi key lain tanpa alasan

## Catatan Untuk GPT / Developer Berikutnya

Hal penting yang harus dipertahankan:

1. endpoint list tidak boleh menyembunyikan pelanggan nonaktif secara default
2. key JSON harus tetap bernama `status`
3. nilai `status` harus tetap string `aktif` atau `nonaktif`
4. `status=all` harus berarti tidak ada filter status
5. variasi `non aktif` dan `non_aktif` tetap sebaiknya diterima

Test yang sudah ada mencakup:

- default list menampilkan aktif dan nonaktif
- filter `status=all`
- filter `status=aktif`
- filter `status=non aktif`
- update `PUT status=nonaktif` tanpa menghapus row
- update status pelanggan kembali ke aktif

# Cleaner Jobs API

Dokumentasi ini khusus untuk modul cleaner melihat dan menyelesaikan job pada project `klinklin-api`.

Dokumen ini ditulis supaya developer manusia maupun GPT lain bisa cepat paham flow backend tanpa harus baca semua source code lebih dulu.

Base URL mengikuti environment backend, contoh:

```text
http://127.0.0.1:8000/api
```

## Kondisi Auth Saat Ini

Auth cleaner belum final.

Untuk sementara endpoint cleaner job memakai query param:

```text
?cleaner_id=ID_KARYAWAN
```

Contoh:

```http
GET /api/cleaner/jobs?cleaner_id=7
```

Nanti kalau auth cleaner sudah siap, bagian ini bisa diganti ke user login / token tanpa mengubah flow bisnis utamanya.

## Ringkasan Flow Bisnis

Flow utama saat ini:

1. CS buat pesanan
2. CS assign cleaner ke pesanan
3. CS notify cleaner
4. `pesanan_cleaners.status_pengerjaan` berubah jadi `notified`
5. Cleaner buka daftar job miliknya
6. Cleaner klik start
7. Status job cleaner jadi `in_progress`
8. Status pesanan jadi `in_progress`
9. Cleaner klik finish
10. Status job cleaner jadi `finished`
11. Jika semua cleaner pada pesanan sudah selesai, status pesanan jadi `finished_by_cleaner`

## Ringkasan Endpoint

| Method | Endpoint | Keterangan |
| --- | --- | --- |
| `GET` | `/cleaner/jobs` | Ambil semua job milik cleaner |
| `GET` | `/cleaner/jobs/{pesananCleaner}` | Ambil detail satu job cleaner |
| `POST` | `/cleaner/jobs/{pesananCleaner}/start` | Mulai job cleaner |
| `POST` | `/cleaner/jobs/{pesananCleaner}/finish` | Selesaikan job cleaner |

## Relasi yang Selalu Di-load

Semua endpoint cleaner jobs memakai relasi berikut:

- `pesanan.pelanggan`
- `pesanan.cabang`
- `pesanan.details.layanan`
- `cleaner`
- `bonuses.tarifBonusCabang.jenisBonus`

Implementasi utamanya ada di:

- [app/Http/Controllers/Api/CleanerJobController.php](/c:/Users/L13%20yoga/klinklin/klinklin-api/app/Http/Controllers/Api/CleanerJobController.php)
- [routes/api.php](/c:/Users/L13%20yoga/klinklin/klinklin-api/routes/api.php)

## Struktur Data Penting

### Tabel `pesanan_cleaners`

Field yang paling penting untuk modul ini:

| Field | Tipe | Catatan |
| --- | --- | --- |
| `id` | number | id job cleaner |
| `pesanan_id` | number | relasi ke pesanan |
| `cleaner_id` | number | relasi ke karyawan cleaner |
| `status_pengerjaan` | string | `assigned`, `notified`, `in_progress`, `finished` |
| `notified_at` | datetime/null | terisi saat cleaner dinotifikasi |
| `started_at` | datetime/null | terisi saat cleaner klik start |
| `finished_at` | datetime/null | terisi saat cleaner klik finish |
| `total_bonus` | number | hasil append accessor dari semua bonus cleaner |

### Tabel `pesanans`

Status pesanan yang relevan untuk flow cleaner:

| Status | Arti |
| --- | --- |
| `assigned` | cleaner sudah ditugaskan |
| `in_progress` | minimal satu cleaner sudah mulai kerja |
| `finished_by_cleaner` | semua cleaner pada pesanan sudah selesai |

## Format Response Umum

Semua success response memakai bentuk ini:

```json
{
  "status": true,
  "message": "pesan response",
  "data": {}
}
```

Semua error custom di controller ini memakai bentuk ini:

```json
{
  "status": false,
  "message": "pesan error",
  "data": {}
}
```

Aturan status HTTP:

- `200` untuk success
- `403` jika cleaner mencoba akses job milik cleaner lain
- `422` jika validasi gagal atau status transisi tidak valid

## 1. List Job Cleaner

### Request

```http
GET /api/cleaner/jobs?cleaner_id=7
```

### Aturan

- `cleaner_id` wajib ada
- hanya menampilkan job dari tabel `pesanan_cleaners` milik cleaner tersebut
- response memuat relasi pesanan, pelanggan, cabang, detail layanan, cleaner, dan bonus

### Contoh Success Response

```json
{
  "status": true,
  "message": "Data job cleaner berhasil diambil",
  "data": [
    {
      "id": 31,
      "pesanan_id": 12,
      "cleaner_id": 7,
      "status_pengerjaan": "notified",
      "notified_at": "2026-06-16T08:30:00.000000Z",
      "started_at": null,
      "finished_at": null,
      "total_bonus": 35000,
      "pesanan": {
        "id": 12,
        "status_pesanan": "assigned",
        "pelanggan": {
          "id": 5,
          "nama_pelanggan": "Ibu Sari"
        },
        "cabang": {
          "id": 2,
          "nama_cabang": "Surabaya"
        },
        "details": [
          {
            "id": 21,
            "layanan_id": 2,
            "qty": "3 jam 2 cleaner",
            "harga": 300000,
            "layanan": {
              "id": 2,
              "nama_layanan": "Cuci Sofa"
            }
          }
        ]
      },
      "cleaner": {
        "id": 7,
        "nama": "Cleaner Budi"
      },
      "bonuses": [
        {
          "id": 1,
          "nominal": 35000,
          "keterangan": "Bonus default dari cabang",
          "tarif_bonus_cabang": {
            "id": 9,
            "jenis_bonus": {
              "id": 2,
              "nama_bonus": "Bonus Kehadiran"
            }
          }
        }
      ]
    }
  ]
}
```

### Error Validasi

Jika `cleaner_id` tidak dikirim:

```json
{
  "status": false,
  "message": "Validasi gagal",
  "data": {
    "errors": {
      "cleaner_id": [
        "The cleaner id field is required."
      ]
    }
  }
}
```

HTTP status:

```text
422 Unprocessable Entity
```

## 2. Detail Satu Job Cleaner

### Request

```http
GET /api/cleaner/jobs/{pesananCleaner}?cleaner_id=7
```

Contoh:

```http
GET /api/cleaner/jobs/31?cleaner_id=7
```

### Aturan

- `cleaner_id` wajib ada
- job harus milik cleaner tersebut
- jika bukan miliknya, backend mengembalikan `403`
- response memuat detail pesanan, pelanggan, layanan, status pengerjaan, bonus, dan `total_bonus`

### Contoh Error Jika Bukan Miliknya

```json
{
  "status": false,
  "message": "Anda tidak boleh mengakses job cleaner ini",
  "data": {}
}
```

HTTP status:

```text
403 Forbidden
```

## 3. Start Job Cleaner

### Request

```http
POST /api/cleaner/jobs/{pesananCleaner}/start?cleaner_id=7
```

Contoh:

```http
POST /api/cleaner/jobs/31/start?cleaner_id=7
```

Body tidak diperlukan:

```json
{}
```

### Aturan

- `cleaner_id` wajib ada
- job harus milik cleaner tersebut
- hanya boleh start jika `status_pengerjaan` adalah `assigned` atau `notified`

### Update yang Dilakukan Backend

Pada `pesanan_cleaners`:

- `status_pengerjaan = in_progress`
- `started_at = now()`

Pada `pesanans`:

- `status_pesanan = in_progress`

### Contoh Success Response

```json
{
  "status": true,
  "message": "Job cleaner berhasil dimulai",
  "data": {
    "id": 31,
    "status_pengerjaan": "in_progress",
    "started_at": "2026-06-17T03:15:00.000000Z",
    "finished_at": null,
    "total_bonus": 35000,
    "pesanan": {
      "id": 12,
      "status_pesanan": "in_progress"
    }
  }
}
```

### Error Jika Status Tidak Valid

Contoh jika job sudah `in_progress` atau `finished`:

```json
{
  "status": false,
  "message": "Job cleaner hanya bisa dimulai saat status assigned atau notified",
  "data": {}
}
```

HTTP status:

```text
422 Unprocessable Entity
```

## 4. Finish Job Cleaner

### Request

```http
POST /api/cleaner/jobs/{pesananCleaner}/finish?cleaner_id=7
```

Contoh:

```http
POST /api/cleaner/jobs/31/finish?cleaner_id=7
```

Body tidak diperlukan:

```json
{}
```

### Aturan

- `cleaner_id` wajib ada
- job harus milik cleaner tersebut
- hanya boleh finish jika `status_pengerjaan = in_progress`

### Update yang Dilakukan Backend

Pada `pesanan_cleaners`:

- `status_pengerjaan = finished`
- `finished_at = now()`

Lalu backend mengecek semua cleaner pada `pesanan_id` yang sama:

- jika semua `pesanan_cleaners.status_pengerjaan = finished`, maka `pesanan.status_pesanan = finished_by_cleaner`
- jika masih ada cleaner lain yang belum selesai, maka `pesanan.status_pesanan = in_progress`

### Contoh Success Jika Masih Ada Cleaner Lain Belum Selesai

```json
{
  "status": true,
  "message": "Job cleaner berhasil diselesaikan",
  "data": {
    "id": 31,
    "status_pengerjaan": "finished",
    "finished_at": "2026-06-17T04:10:00.000000Z",
    "pesanan": {
      "id": 12,
      "status_pesanan": "in_progress"
    }
  }
}
```

### Contoh Success Jika Semua Cleaner Sudah Selesai

```json
{
  "status": true,
  "message": "Job cleaner berhasil diselesaikan",
  "data": {
    "id": 31,
    "status_pengerjaan": "finished",
    "finished_at": "2026-06-17T04:10:00.000000Z",
    "pesanan": {
      "id": 12,
      "status_pesanan": "finished_by_cleaner"
    }
  }
}
```

### Error Jika Status Tidak Valid

Contoh jika cleaner mencoba finish job yang belum di-start:

```json
{
  "status": false,
  "message": "Job cleaner hanya bisa diselesaikan saat status in_progress",
  "data": {}
}
```

HTTP status:

```text
422 Unprocessable Entity
```

## Aturan Otorisasi

Untuk sementara otorisasi ownership dicek sederhana:

- route menerima `cleaner_id`
- backend membandingkan `pesanan_cleaners.cleaner_id` dengan query `cleaner_id`
- jika beda, request ditolak dengan `403`

Artinya:

- cleaner A tidak boleh membuka detail job cleaner B
- cleaner A tidak boleh menekan start pada job cleaner B
- cleaner A tidak boleh menekan finish pada job cleaner B

## Catatan Implementasi Penting

- Route cleaner jobs saat ini dibuka tanpa middleware `auth:sanctum` karena auth cleaner belum final
- Validasi `cleaner_id` dilakukan manual di controller, bukan form request terpisah
- Controller memakai transaksi database untuk proses `start` dan `finish`
- Saat `start` dan `finish`, row `pesanan_cleaners` diambil ulang dengan `lockForUpdate()` supaya update status lebih aman
- `total_bonus` berasal dari accessor model `PesananCleaner`, yaitu penjumlahan `bonuses.nominal`

## Catatan Frontend

- Selalu kirim `cleaner_id` di query string sampai auth cleaner resmi jadi
- Tombol start sebaiknya hanya muncul saat status job `assigned` atau `notified`
- Tombol finish sebaiknya hanya muncul saat status job `in_progress`
- Setelah start atau finish, frontend sebaiknya refresh detail job atau list job
- Frontend bisa memakai `total_bonus` langsung tanpa hitung manual

## Catatan Untuk GPT / Developer Berikutnya

Kalau nanti auth cleaner sudah siap, perubahan yang paling mungkin dibutuhkan:

1. pindahkan route cleaner jobs ke dalam middleware auth
2. ganti `resolveCleanerId()` agar mengambil id cleaner dari user login
3. pertahankan aturan ownership dan transisi status yang sekarang
4. pertahankan format response JSON supaya frontend tidak pecah

Test yang sudah ada untuk modul ini:

- [tests/Feature/CleanerJobApiTest.php](/c:/Users/L13%20yoga/klinklin/klinklin-api/tests/Feature/CleanerJobApiTest.php)

Test tersebut mencakup:

- list job cleaner
- akses detail milik cleaner lain harus `403`
- start job
- finish job saat cleaner lain belum selesai
- finish job saat semua cleaner sudah selesai
- validasi `cleaner_id`

# Cleaner App API

Dokumentasi ini khusus untuk semua endpoint yang paling relevan buat aplikasi cleaner di project `klinklin-api`.

Target dokumen ini adalah tim frontend supaya bisa langsung integrasi tanpa harus baca controller satu per satu.

Base URL mengikuti environment backend, contoh:

```text
http://127.0.0.1:8000/api
```

## Scope Endpoint Cleaner

Dokumen ini fokus ke flow yang dipakai cleaner:

1. login
2. ambil profil user login
3. ganti foto profil sendiri
4. ganti PIN sendiri
5. logout
6. lihat daftar job
7. lihat detail job
8. start job
9. finish job

Endpoint admin / CS seperti assign cleaner, notify cleaner, pembayaran, dan pembatalan tidak dibahas detail di sini karena bukan flow utama aplikasi cleaner.

## Ringkasan Endpoint

| Method | Endpoint | Auth | Keterangan |
| --- | --- | --- | --- |
| `POST` | `/login` | tidak | Login karyawan, termasuk cleaner |
| `GET` | `/me` | Bearer token | Ambil profil user login |
| `POST` | `/me/foto-profil` | Bearer token | Ganti foto profil cleaner yang sedang login |
| `POST` | `/change-pin` | Bearer token | Ganti PIN cleaner yang sedang login |
| `POST` | `/logout` | Bearer token | Logout dari token aktif |
| `GET` | `/cleaner/jobs?cleaner_id={id}` | saat ini tidak wajib token | Ambil semua job milik cleaner |
| `GET` | `/cleaner/jobs/{pesananCleaner}?cleaner_id={id}` | saat ini tidak wajib token | Ambil detail satu job cleaner |
| `POST` | `/cleaner/jobs/{pesananCleaner}/start?cleaner_id={id}` | saat ini tidak wajib token | Ubah job jadi `in_progress` |
| `POST` | `/cleaner/jobs/{pesananCleaner}/finish?cleaner_id={id}` | saat ini tidak wajib token | Selesaikan job cleaner |

## Catatan Auth Saat Ini

Ada 2 pola auth yang sedang hidup bersamaan:

### 1. Endpoint profile/auth cleaner

Endpoint berikut ada di middleware `auth:sanctum`:

- `GET /me`
- `POST /me/foto-profil`
- `POST /change-pin`
- `POST /logout`

Kirim header:

```http
Authorization: Bearer {token}
Accept: application/json
```

### 2. Endpoint job cleaner

Endpoint cleaner jobs saat ini belum masuk middleware `auth:sanctum`.

Sebagai gantinya backend masih memakai query param:

```text
?cleaner_id=ID_KARYAWAN
```

Contoh:

```http
GET /api/cleaner/jobs?cleaner_id=7
```

Jadi untuk frontend cleaner saat ini pola praktisnya:

1. login pakai `/login`
2. simpan `token`
3. ambil `data.id` dari response login atau `/me`
4. pakai `id` itu sebagai `cleaner_id` untuk semua endpoint `/cleaner/jobs`

## 1. Login Cleaner

### Request

```http
POST /api/login
Content-Type: application/json
Accept: application/json
```

### Body

```json
{
  "email": "cleaner@example.com",
  "pin": "1234"
}
```

### Validasi

| Field | Tipe | Wajib | Catatan |
| --- | --- | --- | --- |
| `email` | string | ya | format email valid |
| `pin` | string/number | ya | 4-8 digit |

### Contoh Success Response

```json
{
  "message": "Login berhasil",
  "token_type": "Bearer",
  "token": "1|sanctum-token-example",
  "wajib_ganti_pin": false,
  "data": {
    "id": 7,
    "nama": "Cleaner Budi",
    "email": "cleaner@example.com",
    "no_wa": "081234567890",
    "foto_profil": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...",
    "status": "aktif",
    "last_login_at": "2026-06-22T03:10:00.000000Z",
    "pin_changed_at": "2026-06-20T09:00:00.000000Z",
    "cabang": {
      "id": 2,
      "nama_cabang": "Surabaya"
    },
    "jabatan": {
      "id": 8,
      "nama_jabatan": "Cleaner"
    }
  }
}
```

### Error Penting

Jika email atau PIN salah, backend mengembalikan validasi Laravel:

```json
{
  "message": "The given data was invalid.",
  "errors": {
    "email": [
      "Email atau PIN salah."
    ]
  }
}
```

Jika akun nonaktif:

```json
{
  "message": "Akun sedang nonaktif."
}
```

HTTP status:

```text
403 Forbidden
```

## 2. Ambil Profil User Login

### Request

```http
GET /api/me
Authorization: Bearer {token}
Accept: application/json
```

### Contoh Success Response

```json
{
  "message": "Data user login berhasil diambil",
  "wajib_ganti_pin": false,
  "data": {
    "id": 7,
    "nama": "Cleaner Budi",
    "email": "cleaner@example.com",
    "no_wa": "081234567890",
    "foto_profil": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...",
    "status": "aktif",
    "last_login_at": "2026-06-22T03:10:00.000000Z",
    "pin_changed_at": "2026-06-20T09:00:00.000000Z",
    "cabang": {
      "id": 2,
      "nama_cabang": "Surabaya"
    },
    "jabatan": {
      "id": 8,
      "nama_jabatan": "Cleaner"
    }
  }
}
```

## 3. Ganti Foto Profil Cleaner Sendiri

### Request

```http
POST /api/me/foto-profil
Authorization: Bearer {token}
Accept: application/json
Content-Type: multipart/form-data
```

### Field

| Field | Tipe | Wajib | Catatan |
| --- | --- | --- | --- |
| `foto_profil` | file image | ya | max `2048 KB` |

### Contoh cURL

```bash
curl -X POST "http://127.0.0.1:8000/api/me/foto-profil" \
  -H "Authorization: Bearer {token}" \
  -H "Accept: application/json" \
  -F "foto_profil=@foto-cleaner.jpg"
```

### Contoh Success Response

```json
{
  "message": "Foto profil berhasil diperbarui",
  "data": {
    "id": 7,
    "nama": "Cleaner Budi",
    "email": "cleaner@example.com",
    "foto_profil": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD...",
    "status": "aktif",
    "cabang": {
      "id": 2,
      "nama_cabang": "Surabaya"
    },
    "jabatan": {
      "id": 8,
      "nama_jabatan": "Cleaner"
    }
  }
}
```

### Catatan

- nilai `foto_profil` di response adalah `data URL base64`
- frontend web bisa langsung pakai sebagai `src`
- frontend mobile bisa decode bagian base64 jika perlu

## 4. Ganti PIN Cleaner Sendiri

### Request

```http
POST /api/change-pin
Authorization: Bearer {token}
Content-Type: application/json
Accept: application/json
```

### Body

```json
{
  "pin_lama": "1234",
  "pin_baru": "5678",
  "pin_baru_confirmation": "5678"
}
```

### Validasi

| Field | Tipe | Wajib | Catatan |
| --- | --- | --- | --- |
| `pin_lama` | string/number | ya | 4-8 digit |
| `pin_baru` | string/number | ya | 4-8 digit, harus beda dari `pin_lama` |
| `pin_baru_confirmation` | string/number | ya | harus sama dengan `pin_baru` |

### Contoh Success Response

```json
{
  "message": "PIN berhasil diganti",
  "wajib_ganti_pin": false
}
```

### Catatan Penting

- setelah PIN diganti, token aktif saat ini tetap hidup
- token lain milik user yang sama akan dihapus backend

### Error Penting

Jika `pin_lama` salah, backend mengembalikan validasi Laravel:

```json
{
  "message": "The given data was invalid.",
  "errors": {
    "pin_lama": [
      "PIN lama salah."
    ]
  }
}
```

## 5. Logout

### Request

```http
POST /api/logout
Authorization: Bearer {token}
Accept: application/json
```

Body tidak diperlukan:

```json
{}
```

### Success Response

```json
{
  "message": "Logout berhasil"
}
```

## 6. List Job Cleaner

### Request

```http
GET /api/cleaner/jobs?cleaner_id=7
Accept: application/json
```

### Aturan

- `cleaner_id` wajib dikirim di query string
- hanya job milik cleaner tersebut yang dikembalikan
- hasil memakai urutan `latest()`
- endpoint ini saat ini belum diproteksi `auth:sanctum`

### Relasi yang Selalu Di-load

- `pesanan.pelanggan`
- `pesanan.cabang`
- `pesanan.details.layanan`
- `cleaner`
- `bonuses.tarifBonusCabang.jenisBonus`

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
            "subtotal": 300000,
            "tanggal_pengerjaan": "2026-06-22",
            "waktu_pengerjaan": "09:00",
            "bonus_layanan": 10000,
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
          "keterangan": "Bonus default cabang",
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

## 7. Detail Job Cleaner

### Request

```http
GET /api/cleaner/jobs/31?cleaner_id=7
Accept: application/json
```

### Aturan

- `cleaner_id` wajib
- `pesananCleaner` harus milik cleaner itu sendiri
- jika bukan miliknya, backend mengembalikan `403`

### Contoh Error Jika Akses Job Milik Cleaner Lain

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

## 8. Start Job Cleaner

### Request

```http
POST /api/cleaner/jobs/31/start?cleaner_id=7
Accept: application/json
```

Body tidak diperlukan:

```json
{}
```

### Aturan

- `cleaner_id` wajib
- job harus milik cleaner tersebut
- hanya bisa dijalankan jika `status_pengerjaan` masih `assigned` atau `notified`

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
    "started_at": "2026-06-22T09:15:00.000000Z",
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

## 9. Finish Job Cleaner

### Request

```http
POST /api/cleaner/jobs/31/finish?cleaner_id=7
Accept: application/json
```

Body tidak diperlukan:

```json
{}
```

### Aturan

- `cleaner_id` wajib
- job harus milik cleaner tersebut
- hanya bisa dijalankan jika `status_pengerjaan = in_progress`

### Update yang Dilakukan Backend

Pada `pesanan_cleaners`:

- `status_pengerjaan = finished`
- `finished_at = now()`

Pada `pesanans`:

- jika masih ada cleaner lain yang belum selesai, `status_pesanan = in_progress`
- jika semua cleaner pada pesanan sudah selesai, `status_pesanan = finished_by_cleaner`

### Contoh Success Jika Masih Ada Cleaner Lain Belum Selesai

```json
{
  "status": true,
  "message": "Job cleaner berhasil diselesaikan",
  "data": {
    "id": 31,
    "status_pengerjaan": "finished",
    "finished_at": "2026-06-22T11:10:00.000000Z",
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
    "finished_at": "2026-06-22T11:10:00.000000Z",
    "pesanan": {
      "id": 12,
      "status_pesanan": "finished_by_cleaner"
    }
  }
}
```

### Error Jika Status Tidak Valid

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

## Status yang Perlu Dipahami Frontend Cleaner

### Status job cleaner di `pesanan_cleaners.status_pengerjaan`

| Status | Arti di app cleaner |
| --- | --- |
| `assigned` | cleaner sudah ditugaskan, belum dinotifikasi atau belum mulai |
| `notified` | cleaner sudah dinotifikasi dan job siap dikerjakan |
| `in_progress` | cleaner sedang mengerjakan job |
| `finished` | cleaner sudah menyelesaikan job |

### Status pesanan di `pesanans.status_pesanan`

| Status | Arti |
| --- | --- |
| `assigned` | pesanan sudah punya cleaner |
| `in_progress` | minimal satu cleaner sudah mulai kerja |
| `finished_by_cleaner` | semua cleaner pada pesanan sudah selesai |

## Catatan UI Frontend

- setelah login, simpan `token` dan `data.id`
- gunakan `data.id` sebagai `cleaner_id` di semua endpoint `/cleaner/jobs`
- tombol `Start` sebaiknya hanya tampil saat status `assigned` atau `notified`
- tombol `Finish` sebaiknya hanya tampil saat status `in_progress`
- setelah `start` atau `finish`, refresh detail job atau list job
- bonus cleaner tidak perlu dihitung manual jika cukup pakai `total_bonus`
- jika butuh rincian bonus, baca `bonuses[*]` dari list atau detail job
- jika `foto_profil` null, tampilkan avatar default di frontend

## Referensi Source

- [routes/api.php](/c:/Users/L13%20yoga/klinklin/klinklin-api/routes/api.php)
- [app/Http/Controllers/Api/AuthController.php](/c:/Users/L13%20yoga/klinklin/klinklin-api/app/Http/Controllers/Api/AuthController.php)
- [app/Http/Controllers/Api/CleanerJobController.php](/c:/Users/L13%20yoga/klinklin/klinklin-api/app/Http/Controllers/Api/CleanerJobController.php)
- [app/Models/PesananCleaner.php](/c:/Users/L13%20yoga/klinklin/klinklin-api/app/Models/PesananCleaner.php)
- [docs/cleaner-jobs-api.md](/c:/Users/L13%20yoga/klinklin/klinklin-api/docs/cleaner-jobs-api.md)
- [docs/karyawan-foto-profil-api.md](/c:/Users/L13%20yoga/klinklin/klinklin-api/docs/karyawan-foto-profil-api.md)

## Catatan Untuk Developer Berikutnya

- endpoint cleaner jobs saat ini masih pakai `cleaner_id` query param, belum baca user login langsung
- artinya auth cleaner belum final walaupun cleaner tetap bisa login dengan token Sanctum
- kalau nanti cleaner jobs dipindah ke `auth:sanctum`, kontrak bisnis `start` dan `finish` sebaiknya tetap dipertahankan supaya frontend tidak pecah


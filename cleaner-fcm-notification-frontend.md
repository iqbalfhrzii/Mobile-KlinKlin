# Cleaner FCM Notification - Catatan Implementasi Frontend

Dokumen ini menjelaskan perubahan backend untuk notifikasi Cleaner saat CS melakukan assign Cleaner ke pesanan, dan apa saja yang perlu diimplementasikan di aplikasi frontend/mobile Cleaner.

## Ringkasan Perubahan Backend

Backend sekarang mendukung push notification ke Cleaner memakai Laravel Queue dan Firebase Cloud Messaging (FCM).

Flow utamanya:

1. Cleaner login di aplikasi.
2. Aplikasi Cleaner mengambil FCM token dari Firebase SDK.
3. Aplikasi mengirim FCM token ke backend.
4. CS melakukan assign Cleaner ke pesanan.
5. Backend menyimpan log notifikasi ke tabel `notification_logs`.
6. Backend memasukkan job ke queue database.
7. Queue worker mengirim push notification FCM ke Cleaner yang baru di-assign.

Notifikasi hanya dikirim ke Cleaner yang baru di-assign, bukan semua Cleaner lama yang sudah ada di pesanan.

## Endpoint Untuk Frontend Cleaner

### 1. Login

```http
POST /api/login
Accept: application/json
Content-Type: application/json
```

Body:

```json
{
  "email": "cleaner@example.com",
  "pin": "1234"
}
```

Ambil `token` dari response login. Token ini dipakai sebagai Bearer token untuk menyimpan FCM token.

## 2. Simpan atau Update FCM Token

Endpoint ini wajib dipanggil setelah login dan setiap kali Firebase SDK memberi token baru.

```http
POST /api/cleaner/fcm-token
Authorization: Bearer {token_cleaner}
Accept: application/json
Content-Type: application/json
```

Body:

```json
{
  "fcm_token": "token-dari-firebase-sdk"
}
```

Success response:

```json
{
  "status": true,
  "message": "FCM token cleaner berhasil diperbarui",
  "data": {
    "id": 7,
    "fcm_token_saved": true,
    "updated_at": "2026-06-30T10:00:00.000000Z"
  }
}
```

Catatan:

- Endpoint ini butuh login sebagai role `Cleaner`.
- Token boleh dikirim ulang jika berubah.
- Jika Cleaner login di device baru, token lama akan tertimpa dengan token baru.
- Backend menyimpan token di tabel `karyawans.fcm_token`.

## Endpoint CS Yang Memicu Notifikasi

Frontend CS tetap memakai endpoint assign Cleaner yang sudah ada.

```http
POST /api/pesanan/{pesanan_id}/assign-cleaner
Authorization: Bearer {token_cs}
Accept: application/json
Content-Type: application/json
```

Body:

```json
{
  "cleaner_ids": [7, 8]
}
```

Jika assign berhasil:

- `pesanan.status_pesanan` menjadi `assigned`.
- row `pesanan_cleaners` dibuat.
- backend membuat log `notification_logs` channel `fcm` status `queued`.
- backend dispatch job `SendCleanerJobNotification`.
- queue worker mengirim push notification ke Cleaner baru.

## Isi Push Notification

Title:

```text
Pesanan Baru
```

Body:

```text
Anda mendapat pesanan baru. Silakan cek detail pekerjaan Anda.
```

Data payload:

```json
{
  "type": "new_job",
  "pesanan_id": "12",
  "pesanan_cleaner_id": "31",
  "screen": "detail_pesanan"
}
```

Semua value data payload FCM dikirim sebagai string.

## Yang Perlu Dilakukan Frontend Cleaner

### Saat Login Berhasil

1. Simpan token Sanctum dari response login.
2. Inisialisasi Firebase di aplikasi.
3. Request permission notifikasi ke user.
4. Ambil FCM token dari Firebase SDK.
5. Kirim token tersebut ke:

```http
POST /api/cleaner/fcm-token
```

### Saat FCM Token Berubah

Firebase bisa memberi token baru. Jika token berubah, kirim ulang ke endpoint:

```http
POST /api/cleaner/fcm-token
```

### Saat Push Notification Diterima

Jika payload:

```json
{
  "type": "new_job",
  "screen": "detail_pesanan",
  "pesanan_cleaner_id": "31"
}
```

Maka aplikasi sebaiknya membuka halaman detail pesanan/job Cleaner.

Endpoint detail job yang sudah ada:

```http
GET /api/cleaner/jobs/{pesanan_cleaner_id}?cleaner_id={cleaner_id}
```

Contoh:

```http
GET /api/cleaner/jobs/31?cleaner_id=7
```

## Catatan Queue Backend

Backend memakai database queue.

Worker perlu jalan supaya notifikasi benar-benar terkirim:

```bash
php artisan queue:work
```

Kalau worker tidak jalan:

- assign Cleaner tetap berhasil
- log `notification_logs` akan tetap ada dengan status `queued`
- push notification belum terkirim sampai worker dijalankan

## Status Notification Log

Tabel `notification_logs` dipakai untuk mencatat proses notifikasi.

Kemungkinan status:

| Status | Arti |
| --- | --- |
| `queued` | Notifikasi sudah dibuat dan menunggu queue worker |
| `success` | FCM berhasil dikirim |
| `skipped` | FCM tidak dikirim, biasanya karena token Cleaner kosong |
| `failed` | FCM gagal, misalnya token invalid atau konfigurasi Firebase bermasalah |

Kegagalan FCM tidak membatalkan proses assign Cleaner.

## Konfigurasi Firebase Backend

Backend membutuhkan service account JSON dari Firebase Console.

Langkah manual:

1. Buka Firebase Console.
2. Pilih project.
3. Masuk ke Project Settings.
4. Buka tab Service accounts.
5. Klik Generate new private key.
6. Simpan file JSON ke:

```text
storage/app/firebase/service-account.json
```

7. Isi `.env` backend:

```env
FIREBASE_SERVICE_ACCOUNT_PATH=storage/app/firebase/service-account.json
QUEUE_CONNECTION=database
```

8. Jalankan:

```bash
php artisan migrate
php artisan config:clear
php artisan queue:work
```

File JSON service account tidak boleh masuk Git. Project sudah meng-ignore:

```text
/storage/app/firebase/*.json
```

## Checklist Testing Bruno/Postman

### Test Simpan FCM Token

1. Login sebagai Cleaner.
2. Copy Bearer token.
3. Request:

```http
POST /api/cleaner/fcm-token
Authorization: Bearer {token_cleaner}
```

Body:

```json
{
  "fcm_token": "dummy-token-atau-token-asli-firebase"
}
```

Expected:

- HTTP `200`
- `status: true`
- database `karyawans.fcm_token` terisi

### Test Assign Cleaner

1. Login sebagai CS.
2. Pastikan queue worker berjalan.
3. Request:

```http
POST /api/pesanan/{pesanan_id}/assign-cleaner
Authorization: Bearer {token_cs}
```

Body:

```json
{
  "cleaner_ids": [7]
}
```

Expected:

- assign berhasil
- ada row `notification_logs` channel `fcm`
- status berubah dari `queued` menjadi `success`, `skipped`, atau `failed` setelah worker memproses job
- jika token FCM asli valid, device Cleaner menerima push notification

## Catatan Penting Untuk Frontend

- Jangan hardcode `pesanan_id` dari notification untuk detail job jika halaman Cleaner memakai `pesanan_cleaner_id`.
- Untuk membuka detail job Cleaner, gunakan `pesanan_cleaner_id` dari payload.
- Tetap refresh data dari API setelah user membuka notification, karena notification hanya sebagai trigger.
- Jika user logout lalu login lagi, kirim ulang FCM token.
- Jika aplikasi mendeteksi token FCM berubah, kirim ulang FCM token ke backend.

# Dokumentasi Fitur Absensi Cleaner

Fitur ini memungkinkan Cleaner untuk melakukan absensi dengan swafoto (selfie) menggunakan kamera depan dan lokasi GPS dengan akurasi tinggi.

## Struktur File
- `lib/features/attendance/data/attendance_model.dart`: Model untuk Status Absensi & Riwayat.
- `lib/features/attendance/services/attendance_service.dart`: API Service (Check-in, Check-out, Saya).
- `lib/features/attendance/services/mock_location_service.dart`: Service untuk mendeteksi *Fake GPS* via MethodChannel Kotlin.
- `lib/features/cleaner/attendance/cleaner_attendance_screen.dart`: Layar Utama Absensi (Tombol, Status, Validasi).
- `lib/features/cleaner/attendance/camera_screen.dart`: Layar Kamera (Khusus depan, dilarang upload galeri).
- `lib/features/cleaner/attendance/cleaner_attendance_history_screen.dart`: Layar daftar riwayat absensi.

## Endpoint API yang Digunakan
1. `GET /api/absensi/saya`: Mengecek status hari ini dan mengambil kordinat kantor/cabang.
2. `POST /api/absensi/check-in`: Melakukan absen masuk. (Multipart/form-data: selfie, latitude, longitude, akurasi_meter, is_mock_location, device_info).
3. `POST /api/absensi/check-out`: Melakukan absen pulang. 
4. `GET /api/absensi/history`: Mengambil riwayat.

## Persyaratan Sistem
1. Izin Kamera.
2. Izin Lokasi Akurasi Tinggi (Precise).
3. GPS Harus Nyala.
4. Jarak < Maksimal Radius (mis. 50 meter dari branch).
5. Fake GPS / Mock Location Detection harus *false*.

## Cara Testing (Cleaner)
1. Login menggunakan akun dengan role Cleaner.
2. Klik navigasi "Absen" di tengah *bottom bar*.
3. Izinkan semua permission (jika baru pertama kali).
4. Pastikan mock location mati.
5. Klik Check-In, ambil selfie, dan kirim.
6. Refresh untuk melihat status berubah.

## Mode Admin / Finance
1. Menu absensi juga ditambahkan untuk role Admin/Finance/HRD di *bottom bar*.
2. Layar ini memanggil `GET /api/admin/absensi` untuk melihat riwayat absen seluruh cleaner.
3. Fitur **Selfie Viewer**: Jika ada *selfie*, Admin bisa klik "Lihat Selfie".
4. Karena selfie disimpan di *private storage* server, API akan mengembalikan `selfie_view_url` yang merupakan *Temporary Signed URL* (aman & tanpa Bearer).
5. URL ini akan *expired* dalam beberapa menit. 
6. Jika Admin membiarkan aplikasi menyala lalu membuka URL yang expired, gambar akan gagal dimuat (`errorBuilder` terpanggil).
7. Aplikasi akan otomatis menjalankan retry memanggil `GET /api/absensi/{id}` untuk _refresh_ URL terbaru tanpa _crash_ atau perlu relogin.

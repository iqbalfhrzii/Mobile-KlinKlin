# Dokumentasi: Lokasi Absensi Cabang

Fitur ini memungkinkan Admin/HRD untuk mengonfigurasi titik lokasi (latitude & longitude) serta radius batas absensi (dalam satuan meter) untuk setiap Cabang Klinklin. Data ini digunakan oleh backend untuk memvalidasi posisi GPS cleaner saat mereka melakukan Check-In atau Check-Out.

## Field Baru pada Cabang
Pada model Cabang di Flutter (serta tabel di database Laravel), ditambahkan 3 kolom berikut:
1. `latitude` (Double, opsional): Garis lintang lokasi cabang.
2. `longitude` (Double, opsional): Garis bujur lokasi cabang.
3. `radius_absensi_meter` (Int, opsional, default 100): Jarak maksimal yang diperbolehkan bagi cleaner untuk melakukan absensi (dihitung dari titik latitude & longitude cabang).

## Cara Admin Mengambil Lokasi Kantor
1. Buka aplikasi sebagai **HRD/Admin/Finance**.
2. Masuk ke **Data Master -> Cabang**.
3. Pilih **Tambah Cabang** atau **Edit Cabang** yang sudah ada.
4. Pada bagian form "Lokasi Absensi Cleaner", tekan tombol **Ambil Lokasi Kantor Saat Ini**.
5. Sistem akan meminta izin (*permission*) lokasi. Jika diizinkan, aplikasi akan mencari koordinat GPS dengan akurasi tinggi.
6. Kolom *Latitude* dan *Longitude* akan otomatis terisi. Nilai *Radius* akan diisi *default* 100 (jika kosong).

## Arti Radius Absensi
Radius absensi adalah jarak toleransi maksimal dari titik tengah (lokasi kantor) hingga ke titik HP cleaner. 
- Minimum radius: 20 meter.
- Maksimum radius: 1000 meter.
Jika jarak *cleaner* melebihi batas radius tersebut, maka absensi akan otomatis ditandai `invalid` (ditolak) oleh server.

## Contoh Payload API
Saat Admin menyimpan data cabang, Flutter akan mengirimkan payload JSON ke endpoint `POST /api/cabang` (Tambah) atau `PUT /api/cabang/{id}` (Edit):

```json
{
  "nama_cabang": "Cabang Malang",
  "alamat": "Jl. Kenanga Indah I",
  "status": "aktif",
  "latitude": -7.940562,
  "longitude": 112.625368,
  "radius_absensi_meter": 100
}
```

## Cara Testing Tambah dan Edit Cabang
1. Pastikan fitur GPS menyala.
2. Coba tambahkan Cabang baru, isi form secara manual tanpa memencet tombol lokasi. Tekan **Simpan**. Sistem harus menolak dengan pesan *"Silakan ambil titik lokasi kantor terlebih dahulu."*
3. Coba isi radius dengan angka 10, sistem akan merespons *"Radius absensi minimal 20 meter."*
4. Tekan **Ambil Lokasi**, pastikan titik latitude dan longitude terisi, lalu simpan.
5. Buka kembali halaman **Detail Cabang**, verifikasi bahwa informasi lokasi absensi (Latitude, Longitude, Radius) tampil dengan benar.

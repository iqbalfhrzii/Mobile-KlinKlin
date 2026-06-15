# Rekap Endpoint API Klinklin

Base URL lokal:

```txt
http://127.0.0.1:8000/api
```

Base URL dari HP fisik, sesuaikan IP laptop:

```txt
http://192.168.1.18:8000/api
```

Header umum untuk semua endpoint yang berada di dalam `auth:sanctum`:

```txt
Accept: application/json
Content-Type: application/json
Authorization: Bearer TOKEN_LOGIN
```

Catatan:

```txt
POST /api/login tidak memakai Authorization Bearer.
Endpoint cabang, jabatan, karyawan, pelanggan, dan layanan memakai Authorization Bearer.
```

---

# 1. Auth Singkat

## Login

```txt
POST /api/login
```

Body JSON:

```json
{
  "email": "cs@klinklin.com",
  "pin": "123456"
}
```

Response penting:

```json
{
  "message": "Login berhasil",
  "token_type": "Bearer",
  "token": "TOKEN_LOGIN",
  "wajib_ganti_pin": true
}
```

---

# 2. Cabang

## List Cabang

```txt
GET /api/cabangs
```

Body: tidak ada.

---

## Detail Cabang

```txt
GET /api/cabangs/{id}
```

Contoh:

```txt
GET /api/cabangs/1
```

Body: tidak ada.

---

## Tambah Cabang

```txt
POST /api/cabangs
```

Body JSON:

```json
{
  "nama_cabang": "Malang",
  "alamat": "Jl. Soekarno Hatta, Malang",
  "status": "aktif"
}
```

---

## Update Cabang

```txt
PUT /api/cabangs/{id}
```

Contoh:

```txt
PUT /api/cabangs/1
```

Body JSON:

```json
{
  "nama_cabang": "Malang Kota",
  "alamat": "Jl. Soekarno Hatta No. 10, Malang",
  "status": "aktif"
}
```

---

## Hapus Cabang

```txt
DELETE /api/cabangs/{id}
```

Contoh:

```txt
DELETE /api/cabangs/1
```

Body: tidak ada.

---

# 3. Jabatan

## List Jabatan

```txt
GET /api/jabatans
```

Body: tidak ada.

---

## Detail Jabatan

```txt
GET /api/jabatans/{id}
```

Contoh:

```txt
GET /api/jabatans/1
```

Body: tidak ada.

---

## Tambah Jabatan

```txt
POST /api/jabatans
```

Body JSON:

```json
{
  "cabang_id": 1,
  "nama_jabatan": "CS"
}
```

Contoh lain:

```json
{
  "cabang_id": 1,
  "nama_jabatan": "Cleaner"
}
```

```json
{
  "cabang_id": 1,
  "nama_jabatan": "Finance"
}
```

---

## Update Jabatan

```txt
PUT /api/jabatans/{id}
```

Contoh:

```txt
PUT /api/jabatans/1
```

Body JSON:

```json
{
  "cabang_id": 1,
  "nama_jabatan": "Customer Service"
}
```

---

## Hapus Jabatan

```txt
DELETE /api/jabatans/{id}
```

Contoh:

```txt
DELETE /api/jabatans/1
```

Body: tidak ada.

---

# 4. Karyawan

## List Karyawan

```txt
GET /api/karyawans
```

Body: tidak ada.

---

## Detail Karyawan

```txt
GET /api/karyawans/{id}
```

Contoh:

```txt
GET /api/karyawans/1
```

Body: tidak ada.

---

## Tambah Karyawan

```txt
POST /api/karyawans
```

Body JSON:

```json
{
  "cabang_id": 1,
  "jabatan_id": 1,
  "nama": "CS Malang",
  "email": "cs@klinklin.com",
  "pin": "123456",
  "no_wa": "081234567890",
  "foto_profil": null,
  "status": "aktif"
}
```

Catatan:

```txt
PIN dikirim plain dari request, lalu di backend disimpan dalam bentuk hash.
```

---

## Update Karyawan

```txt
PUT /api/karyawans/{id}
```

Contoh:

```txt
PUT /api/karyawans/1
```

Body JSON tanpa ganti PIN:

```json
{
  "cabang_id": 1,
  "jabatan_id": 1,
  "nama": "CS Malang Update",
  "email": "cs@klinklin.com",
  "no_wa": "081234567890",
  "foto_profil": null,
  "status": "aktif"
}
```

Body JSON dengan ganti PIN:

```json
{
  "cabang_id": 1,
  "jabatan_id": 1,
  "nama": "CS Malang Update",
  "email": "cs@klinklin.com",
  "pin": "654321",
  "no_wa": "081234567890",
  "foto_profil": null,
  "status": "aktif"
}
```

---

## Hapus Karyawan

```txt
DELETE /api/karyawans/{id}
```

Contoh:

```txt
DELETE /api/karyawans/1
```

Body: tidak ada.

---

# 5. Pelanggan

## List Pelanggan

```txt
GET /api/pelanggans
```

Body: tidak ada.

Query optional:

```txt
GET /api/pelanggans?search=budi
GET /api/pelanggans?cabang_id=1
GET /api/pelanggans?status=aktif
GET /api/pelanggans?search=budi&cabang_id=1&status=aktif
```

---

## Detail Pelanggan

```txt
GET /api/pelanggans/{id}
```

Contoh:

```txt
GET /api/pelanggans/1
```

Body: tidak ada.

---

## Tambah Pelanggan

```txt
POST /api/pelanggans
```

Body JSON:

```json
{
  "cabang_id": 1,
  "nama_pelanggan": "Budi Santoso",
  "no_wa": "081234567890",
  "alamat": "Jl. Mawar No. 10, Malang",
  "status": "aktif"
}
```

Catatan:

```txt
no_wa boleh kosong dan boleh dobel walaupun dalam cabang yang sama.
```

Body JSON jika tanpa nomor WA:

```json
{
  "cabang_id": 1,
  "nama_pelanggan": "Customer Walk In",
  "no_wa": null,
  "alamat": "Malang",
  "status": "aktif"
}
```

---

## Update Pelanggan

```txt
PUT /api/pelanggans/{id}
```

Contoh:

```txt
PUT /api/pelanggans/1
```

Body JSON:

```json
{
  "cabang_id": 1,
  "nama_pelanggan": "Budi Santoso Update",
  "no_wa": "081234567890",
  "alamat": "Jl. Mawar No. 11, Malang",
  "status": "aktif"
}
```

---

## Nonaktifkan Pelanggan

```txt
DELETE /api/pelanggans/{id}
```

Contoh:

```txt
DELETE /api/pelanggans/1
```

Body: tidak ada.

Catatan:

```txt
Di controller terakhir, delete pelanggan tidak menghapus permanen.
Delete hanya mengubah status menjadi nonaktif.
```

---

# 6. Layanan

## List Layanan

```txt
GET /api/layanans
```

Body: tidak ada.

Query optional:

```txt
GET /api/layanans?search=sofa
GET /api/layanans?cabang_id=1
GET /api/layanans?status=aktif
GET /api/layanans?search=sofa&cabang_id=1&status=aktif
```

---

## Detail Layanan

```txt
GET /api/layanans/{id}
```

Contoh:

```txt
GET /api/layanans/1
```

Body: tidak ada.

---

## Tambah Layanan

```txt
POST /api/layanans
```

Body JSON:

```json
{
  "cabang_id": 1,
  "nama_layanan": "Cuci Sofa",
  "status": "aktif"
}
```

Catatan:

```txt
Layanan tidak memakai harga_default.
Harga nanti diatur di detail_pesanan.
Nama layanan tidak dibuat unique, jadi bisa dobel kalau memang dibutuhkan.
```

---

## Update Layanan

```txt
PUT /api/layanans/{id}
```

Contoh:

```txt
PUT /api/layanans/1
```

Body JSON:

```json
{
  "cabang_id": 1,
  "nama_layanan": "Cuci Sofa Premium",
  "status": "aktif"
}
```

---

## Nonaktifkan Layanan

```txt
DELETE /api/layanans/{id}
```

Contoh:

```txt
DELETE /api/layanans/1
```

Body: tidak ada.

Catatan:

```txt
Delete layanan tidak menghapus permanen.
Delete hanya mengubah status menjadi nonaktif.
```

---

# 7. Urutan Testing yang Disarankan

```txt
1. Login untuk mendapatkan token
2. Tambah cabang
3. Tambah jabatan berdasarkan cabang
4. Tambah karyawan berdasarkan cabang dan jabatan
5. Tambah pelanggan berdasarkan cabang
6. Tambah layanan berdasarkan cabang
7. Baru lanjut modul pesanan
```

---

# 8. Contoh Header di Postman

Untuk endpoint selain login:

```txt
Accept: application/json
Content-Type: application/json
Authorization: Bearer 1|xxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

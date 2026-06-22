# Karyawan Foto Profil API

Dokumentasi ini khusus untuk alur ganti foto profil karyawan pada project `klinklin-api`.

Dokumen ini ditulis supaya developer frontend bisa cepat paham cara upload, cara membaca response, dan cara menampilkan foto profil lagi di dashboard CS tanpa harus baca source code backend lebih dulu.

Base URL mengikuti environment backend, contoh:

```text
http://127.0.0.1:8000/api
```

## Kebutuhan Auth

Semua endpoint di dokumen ini saat ini berada di dalam middleware `auth:sanctum`.

Gunakan header:

```http
Authorization: Bearer {token}
Accept: application/json
```

Karena ada upload file, request kirim foto harus memakai `multipart/form-data`.

## Tujuan Fitur

Fitur ini dibuat supaya:

1. frontend bisa pilih file gambar dari device
2. frontend upload gambar ke backend
3. backend simpan isi foto ke database pada kolom `karyawans.foto_profil`
4. field `foto_profil` bisa dikembalikan lagi di endpoint login, `me`, dan data karyawan
5. frontend dashboard CS bisa langsung menampilkan foto profil dari field itu

## Ringkasan Endpoint

| Method | Endpoint | Keterangan |
| --- | --- | --- |
| `POST` | `/me/foto-profil` | User login ganti foto profil miliknya sendiri |
| `POST` | `/karyawans/{karyawan}/foto-profil` | Admin/HRD/CS update foto profil karyawan tertentu |
| `POST` | `/karyawans` | Create karyawan baru, bisa sekalian kirim `foto_profil_file` |
| `PUT` | `/karyawans/{karyawan}` | Update data karyawan, bisa sekalian kirim `foto_profil_file` |
| `GET` | `/me` | Ambil data user login, termasuk `foto_profil` |
| `POST` | `/login` | Response login juga sudah menyertakan `foto_profil` |
| `GET` | `/karyawans` | List karyawan menyertakan `foto_profil` |
| `GET` | `/karyawans/{karyawan}` | Detail karyawan menyertakan `foto_profil` |

Implementasi utamanya ada di:

- [app/Http/Controllers/Api/AuthController.php](/c:/Users/L13%20yoga/klinklin/klinklin-api/app/Http/Controllers/Api/AuthController.php)
- [app/Http/Controllers/Api/KaryawanController.php](/c:/Users/L13%20yoga/klinklin/klinklin-api/app/Http/Controllers/Api/KaryawanController.php)
- [app/Support/ProfilePhotoData.php](/c:/Users/L13%20yoga/klinklin/klinklin-api/app/Support/ProfilePhotoData.php)
- [routes/api.php](/c:/Users/L13%20yoga/klinklin/klinklin-api/routes/api.php)
- [database/migrations/2026_06_20_000000_change_foto_profil_column_on_karyawans_table.php](/c:/Users/L13%20yoga/klinklin/klinklin-api/database/migrations/2026_06_20_000000_change_foto_profil_column_on_karyawans_table.php)

## Bentuk Data `foto_profil`

Backend menyimpan `foto_profil` ke database dalam format `data URL base64`.

Contoh nilai field:

```text
data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...
```

Artinya:

- ini bukan path file storage
- ini bukan URL CDN
- ini isi gambar langsung yang dibungkus string
- untuk frontend web, string ini bisa langsung dipakai sebagai nilai `src` pada tag `<img>`

## Validasi Upload

Semua upload foto profil memakai rule:

| Field | Tipe | Wajib | Catatan |
| --- | --- | --- | --- |
| `foto_profil` | file image | ya | khusus endpoint upload foto |
| `foto_profil_file` | file image | tidak | hanya untuk create/update data karyawan |

Batas saat ini:

- file harus lolos validasi `image`
- ukuran maksimal `2048 KB`

## 1. Ganti Foto Profil User Login

### Request

```http
POST /api/me/foto-profil
```

### Content Type

Gunakan `multipart/form-data`.

### Field Request

| Field | Tipe | Wajib | Catatan |
| --- | --- | --- | --- |
| `foto_profil` | file | ya | jpg, jpeg, png, webp, dan format image lain yang lolos validasi Laravel |

### Contoh cURL

```bash
curl -X POST "http://127.0.0.1:8000/api/me/foto-profil" \
  -H "Authorization: Bearer {token}" \
  -H "Accept: application/json" \
  -F "foto_profil=@foto-saya.png"
```

### Contoh Success Response

```json
{
  "message": "Foto profil berhasil diperbarui",
  "data": {
    "id": 4,
    "cabang_id": 2,
    "jabatan_id": 7,
    "nama": "CS Surabaya",
    "email": "cs.sby@example.com",
    "no_wa": "081234567890",
    "foto_profil": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...",
    "status": "aktif",
    "last_login_at": "2026-06-20T08:10:00.000000Z",
    "pin_changed_at": "2026-06-18T09:00:00.000000Z",
    "cabang": {
      "id": 2,
      "nama_cabang": "Surabaya"
    },
    "jabatan": {
      "id": 7,
      "nama_jabatan": "CS"
    }
  }
}
```

## 2. Ganti Foto Profil Karyawan dari Tabel Karyawan

Endpoint ini cocok untuk halaman admin atau HRD yang mengelola data karyawan dari tabel.

### Request

```http
POST /api/karyawans/{karyawan}/foto-profil
```

Contoh:

```http
POST /api/karyawans/12/foto-profil
```

### Field Request

| Field | Tipe | Wajib | Catatan |
| --- | --- | --- | --- |
| `foto_profil` | file | ya | file gambar profil karyawan |

### Contoh cURL

```bash
curl -X POST "http://127.0.0.1:8000/api/karyawans/12/foto-profil" \
  -H "Authorization: Bearer {token}" \
  -H "Accept: application/json" \
  -F "foto_profil=@foto-karyawan.jpg"
```

### Contoh Success Response

```json
{
  "message": "Foto profil karyawan berhasil diperbarui",
  "data": {
    "id": 12,
    "nama": "Budi Cleaner",
    "email": "budi.cleaner@example.com",
    "foto_profil": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD...",
    "status": "aktif",
    "cabang": {
      "id": 3,
      "nama_cabang": "Jakarta Selatan"
    },
    "jabatan": {
      "id": 8,
      "nama_jabatan": "Cleaner"
    }
  }
}
```

## 3. Create Karyawan Sekalian Upload Foto

Kalau form tambah karyawan ingin sekalian upload foto, frontend bisa tetap memakai endpoint create biasa.

### Request

```http
POST /api/karyawans
```

### Field Baru yang Relevan

| Field | Tipe | Wajib | Catatan |
| --- | --- | --- | --- |
| `foto_profil` | string | tidak | boleh dipakai kalau frontend memang sudah punya data URL sendiri |
| `foto_profil_file` | file | tidak | direkomendasikan jika frontend upload file biasa |

### Contoh cURL

```bash
curl -X POST "http://127.0.0.1:8000/api/karyawans" \
  -H "Authorization: Bearer {token}" \
  -H "Accept: application/json" \
  -F "cabang_id=2" \
  -F "jabatan_id=7" \
  -F "nama=CS Baru" \
  -F "email=cs.baru@example.com" \
  -F "pin=1234" \
  -F "status=aktif" \
  -F "foto_profil_file=@avatar.png"
```

## 4. Update Karyawan Sekalian Upload Foto

Kalau halaman edit karyawan sudah punya form lengkap, frontend bisa kirim data edit biasa plus file baru.

### Request

```http
PUT /api/karyawans/{karyawan}
```

Catatan penting:

- beberapa client frontend lebih mudah kirim `POST` + `_method=PUT` saat ada upload file
- kalau client bisa kirim `PUT multipart/form-data` langsung, itu juga boleh

### Field Baru yang Relevan

| Field | Tipe | Wajib | Catatan |
| --- | --- | --- | --- |
| `foto_profil` | string | tidak | opsional |
| `foto_profil_file` | file | tidak | rekomendasi untuk upload file |

### Contoh cURL

```bash
curl -X POST "http://127.0.0.1:8000/api/karyawans/12" \
  -H "Authorization: Bearer {token}" \
  -H "Accept: application/json" \
  -F "_method=PUT" \
  -F "cabang_id=2" \
  -F "jabatan_id=8" \
  -F "nama=Budi Cleaner" \
  -F "email=budi.cleaner@example.com" \
  -F "status=aktif" \
  -F "foto_profil_file=@avatar-baru.png"
```

## 5. Ambil Foto Profil untuk Ditampilkan

Frontend tidak perlu endpoint tambahan untuk preview.

Karena `foto_profil` sudah ikut di beberapa response, frontend cukup baca field itu dari endpoint yang memang sudah dipakai.

Paling umum:

- setelah login: ambil dari response `POST /login`
- saat buka profile sendiri: ambil dari `GET /me`
- saat buka tabel karyawan: ambil dari `GET /karyawans`
- saat buka detail karyawan: ambil dari `GET /karyawans/{karyawan}`

### Contoh Potongan Response `GET /me`

```json
{
  "message": "Data user login berhasil diambil",
  "wajib_ganti_pin": false,
  "data": {
    "id": 4,
    "nama": "CS Surabaya",
    "foto_profil": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..."
  }
}
```

## Cara Pakai di Frontend

### Frontend Web

Kalau `foto_profil` tidak null, string itu bisa langsung dipakai di `img`.

Contoh React / web biasa:

```jsx
<img
  src={karyawan.foto_profil || "/images/default-avatar.png"}
  alt={karyawan.nama}
  width={40}
  height={40}
/>
```

### Flutter

Kalau widget yang dipakai mendukung data URL langsung, field bisa dipakai apa adanya.

Kalau ingin lebih aman, parse bagian base64-nya lalu decode:

```dart
import 'dart:convert';
import 'dart:typed_data';

Uint8List? decodeProfilePhoto(String? value) {
  if (value == null || value.isEmpty) return null;
  final parts = value.split(',');
  if (parts.length != 2) return null;
  return base64Decode(parts[1]);
}
```

Lalu:

```dart
final bytes = decodeProfilePhoto(karyawan.fotoProfil);

if (bytes != null) {
  return Image.memory(bytes, fit: BoxFit.cover);
}

return Image.asset('assets/images/default-avatar.png');
```

## Contoh Request Frontend

### JavaScript Fetch

```js
const formData = new FormData();
formData.append("foto_profil", fileInput.files[0]);

const response = await fetch("/api/me/foto-profil", {
  method: "POST",
  headers: {
    Authorization: `Bearer ${token}`,
    Accept: "application/json",
  },
  body: formData,
});

const result = await response.json();
```

### Axios

```js
const formData = new FormData();
formData.append("foto_profil", file);

const { data } = await axios.post("/api/karyawans/12/foto-profil", formData, {
  headers: {
    Authorization: `Bearer ${token}`,
    Accept: "application/json",
  },
});
```

### Flutter Dio

```dart
final formData = FormData.fromMap({
  'foto_profil': await MultipartFile.fromFile(file.path),
});

final response = await dio.post(
  '/api/me/foto-profil',
  data: formData,
  options: Options(
    headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    },
  ),
);
```

## Error Yang Perlu Diantisipasi Frontend

Jika file tidak valid, Laravel akan mengembalikan `422 Unprocessable Entity`.

Contoh kasus:

- file tidak dikirim
- file bukan image
- file melebihi `2048 KB`

Contoh bentuk response validasi:

```json
{
  "message": "The foto profil field is required.",
  "errors": {
    "foto_profil": [
      "The foto profil field is required."
    ]
  }
}
```

## Catatan Penting untuk Frontend

- gunakan `multipart/form-data` saat upload
- nama field upload endpoint khusus adalah `foto_profil`
- nama field upload di form create/edit karyawan adalah `foto_profil_file`
- `foto_profil` pada response adalah string gambar dalam format `data URL`
- kalau `foto_profil = null`, frontend sebaiknya fallback ke avatar default
- setelah upload berhasil, frontend sebaiknya update state lokal dari response terbaru, tidak perlu menebak URL sendiri

## Catatan Penting untuk Backend / Developer Berikutnya

- saat ini foto profil disimpan langsung di database, bukan di filesystem
- karena itu kolom `karyawans.foto_profil` sudah diubah ke `LONGTEXT`
- jika nanti ingin dipindah ke storage file/CDN, kontrak response `foto_profil` perlu dibahas lagi karena formatnya akan berubah

Test yang sudah ada:

- [tests/Feature/KaryawanProfilePhotoApiTest.php](/c:/Users/L13%20yoga/klinklin/klinklin-api/tests/Feature/KaryawanProfilePhotoApiTest.php)

Test tersebut mencakup:

- upload foto profil karyawan tertentu
- upload foto profil user login sendiri
- memastikan nilai `foto_profil` tersimpan di database
- memastikan nilai `foto_profil` muncul lagi di endpoint `me`

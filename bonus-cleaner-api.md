# Bonus Cleaner API

Dokumentasi ini khusus untuk endpoint bonus cleaner pada project `klinklin-api`.

Dokumen ini ditulis supaya frontend, QA, dan GPT lain mudah mengetes flow bonus tanpa harus menebak hubungan antara `bonus_layanan`, `jenis_bonuses`, dan `bonus_cleaners`.

## Tujuan Modul

Modul bonus cleaner sekarang dibagi menjadi 2 alur:

1. Bonus layanan
   Bonus berasal dari `detail_pesanans.bonus_layanan`, lalu diarahkan ke cleaner tertentu.

2. Bonus non-layanan / bonus manual
   Bonus seperti tip, parkir, bonus lembur, bonus area jauh, atau bonus manual lain ditambahkan langsung ke cleaner tertentu memakai `jenis_bonus_id`.

## Poin Penting

- bonus cleaner **tidak masuk ke subtotal pesanan**
- bonus cleaner **tidak masuk ke total tagihan pembayaran**
- total bonus cleaner berdiri sendiri di `PesananCleaner.total_bonus`
- `PesananCleaner.total_bonus` dihitung dari:

```text
sum(bonus_cleaners.nominal)
```

Jadi:

- `pesanan.subtotal` tetap hanya dari `detail_pesanans.subtotal`
- `pembayaran.total_tagihan` tetap hanya dari subtotal pesanan
- bonus hanya tampil di sisi cleaner / bonus ledger

## Base URL

Contoh:

```text
http://127.0.0.1:8000/api
```

## Auth

Endpoint bonus cleaner saat ini berada di dalam middleware `auth:sanctum`.

Gunakan header:

```http
Authorization: Bearer {token}
Accept: application/json
Content-Type: application/json
```

## Tabel yang Dipakai

### `detail_pesanans`

Source bonus layanan:

- `bonus_layanan`

### `jenis_bonuses`

Kategori bonus:

- `Bonus Layanan`
- `Bonus Area Jauh`
- `Bonus Lembur`
- `Bonus Manual`

### `tarif_bonus_cabangs`

Master default nominal bonus per cabang dan per jenis bonus.

### `bonus_cleaners`

Tempat bonus final milik cleaner.

Kolom penting:

- `pesanan_cleaner_id`
- `tarif_bonus_cabang_id`
- `nominal`
- `keterangan`

## Catatan Penting untuk Frontend (Ringkas)

- Penyimpanan: setiap bonus disimpan per-cleaner pada relasi `pesanan_cleaners` (lihat kolom `pesanan_cleaner_id` di tabel `bonus_cleaners`). Artinya setiap pesanan dapat memiliki beberapa `pesanan_cleaners`, dan masing-masing `pesanan_cleaner` punya `bonuses` sendiri.
- Dampak ke pesanan/customer: bonus tidak mengubah `pesanan.subtotal` atau `pembayaran.total_tagihan`. Jangan mengandalkan nilai bonus untuk menghitung tagihan customer.
- Ketika frontend hanya punya `cleaner_id` (bukan `pesanan_cleaner_id`), backend akan mencocokkan `pesanan_cleaners` yang terkait dengan `pesanan` tersebut dan `cleaner_id` yang dikirim untuk menemukan `pesanan_cleaner_id` yang benar.
- Untuk bonus manual yang dikirim batch, backend akan menyimpan `nominal` persis seperti yang dikirim frontend, dan `tarif_bonus_cabang_id` akan diset ke `null` (ini menandakan bonus bersifat manual, bukan berasal dari master tarif).

Contoh singkat pemetaan frontend → penyimpanan di DB:

Frontend: `{ "cleaner_id": 7, "nominal": 50000 }`

DB (bonus_cleaners): `{ "pesanan_cleaner_id": 31, "tarif_bonus_cabang_id": null, "nominal": 50000, "keterangan": "Bonus manual" }`

Jika frontend sudah punya `pesanan_cleaner_id`, kirimlah langsung untuk kejelasan dan efisiensi.


## Ringkasan Endpoint

| Method | Endpoint | Fungsi |
| --- | --- | --- |
| `POST` | `/pesanan/{pesanan}/bonus-layanan` | Alokasikan bonus layanan ke cleaner tertentu |
| `POST` | `/pesanan-cleaners/{pesananCleaner}/bonus` | Tambah bonus manual / non-layanan ke cleaner |

## Relasi yang Dipakai di Response

Response bonus cleaner memanfaatkan relasi existing:

- `pesanan.cleaners.bonuses.tarifBonusCabang.jenisBonus`
- `pesananCleaner.bonuses.tarifBonusCabang.jenisBonus`

Dengan ini frontend bisa menampilkan:

- nama bonus
- nominal
- keterangan
- total bonus cleaner

## 1. Alokasikan Bonus Layanan

### Tujuan

Dipakai ketika 1 pesanan punya satu atau lebih cleaner, lalu bonus dari masing-masing layanan ingin diberikan ke cleaner tertentu.

### Endpoint

```http
POST /api/pesanan/{pesanan}/bonus-layanan
```

### Rule

- pesanan harus berada di status:
  - `assigned`
  - `in_progress`
  - `finished_by_cleaner`
- bonus layanan diambil dari `detail_pesanans.bonus_layanan`
- satu detail pesanan hanya boleh dialokasikan satu kali
- bonus layanan tidak dibagi otomatis
- user menentukan bonus layanan item ini diberikan ke cleaner yang mana

### Request Body

```json
{
  "items": [
    {
      "detail_pesanan_id": 25,
      "pesanan_cleaner_id": 31
    },
    {
      "detail_pesanan_id": 26,
      "pesanan_cleaner_id": 32,
      "keterangan": "Diarahkan ke cleaner kedua"
    }
  ]
}
```

### Arti Field

| Field | Tipe | Wajib | Catatan |
| --- | --- | --- | --- |
| `items` | array | ya | daftar alokasi bonus layanan |
| `items.*.detail_pesanan_id` | number | ya | detail pesanan sumber bonus |
| `items.*.pesanan_cleaner_id` | number | ya | cleaner penerima bonus |
| `items.*.keterangan` | string | tidak | catatan tambahan |

### Cara Hitung

Nominal bonus **tidak diinput lagi** di endpoint ini.

Backend otomatis mengambil:

```text
nominal = detail_pesanans.bonus_layanan
```

Contoh:

- detail `Cuci Sofa` punya `bonus_layanan = 10000`
- dialokasikan ke cleaner Budi
- sistem buat row `bonus_cleaners.nominal = 10000`

### Success Response

```json
{
  "status": true,
  "message": "Bonus layanan berhasil dialokasikan ke cleaner",
  "data": {
    "id": 12,
    "status_pesanan": "finished_by_cleaner",
    "subtotal": 200000,
    "details": [
      {
        "id": 25,
        "layanan_id": 2,
        "bonus_layanan": 10000,
        "layanan": {
          "id": 2,
          "nama_layanan": "Cuci Sofa"
        }
      },
      {
        "id": 26,
        "layanan_id": 3,
        "bonus_layanan": 5000,
        "layanan": {
          "id": 3,
          "nama_layanan": "Cuci Karpet"
        }
      }
    ],
    "cleaners": [
      {
        "id": 31,
        "cleaner_id": 7,
        "total_bonus": 10000,
        "bonuses": [
          {
            "id": 1,
            "nominal": 10000,
            "keterangan": "[BONUS_LAYANAN][DETAIL:25] | Bonus layanan - Cuci Sofa",
            "tarif_bonus_cabang": {
              "id": 9,
              "jenis_bonus": {
                "id": 1,
                "nama_bonus": "Bonus Layanan"
              }
            }
          }
        ]
      },
      {
        "id": 32,
        "cleaner_id": 8,
        "total_bonus": 5000,
        "bonuses": [
          {
            "id": 2,
            "nominal": 5000,
            "keterangan": "[BONUS_LAYANAN][DETAIL:26] | Bonus layanan - Cuci Karpet | Diarahkan ke cleaner kedua",
            "tarif_bonus_cabang": {
              "id": 9,
              "jenis_bonus": {
                "id": 1,
                "nama_bonus": "Bonus Layanan"
              }
            }
          }
        ]
      }
    ]
  }
}
```

### Error Jika Detail Sudah Pernah Dialokasikan

```json
{
  "status": false,
  "message": "Bonus layanan untuk detail pesanan ini sudah dialokasikan",
  "data": {}
}
```

### Error Jika Status Pesanan Tidak Valid

```json
{
  "status": false,
  "message": "Bonus layanan hanya bisa dialokasikan saat pesanan sudah memiliki cleaner aktif",
  "data": {}
}
```

## 2. Tambah Bonus Manual / Non-Layanan

### Tujuan

Dipakai untuk bonus di luar layanan seperti:

- tip customer
- parkir
- bonus lembur
- bonus area jauh
- bonus manual lain

### Endpoint

```http
POST /api/pesanan-cleaners/{pesananCleaner}/bonus
```

### Request Body

```json
{
  "jenis_bonus_id": 4,
  "nominal": 20000,
  "keterangan": "Tip customer"
}
```

### Arti Field

| Field | Tipe | Wajib | Catatan |
| --- | --- | --- | --- |
| `jenis_bonus_id` | number | ya | referensi ke `jenis_bonuses` |
| `nominal` | number | ya | nominal final bonus untuk cleaner itu |
| `keterangan` | string | tidak | catatan bonus, misalnya `Tip customer` |

### Rule

- bonus manual selalu terkait ke satu `pesanan_cleaner`
- backend akan mencari `tarif_bonus_cabang` berdasarkan:
  - cabang dari pesanan
  - `jenis_bonus_id`
- `jenis_bonus_id` untuk `Bonus Layanan` tidak boleh dipakai di endpoint ini
- untuk `Bonus Layanan`, harus lewat endpoint `bonus-layanan`

### Success Response

```json
{
  "status": true,
  "message": "Bonus cleaner berhasil ditambahkan",
  "data": {
    "id": 31,
    "pesanan_id": 12,
    "cleaner_id": 7,
    "status_pengerjaan": "finished",
    "total_bonus": 20000,
    "cleaner": {
      "id": 7,
      "nama": "Cleaner Budi"
    },
    "bonuses": [
      {
        "id": 5,
        "nominal": 20000,
        "keterangan": "Tip customer",
        "tarif_bonus_cabang": {
          "id": 10,
          "jenis_bonus": {
            "id": 4,
            "nama_bonus": "Bonus Manual"
          }
        }
      }
    ],
    "pesanan": {
      "id": 12,
      "status_pesanan": "finished_by_cleaner",
      "subtotal": 200000
    }
  }
}
```

### Error Jika `jenis_bonus_id` Mengarah ke Bonus Layanan

```json
{
  "status": false,
  "message": "Bonus Layanan harus dialokasikan lewat endpoint bonus layanan",
  "data": {}
}
```

### Error Jika Master Tarif Bonus Cabang Belum Ada

```json
{
  "status": false,
  "message": "Tarif bonus cabang untuk jenis bonus ini belum tersedia",
  "data": {}
}

## 3. Tambah Bonus Manual (Batch) — format frontend baru

### Tujuan

Dipakai ketika frontend ingin mengirim daftar bonus per cleaner sekaligus (manual input nominal per cleaner). Contoh: cashier atau admin mengisi nilai bonus per cleaner lalu submit satu kali.

### Endpoint

```http
POST /api/pesanan/{pesanan}/bonus-manual
```

### Request Body (contoh yang diminta frontend)

Jika frontend hanya punya `cleaner_id` dan `bonus` per item:

```json
{
  "items": [
    {"cleaner_id": 7, "nominal": 50000},
    {"cleaner_id": 8, "nominal": 20000}
  ]
}
```

Atau frontend dapat mengirim langsung `pesanan_cleaner_id` ketika tersedia:

```json
{
  "items": [
    {"pesanan_cleaner_id": 31, "nominal": 50000},
    {"pesanan_cleaner_id": 32, "nominal": 20000}
  ]
}
```

### Arti Field

| Field | Tipe | Wajib | Catatan |
| --- | --- | --- | --- |
| `items` | array | ya | daftar bonus per cleaner |
| `items.*.cleaner_id` | number | ya salah satu dari dua | cleaner id global — controller akan mencari `pesanan_cleaners` milik `pesanan` tersebut |
| `items.*.pesanan_cleaner_id` | number | ya salah satu dari dua | id relasi `pesanan_cleaners` (lebih langsung dan disarankan jika tersedia) |
| `items.*.nominal` | number | ya | nominal final yang akan disimpan di `bonus_cleaners.nominal` |
| `items.*.keterangan` | string | tidak | catatan tambahan |

### Rule

- pesanan harus berada di status: `assigned`, `in_progress`, atau `finished_by_cleaner`
- backend akan menyimpan `nominal` yang dikirim frontend langsung ke `bonus_cleaners.nominal`
- untuk record yang dibuat lewat endpoint ini, `tarif_bonus_cabang_id` akan diset `null` (riwayat bonus tetap tersimpan)

### Success Response

Response akan mirip dengan endpoint lain: `status`, `message`, dan data pesanan yang di-refresh termasuk relasi `cleaners.bonuses`.

---

```

## Total Bonus vs Total Pesanan

Ini bagian yang paling penting untuk tester:

### Yang masuk ke total pesanan

Yang masuk ke subtotal / total tagihan pesanan hanya:

```text
sum(detail_pesanans.subtotal)
```

### Yang tidak masuk ke total pesanan

Bonus cleaner:

- bonus layanan
- tip
- parkir
- bonus lembur
- bonus area jauh
- bonus manual

semuanya **tidak masuk ke subtotal pesanan** dan **tidak masuk ke total pembayaran customer**.

### Contoh

Pesanan:

- subtotal layanan = 200000

Bonus cleaner:

- bonus layanan = 10000
- tip = 20000

Hasil:

```text
pesanan.subtotal = 200000
pembayaran.total_tagihan = 200000
total_bonus cleaner = 30000
```

Jadi bonus punya total sendiri.

## Cara Frontend Menampilkan

Frontend bisa menampilkan:

### Di detail pesanan

- `subtotal` untuk total order customer
- `details[*].bonus_layanan` untuk source bonus layanan
- `cleaners[*].total_bonus` untuk total bonus final per cleaner
- `cleaners[*].bonuses[*]` untuk rincian bonus

### Di detail cleaner

Gunakan relasi di endpoint existing seperti:

- `GET /api/pesanan/{pesanan}`
- `GET /api/cleaner/jobs/{pesananCleaner}?cleaner_id=...`

Karena keduanya sudah meload:

```text
bonuses.tarifBonusCabang.jenisBonus
```

## Catatan Tester

- Jangan cek bonus cleaner dari `subtotal`
- Jangan cek bonus cleaner dari `pembayaran.total_akhir`
- Cek bonus cleaner dari:
  - `cleaners[*].total_bonus`
  - `cleaners[*].bonuses`

## Referensi Test Otomatis

Flow bonus ini sudah dites di:

- [tests/Feature/BonusCleanerApiTest.php](/c:/Users/L13%20yoga/klinklin/klinklin-api/tests/Feature/BonusCleanerApiTest.php)

Yang sudah dicek:

- bonus layanan bisa dialokasikan ke cleaner tertentu
- satu detail bonus layanan tidak boleh dialokasikan dua kali
- bonus manual bisa ditambahkan per cleaner dengan `jenis_bonus_id`
- bonus cleaner tidak mengubah subtotal pesanan maupun total tagihan pembayaran

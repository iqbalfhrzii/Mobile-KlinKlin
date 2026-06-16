# Dokumentasi Frontend Modul Pesanan Klinklin

Dokumen ini dipakai sebagai panduan untuk tim frontend dalam membuat halaman, membaca alur status, dan menggunakan endpoint API modul **Pesanan**.

Update terakhir:
- Pesanan bisa dibuat oleh CS tanpa harus dibayar dulu.
- Cleaner bisa langsung di-assign dari halaman detail pesanan.
- Setelah assign, CS bisa mengirim notifikasi job ke cleaner.
- Cleaner bisa melihat job dan estimasi bonus.
- Pembayaran diinput setelah pekerjaan selesai.
- Finance melakukan approval pembayaran atau pembatalan.

---

# 1. Ringkasan Alur Sistem

## 1.1 Alur CS

```txt
CS login
→ CS membuat pesanan
→ CS membuka detail pesanan
→ CS assign cleaner
→ Sistem membuat bonus cleaner berdasarkan tarif bonus cabang
→ CS klik kirim notifikasi job
→ Cleaner menerima job
→ Cleaner mengerjakan job
→ Cleaner menandai pekerjaan selesai
→ CS lanjut pembayaran atau ajukan pembatalan
→ Finance melakukan approval
```

## 1.2 Alur Cleaner

```txt
Cleaner menerima notifikasi job
→ Cleaner buka detail job
→ Cleaner melihat detail pelanggan, layanan, dan estimasi bonus
→ Cleaner mulai pekerjaan
→ Cleaner menyelesaikan pekerjaan
→ Status pesanan berubah jika semua cleaner sudah selesai
```

## 1.3 Alur Finance / HRD

```txt
Finance membuka daftar approval
→ Finance melihat pembayaran atau pembatalan yang menunggu validasi
→ Finance approve / reject pembayaran
→ Finance approve pembatalan
```

---

# 2. Status yang Dipakai

## 2.1 Status Pesanan

Field:

```txt
status_pesanan
```

| Status | Arti |
|---|---|
| `draft` | Pesanan baru dibuat, belum assign cleaner |
| `assigned` | Cleaner sudah ditugaskan |
| `in_progress` | Cleaner sedang mengerjakan |
| `finished_by_cleaner` | Semua cleaner selesai mengerjakan |
| `waiting_payment_approval` | CS sudah input pembayaran, menunggu approval Finance |
| `waiting_cancel_approval` | CS mengajukan pembatalan, menunggu approval |
| `completed` | Pembayaran sudah valid dan pesanan selesai |
| `cancelled` | Pesanan dibatalkan |

---

## 2.2 Status Pengerjaan Cleaner

Field:

```txt
status_pengerjaan
```

Tabel:

```txt
pesanan_cleaners
```

| Status | Arti |
|---|---|
| `assigned` | Cleaner sudah dipilih oleh CS |
| `notified` | Cleaner sudah dikirim notifikasi |
| `in_progress` | Cleaner sedang mengerjakan |
| `finished` | Cleaner sudah menyelesaikan pekerjaan |

---

# 3. Halaman yang Dibutuhkan untuk CS

---

## 3.1 Halaman Daftar Pesanan

### Route Frontend

```txt
/pesanan
```

### Fungsi

Menampilkan seluruh data pesanan.

### Endpoint

```http
GET /api/pesanan
```

### Query Filter Opsional

```txt
status_pesanan=draft
cabang_id=2
chat_dari=organik
tipe_customer=baru
```

### Contoh Request

```http
GET /api/pesanan
GET /api/pesanan?status_pesanan=draft
GET /api/pesanan?status_pesanan=assigned
GET /api/pesanan?cabang_id=2
GET /api/pesanan?chat_dari=ads
GET /api/pesanan?tipe_customer=baru
```

### Data yang Ditampilkan

```txt
- ID pesanan
- Nama pelanggan
- Cabang
- CS
- Status pesanan
- Chat dari
- Tipe customer
- Tanggal input
- Jumlah layanan
- Jumlah cleaner
- Tombol detail
```

### Tombol

```txt
- Detail
- Buat Pesanan
```

---

## 3.2 Halaman Buat Pesanan

### Route Frontend

```txt
/pesanan/create
```

### Fungsi

CS membuat pesanan baru dan memilih layanan yang dipesan pelanggan.

### Endpoint

```http
POST /api/pesanan
```

### Field Form

```txt
- Pelanggan
- Cabang
- CS
- Chat dari
- Tipe customer
- Keterangan order
- Detail layanan
```

### Enum `chat_dari`

```txt
organik
ads
lama
```

### Enum `tipe_customer`

```txt
lama
baru
```

### Detail Layanan

```txt
- Layanan
- Qty
- Harga
- Tanggal pengerjaan
- Waktu pengerjaan
- Bonus layanan
```

### Contoh Body JSON

```json
{
  "pelanggan_id": 1,
  "cabang_id": 2,
  "cs_id": 2,
  "chat_dari": "organik",
  "tipe_customer": "baru",
  "keterangan_order": "Cuci sofa dan kasur",
  "details": [
    {
      "layanan_id": 1,
      "qty": 2,
      "harga": 50000,
      "tanggal_pengerjaan": "2026-06-20",
      "waktu_pengerjaan": "10:00",
      "bonus_layanan": 10000
    },
    {
      "layanan_id": 2,
      "qty": 1,
      "harga": 75000,
      "tanggal_pengerjaan": "2026-06-20",
      "waktu_pengerjaan": "10:00",
      "bonus_layanan": 15000
    }
  ]
}
```

### Hasil Setelah Berhasil

```txt
status_pesanan = draft
```

### Redirect Setelah Berhasil

```txt
/pesanan/{id}
```

---

## 3.3 Halaman Detail Pesanan CS

### Route Frontend

```txt
/pesanan/{id}
```

### Fungsi

Halaman pusat kontrol pesanan untuk CS.

### Endpoint

```http
GET /api/pesanan/{id}
```

### Data yang Ditampilkan

#### 1. Informasi Pesanan

```txt
- ID pesanan
- Nama pelanggan
- No WhatsApp pelanggan
- Alamat pelanggan
- Cabang
- CS
- Chat dari
- Tipe customer
- Status pesanan
- Keterangan order
- Tanggal input
```

#### 2. Detail Layanan

```txt
- Nama layanan
- Qty
- Harga
- Subtotal
- Tanggal pengerjaan
- Waktu pengerjaan
- Bonus layanan
```

#### 3. Assign Cleaner

```txt
- Cleaner yang ditugaskan
- Status pengerjaan tiap cleaner
- Waktu notified
- Waktu mulai
- Waktu selesai
```

#### 4. Bonus Cleaner

```txt
- Nama cleaner
- Jenis bonus
- Nominal bonus
- Keterangan bonus
- Total bonus per cleaner
```

Contoh tampilan:

```txt
Cleaner Budi
- Bonus Layanan: Rp15.000
- Bonus Area Jauh: Rp10.000
Total Bonus: Rp25.000
```

#### 5. Aksi

```txt
- Edit pesanan
- Hapus pesanan
- Assign / ubah cleaner
- Kirim notifikasi job
- Lanjut pembayaran
- Ajukan pembatalan
```

---

## 3.4 Tombol pada Detail Pesanan Berdasarkan Status

| Status Pesanan | Tombol yang Muncul |
|---|---|
| `draft` | Edit Pesanan, Hapus Pesanan, Assign Cleaner |
| `assigned` | Edit Pesanan, Ubah Cleaner, Kirim Notifikasi Job |
| `in_progress` | Lihat Progress Cleaner |
| `finished_by_cleaner` | Lanjut Pembayaran, Ajukan Pembatalan |
| `waiting_payment_approval` | Menunggu Approval Finance |
| `waiting_cancel_approval` | Menunggu Approval Pembatalan |
| `completed` | Pesanan Selesai |
| `cancelled` | Pesanan Dibatalkan |

---

## 3.5 Halaman Edit Pesanan

### Route Frontend

```txt
/pesanan/{id}/edit
```

### Endpoint

```http
PUT /api/pesanan/{id}
```

### Syarat Bisa Edit

```txt
status_pesanan = draft
atau
status_pesanan = assigned
```

### Body

Format body sama seperti create pesanan.

### Catatan

Saat update, detail layanan lama akan diganti dengan detail layanan baru dari request.

---

## 3.6 Hapus Pesanan

### Endpoint

```http
DELETE /api/pesanan/{id}
```

### Syarat

```txt
status_pesanan = draft
```

---

## 3.7 Section Assign Cleaner

### Lokasi UI

Ada di halaman:

```txt
/pesanan/{id}
```

### Endpoint

```http
POST /api/pesanan/{id}/assign-cleaner
```

### Body

```json
{
  "cleaner_ids": [3, 4]
}
```

### Efek Backend

```txt
- Data masuk ke tabel pesanan_cleaners
- status_pengerjaan = assigned
- status_pesanan = assigned
- Sistem mengambil tarif_bonus_cabangs berdasarkan cabang pesanan
- Sistem membuat data bonus_cleaners untuk setiap cleaner
```

### Response yang Perlu Dipakai Frontend

Frontend perlu membaca:

```txt
data.cleaners
data.cleaners[].cleaner
data.cleaners[].bonuses
data.cleaners[].bonuses[].tarif_bonus_cabang
data.cleaners[].bonuses[].tarif_bonus_cabang.jenis_bonus
data.cleaners[].total_bonus
```

### Contoh Data Cleaner dan Bonus

```json
{
  "id": 1,
  "pesanan_id": 2,
  "cleaner_id": 3,
  "status_pengerjaan": "assigned",
  "total_bonus": 25000,
  "cleaner": {
    "id": 3,
    "nama": "Cleaner Budi"
  },
  "bonuses": [
    {
      "id": 1,
      "nominal": "15000.00",
      "keterangan": "Bonus default dari cabang",
      "tarif_bonus_cabang": {
        "id": 1,
        "nominal_default": "15000.00",
        "jenis_bonus": {
          "id": 1,
          "nama_bonus": "Bonus Layanan"
        }
      }
    },
    {
      "id": 2,
      "nominal": "10000.00",
      "keterangan": "Bonus default dari cabang",
      "tarif_bonus_cabang": {
        "id": 2,
        "nominal_default": "10000.00",
        "jenis_bonus": {
          "id": 2,
          "nama_bonus": "Bonus Area Jauh"
        }
      }
    }
  ]
}
```

---

## 3.8 Action Kirim Notifikasi Job

### Lokasi UI

Ada di halaman detail pesanan:

```txt
/pesanan/{id}
```

### Endpoint

```http
POST /api/pesanan/{id}/notify-cleaner
```

### Status

```txt
Belum dibuat di backend tahap pertama.
```

### Body

```json
{}
```

### Efek yang Diharapkan

```txt
- Sistem kirim WhatsApp ke cleaner
- Sistem kirim push notification ke aplikasi cleaner
- status_pengerjaan cleaner berubah menjadi notified
- notified_at terisi
```

### Syarat Tombol Aktif

```txt
status_pesanan = assigned
minimal ada 1 cleaner
```

---

## 3.9 Halaman Lanjut Pembayaran

### Route Frontend

```txt
/pesanan/{id}/pembayaran
```

### Endpoint

```http
POST /api/pesanan/{id}/pembayaran
```

### Status

```txt
Belum dibuat di backend tahap pertama.
```

### Syarat Tombol Muncul

```txt
status_pesanan = finished_by_cleaner
```

### Field Form

```txt
- Metode pembayaran
- Diskon persen
- PPN
- Total tagihan
- Total setelah diskon
- Total akhir
- Upload bukti transfer
```

### Body Multipart/Form-Data

```txt
metode_pembayaran: transfer
diskon_persen: 10
ppn: 11
total_tagihan: 175000
total_setelah_diskon: 157500
total_akhir: 174825
bukti_transfer: file gambar
```

### Efek yang Diharapkan

```txt
- Data masuk ke tabel pembayaran
- status_pembayaran = pending
- status_pesanan = waiting_payment_approval
```

---

## 3.10 Halaman Ajukan Pembatalan

### Route Frontend

```txt
/pesanan/{id}/pembatalan
```

### Endpoint

```http
POST /api/pesanan/{id}/pembatalan
```

### Status

```txt
Belum dibuat di backend tahap pertama.
```

### Field Form

```txt
- Alasan cancel
- Upload bukti cancel
```

### Body Multipart/Form-Data

```txt
alasan_cancel: Customer membatalkan jadwal
bukti_cancel: file gambar
```

### Efek yang Diharapkan

```txt
- Data masuk ke tabel pembatalan
- status_pesanan = waiting_cancel_approval
```

---

# 4. Halaman yang Dibutuhkan untuk Cleaner Mobile

---

## 4.1 Halaman Daftar Job Cleaner

### Route Mobile

```txt
/cleaner/jobs
```

### Endpoint

```http
GET /api/cleaner/jobs
```

### Status

```txt
Belum dibuat di backend tahap pertama.
```

### Fungsi

Menampilkan job yang ditugaskan ke cleaner yang sedang login.

### Data yang Ditampilkan

```txt
- ID pesanan
- Nama pelanggan
- Alamat pelanggan
- Tanggal pengerjaan
- Waktu pengerjaan
- Status pengerjaan cleaner
- Estimasi total bonus
- Tombol detail
```

### Catatan

Cleaner hanya boleh melihat job miliknya sendiri.

---

## 4.2 Halaman Detail Job Cleaner

### Route Mobile

```txt
/cleaner/jobs/{id}
```

### Endpoint

```http
GET /api/cleaner/jobs/{id}
```

### Status

```txt
Belum dibuat di backend tahap pertama.
```

### Data yang Ditampilkan

```txt
- Nama pelanggan
- No WhatsApp pelanggan
- Alamat pelanggan
- Detail layanan
- Catatan order
- Tanggal pengerjaan
- Waktu pengerjaan
- Status pengerjaan
- Estimasi bonus
```

### Bagian Bonus yang Wajib Ada

```txt
- Nama jenis bonus
- Nominal bonus
- Keterangan bonus
- Total bonus
```

Contoh tampilan:

```txt
Estimasi Bonus:
- Bonus Layanan: Rp15.000
- Bonus Area Jauh: Rp10.000

Total Bonus: Rp25.000
```

---

## 4.3 Action Cleaner Mulai Pekerjaan

### Endpoint

```http
POST /api/cleaner/jobs/{id}/start
```

### Status

```txt
Belum dibuat di backend tahap pertama.
```

### Efek yang Diharapkan

```txt
status_pengerjaan = in_progress
started_at = waktu sekarang
status_pesanan = in_progress
```

---

## 4.4 Action Cleaner Selesai Pekerjaan

### Endpoint

```http
POST /api/cleaner/jobs/{id}/finish
```

### Status

```txt
Belum dibuat di backend tahap pertama.
```

### Efek yang Diharapkan

```txt
status_pengerjaan = finished
finished_at = waktu sekarang
```

Jika semua cleaner pada pesanan sudah `finished`, maka:

```txt
status_pesanan = finished_by_cleaner
```

---

# 5. Halaman yang Dibutuhkan untuk Finance / HRD

---

## 5.1 Halaman Approval List

### Route Frontend

```txt
/finance/approval
```

### Endpoint

```http
GET /api/finance/approval
```

### Status

```txt
Belum dibuat di backend tahap pertama.
```

### Fungsi

Menampilkan pesanan yang menunggu approval pembayaran atau pembatalan.

### Data yang Ditampilkan

```txt
- ID pesanan
- Nama pelanggan
- Cabang
- Jenis approval
- Status pesanan
- Tanggal pengajuan
- Total tagihan / total akhir
- Tombol detail
```

### Status yang Difilter

```txt
waiting_payment_approval
waiting_cancel_approval
```

---

## 5.2 Halaman Detail Approval Pembayaran

### Route Frontend

```txt
/finance/approval/pembayaran/{id}
```

### Endpoint Detail

```http
GET /api/pembayaran/{id}
```

### Endpoint Approve

```http
POST /api/pembayaran/{id}/approve
```

### Endpoint Reject

```http
POST /api/pembayaran/{id}/reject
```

### Status

```txt
Belum dibuat di backend tahap pertama.
```

### Data yang Ditampilkan

```txt
- Ringkasan pesanan
- Data pelanggan
- Detail layanan
- Total tagihan
- Diskon persen
- PPN
- Total setelah diskon
- Total akhir
- Bukti transfer
- Tombol approve
- Tombol reject
```

### Efek Approve

```txt
status_pembayaran = approved
status_pesanan = completed
```

### Efek Reject

```txt
status_pembayaran = rejected
status_pesanan = finished_by_cleaner
```

---

## 5.3 Halaman Detail Approval Pembatalan

### Route Frontend

```txt
/finance/approval/pembatalan/{id}
```

### Endpoint Detail

```http
GET /api/pembatalan/{id}
```

### Endpoint Approve

```http
POST /api/pembatalan/{id}/approve
```

### Status

```txt
Belum dibuat di backend tahap pertama.
```

### Data yang Ditampilkan

```txt
- Ringkasan pesanan
- Data pelanggan
- Alasan cancel
- Bukti cancel
- Tombol approve pembatalan
```

### Efek Approve

```txt
status_pesanan = cancelled
cancelled_by = id finance/hrd
cancelled_at = waktu approve
```

---

# 6. Halaman Master Data yang Dibutuhkan Frontend

Data master ini dibutuhkan untuk dropdown.

## 6.1 Pelanggan

### Endpoint

```http
GET /api/pelanggans
```

atau sesuai route backend:

```http
GET /api/pelanggan
```

### Dipakai di

```txt
- Halaman buat pesanan
- Halaman edit pesanan
```

---

## 6.2 Cabang

### Endpoint

```http
GET /api/cabangs
```

atau sesuai route backend:

```http
GET /api/cabang
```

### Dipakai di

```txt
- Halaman buat pesanan
- Halaman edit pesanan
- Filter daftar pesanan
```

---

## 6.3 Karyawan / Cleaner

### Endpoint

```http
GET /api/karyawans
```

atau sesuai route backend:

```http
GET /api/karyawan
```

### Dipakai di

```txt
- Dropdown CS
- Dropdown cleaner
- Assign cleaner
```

### Filter yang Disarankan

```txt
cabang_id=2
jabatan=Cleaner
status=aktif
```

---

## 6.4 Layanan

### Endpoint

```http
GET /api/layanans
```

atau sesuai route backend:

```http
GET /api/layanan
```

### Dipakai di

```txt
- Halaman buat pesanan
- Halaman edit pesanan
- Detail layanan
```

---

## 6.5 Jenis Bonus

### Endpoint

```http
GET /api/jenis-bonus
```

### Status

```txt
Belum dibuat di backend tahap pertama jika controller bonus belum ada.
```

### Dipakai di

```txt
- Setting bonus
- Tambah bonus manual
```

---

## 6.6 Tarif Bonus Cabang

### Endpoint

```http
GET /api/tarif-bonus-cabang?cabang_id=2
```

### Status

```txt
Belum dibuat di backend tahap pertama jika controller bonus belum ada.
```

### Dipakai di

```txt
- Menampilkan bonus default cabang
- Tambah / edit bonus cleaner
```

---

# 7. Endpoint yang Sudah Bisa Digunakan Saat Ini

Endpoint ini mengikuti controller pesanan tahap pertama.

| Method | Endpoint | Fungsi |
|---|---|---|
| GET | `/api/pesanan` | List pesanan |
| POST | `/api/pesanan` | Buat pesanan |
| GET | `/api/pesanan/{id}` | Detail pesanan |
| PUT | `/api/pesanan/{id}` | Update pesanan |
| DELETE | `/api/pesanan/{id}` | Hapus pesanan |
| POST | `/api/pesanan/{id}/assign-cleaner` | Assign cleaner dan generate bonus default |

---

# 8. Endpoint Tahap Berikutnya

Endpoint ini perlu dibuat setelah core pesanan aman.

| Method | Endpoint | Fungsi |
|---|---|---|
| POST | `/api/pesanan/{id}/notify-cleaner` | Kirim notif WA dan aplikasi ke cleaner |
| GET | `/api/cleaner/jobs` | List job cleaner |
| GET | `/api/cleaner/jobs/{id}` | Detail job cleaner |
| POST | `/api/cleaner/jobs/{id}/start` | Cleaner mulai pekerjaan |
| POST | `/api/cleaner/jobs/{id}/finish` | Cleaner selesai pekerjaan |
| POST | `/api/pesanan/{id}/pembayaran` | CS input pembayaran |
| POST | `/api/pesanan/{id}/pembatalan` | CS ajukan pembatalan |
| GET | `/api/finance/approval` | List approval Finance |
| GET | `/api/pembayaran/{id}` | Detail pembayaran |
| POST | `/api/pembayaran/{id}/approve` | Approve pembayaran |
| POST | `/api/pembayaran/{id}/reject` | Reject pembayaran |
| GET | `/api/pembatalan/{id}` | Detail pembatalan |
| POST | `/api/pembatalan/{id}/approve` | Approve pembatalan |
| POST | `/api/pesanan-cleaner/{id}/bonus` | Tambah bonus manual cleaner |
| PUT | `/api/bonus-cleaner/{id}` | Edit nominal bonus cleaner |
| DELETE | `/api/bonus-cleaner/{id}` | Hapus bonus cleaner |

---

# 9. Format Request Penting

---

## 9.1 Create Pesanan

```http
POST /api/pesanan
```

```json
{
  "pelanggan_id": 1,
  "cabang_id": 2,
  "cs_id": 2,
  "chat_dari": "organik",
  "tipe_customer": "baru",
  "keterangan_order": "Cuci sofa dan kasur",
  "details": [
    {
      "layanan_id": 1,
      "qty": 2,
      "harga": 50000,
      "tanggal_pengerjaan": "2026-06-20",
      "waktu_pengerjaan": "10:00",
      "bonus_layanan": 10000
    }
  ]
}
```

---

## 9.2 Assign Cleaner

```http
POST /api/pesanan/{id}/assign-cleaner
```

```json
{
  "cleaner_ids": [3, 4]
}
```

---

## 9.3 Notify Cleaner

```http
POST /api/pesanan/{id}/notify-cleaner
```

```json
{}
```

---

## 9.4 Input Pembayaran

```http
POST /api/pesanan/{id}/pembayaran
Content-Type: multipart/form-data
```

```txt
metode_pembayaran: transfer
diskon_persen: 10
ppn: 11
total_tagihan: 175000
total_setelah_diskon: 157500
total_akhir: 174825
bukti_transfer: file gambar
```

---

## 9.5 Ajukan Pembatalan

```http
POST /api/pesanan/{id}/pembatalan
Content-Type: multipart/form-data
```

```txt
alasan_cancel: Customer membatalkan jadwal
bukti_cancel: file gambar
```

---

# 10. Data Demo dari Seeder

Seeder demo menyediakan data untuk frontend mencoba fitur.

## 10.1 Data Existing yang Dipakai

Seeder memakai data yang sudah ada:

```txt
Cabang Surabaya
CS Surabaya / Joko Wi
Jabatan Customer Service
```

## 10.2 Data Tambahan dari Seeder

```txt
- Cleaner Budi
- Cleaner Andi
- Pelanggan dummy
- Layanan dummy
- Jenis bonus
- Tarif bonus cabang
- Pesanan draft
- Pesanan assigned dengan bonus
- Pesanan finished_by_cleaner untuk test pembayaran
```

## 10.3 Sample Testing

```txt
Pesanan draft:
- Dipakai untuk test edit, delete, dan assign cleaner

Pesanan assigned:
- Dipakai untuk test detail pesanan, cleaner, dan bonus cleaner

Pesanan finished_by_cleaner:
- Dipakai untuk test halaman lanjut pembayaran
```

---

# 11. Catatan UI Penting

## 11.1 Assign Cleaner dan Notify Dipisah

Frontend jangan langsung mengirim notifikasi ketika cleaner dipilih.

Flow yang benar:

```txt
CS pilih cleaner
→ klik simpan assign cleaner
→ backend generate bonus cleaner
→ CS cek data cleaner dan bonus
→ CS klik kirim notifikasi job
```

---

## 11.2 Bonus Cleaner Ditampilkan di Web dan Mobile

Bonus cleaner wajib tampil di:

```txt
- Detail pesanan CS
- Detail job cleaner mobile
```

Yang ditampilkan:

```txt
- Jenis bonus
- Nominal
- Keterangan
- Total bonus per cleaner
```

---

## 11.3 Subtotal Dihitung Frontend dan Backend

Frontend boleh hitung subtotal untuk preview:

```txt
subtotal = qty * harga
```

Tapi backend tetap menghitung ulang subtotal agar data aman.

---

## 11.4 Format Tanggal dan Waktu

Gunakan format:

```txt
tanggal_pengerjaan: YYYY-MM-DD
waktu_pengerjaan: HH:mm
```

Contoh:

```txt
tanggal_pengerjaan: 2026-06-20
waktu_pengerjaan: 10:00
```

---

## 11.5 Upload File

Endpoint pembayaran dan pembatalan memakai:

```txt
multipart/form-data
```

Field file:

```txt
bukti_transfer
bukti_cancel
```

---

# 12. Rekomendasi Urutan Pengerjaan Frontend

Urutan paling aman:

```txt
1. Halaman daftar pesanan
2. Halaman buat pesanan
3. Halaman detail pesanan
4. Section assign cleaner
5. Tampilan bonus cleaner
6. Halaman edit pesanan
7. UI tombol kirim notifikasi job
8. Halaman cleaner jobs
9. Halaman detail job cleaner
10. Tombol cleaner start / finish
11. Halaman pembayaran CS
12. Halaman pembatalan CS
13. Halaman approval Finance
```

---

# 13. Fokus Tahap Pertama

Frontend sebaiknya fokus dulu ke:

```txt
- List pesanan
- Create pesanan
- Detail pesanan
- Assign cleaner
- Tampilkan bonus cleaner
```

Setelah itu lanjut ke:

```txt
- Notify cleaner
- Mobile cleaner job
- Pembayaran
- Pembatalan
- Approval Finance
```

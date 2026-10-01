class PengajuanFiturModel {
  final int id;
  final int karyawanId;
  final String jenis; // 'pengajuan_fitur' | 'pelaporan_bug'
  final String kategori; // 'website' | 'aplikasi'
  final String kendalaUtama;
  final String deskripsi;
  final String? fotoHalaman;
  final String? fotoHalamanUrl;
  final String status; // 'antri' | 'proses' | 'selesai'
  final String userApproval; // 'pending' | 'approved' | 'rejected'
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? namaKaryawan;
  final String? jabatanKaryawan;
  final String? cabangKaryawan;

  PengajuanFiturModel({
    required this.id,
    required this.karyawanId,
    required this.jenis,
    required this.kategori,
    required this.kendalaUtama,
    required this.deskripsi,
    this.fotoHalaman,
    this.fotoHalamanUrl,
    required this.status,
    this.userApproval = 'pending',
    this.createdAt,
    this.updatedAt,
    this.namaKaryawan,
    this.jabatanKaryawan,
    this.cabangKaryawan,
  });

  bool get isFitur => jenis == 'pengajuan_fitur';
  bool get isBug => jenis == 'pelaporan_bug';
  bool get isAplikasi => kategori == 'aplikasi';
  bool get isWebsite => kategori == 'website';

  bool get isApproved => userApproval == 'approved';
  bool get isRejected => userApproval == 'rejected';
  bool get isPendingApproval => userApproval == 'pending';

  String get jenisLabel => isFitur ? 'Fitur Baru' : 'Pelaporan Bug';
  String get kategoriLabel => isAplikasi ? 'Aplikasi Mobile' : 'Website';

  String get statusLabel {
    switch (status) {
      case 'antri':
        return 'Antri';
      case 'proses':
        return 'Sedang Diproses';
      case 'selesai':
        return 'Selesai';
      default:
        return status;
    }
  }

  factory PengajuanFiturModel.fromJson(Map<String, dynamic> json) {
    // Eager-loaded relations
    final karyawan = json['karyawan'] as Map<String, dynamic>?;
    final jabatan = karyawan?['jabatan'] as Map<String, dynamic>?;
    final cabang = karyawan?['cabang'] as Map<String, dynamic>?;

    String? fotoUrl = json['foto_halaman_url'] as String?;
    if (fotoUrl == null && json['foto_halaman'] != null) {
      final rawPath = json['foto_halaman'].toString();
      if (rawPath.startsWith('http')) {
        fotoUrl = rawPath;
      } else {
        fotoUrl = 'https://erp.klinklin.online/storage/$rawPath';
      }
    }

    return PengajuanFiturModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      karyawanId: json['karyawan_id'] is int
          ? json['karyawan_id']
          : int.tryParse(json['karyawan_id']?.toString() ?? '') ?? 0,
      jenis: json['jenis']?.toString() ?? 'pengajuan_fitur',
      kategori: json['kategori']?.toString() ?? 'website',
      kendalaUtama: json['kendala_utama']?.toString() ?? '',
      deskripsi: json['deskripsi']?.toString() ?? '',
      fotoHalaman: json['foto_halaman']?.toString(),
      fotoHalamanUrl: fotoUrl,
      status: json['status']?.toString() ?? 'antri',
      userApproval: json['user_approval']?.toString() ?? 'pending',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      namaKaryawan: karyawan?['nama']?.toString() ?? karyawan?['nama_lengkap']?.toString() ?? 'Pengguna',
      jabatanKaryawan: jabatan?['nama_jabatan']?.toString() ?? '-',
      cabangKaryawan: cabang?['nama_cabang']?.toString(),
    );
  }
}

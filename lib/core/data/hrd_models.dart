class CabangModel {
  final int id;
  final String namaCabang;
  final String? alamat;
  final String status;

  CabangModel({
    required this.id,
    required this.namaCabang,
    this.alamat,
    required this.status,
  });

  factory CabangModel.fromJson(Map<String, dynamic> json) {
    return CabangModel(
      id: json['id'],
      namaCabang: json['nama_cabang'] ?? '',
      alamat: json['alamat'],
      status: json['status'] ?? 'aktif',
    );
  }
}

class JabatanModel {
  final int id;
  final int cabangId;
  final String namaJabatan;
  final CabangModel? cabang;

  JabatanModel({
    required this.id,
    required this.cabangId,
    required this.namaJabatan,
    this.cabang,
  });

  factory JabatanModel.fromJson(Map<String, dynamic> json) {
    return JabatanModel(
      id: json['id'],
      cabangId: json['cabang_id'],
      namaJabatan: json['nama_jabatan'] ?? '',
      cabang: json['cabang'] != null ? CabangModel.fromJson(json['cabang']) : null,
    );
  }
}

class KaryawanModel {
  final int id;
  final int cabangId;
  final int jabatanId;
  final String nama;
  final String email;
  final String? noWa;
  final String? fotoProfil;
  final String status;
  final CabangModel? cabang;
  final JabatanModel? jabatan;

  KaryawanModel({
    required this.id,
    required this.cabangId,
    required this.jabatanId,
    required this.nama,
    required this.email,
    this.noWa,
    this.fotoProfil,
    required this.status,
    this.cabang,
    this.jabatan,
  });

  factory KaryawanModel.fromJson(Map<String, dynamic> json) {
    return KaryawanModel(
      id: json['id'],
      cabangId: json['cabang_id'],
      jabatanId: json['jabatan_id'],
      nama: json['nama'] ?? '',
      email: json['email'] ?? '',
      noWa: json['no_wa'],
      fotoProfil: json['foto_profil_url'] ?? json['foto_profil'],
      status: json['status'] ?? 'aktif',
      cabang: json['cabang'] != null ? CabangModel.fromJson(json['cabang']) : null,
      jabatan: json['jabatan'] != null ? JabatanModel.fromJson(json['jabatan']) : null,
    );
  }
}

class LayananModel {
  final int id;
  final int cabangId;
  final String namaLayanan;
  final String status;

  LayananModel({
    required this.id,
    required this.cabangId,
    required this.namaLayanan,
    required this.status,
  });

  factory LayananModel.fromJson(Map<String, dynamic> json) {
    return LayananModel(
      id: json['id'],
      cabangId: json['cabang_id'] ?? 0,
      namaLayanan: json['nama_layanan'] ?? '',
      status: json['status'] ?? 'aktif',
    );
  }
}

class JenisBonusModel {
  final int id;
  final String namaBonus;

  JenisBonusModel({
    required this.id,
    required this.namaBonus,
  });

  factory JenisBonusModel.fromJson(Map<String, dynamic> json) {
    return JenisBonusModel(
      id: json['id'],
      namaBonus: json['nama_bonus'] ?? '',
    );
  }
}

class TarifBonusCabangModel {
  final int id;
  final int cabangId;
  final int jenisBonusId;
  final int nominal;
  final CabangModel? cabang;
  final JenisBonusModel? jenisBonus;

  TarifBonusCabangModel({
    required this.id,
    required this.cabangId,
    required this.jenisBonusId,
    required this.nominal,
    this.cabang,
    this.jenisBonus,
  });

  factory TarifBonusCabangModel.fromJson(Map<String, dynamic> json) {
    return TarifBonusCabangModel(
      id: json['id'],
      cabangId: json['cabang_id'],
      jenisBonusId: json['jenis_bonus_id'],
      nominal: json['nominal_default'] != null ? (double.tryParse(json['nominal_default'].toString())?.toInt() ?? 0) : 0,
      cabang: json['cabang'] != null ? CabangModel.fromJson(json['cabang']) : null,
      jenisBonus: json['jenis_bonus'] != null ? JenisBonusModel.fromJson(json['jenis_bonus']) : null,
    );
  }
}

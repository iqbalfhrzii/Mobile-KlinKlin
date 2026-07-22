class CabangModel {
  final int id;
  final String namaCabang;
  final String? alamat;
  final String status;
  final double? latitude;
  final double? longitude;
  final int? radiusAbsensiMeter;
  final String? jamMasuk;
  final int? toleransiTelatMenit;
  final String? jamPulang;
  final double? targetOmzet;

  CabangModel({
    required this.id,
    required this.namaCabang,
    this.alamat,
    required this.status,
    this.latitude,
    this.longitude,
    this.radiusAbsensiMeter,
    this.jamMasuk,
    this.toleransiTelatMenit,
    this.jamPulang,
    this.targetOmzet,
  });

  factory CabangModel.fromJson(Map<String, dynamic> json) {
    return CabangModel(
      id: json['id'],
      namaCabang: json['nama_cabang'] ?? '',
      alamat: json['alamat'],
      status: json['status'] ?? 'aktif',
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      radiusAbsensiMeter: json['radius_absensi_meter'] != null ? int.tryParse(json['radius_absensi_meter'].toString()) : null,
      jamMasuk: json['jam_masuk'] != null ? json['jam_masuk'].toString().substring(0, 5) : null,
      toleransiTelatMenit: json['toleransi_telat_menit'] != null ? int.tryParse(json['toleransi_telat_menit'].toString()) : null,
      jamPulang: json['jam_pulang'] != null ? json['jam_pulang'].toString().substring(0, 5) : null,
      targetOmzet: json['target_omzet'] != null ? double.tryParse(json['target_omzet'].toString()) : null,
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
  final String? statusKaryawan;
  final String? namaBank;
  final String? noRekening;
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
    this.statusKaryawan,
    this.namaBank,
    this.noRekening,
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
      statusKaryawan: json['status_karyawan'],
      namaBank: json['nama_bank'],
      noRekening: json['no_rekening'],
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

class PelangganHrdModel {
  final int id;
  final int cabangId;
  final String namaPelanggan;
  final String? noWa;
  final String? alamat;
  final String? catatan;
  final String status;
  final CabangModel? cabang;

  PelangganHrdModel({
    required this.id,
    required this.cabangId,
    required this.namaPelanggan,
    this.noWa,
    this.alamat,
    this.catatan,
    required this.status,
    this.cabang,
  });

  factory PelangganHrdModel.fromJson(Map<String, dynamic> json) {
    return PelangganHrdModel(
      id: json['id'],
      cabangId: json['cabang_id'],
      namaPelanggan: json['nama_pelanggan'] ?? '',
      noWa: json['no_wa'],
      alamat: json['alamat'],
      catatan: json['catatan'],
      status: json['status'] ?? 'aktif',
      cabang: json['cabang'] != null ? CabangModel.fromJson(json['cabang']) : null,
    );
  }
}

class GajiPokokModel {
  final int id;
  final int cabangId;
  final int jabatanId;
  final String statusKaryawan;
  final int gajiPokok;
  final int bonusBulanan;
  final int tunjanganKos;
  final int tunjanganKerja;
  final int gajiPokokHarian;
  final int premiBpjs;
  final CabangModel? cabang;
  final JabatanModel? jabatan;

  GajiPokokModel({
    required this.id,
    required this.cabangId,
    required this.jabatanId,
    required this.statusKaryawan,
    required this.gajiPokok,
    required this.bonusBulanan,
    required this.tunjanganKos,
    required this.tunjanganKerja,
    required this.gajiPokokHarian,
    required this.premiBpjs,
    this.cabang,
    this.jabatan,
  });

  factory GajiPokokModel.fromJson(Map<String, dynamic> json) {
    return GajiPokokModel(
      id: json['id'],
      cabangId: json['cabang_id'],
      jabatanId: json['jabatan_id'],
      statusKaryawan: json['status_karyawan'] ?? '',
      gajiPokok: json['gaji_pokok'] != null ? (double.tryParse(json['gaji_pokok'].toString())?.toInt() ?? 0) : 0,
      bonusBulanan: json['bonus_bulanan'] != null ? (double.tryParse(json['bonus_bulanan'].toString())?.toInt() ?? 0) : 0,
      tunjanganKos: json['tunjangan_kos'] != null ? (double.tryParse(json['tunjangan_kos'].toString())?.toInt() ?? 0) : 0,
      tunjanganKerja: json['tunjangan_kerja'] != null ? (double.tryParse(json['tunjangan_kerja'].toString())?.toInt() ?? 0) : 0,
      gajiPokokHarian: json['gaji_pokok_harian'] != null ? (double.tryParse(json['gaji_pokok_harian'].toString())?.toInt() ?? 0) : 0,
      premiBpjs: json['premi_bpjs'] != null ? (double.tryParse(json['premi_bpjs'].toString())?.toInt() ?? 0) : 0,
      cabang: json['cabang'] != null ? CabangModel.fromJson(json['cabang']) : null,
      jabatan: json['jabatan'] != null ? JabatanModel.fromJson(json['jabatan']) : null,
    );
  }
}

class GajiKaryawanModel {
  final int id;
  final int karyawanId;
  final String jenisGaji;
  final String? snapshotCabang;
  final String? snapshotJabatan;
  final String? snapshotStatus;
  final String? awalPeriode;
  final String? akhirPeriode;
  final int? periodeBulan;
  final int? periodeTahun;
  final int? jumlahHariKerja;
  
  final int gajiPokok;
  final int gajiPokokHarian;
  final int bonusBulanan;
  final int tunjanganKos;
  final int tunjanganKerja;
  final int premiBpjs;
  
  final int kasbon;
  final int potonganTidakAbsen;
  final int potonganKeterlambatan;
  final int potonganAbsen;
  final int bpjsKetenagakerjaan;
  final int potonganLainnya;
  final String? keteranganPotonganLainnya;
  
  final int bonusReview;
  final int bonusTanggalMerah;
  final int totalKilometer;
  final int totalDeepclean;
  final int totalSalon;
  final int totalTips;
  final int totalParkir;
  final int totalLembur;
  final int totalUangMakan;
  final int totalBonusLainnya;
  
  final int totalBonus;
  final int totalPotongan;
  final int takeHomePay;
  final int totalGajiDiterima;

  final KaryawanModel? karyawan;

  GajiKaryawanModel({
    required this.id,
    required this.karyawanId,
    required this.jenisGaji,
    this.snapshotCabang,
    this.snapshotJabatan,
    this.snapshotStatus,
    this.awalPeriode,
    this.akhirPeriode,
    this.periodeBulan,
    this.periodeTahun,
    this.jumlahHariKerja,
    required this.gajiPokok,
    required this.gajiPokokHarian,
    required this.bonusBulanan,
    required this.tunjanganKos,
    required this.tunjanganKerja,
    required this.premiBpjs,
    required this.kasbon,
    required this.potonganTidakAbsen,
    required this.potonganKeterlambatan,
    required this.potonganAbsen,
    required this.bpjsKetenagakerjaan,
    required this.potonganLainnya,
    this.keteranganPotonganLainnya,
    required this.bonusReview,
    required this.bonusTanggalMerah,
    required this.totalKilometer,
    required this.totalDeepclean,
    required this.totalSalon,
    required this.totalTips,
    required this.totalParkir,
    required this.totalLembur,
    required this.totalUangMakan,
    required this.totalBonusLainnya,
    required this.totalBonus,
    required this.totalPotongan,
    required this.takeHomePay,
    required this.totalGajiDiterima,
    this.karyawan,
  });

  factory GajiKaryawanModel.fromJson(Map<String, dynamic> json) {
    return GajiKaryawanModel(
      id: json['id'] ?? 0,
      karyawanId: json['karyawan_id'] ?? 0,
      jenisGaji: json['jenis_gaji'] ?? 'bulanan',
      snapshotCabang: json['snapshot_cabang'],
      snapshotJabatan: json['snapshot_jabatan'],
      snapshotStatus: json['snapshot_status'],
      awalPeriode: json['awal_periode'],
      akhirPeriode: json['akhir_periode'],
      periodeBulan: json['periode_bulan'],
      periodeTahun: json['periode_tahun'],
      jumlahHariKerja: json['jumlah_hari_kerja'],
      gajiPokok: _parseInt(json['gaji_pokok']),
      gajiPokokHarian: _parseInt(json['gaji_pokok_harian']),
      bonusBulanan: _parseInt(json['bonus_bulanan']),
      tunjanganKos: _parseInt(json['tunjangan_kos']),
      tunjanganKerja: _parseInt(json['tunjangan_kerja']),
      premiBpjs: _parseInt(json['premi_bpjs']),
      kasbon: _parseInt(json['kasbon']),
      potonganTidakAbsen: _parseInt(json['potongan_tidak_absen']),
      potonganKeterlambatan: _parseInt(json['potongan_keterlambatan']),
      potonganAbsen: _parseInt(json['potongan_absen']),
      bpjsKetenagakerjaan: _parseInt(json['bpjs_ketenagakerjaan']),
      potonganLainnya: _parseInt(json['potongan_lainnya']),
      keteranganPotonganLainnya: json['keterangan_potongan_lainnya'],
      bonusReview: _parseInt(json['bonus_review']),
      bonusTanggalMerah: _parseInt(json['bonus_tanggal_merah']),
      totalKilometer: _parseInt(json['total_kilometer']),
      totalDeepclean: _parseInt(json['total_deepclean']),
      totalSalon: _parseInt(json['total_salon']),
      totalTips: _parseInt(json['total_tips']),
      totalParkir: _parseInt(json['total_parkir']),
      totalLembur: _parseInt(json['total_lembur']),
      totalUangMakan: _parseInt(json['total_uang_makan']),
      totalBonusLainnya: _parseInt(json['total_bonus_lainnya']),
      totalBonus: _parseInt(json['total_bonus']),
      totalPotongan: _parseInt(json['total_potongan']),
      takeHomePay: _parseInt(json['take_home_pay']),
      totalGajiDiterima: _parseInt(json['total_gaji_diterima']),
      karyawan: json['karyawan'] != null ? KaryawanModel.fromJson(json['karyawan']) : null,
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString())?.toInt() ?? 0;
  }
}

class InsentifCleanerModel {
  final int karyawanId;
  final String namaCleaner;
  final String cabang;
  final int totalInsentif;
  final int jumlahBonus;
  final List<InsentifDetailModel> riwayat;

  InsentifCleanerModel({
    required this.karyawanId,
    required this.namaCleaner,
    required this.cabang,
    required this.totalInsentif,
    required this.jumlahBonus,
    this.riwayat = const [],
  });

  factory InsentifCleanerModel.fromJson(Map<String, dynamic> json) {
    return InsentifCleanerModel(
      karyawanId: json['karyawan_id'] ?? json['id'] ?? 0,
      namaCleaner: json['nama_cleaner'] ?? json['nama'] ?? '-',
      cabang: json['cabang'] ?? (json['cabang'] is Map ? json['cabang']['nama_cabang'] : null) ?? '-',
      totalInsentif: _parseInt(json['total_insentif']),
      jumlahBonus: _parseInt(json['jumlah_bonus']),
      riwayat: json['riwayat'] != null
          ? (json['riwayat'] as List).map((e) => InsentifDetailModel.fromJson(e)).toList()
          : [],
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString())?.toInt() ?? 0;
  }
}

class InsentifDetailModel {
  final String tanggal;
  final String pelanggan;
  final String pesananIdVisual;
  final int totalNominal;
  final List<InsentifItemModel> items;

  InsentifDetailModel({
    required this.tanggal,
    required this.pelanggan,
    required this.pesananIdVisual,
    required this.totalNominal,
    this.items = const [],
  });

  factory InsentifDetailModel.fromJson(Map<String, dynamic> json) {
    return InsentifDetailModel(
      tanggal: json['tanggal'] ?? '',
      pelanggan: json['pelanggan'] ?? '',
      pesananIdVisual: json['pesanan_id_visual'] ?? '',
      totalNominal: _parseInt(json['total_nominal']),
      items: json['items'] != null
          ? (json['items'] as List).map((e) => InsentifItemModel.fromJson(e)).toList()
          : [],
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString())?.toInt() ?? 0;
  }
}

class InsentifItemModel {
  final String jenisBonus;
  final int nominal;
  final String? keterangan;

  InsentifItemModel({
    required this.jenisBonus,
    required this.nominal,
    this.keterangan,
  });

  factory InsentifItemModel.fromJson(Map<String, dynamic> json) {
    return InsentifItemModel(
      jenisBonus: json['jenis_bonus'] ?? '',
      nominal: _parseInt(json['nominal']),
      keterangan: json['keterangan'],
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString())?.toInt() ?? 0;
  }
}

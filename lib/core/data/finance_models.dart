import 'hrd_models.dart';
import 'order_model.dart';

class PemasukanModel {
  final int id;
  final int? pembayaranId;
  final int? pesananId;
  final int? cabangId;
  final int? approvedBy;
  final DateTime? tanggalPemasukan;
  final double nominal;
  final String keterangan;
  final OrderModel? pesanan;
  final CabangModel? cabang;
  final KaryawanModel? approver;

  PemasukanModel({
    required this.id,
    this.pembayaranId,
    this.pesananId,
    this.cabangId,
    this.approvedBy,
    this.tanggalPemasukan,
    required this.nominal,
    required this.keterangan,
    this.pesanan,
    this.cabang,
    this.approver,
  });

  factory PemasukanModel.fromJson(Map<String, dynamic> json) {
    return PemasukanModel(
      id: json['id'],
      pembayaranId: json['pembayaran_id'],
      pesananId: json['pesanan_id'],
      cabangId: json['cabang_id'],
      approvedBy: json['approved_by'],
      tanggalPemasukan: json['tanggal_pemasukan'] != null ? DateTime.parse(json['tanggal_pemasukan']) : null,
      nominal: double.tryParse(json['nominal'].toString()) ?? 0.0,
      keterangan: json['keterangan'] ?? '',
      pesanan: json['pesanan'] != null ? OrderModel.fromJson(json['pesanan']) : null,
      cabang: json['cabang'] != null ? CabangModel.fromJson(json['cabang']) : null,
      approver: json['approved_by'] != null && json['approved_by'] is Map ? KaryawanModel.fromJson(json['approved_by']) : null,
    );
  }
}

class PengeluaranModel {
  final int id;
  final String nomorTransaksi;
  final int? cabangId;
  final int? createdBy;
  final String kategori;
  final DateTime? tanggalPengeluaran;
  final double nominal;
  final String keterangan;
  final String? buktiPengeluaran;
  final CabangModel? cabang;
  final KaryawanModel? creator;

  PengeluaranModel({
    required this.id,
    required this.nomorTransaksi,
    this.cabangId,
    this.createdBy,
    required this.kategori,
    this.tanggalPengeluaran,
    required this.nominal,
    required this.keterangan,
    this.buktiPengeluaran,
    this.cabang,
    this.creator,
  });

  factory PengeluaranModel.fromJson(Map<String, dynamic> json) {
    return PengeluaranModel(
      id: json['id'],
      nomorTransaksi: json['nomor_transaksi'] ?? '',
      cabangId: json['cabang_id'],
      createdBy: json['created_by'],
      kategori: json['kategori'] ?? '',
      tanggalPengeluaran: json['tanggal_pengeluaran'] != null ? DateTime.parse(json['tanggal_pengeluaran']) : null,
      nominal: double.tryParse(json['nominal'].toString()) ?? 0.0,
      keterangan: json['keterangan'] ?? '',
      buktiPengeluaran: json['bukti_pengeluaran'],
      cabang: json['cabang'] != null ? CabangModel.fromJson(json['cabang']) : null,
      creator: json['created_by'] != null && json['created_by'] is Map ? KaryawanModel.fromJson(json['created_by']) : null,
    );
  }
}

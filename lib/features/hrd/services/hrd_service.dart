import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/data/hrd_models.dart';

class HrdService {
  final Dio _dio = ApiClient.instance;

  // --- Cabang ---
  Future<List<CabangModel>> fetchCabang() async {
    final response = await _dio.get('/cabangs');
    final data = response.data['data'] as List;
    return data.map((e) => CabangModel.fromJson(e)).toList();
  }

  Future<CabangModel> createCabang(Map<String, dynamic> data) async {
    final response = await _dio.post('/cabangs', data: data);
    return CabangModel.fromJson(response.data['data']);
  }

  Future<CabangModel> updateCabang(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/cabangs/$id', data: data);
    return CabangModel.fromJson(response.data['data']);
  }

  Future<void> deleteCabang(int id) async {
    await _dio.delete('/cabangs/$id');
  }

  // --- Jabatan ---
  Future<List<JabatanModel>> fetchJabatan() async {
    final response = await _dio.get('/jabatans');
    final data = response.data['data'] as List;
    return data.map((e) => JabatanModel.fromJson(e)).toList();
  }

  Future<JabatanModel> createJabatan(Map<String, dynamic> data) async {
    final response = await _dio.post('/jabatans', data: data);
    return JabatanModel.fromJson(response.data['data']);
  }

  Future<JabatanModel> updateJabatan(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/jabatans/$id', data: data);
    return JabatanModel.fromJson(response.data['data']);
  }

  Future<void> deleteJabatan(int id) async {
    await _dio.delete('/jabatans/$id');
  }

  // --- Karyawan ---
  Future<List<KaryawanModel>> fetchKaryawan({bool all = true}) async {
    final response = await _dio.get('/karyawans', queryParameters: all ? {'all': 1} : null);
    final data = response.data['data'] as List;
    return data.map((e) => KaryawanModel.fromJson(e)).toList();
  }

  Future<KaryawanModel> createKaryawan(Map<String, dynamic> data) async {
    final response = await _dio.post('/karyawans', data: data);
    return KaryawanModel.fromJson(response.data['data']);
  }

  Future<KaryawanModel> updateKaryawan(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/karyawans/$id', data: data);
    return KaryawanModel.fromJson(response.data['data']);
  }

  Future<void> updateKaryawanFoto(int id, String filePath) async {
    final filename = filePath.split(RegExp(r'[/\\]')).last;
    final formData = FormData.fromMap({
      'foto_profil': await MultipartFile.fromFile(
        filePath,
        filename: filename,
      ),
    });
    await _dio.post('/karyawans/$id/foto-profil', data: formData);
  }

  Future<void> deleteKaryawan(int id) async {
    await _dio.delete('/karyawans/$id');
  }

  // --- Layanan ---
  Future<List<LayananModel>> fetchLayanan() async {
    final response = await _dio.get('/layanans');
    final data = response.data['data'] as List;
    return data.map((e) => LayananModel.fromJson(e)).toList();
  }

  Future<LayananModel> createLayanan(Map<String, dynamic> data) async {
    final response = await _dio.post('/layanans', data: data);
    return LayananModel.fromJson(response.data['data']);
  }

  Future<LayananModel> updateLayanan(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/layanans/$id', data: data);
    return LayananModel.fromJson(response.data['data']);
  }

  Future<void> deleteLayanan(int id) async {
    await _dio.delete('/layanans/$id');
  }

  // --- Jenis Bonus ---
  Future<List<JenisBonusModel>> fetchJenisBonus() async {
    final response = await _dio.get('/jenis-bonuses');
    final data = response.data['data'] as List;
    return data.map((e) => JenisBonusModel.fromJson(e)).toList();
  }

  Future<JenisBonusModel> createJenisBonus(Map<String, dynamic> data) async {
    final response = await _dio.post('/jenis-bonuses', data: data);
    return JenisBonusModel.fromJson(response.data['data']);
  }

  Future<JenisBonusModel> updateJenisBonus(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/jenis-bonuses/$id', data: data);
    return JenisBonusModel.fromJson(response.data['data']);
  }

  Future<void> deleteJenisBonus(int id) async {
    await _dio.delete('/jenis-bonuses/$id');
  }

  // --- Tarif Bonus Cabang ---
  Future<List<TarifBonusCabangModel>> fetchTarifBonus(int cabangId) async {
    final response = await _dio.get('/tarif-bonus-cabangs', queryParameters: {'cabang_id': cabangId});
    final data = response.data['data'] as List;
    return data.map((e) => TarifBonusCabangModel.fromJson(e)).toList();
  }

  Future<TarifBonusCabangModel> setTarifBonus(int id, int cabangId, int jenisBonusId, int nominal) async {
    final dataBody = {
      'cabang_id': cabangId,
      'jenis_bonus_id': jenisBonusId,
      'nominal_default': nominal,
    };
    
    if (id > 0) {
      final response = await _dio.put('/tarif-bonus-cabangs/$id', data: dataBody);
      return TarifBonusCabangModel.fromJson(response.data['data']);
    } else {
      final response = await _dio.post('/tarif-bonus-cabangs', data: dataBody);
      return TarifBonusCabangModel.fromJson(response.data['data']);
    }
  }

  // --- Pelanggan ---
  Future<List<PelangganHrdModel>> fetchPelanggan({int? cabangId, String? search}) async {
    final Map<String, dynamic> params = {};
    if (cabangId != null) params['cabang_id'] = cabangId;
    if (search != null && search.isNotEmpty) params['search'] = search;
    
    final response = await _dio.get('/pelanggans', queryParameters: params);
    final data = response.data['data'] as List;
    return data.map((e) => PelangganHrdModel.fromJson(e)).toList();
  }

  Future<PelangganHrdModel> createPelanggan(Map<String, dynamic> data) async {
    final response = await _dio.post('/pelanggans', data: data);
    return PelangganHrdModel.fromJson(response.data['data']);
  }

  Future<PelangganHrdModel> updatePelanggan(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/pelanggans/$id', data: data);
    return PelangganHrdModel.fromJson(response.data['data']);
  }

  Future<void> deletePelanggan(int id) async {
    await _dio.delete('/pelanggans/$id');
  }

  // --- Gaji Pokok ---
  Future<List<GajiPokokModel>> fetchGajiPokok() async {
    final response = await _dio.get('/gaji-pokoks');
    final data = response.data['data'] as List;
    return data.map((e) => GajiPokokModel.fromJson(e)).toList();
  }

  Future<GajiPokokModel> createGajiPokok(Map<String, dynamic> data) async {
    final response = await _dio.post('/gaji-pokoks', data: data);
    return GajiPokokModel.fromJson(response.data['data']);
  }

  Future<GajiPokokModel> updateGajiPokok(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/gaji-pokoks/$id', data: data);
    return GajiPokokModel.fromJson(response.data['data']);
  }

  Future<void> deleteGajiPokok(int id) async {
    await _dio.delete('/gaji-pokoks/$id');
  }

  // --- Gaji Karyawan ---
  Future<List<GajiKaryawanModel>> fetchGajiKaryawan({String? filterCabang, String? filterBulan, String? search}) async {
    final response = await _dio.get('/gaji-karyawans', queryParameters: {
      if (filterCabang != null && filterCabang.isNotEmpty) 'filter_cabang': filterCabang,
      if (filterBulan != null && filterBulan.isNotEmpty) 'filter_bulan': filterBulan,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final List data = response.data['data'] ?? [];
    return data.map((json) => GajiKaryawanModel.fromJson(json)).toList();
  }

  Future<GajiKaryawanModel> generateDraftGajiKaryawan(Map<String, dynamic> params) async {
    final response = await _dio.get('/gaji-karyawans/draft', queryParameters: params);
    return GajiKaryawanModel.fromJson(response.data['data']);
  }

  Future<GajiKaryawanModel> createGajiKaryawan(Map<String, dynamic> data) async {
    final response = await _dio.post('/gaji-karyawans', data: data);
    return GajiKaryawanModel.fromJson(response.data['data']);
  }

  Future<void> deleteGajiKaryawan(int id) async {
    await _dio.delete('/gaji-karyawans/$id');
  }

  String getPrintSlipGajiUrl(int id) {
    final rootUrl = _dio.options.baseUrl.replaceAll('/api', '');
    return '$rootUrl/hrd/gaji-karyawan/$id/print';
  }

  Future<Uint8List> fetchPrintSlipPdfBytes(int id) async {
    final response = await _dio.get<List<int>>(
      '/gaji-karyawans/$id/print',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }

  // --- Insentif Cleaner (optimized direct API call) ---

  Future<Map<String, dynamic>> fetchInsentifCleaner({
    String filterWaktu = 'bulan_ini',
    int? filterCabang,
    String? filterTanggal,
  }) async {
    try {
      final params = <String, dynamic>{
        'filter_waktu': filterWaktu,
      };
      if (filterCabang != null) params['filter_cabang'] = filterCabang;
      if (filterTanggal != null && filterTanggal.isNotEmpty) {
        params['filter_tanggal'] = filterTanggal;
      }

      final response = await _dio.get('/insentif-cleaner', queryParameters: params).timeout(const Duration(seconds: 12));
      final resBody = response.data;
      if (resBody['status'] == true && resBody['data'] is List) {
        final rawList = resBody['data'] as List;
        final list = rawList.map((item) {
          return InsentifCleanerModel(
            karyawanId: item['karyawan_id'] is int ? item['karyawan_id'] : int.tryParse(item['karyawan_id'].toString()) ?? 0,
            namaCleaner: item['nama_cleaner']?.toString() ?? '-',
            cabang: item['cabang']?.toString() ?? '-',
            totalInsentif: item['total_insentif'] is int ? item['total_insentif'] : int.tryParse(item['total_insentif'].toString()) ?? 0,
            jumlahBonus: item['jumlah_bonus'] is int ? item['jumlah_bonus'] : int.tryParse(item['jumlah_bonus'].toString()) ?? 0,
            riwayat: [],
          );
        }).toList();

        return {
          'data': list,
          'total_insentif': resBody['total_insentif'] is int ? resBody['total_insentif'] : int.tryParse(resBody['total_insentif'].toString()) ?? 0,
          'jumlah_cleaner': resBody['jumlah_cleaner'] is int ? resBody['jumlah_cleaner'] : int.tryParse(resBody['jumlah_cleaner'].toString()) ?? 0,
        };
      }
    } catch (_) {}

    return {
      'data': <InsentifCleanerModel>[],
      'total_insentif': 0,
      'jumlah_cleaner': 0,
    };
  }

  Future<InsentifCleanerModel?> fetchInsentifCleanerDetail(int karyawanId, {
    String filterWaktu = 'bulan_ini',
    String? filterTanggal,
  }) async {
    try {
      final params = <String, dynamic>{
        'filter_waktu': filterWaktu,
      };
      if (filterTanggal != null && filterTanggal.isNotEmpty) {
        params['filter_tanggal'] = filterTanggal;
      }

      final response = await _dio.get('/insentif-cleaner/$karyawanId', queryParameters: params).timeout(const Duration(seconds: 12));
      final resBody = response.data;
      if (resBody['status'] == true && resBody['data'] is Map) {
        final d = resBody['data'];
        final rawRiwayat = d['riwayat'] as List? ?? [];
        final riwayatList = rawRiwayat.map((r) {
          final rawItems = r['items'] as List? ?? [];
          final itemsList = rawItems.map((it) {
            return InsentifItemModel(
              jenisBonus: it['jenis_bonus']?.toString() ?? 'Bonus Lainnya',
              nominal: it['nominal'] is int ? it['nominal'] : int.tryParse(it['nominal'].toString()) ?? 0,
              keterangan: it['keterangan']?.toString(),
            );
          }).toList();

          return InsentifDetailModel(
            tanggal: r['tanggal']?.toString() ?? '-',
            pelanggan: r['pelanggan']?.toString() ?? '-',
            pesananIdVisual: r['pesanan_id_visual']?.toString() ?? '-',
            totalNominal: r['total_nominal'] is int ? r['total_nominal'] : int.tryParse(r['total_nominal'].toString()) ?? 0,
            items: itemsList,
          );
        }).toList();

        return InsentifCleanerModel(
          karyawanId: d['karyawan_id'] is int ? d['karyawan_id'] : int.tryParse(d['karyawan_id'].toString()) ?? karyawanId,
          namaCleaner: d['nama_cleaner']?.toString() ?? '-',
          cabang: d['cabang']?.toString() ?? '-',
          totalInsentif: d['total_insentif'] is int ? d['total_insentif'] : int.tryParse(d['total_insentif'].toString()) ?? 0,
          jumlahBonus: d['jumlah_bonus'] is int ? d['jumlah_bonus'] : int.tryParse(d['jumlah_bonus'].toString()) ?? 0,
          riwayat: riwayatList,
        );
      }
    } catch (_) {}
    return null;
  }
}

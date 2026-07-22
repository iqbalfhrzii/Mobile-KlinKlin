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
  Future<List<KaryawanModel>> fetchKaryawan() async {
    final response = await _dio.get('/karyawans');
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

  // --- Insentif Cleaner (aggregated from /pesanan API, matching web Livewire logic) ---

  /// Build the list of date strings to filter on, matching InsentifPage::getFilterDates()
  List<String> _getFilterDateStrings(String filterWaktu, String? filterTanggal) {
    final now = DateTime.now();
    if (filterTanggal != null && filterTanggal.isNotEmpty) {
      return [filterTanggal]; // Already in yyyy-MM-dd format
    }
    if (filterWaktu == 'hari_ini') {
      return [_fmtDate(now)];
    } else if (filterWaktu == 'kemarin') {
      return [_fmtDate(now.subtract(const Duration(days: 1)))];
    } else if (filterWaktu == 'bulan_ini') {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0);
      final dates = <String>[];
      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        dates.add(_fmtDate(d));
      }
      return dates;
    } else if (filterWaktu == 'semua') {
      // "Semua" in web = start of month to today
      final start = DateTime(now.year, now.month, 1);
      final dates = <String>[];
      for (var d = now; !d.isBefore(start); d = d.subtract(const Duration(days: 1))) {
        dates.add(_fmtDate(d));
      }
      return dates;
    }
    return [_fmtDate(now)];
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Fetch ALL pages of pesanan from the paginated /pesanan API.
  /// Returns the raw JSON list of all order maps.
  Future<List<dynamic>> _fetchAllPesananRaw() async {
    final allOrders = <dynamic>[];
    int currentPage = 1;
    int lastPage = 1;

    do {
      final response = await _dio.get('/pesanan', queryParameters: {'page': currentPage});
      final data = response.data['data'] ?? response.data;

      if (data is Map) {
        // Laravel paginated response: { data: [...], last_page: N, ... }
        final items = data['data'] as List? ?? [];
        allOrders.addAll(items);
        lastPage = data['last_page'] ?? 1;
      } else if (data is List) {
        allOrders.addAll(data);
        break; // Non-paginated, we have all data
      }
      currentPage++;
    } while (currentPage <= lastPage);

    return allOrders;
  }

  Future<Map<String, dynamic>> fetchInsentifCleaner({
    String filterWaktu = 'bulan_ini',
    int? filterCabang,
    String? filterTanggal,
  }) async {
    try {
      // 1. Fetch all cleaners (karyawan with jabatan=Cleaner)
      final allKaryawan = await fetchKaryawan();
      final cleaners = allKaryawan.where((k) {
        final role = k.jabatan?.namaJabatan.toLowerCase() ?? '';
        if (!role.contains('cleaner')) return false;
        if (filterCabang != null && k.cabangId != filterCabang) return false;
        return true;
      }).toList();

      // 2. Fetch ALL pesanan pages (API is paginated at 10 per page)
      final allOrders = await _fetchAllPesananRaw();

      // 3. Build date filter set
      final dateSet = _getFilterDateStrings(filterWaktu, filterTanggal).toSet();

      // 4. Aggregate bonuses per cleaner, matching Livewire logic
      final Map<int, int> cleanerTotalInsentif = {};
      final Map<int, int> cleanerJumlahBonus = {};

      for (final order in allOrders) {
        final tanggalInput = order['tanggal_input']?.toString() ?? '';
        final orderDate = tanggalInput.length >= 10 ? tanggalInput.substring(0, 10) : '';
        if (!dateSet.contains(orderDate)) continue;

        if (filterCabang != null) {
          final orderCabangId = order['cabang_id'];
          if (orderCabangId != null && int.tryParse(orderCabangId.toString()) != filterCabang) continue;
        }

        final pesananCleaners = order['cleaners'] ?? order['pesanan_cleaners'] ?? [];
        for (final pc in pesananCleaners) {
          final cleanerId = int.tryParse((pc['cleaner']?['id'] ?? pc['cleaner_id'] ?? 0).toString()) ?? 0;
          if (cleanerId == 0) continue;

          final bonuses = pc['bonuses'] as List? ?? [];
          if (bonuses.isEmpty) continue;

          int bonusSum = 0;
          for (final b in bonuses) {
            final nominal = double.tryParse((b['nominal'] ?? 0).toString())?.toInt() ?? 0;
            bonusSum += nominal;
          }

          if (bonusSum > 0) {
            cleanerTotalInsentif[cleanerId] = (cleanerTotalInsentif[cleanerId] ?? 0) + bonusSum;
            cleanerJumlahBonus[cleanerId] = (cleanerJumlahBonus[cleanerId] ?? 0) + 1;
          }
        }
      }

      // 5. Build result list
      final list = cleaners.map((k) {
        return InsentifCleanerModel(
          karyawanId: k.id,
          namaCleaner: k.nama,
          cabang: k.cabang?.namaCabang ?? '-',
          totalInsentif: cleanerTotalInsentif[k.id] ?? 0,
          jumlahBonus: cleanerJumlahBonus[k.id] ?? 0,
          riwayat: [],
        );
      }).toList();

      final totalGlobal = list.fold<int>(0, (sum, item) => sum + item.totalInsentif);
      final cleanerGlobal = list.where((item) => item.totalInsentif > 0).length;

      return {
        'data': list,
        'total_insentif': totalGlobal,
        'jumlah_cleaner': cleanerGlobal,
      };
    } catch (e) {
      return {
        'data': <InsentifCleanerModel>[],
        'total_insentif': 0,
        'jumlah_cleaner': 0,
      };
    }
  }

  Future<InsentifCleanerModel?> fetchInsentifCleanerDetail(int karyawanId, {
    String filterWaktu = 'bulan_ini',
    String? filterTanggal,
  }) async {
    try {
      // Fetch cleaner info
      final allKaryawan = await fetchKaryawan();
      final cleaner = allKaryawan.firstWhere((k) => k.id == karyawanId);

      // Fetch ALL pesanan pages
      final allOrders = await _fetchAllPesananRaw();

      final dateSet = _getFilterDateStrings(filterWaktu, filterTanggal).toSet();

      // Aggregate per pesanan_cleaner (matching Livewire showDetail)
      int totalInsentif = 0;
      int jumlahBonusGroups = 0;
      final riwayat = <InsentifDetailModel>[];

      for (final order in allOrders) {
        final tanggalInput = order['tanggal_input']?.toString() ?? '';
        final orderDate = tanggalInput.length >= 10 ? tanggalInput.substring(0, 10) : '';
        if (!dateSet.contains(orderDate)) continue;

        final pesananCleaners = order['cleaners'] ?? order['pesanan_cleaners'] ?? [];
        for (final pc in pesananCleaners) {
          final cleanerId = int.tryParse((pc['cleaner']?['id'] ?? pc['cleaner_id'] ?? 0).toString()) ?? 0;
          if (cleanerId != karyawanId) continue;

          final bonuses = pc['bonuses'] as List? ?? [];
          if (bonuses.isEmpty) continue;

          int groupNominal = 0;
          final items = <InsentifItemModel>[];
          for (final b in bonuses) {
            final nominal = double.tryParse((b['nominal'] ?? 0).toString())?.toInt() ?? 0;
            groupNominal += nominal;

            String jenisBonus = 'Bonus Lainnya';
            if (b['tarif_bonus_cabang'] != null && b['tarif_bonus_cabang']['jenis_bonus'] != null) {
              jenisBonus = b['tarif_bonus_cabang']['jenis_bonus']['nama_bonus'] ?? 'Bonus Lainnya';
            }

            items.add(InsentifItemModel(
              jenisBonus: jenisBonus,
              nominal: nominal,
              keterangan: b['keterangan'],
            ));
          }

          if (groupNominal > 0) {
            totalInsentif += groupNominal;
            jumlahBonusGroups++;

            // Build visual ID matching Livewire format
            final cabangName = cleaner.cabang?.namaCabang ?? 'KLI';
            final cabangCode = cabangName.substring(0, cabangName.length >= 3 ? 3 : cabangName.length).toUpperCase();
            final parsedDate = DateTime.tryParse(tanggalInput);
            final dateCode = parsedDate != null
                ? '${parsedDate.day.toString().padLeft(2, '0')}${parsedDate.month.toString().padLeft(2, '0')}${(parsedDate.year % 100).toString().padLeft(2, '0')}'
                : '000000';
            final orderId = order['id']?.toString() ?? '0';
            final idCode = orderId.padLeft(6, '0');
            final visualId = '$cabangCode-$dateCode-$idCode';

            final pelanggan = order['pelanggan']?['nama_pelanggan'] ?? 'Unknown';
            final tanggalFmt = parsedDate != null
                ? '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year}'
                : '-';

            riwayat.add(InsentifDetailModel(
              tanggal: tanggalFmt,
              pelanggan: pelanggan,
              pesananIdVisual: visualId,
              totalNominal: groupNominal,
              items: items,
            ));
          }
        }
      }

      // Sort by tanggal descending
      riwayat.sort((a, b) => b.tanggal.compareTo(a.tanggal));

      return InsentifCleanerModel(
        karyawanId: karyawanId,
        namaCleaner: cleaner.nama,
        cabang: cleaner.cabang?.namaCabang ?? '-',
        totalInsentif: totalInsentif,
        jumlahBonus: jumlahBonusGroups,
        riwayat: riwayat,
      );
    } catch (_) {
      return null;
    }
  }
}

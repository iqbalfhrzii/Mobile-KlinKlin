import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/data/order_model.dart';
import '../../../core/data/hrd_models.dart';
import '../../orders/services/order_service.dart';
import '../../hrd/services/hrd_service.dart';

class FinanceDownloadScreen extends StatefulWidget {
  const FinanceDownloadScreen({super.key});

  @override
  State<FinanceDownloadScreen> createState() => _FinanceDownloadScreenState();
}

class _FinanceDownloadScreenState extends State<FinanceDownloadScreen> {
  final OrderService _orderService = OrderService();
  final HrdService _hrdService = HrdService();
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  String _tab = 'order';
  bool _isLoading = false;
  bool _isDownloading = false;
  String? _lastFetchError;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _filterBulan = '';
  String? _filterCabangId;
  String _filterStatus = '';

  List<CabangModel> _cabangs = [];
  List<OrderModel> _orders = [];
  List<GajiKaryawanModel> _gajiList = [];

  String _extractApiError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      if (error.response?.statusCode == 403) {
        return 'Akses ditolak (403). Akun ini tidak punya role untuk membaca data pesanan.';
      }
      if (error.response?.statusCode == 401) {
        return 'Sesi login tidak valid (401). Silakan login ulang.';
      }
      return error.message ?? 'Terjadi kesalahan jaringan.';
    }
    return error.toString();
  }

  DateTime? _tryParseFlexibleDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final direct = DateTime.tryParse(trimmed);
    if (direct != null) return direct;

    final candidate = trimmed.replaceFirst(',', '');
    const patterns = [
      'yyyy-MM-dd',
      'yyyy-MM-dd HH:mm:ss',
      'dd MMM yyyy',
      'd MMM yyyy',
      'dd MMMM yyyy',
      'd MMMM yyyy',
      'EEEE dd MMM yyyy',
      'EEEE d MMM yyyy',
      'EEEE dd MMMM yyyy',
      'EEEE d MMMM yyyy',
    ];
    const locales = ['id_ID', 'en_US'];
    for (final p in patterns) {
      for (final loc in locales) {
        try {
          return DateFormat(p, loc).parseStrict(candidate);
        } catch (_) {}
      }
    }

    final normalized = trimmed.replaceAll('/', '-');
    final dmy = RegExp(r'^(\d{2})-(\d{2})-(\d{4})(?:\s+.*)?$').firstMatch(normalized);
    if (dmy != null) {
      final day = int.tryParse(dmy.group(1)!);
      final month = int.tryParse(dmy.group(2)!);
      final year = int.tryParse(dmy.group(3)!);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  String _toCsvCell(String value) {
    var v = value.replaceAll('\r\n', ' ').replaceAll('\n', ' ').trim();
    if (v.contains('"')) {
      v = v.replaceAll('"', '""');
    }
    if (v.contains(',') || v.contains('"')) {
      return '"$v"';
    }
    return v;
  }

  String _toHtmlCell(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _updateFilterBulan();
    _fetchData();
  }

  void _updateFilterBulan() {
    _filterBulan = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _lastFetchError = null;
    });
    try {
      final cabangs = await _hrdService.fetchCabang();
      List<OrderModel> orders = [];
      List<GajiKaryawanModel> gaji = [];

      if (_tab == 'order') {
        orders = await _orderService.fetchOrders();
      } else {
        gaji = await _hrdService.fetchGajiKaryawan();
      }

      if (mounted) {
        setState(() {
          _cabangs = cabangs;
          _orders = orders;
          _gajiList = gaji;
          _isLoading = false;
          _lastFetchError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _lastFetchError = _extractApiError(e);
        });
      }
    }
  }

  // --- Expanded rows: 1 row per ServiceItem (matching Laravel DetailPesanan query) ---
  // Each entry: (order, serviceItem)
  List<(OrderModel, ServiceItem)> get _filteredOrderRows {
    final rows = <(OrderModel, ServiceItem)>[];
    int? filterMonth, filterYear;
    if (_filterBulan.isNotEmpty) {
      final parts = _filterBulan.split('-');
      if (parts.length == 2) {
        filterYear = int.tryParse(parts[0]);
        filterMonth = int.tryParse(parts[1]);
      }
    }

    for (final o in _orders) {
      // Filter cabang
      if (_filterCabangId != null && o.cabangId != _filterCabangId) continue;
      // Filter status (status_order_utama)
      if (_filterStatus.isNotEmpty) {
        if (o.statusUtamaLabel.toLowerCase() != _filterStatus.toLowerCase()) continue;
      }

      for (final svc in o.services) {
        // Filter by tanggal_pengerjaan (like Laravel whereMonth/whereYear on detail)
        if (filterMonth != null && filterYear != null) {
          final dt = _tryParseFlexibleDate(svc.tanggalPengerjaan);
          if (dt == null) continue;
          if (dt.month != filterMonth || dt.year != filterYear) continue;
        }
        rows.add((o, svc));
      }
    }
    // Sort by tanggal_pengerjaan desc
    rows.sort((a, b) {
      final da = _tryParseFlexibleDate(a.$2.tanggalPengerjaan) ?? DateTime(0);
      final db = _tryParseFlexibleDate(b.$2.tanggalPengerjaan) ?? DateTime(0);
      return db.compareTo(da);
    });
    return rows;
  }

  List<GajiKaryawanModel> get _filteredGaji {
    return _gajiList.where((g) {
      if (_filterBulan.isNotEmpty) {
        final parts = _filterBulan.split('-');
        if (parts.length == 2) {
          final month = int.tryParse(parts[1]) ?? 0;
          final year = int.tryParse(parts[0]) ?? 0;
          if (g.periodeBulan != month || g.periodeTahun != year) return false;
        }
      }
      if (_filterCabangId != null) {
        final cabangIdInt = int.tryParse(_filterCabangId!);
        if (cabangIdInt != null && g.karyawan?.cabangId != cabangIdInt) return false;
      }
      return true;
    }).toList();
  }

  String get _periodeLabel {
    if (_filterBulan.isEmpty) return 'Semua';
    try {
      final dt = DateFormat('yyyy-MM').parse(_filterBulan);
      return DateFormat('MMMM yyyy', 'id_ID').format(dt) + ' (1 bulan penuh)';
    } catch (_) {
      return _filterBulan;
    }
  }

  String get _cabangName {
    if (_filterCabangId == null) return 'SEMUA';
    try {
      final found = _cabangs.firstWhere((c) => c.id.toString() == _filterCabangId);
      return found.namaCabang.toUpperCase();
    } catch (_) {
      return 'SEMUA';
    }
  }

  int get _colCount => _tab == 'order' ? 12 : 4;

  // --- Generate CSV (12 kolom, 1 baris per service item, sama dengan web) ---
  String _generateCsvOrder(List<(OrderModel, ServiceItem)> rows) {
    final buffer = StringBuffer();
    buffer.writeln('NAMA HARI,TANGGAL PENGERJAAN,NAMA CLEANER,JAM PENGERJAAN,NAMA CUSTOMER,ALAMAT CUSTOMER,NOMOR WA CUSTOMER,LAYANAN YANG DIPESAN,QTY,NOMINAL LAYANAN,METODE PEMBAYARAN,STATUS ORDER');
    for (final (o, svc) in rows) {
      final dt = _tryParseFlexibleDate(svc.tanggalPengerjaan);
      final namaHari = dt != null ? DateFormat('EEEE', 'id_ID').format(dt) : '-';
      final tgl = dt != null ? DateFormat('dd MMM yyyy', 'id_ID').format(dt) : '-';
      final cleaners = o.cleaners.isEmpty ? '-' : o.cleaners.map((c) => c.name).join(', ');
      final jam = svc.waktuPengerjaan.isEmpty ? '-' : svc.waktuPengerjaan;
      final customer = o.customer.name;
      final alamat = o.customer.address;
      final noWa = o.customer.phone;
      final layanan = svc.name;
      final qty = svc.qty;
      final nominal = svc.subtotal;
      final metode = o.paymentMethod.isNotEmpty && o.paymentMethod != '-'
          ? o.paymentMethod
          : (o.pembayaran?.metodePembayaran ?? '-');
      final status = o.statusPesananRaw;
      buffer.writeln([
        _toCsvCell(namaHari),
        _toCsvCell(tgl),
        _toCsvCell(cleaners),
        _toCsvCell(jam),
        _toCsvCell(customer),
        _toCsvCell(alamat),
        _toCsvCell(noWa),
        _toCsvCell(layanan),
        _toCsvCell(qty),
        nominal.toString(),
        _toCsvCell(metode),
        _toCsvCell(status),
      ].join(','));
    }
    return buffer.toString();
  }

  String _generateCsvGaji(List<GajiKaryawanModel> rows) {
    final buffer = StringBuffer();
    buffer.writeln('NAMA CLEANER,TAKE HOME PAY,TOTAL BONUS,TOTAL POTONGAN');
    for (final g in rows) {
      final nama = g.karyawan?.nama ?? '-';
      buffer.writeln('${_toCsvCell(nama)},${g.takeHomePay},${g.totalBonus},${g.totalPotongan}');
    }
    return buffer.toString();
  }

  Future<void> _downloadCsv() async {
    final csvContent = _tab == 'order'
        ? _generateCsvOrder(_filteredOrderRows)
        : _generateCsvGaji(_filteredGaji);

    final bulan = _filterBulan.replaceAll('-', '_');
    final filename =
        'Rekap_${_tab.toUpperCase()}_${bulan}_${DateTime.now().millisecondsSinceEpoch}.csv';

    await _saveFileToDownloads(
      filename: filename,
      bytes: Uint8List.fromList(csvContent.codeUnits),
      mimeType: 'text/csv',
    );
  }

  Future<void> _downloadExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    if (_tab == 'order') {
      sheet.appendRow([
        TextCellValue('NAMA HARI'),
        TextCellValue('TANGGAL PENGERJAAN'),
        TextCellValue('NAMA CLEANER'),
        TextCellValue('JAM PENGERJAAN'),
        TextCellValue('NAMA CUSTOMER'),
        TextCellValue('ALAMAT CUSTOMER'),
        TextCellValue('NOMOR WA CUSTOMER'),
        TextCellValue('LAYANAN YANG DIPESAN'),
        TextCellValue('QTY'),
        TextCellValue('NOMINAL LAYANAN'),
        TextCellValue('METODE PEMBAYARAN'),
        TextCellValue('STATUS ORDER'),
      ]);

      for (final (o, svc) in _filteredOrderRows) {
        final dt = _tryParseFlexibleDate(svc.tanggalPengerjaan);
        final namaHari = dt != null ? DateFormat('EEEE', 'id_ID').format(dt) : '-';
        final tgl = dt != null ? DateFormat('dd MMM yyyy', 'id_ID').format(dt) : '-';
        final cleaners = o.cleaners.isEmpty ? '-' : o.cleaners.map((c) => c.name).join(', ');
        final jam = svc.waktuPengerjaan.isEmpty ? '-' : svc.waktuPengerjaan;
        final metode = o.paymentMethod.isNotEmpty && o.paymentMethod != '-'
            ? o.paymentMethod
            : (o.pembayaran?.metodePembayaran ?? '-');
        final status = o.statusPesananRaw;
        
        sheet.appendRow([
          TextCellValue(namaHari),
          TextCellValue(tgl),
          TextCellValue(cleaners),
          TextCellValue(jam),
          TextCellValue(o.customer.name.toString()),
          TextCellValue(o.customer.address.toString()),
          TextCellValue(o.customer.phone.toString()),
          TextCellValue(svc.name.toString()),
          TextCellValue(svc.qty.toString()),
          IntCellValue(svc.subtotal),
          TextCellValue(metode),
          TextCellValue(status),
        ]);
      }
    } else {
      sheet.appendRow([
        TextCellValue('NAMA CLEANER'),
        TextCellValue('TAKE HOME PAY'),
        TextCellValue('TOTAL BONUS'),
        TextCellValue('TOTAL POTONGAN'),
      ]);

      for (final g in _filteredGaji) {
        sheet.appendRow([
          TextCellValue(g.karyawan?.nama ?? "-"),
          IntCellValue(int.tryParse(g.takeHomePay.toString()) ?? 0),
          IntCellValue(int.tryParse(g.totalBonus.toString()) ?? 0),
          IntCellValue(int.tryParse(g.totalPotongan.toString()) ?? 0),
        ]);
      }
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Gagal membuat file excel');

    final bulan = _filterBulan.replaceAll('-', '_');
    final filename =
        'Rekap_${_tab.toUpperCase()}_${bulan}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

    await _saveFileToDownloads(
      filename: filename,
      bytes: Uint8List.fromList(bytes),
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<void> _saveFileToDownloads({
    required String filename,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    setState(() => _isDownloading = true);
    try {
      // Request storage permission
      PermissionStatus status;
      if (Platform.isAndroid) {
        // Android 13+ uses READ_MEDIA_IMAGES, below uses STORAGE
        final sdkVersion = await _getAndroidSdk();
        if (sdkVersion >= 33) {
          status = PermissionStatus.granted; // No permission needed for Downloads on Android 13+
        } else {
          status = await Permission.storage.request();
        }
      } else {
        status = PermissionStatus.granted;
      }

      if (status.isGranted || Platform.isAndroid) {
        // Try Downloads folder first
        String savePath;
        if (Platform.isAndroid) {
          savePath = '/storage/emulated/0/Download/$filename';
        } else {
          // iOS - save to app documents
          final dir = Directory('/var/mobile/Containers/Data/Application');
          savePath = '${dir.path}/$filename';
        }

        final file = File(savePath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✅ File berhasil diunduh!',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(savePath,
                      style: GoogleFonts.inter(fontSize: 10, color: Colors.white70)),
                ],
              ),
              backgroundColor: const Color(0xFF15803D),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Izin penyimpanan diperlukan untuk mengunduh file.',
                  style: GoogleFonts.inter(color: Colors.white)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunduh: $e',
                style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<int> _getAndroidSdk() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.version.sdkInt;
    } catch (_) {
      return 30;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredRows = _filteredOrderRows;
    final filteredGaji = _filteredGaji;
    final previewRows = filteredRows.take(100).toList();
    final previewGaji = filteredGaji.take(100).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTabRow(),
                    const SizedBox(height: 10),
                    _buildFilterPanel(),
                    const SizedBox(height: 10),
                    _buildDownloadPanel(filteredRows.length, filteredGaji.length),
                    const SizedBox(height: 10),
                    _buildPreviewPanel(previewRows, previewGaji),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Download Data',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Unduh data Order & Gaji ke file CSV/Excel',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.download_rounded, color: Colors.white, size: 15),
                const SizedBox(width: 6),
                Text(
                  'Rekap Data',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabRow() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTabBtn('Order', 'order'),
          const SizedBox(width: 4),
          _buildTabBtn('Gaji', 'gaji'),
        ],
      ),
    );
  }

  Widget _buildTabBtn(String label, String key) {
    final isActive = _tab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_tab == key) return;
          setState(() {
            _tab = key;
            _orders = [];
            _gajiList = [];
          });
          _fetchData();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF0F52BA) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (isActive)
                BoxShadow(
                  color: const Color(0xFF0F52BA).withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 8),
              Text(
                'Pilih Data yang Diunduh',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Kalender (Bulan & Tahun)
          GestureDetector(
            onTap: _showMonthYearPicker,
            child: _buildDropdownContainer(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        DateFormat('MMMM yyyy', 'id_ID').format(DateTime(_selectedYear, _selectedMonth)),
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Row 2: Cabang + Status (if order)
          Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildDropdownContainer(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _filterCabangId,
                      isExpanded: true,
                      isDense: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                      hint: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      items: [
                        DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Semua Cabang',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600))),
                        ..._cabangs.map((c) => DropdownMenuItem<String?>(
                              value: c.id.toString(),
                              child: Text(c.namaCabang,
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (val) => setState(() => _filterCabangId = val),
                    ),
                  ),
                ),
              ),
              if (_tab == 'order') ...[
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: _buildDropdownContainer(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _filterStatus.isEmpty ? '' : _filterStatus,
                        isExpanded: true,
                        isDense: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        items: [
                          DropdownMenuItem(value: '', child: Text('Semua Status', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: 'done', child: Text('Done', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: 'process', child: Text('Process', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: 'pending', child: Text('Pending', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: 'cancelled', child: Text('Dibatalkan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: 'draft', child: Text('Draft', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600))),
                        ],
                        onChanged: (val) => setState(() => _filterStatus = val ?? ''),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }

  Future<void> _showMonthYearPicker() async {
    int tempYear = _selectedYear;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.all(20),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => setStateDialog(() => tempYear--),
                  ),
                  Text(tempYear.toString(), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => setStateDialog(() => tempYear++),
                  ),
                ],
              ),
              content: SizedBox(
                width: 300,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, i) {
                    final monthNumber = i + 1;
                    final isSelected = (monthNumber == _selectedMonth && tempYear == _selectedYear);
                    final monthName = DateFormat('MMM', 'id_ID').format(DateTime(2000, monthNumber));
                    
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedMonth = monthNumber;
                          _selectedYear = tempYear;
                          _updateFilterBulan();
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade200),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          monthName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.textDark,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDownloadPanel(int orderCount, int gajiCount) {
    final totalRows = _tab == 'order' ? _filteredOrderRows.length : gajiCount;
    final statusLabel = _filterStatus.isEmpty ? 'Semua' : _filterStatus;
    final totalDetailRows = _orders.fold<int>(0, (sum, o) => sum + o.services.length);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info Card with clean background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(
                      'Ringkasan Data Unduhan',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), height: 1.4),
                    children: [
                      const TextSpan(text: 'Data '),
                      TextSpan(text: _tab.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const TextSpan(text: ' • Periode: '),
                      TextSpan(text: _periodeLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const TextSpan(text: ' • Cabang: '),
                      TextSpan(text: _cabangName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      if (_tab == 'order') ...[
                        const TextSpan(text: ' • Status: '),
                        TextSpan(text: statusLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ],
                      const TextSpan(text: '\nDitemukan: '),
                      TextSpan(text: '$totalRows baris', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                      TextSpan(text: ' ($_colCount kolom)', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      if (_tab == 'order')
                        TextSpan(text: ' ($orderCount pesanan, $totalDetailRows detail)', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_lastFetchError != null) ...[
            const SizedBox(height: 8),
            Text(
              'Gagal memuat data: $_lastFetchError',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFDC2626)),
            ),
          ],
          const SizedBox(height: 12),

          // Download Buttons
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _isDownloading || _isLoading ? null : _downloadExcel,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                elevation: 1,
                padding: EdgeInsets.zero,
                shadowColor: const Color(0xFF059669).withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_isDownloading)
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  else
                    const Icon(Icons.table_chart_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Unduh Excel (.xls)',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _isDownloading || _isLoading ? null : _downloadCsv,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.description_rounded, size: 16, color: Color(0xFF0F172A)),
                        const SizedBox(width: 6),
                        Text(
                          'Unduh CSV',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _fetchData,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (_isLoading)
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF0F172A)),
                        const SizedBox(width: 6),
                        Text(
                          'Muat Ulang',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel(List<(OrderModel, ServiceItem)> previewRows, List<GajiKaryawanModel> previewGaji) {
    final allRows = _filteredOrderRows;
    final totalRows = _tab == 'order' ? allRows.length : _filteredGaji.length;
    final shownRows = _tab == 'order' ? previewRows.length : previewGaji.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.visibility_rounded, size: 16, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pratinjau Data',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$shownRows dari $totalRows baris',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_tab == 'order')
            _buildOrderList(previewRows)
          else
            _buildGajiList(previewGaji),
        ],
      ),
    );
  }

  // --- Order List Preview ---
  Widget _buildOrderList(List<(OrderModel, ServiceItem)> rows) {
    if (rows.isEmpty) return _emptyView('Tidak ada data order untuk periode/filter ini.');

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          ...rows.map((row) {
            final (o, svc) = row;
            final dt = _tryParseFlexibleDate(svc.tanggalPengerjaan);
            final namaHari = dt != null ? DateFormat('EEEE', 'id_ID').format(dt) : '-';
            final tgl = dt != null ? DateFormat('dd MMM yyyy', 'id_ID').format(dt) : '-';
            final cleaners = o.cleaners.isEmpty ? '-' : o.cleaners.map((c) => c.name).join(', ');
            final jam = svc.waktuPengerjaan.isEmpty ? '-' : svc.waktuPengerjaan;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Clean Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_note_rounded, size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                '$namaHari, ',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                              Text(
                                tgl,
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusBadge(o.statusUtamaLabel),
                      ],
                    ),
                  ),
                  // Body Details
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _buildPremiumInfoRow(Icons.cleaning_services_rounded, 'Layanan', svc.name, const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
                        const SizedBox(height: 8),
                        _buildPremiumInfoRow(Icons.person_rounded, 'Customer', o.customer.name, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                        const SizedBox(height: 8),
                        _buildPremiumInfoRow(Icons.support_agent_rounded, 'Cleaner', cleaners.isEmpty ? '-' : cleaners, const Color(0xFF059669), const Color(0xFFECFDF5)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildPremiumInfoRow(Icons.access_time_filled_rounded, 'Jam', jam, const Color(0xFFD97706), const Color(0xFFFFFBEB))),
                            const SizedBox(width: 8),
                            Expanded(child: _buildPremiumInfoRow(Icons.payments_rounded, 'Via', o.paymentMethod.toUpperCase(), const Color(0xFF4F46E5), const Color(0xFFEEF2FF))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPremiumInfoRow(IconData icon, String label, String value, Color iconColor, Color bgColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 13, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
              const SizedBox(height: 1),
              Text(value,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2),
            ],
          ),
        ),
      ],
    );
  }

  // --- Gaji List Preview ---
  Widget _buildGajiList(List<GajiKaryawanModel> rows) {
    if (rows.isEmpty) return _emptyView('Tidak ada data gaji untuk periode/filter ini.');

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          ...rows.map((g) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  // Header Cleaner Name
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFECFDF5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_rounded, size: 14, color: Color(0xFF059669)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CLEANER', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                              Text(g.karyawan?.nama ?? '-', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Body
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.add_circle_rounded, size: 12, color: Color(0xFF059669)),
                                        const SizedBox(width: 4),
                                        Text('Bonus', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF047857), fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(_currencyFormat.format(g.totalBonus), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.remove_circle_rounded, size: 12, color: Color(0xFFDC2626)),
                                        const SizedBox(width: 4),
                                        Text('Potongan', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFB91C1C), fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(_currencyFormat.format(g.totalPotongan), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.payments_rounded, size: 15, color: Color(0xFF047857)),
                                  const SizedBox(width: 6),
                                  Text('TAKE HOME PAY', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF047857), letterSpacing: 0.5)),
                                ],
                              ),
                              Text(_currencyFormat.format(g.takeHomePay), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF047857))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _emptyView(String msg) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.inbox_rounded, size: 36, color: Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text(msg,
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg, fg, border;
    switch (status.toLowerCase()) {
      case 'done':
        bg = const Color(0xFFDCFCE7); fg = const Color(0xFF15803D); border = const Color(0xFF86EFAC);
        break;
      case 'cancelled':
        bg = const Color(0xFFFEE2E2); fg = const Color(0xFFB91C1C); border = const Color(0xFFFCA5A5);
        break;
      case 'process':
        bg = const Color(0xFFFFF7ED); fg = const Color(0xFFC2410C); border = const Color(0xFFFDBA74);
        break;
      case 'pending':
        bg = const Color(0xFFEFF6FF); fg = const Color(0xFF1D4ED8); border = const Color(0xFF93C5FD);
        break;
      default:
        bg = const Color(0xFFF1F5F9); fg = const Color(0xFF475569); border = const Color(0xFFCBD5E1);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}

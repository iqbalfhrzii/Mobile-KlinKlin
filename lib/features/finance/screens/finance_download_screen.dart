import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
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
      final nominal = svc.price;
      final metode = o.paymentMethod;
      final status = o.statusUtamaLabel;
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
          IntCellValue(int.tryParse(svc.price.toString()) ?? 0),
          TextCellValue(o.paymentMethod.toString()),
          TextCellValue(o.statusUtamaLabel.toString()),
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
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTabRow(),
                    const SizedBox(height: 12),
                    _buildFilterPanel(),
                    const SizedBox(height: 12),
                    _buildDownloadPanel(filteredRows.length, filteredGaji.length),
                    const SizedBox(height: 12),
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
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Download Data',
                    style: GoogleFonts.inter(
                        fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Unduh data Order & Gaji ke file CSV/Excel',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.white.withOpacity(0.8))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.download_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text('Rekap Data',
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabRow() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _buildTabBtn('Order', 'order'),
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
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : AppColors.textDark,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pilih data yang diunduh',
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 10),

          // Row 1: Kalender (Bulan & Tahun)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _showMonthYearPicker,
                  child: _buildDropdownContainer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('MMMM yyyy', 'id_ID').format(DateTime(_selectedYear, _selectedMonth)),
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

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
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textMuted),
                      hint: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w600),
                      items: [
                        DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Semua Cabang',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))),
                        ..._cabangs.map((c) => DropdownMenuItem<String?>(
                              value: c.id.toString(),
                              child: Text(c.namaCabang,
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (val) => setState(() => _filterCabangId = val),
                    ),
                  ),
                ),
              ),
              if (_tab == 'order') ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _buildDropdownContainer(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _filterStatus.isEmpty ? '' : _filterStatus,
                        isExpanded: true,
                        isDense: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textMuted),
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w600),
                        items: [
                          DropdownMenuItem(value: '', child: Text('Semua Status', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: 'done', child: Text('Done', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: 'process', child: Text('Process', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: 'pending', child: Text('Pending', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: 'cancelled', child: Text('Dibatalkan', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: 'draft', child: Text('Draft', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info text
          Wrap(
            children: [
              Text('Data ', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
              Text(_tab.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              Text(' periode ', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
              Text(_periodeLabel, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              Text(' cabang ', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
              Text(_cabangName, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              if (_tab == 'order') ...[
                Text(' status ', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                Text(statusLabel, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              ],
              Text(' ditemukan ', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
              Text('$totalRows baris', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
              Text(' $_colCount kolom.', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
              if (_tab == 'order') ...[
                Text(' (raw: ', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                Text('$orderCount pesanan', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                Text(', ', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                Text('$totalDetailRows detail', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                Text(')', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
              ],
            ],
          ),
          if (_lastFetchError != null) ...[
            const SizedBox(height: 6),
            Text(
              'Gagal memuat data: $_lastFetchError',
              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFB91C1C)),
            ),
          ],
          const SizedBox(height: 12),

          // Download Buttons - vertical stack to avoid overflow
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isDownloading || _isLoading ? null : _downloadExcel,
              icon: _isDownloading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.table_chart_outlined, size: 15),
              label: const Text('Unduh Excel (.xls)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isDownloading || _isLoading ? null : _downloadCsv,
                  icon: const Icon(Icons.description_outlined, size: 14),
                  label: const Text('Unduh CSV'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textDark,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _fetchData,
                  icon: _isLoading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Muat Ulang'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textDark,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              _isLoading
                  ? 'Memuat data...'
                  : 'Pratinjau ($shownRows dari $totalRows baris)',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          const Divider(height: 1),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
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

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        final (o, svc) = rows[i];
        final dt = _tryParseFlexibleDate(svc.tanggalPengerjaan);
        final namaHari = dt != null ? DateFormat('EEEE', 'id_ID').format(dt) : '-';
        final tgl = dt != null ? DateFormat('dd MMM yyyy', 'id_ID').format(dt) : '-';
        final cleaners = o.cleaners.isEmpty ? '-' : o.cleaners.map((c) => c.name).join(', ');
        final jam = svc.waktuPengerjaan.isEmpty ? '-' : svc.waktuPengerjaan;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5)),
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Premium Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
                      ),
                      child: const Icon(Icons.event_note_rounded, size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(namaHari, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                          Text(tgl, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        ],
                      ),
                    ),
                    _buildStatusBadge(o.statusUtamaLabel),
                  ],
                ),
              ),
              // Body Details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildPremiumInfoRow(Icons.cleaning_services_rounded, 'Layanan', svc.name, const Color(0xFF8B5CF6), const Color(0xFFEDE9FE)),
                    const SizedBox(height: 12),
                    _buildPremiumInfoRow(Icons.person_rounded, 'Customer', o.customer.name, const Color(0xFF3B82F6), const Color(0xFFDBEAFE)),
                    const SizedBox(height: 12),
                    _buildPremiumInfoRow(Icons.support_agent_rounded, 'Cleaner', cleaners.isEmpty ? '-' : cleaners, const Color(0xFF10B981), const Color(0xFFD1FAE5)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildPremiumInfoRow(Icons.access_time_filled_rounded, 'Jam', jam, const Color(0xFFF59E0B), const Color(0xFFFEF3C7))),
                        Expanded(child: _buildPremiumInfoRow(Icons.payments_rounded, 'Via', o.paymentMethod.toUpperCase(), const Color(0xFF6366F1), const Color(0xFFE0E7FF))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumInfoRow(IconData icon, String label, String value, Color iconColor, Color bgColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
              const SizedBox(height: 2),
              Text(value,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
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

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        final g = rows[i];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5)),
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              // Header Cleaner Name
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: const Color(0xFFBBF7D0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: const Color(0xFF15803D).withValues(alpha: 0.1), blurRadius: 5)],
                      ),
                      child: const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF15803D)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CLEANER', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF166534))),
                          Text(g.karyawan?.nama ?? '-', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF14532D))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Body: Cards layout
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.add_circle_rounded, size: 12, color: Color(0xFF059669)),
                                    const SizedBox(width: 4),
                                    Text('Bonus', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(_currencyFormat.format(g.totalBonus), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.remove_circle_rounded, size: 12, color: Color(0xFFDC2626)),
                                    const SizedBox(width: 4),
                                    Text('Potongan', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(_currencyFormat.format(g.totalPotongan), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('TAKE HOME PAY', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(_currencyFormat.format(g.takeHomePay), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyView(String msg) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 8),
            Text(msg,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg, fg;
    switch (status.toLowerCase()) {
      case 'done':
        bg = const Color(0xFFDCFCE7); fg = const Color(0xFF15803D);
        break;
      case 'cancelled':
        bg = const Color(0xFFFEE2E2); fg = const Color(0xFFB91C1C);
        break;
      case 'process':
        bg = const Color(0xFFFFF7ED); fg = const Color(0xFFD97706);
        break;
      case 'pending':
        bg = const Color(0xFFEFF6FF); fg = const Color(0xFF1D4ED8);
        break;
      default:
        bg = Colors.grey.shade200; fg = AppColors.textMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Text(status,
          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}

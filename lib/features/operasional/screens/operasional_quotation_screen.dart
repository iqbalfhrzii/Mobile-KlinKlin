import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/services/pdf_quotation_service.dart';
import '../services/operasional_quotation_service.dart';
import 'operasional_quotation_form_sheet.dart';

class OperasionalQuotationScreen extends StatefulWidget {
  const OperasionalQuotationScreen({super.key});

  @override
  State<OperasionalQuotationScreen> createState() => _OperasionalQuotationScreenState();
}

class _OperasionalQuotationScreenState extends State<OperasionalQuotationScreen> {
  final _service = OperasionalQuotationService();
  final _searchController = TextEditingController();
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _error = '';
  List<dynamic> _quotations = [];
  List<dynamic> _cabangs = [];
  
  int _currentPage = 1;
  int _lastPage = 1;
  String _selectedStatus = 'Semua';
  final List<String> _statusFilters = ['Semua', 'Menunggu', 'Disetujui', 'Ditolak'];
  
  int? _selectedCabangId;
  String _userRole = '';
  int? _userCabangId;
  String _userCabangName = '';
  bool _isOperasionalOrAdmin = true;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _currentPage < _lastPage) {
        _fetchQuotations(page: _currentPage + 1, append: true);
      }
    }
  }

  Future<void> _loadUserAndData() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    _userCabangId = prefs.getInt('user_cabang_id');
    _userCabangName = prefs.getString('user_cabang_name') ?? '';

    final r = _userRole.toLowerCase();
    _isOperasionalOrAdmin = r.contains('operasional') || r.contains('admin') || r.contains('ceo') || r.contains('superadmin');

    if (!_isOperasionalOrAdmin && _userCabangId != null) {
      _selectedCabangId = _userCabangId;
    }

    try {
      final cabangs = await _service.getCabangs();
      if (mounted) {
        setState(() {
          _cabangs = cabangs;
          if (_userCabangName.isEmpty && _userCabangId != null && _cabangs.isNotEmpty) {
            final match = _cabangs.firstWhere((c) => c['id'] == _userCabangId, orElse: () => null);
            if (match != null) {
              _userCabangName = match['nama_cabang'] ?? match['nama'] ?? 'Cabang $_userCabangId';
            }
          }
        });
      }
    } catch (_) {}

    _fetchQuotations();
  }

  Future<void> _fetchQuotations({int page = 1, bool append = false}) async {
    if (!append) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final res = await _service.getQuotations(
        page: page,
        search: _searchController.text.trim(),
        status: _selectedStatus == 'Semua' ? null : _selectedStatus,
        cabangId: _selectedCabangId,
      );

      if (res['status'] == true) {
        setState(() {
          if (append) {
            _quotations.addAll(res['data']['data'] ?? res['data'] ?? []);
          } else {
            _quotations = res['data']['data'] ?? res['data'] ?? [];
          }
          _currentPage = res['data']['current_page'] ?? 1;
          _lastPage = res['data']['last_page'] ?? 1;
        });
      } else {
        setState(() => _error = res['message'] ?? 'Gagal memuat data penawaran');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedStatus != 'Semua' && _selectedStatus.isNotEmpty) count++;
    if (_isOperasionalOrAdmin && _selectedCabangId != null) count++;
    return count;
  }

  void _showFilterModal() {
    String tempStatus = _selectedStatus;
    int? tempCabangId = _selectedCabangId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune_rounded, size: 20, color: AppColors.primaryMid),
                            const SizedBox(width: 8),
                            Text(
                              'Filter Penawaran',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Section 1: Status Persetujuan
                    Text(
                      'Status Persetujuan',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _statusFilters.map((s) {
                        final isSel = tempStatus == s;
                        return ChoiceChip(
                          label: Text(s),
                          selected: isSel,
                          selectedColor: AppColors.primaryMid,
                          backgroundColor: const Color(0xFFF1F5F9),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            color: isSel ? Colors.white : AppColors.textDark,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: isSel ? AppColors.primaryMid : Colors.transparent),
                          ),
                          onSelected: (_) {
                            setModalState(() => tempStatus = s);
                          },
                        );
                      }).toList(),
                    ),

                    // Section 2: Cabang (Jika Operasional / Admin)
                    if (_isOperasionalOrAdmin && _cabangs.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Cabang',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Semua Cabang'),
                            selected: tempCabangId == null,
                            selectedColor: AppColors.primaryMid,
                            backgroundColor: const Color(0xFFF1F5F9),
                            labelStyle: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: tempCabangId == null ? FontWeight.bold : FontWeight.w500,
                              color: tempCabangId == null ? Colors.white : AppColors.textDark,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: tempCabangId == null ? AppColors.primaryMid : Colors.transparent),
                            ),
                            onSelected: (_) {
                              setModalState(() => tempCabangId = null);
                            },
                          ),
                          ..._cabangs.map((c) {
                            final isSel = tempCabangId == c['id'];
                            final cName = c['nama_cabang'] ?? c['nama'] ?? 'Cabang ${c['id']}';
                            return ChoiceChip(
                              label: Text(cName),
                              selected: isSel,
                              selectedColor: AppColors.primaryMid,
                              backgroundColor: const Color(0xFFF1F5F9),
                              labelStyle: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                color: isSel ? Colors.white : AppColors.textDark,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: isSel ? AppColors.primaryMid : Colors.transparent),
                              ),
                              onSelected: (_) {
                                setModalState(() => tempCabangId = c['id']);
                              },
                            );
                          }),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),
                    // Action Buttons: Reset & Terapkan
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                tempStatus = 'Semua';
                                if (_isOperasionalOrAdmin) {
                                  tempCabangId = null;
                                }
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              'Reset Filter',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedStatus = tempStatus;
                                _selectedCabangId = tempCabangId;
                              });
                              Navigator.pop(context);
                              _fetchQuotations(page: 1);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryMid,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: Text(
                              'Terapkan Filter',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  Color _getStatusColor(String? status) {
    final s = (status ?? 'Menunggu').toLowerCase();
    if (s.contains('setuju') || s == 'disetujui') {
      return const Color(0xFF16A34A); // Emerald Green
    } else if (s.contains('tolak') || s == 'ditolak') {
      return const Color(0xFFDC2626); // Red
    } else {
      return const Color(0xFFD97706); // Amber Orange
    }
  }

  Future<void> _downloadOrPrintInvoice(dynamic quotation) async {
    try {
      final cleanNo = quotation['no_quotation']?.toString().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_') ?? 'Invoice';
      final docName = 'Quotation_$cleanNo.pdf';
      await Printing.layoutPdf(
        name: docName,
        onLayout: (format) async => await PdfQuotationService.generateQuotation(quotation),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mencetak PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareToWhatsApp(dynamic quotation) async {
    final rawPhone = quotation['no_wa_customer']?.toString() ?? '';
    String cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    }

    final noQuo = quotation['no_quotation'] ?? '-';
    final customer = quotation['nama_customer'] ?? 'Pelanggan';
    final tgl = quotation['tanggal'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(quotation['tanggal'].toString())) : '-';
    final expDate = quotation['exp_date'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(quotation['exp_date'].toString())) : '-';
    final grandTotal = _formatCurrency(quotation['grand_total_calc'] ?? quotation['grand_total'] ?? 0);

    List<dynamic> rincianList = [];
    if (quotation['rincian'] != null) {
      if (quotation['rincian'] is List) {
        rincianList = quotation['rincian'];
      } else if (quotation['rincian'] is String) {
        try {
          rincianList = jsonDecode(quotation['rincian']);
        } catch (_) {}
      }
    }

    final buffer = StringBuffer();
    buffer.writeln('Halo Bapak/Ibu *$customer*,');
    buffer.writeln('Berikut kami sampaikan rincian *Surat Penawaran Harga (Quotation)* dari *KlinKlin*:');
    buffer.writeln('');
    buffer.writeln('📄 *No Quotation*: $noQuo');
    buffer.writeln('📅 *Tanggal*: $tgl (Exp: $expDate)');
    buffer.writeln('');
    buffer.writeln('*Rincian Layanan / Barang*:');
    for (var i = 0; i < rincianList.length; i++) {
      final item = rincianList[i];
      final desc = item['deskripsi'] ?? '-';
      final qty = item['qty'] ?? 1;
      final harga = _formatCurrency(num.tryParse(item['harga']?.toString() ?? '0') ?? 0);
      buffer.writeln('${i + 1}. $desc (${qty}x) - $harga');
    }
    buffer.writeln('');
    buffer.writeln('💰 *GRAND TOTAL*: *$grandTotal*');
    if (quotation['alat_chemical_klinklin'] == true || quotation['alat_chemical_klinklin'] == 1) {
      buffer.writeln('✨ *Catatan*: Termasuk Alat & Chemical dari KlinKlin.');
    }
    buffer.writeln('');
    buffer.writeln('Terima kasih telah mempercayakan layanan kebersihan kepada *KlinKlin*.');

    final text = Uri.encodeComponent(buffer.toString());
    final url = 'https://wa.me/$cleanPhone?text=$text';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka aplikasi WhatsApp')),
        );
      }
    }
  }

  void _openForm([dynamic quotation]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: OperasionalQuotationFormSheet(
            initialData: quotation,
            onSave: () {
              Navigator.pop(context);
              _fetchQuotations(page: 1);
            },
          ),
        ),
      ),
    );
  }

  void _showDetailModal(dynamic item) {
    final statusColor = _getStatusColor(item['status']);
    
    List<dynamic> rincianList = [];
    if (item['rincian'] != null) {
      if (item['rincian'] is List) {
        rincianList = item['rincian'];
      } else if (item['rincian'] is String) {
        try {
          rincianList = jsonDecode(item['rincian']);
        } catch (_) {}
      }
    }

    final num subtotal = num.tryParse(item['subtotal_calc']?.toString() ?? item['subtotal']?.toString() ?? '0') ?? 0;
    final num ppnNominal = num.tryParse(item['ppn_nominal_calc']?.toString() ?? item['ppn_nominal']?.toString() ?? '0') ?? 0;
    final num pphNominal = num.tryParse(item['pph_nominal_calc']?.toString() ?? item['pph_nominal']?.toString() ?? '0') ?? 0;
    final num diskon = num.tryParse(item['diskon']?.toString() ?? '0') ?? 0;
    final num grandTotal = num.tryParse(item['grand_total_calc']?.toString() ?? item['grand_total']?.toString() ?? '0') ?? (subtotal - diskon + ppnNominal - pphNominal);

    String tglStr = '-';
    if (item['tanggal'] != null) {
      try {
        tglStr = DateFormat('dd MMM yyyy').format(DateTime.parse(item['tanggal'].toString()));
      } catch (_) {
        tglStr = item['tanggal'].toString();
      }
    }

    String expStr = '-';
    if (item['exp_date'] != null) {
      try {
        expStr = DateFormat('dd MMM yyyy').format(DateTime.parse(item['exp_date'].toString()));
      } catch (_) {
        expStr = item['exp_date'].toString();
      }
    }

    final bool hasAlatChemical = item['alat_chemical_klinklin'] == 1 || item['alat_chemical_klinklin'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMid.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.description_rounded, color: AppColors.primaryMid, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Detail Penawaran',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item['status'] ?? 'Menunggu Review',
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['no_quotation'] ?? '-',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Content Body (Scrollable)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // General Info Summary
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Dibuat Oleh', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                  const SizedBox(height: 2),
                                  Text(
                                    item['pembuat']?['name'] ?? item['pembuat']?['nama'] ?? 'Bagus',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Tanggal & Exp', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$tglStr (Exp: $expStr)',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 1. Card: Informasi Customer
                      _buildSectionContainer(
                        title: 'Informasi Customer',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoItem('Nama Customer', item['nama_customer'] ?? '-'),
                            const SizedBox(height: 10),
                            _buildInfoItem('No WhatsApp', item['no_wa_customer'] ?? '-'),
                            const SizedBox(height: 10),
                            _buildInfoItem('Alamat', item['alamat'] ?? '-'),
                            if (item['job_location'] != null && item['job_location'].toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _buildInfoItem('Lokasi Pengerjaan (Job Location)', item['job_location'].toString()),
                            ],
                            const SizedBox(height: 10),
                            _buildInfoItem('Cabang', item['cabang']?['nama_cabang'] ?? item['cabang']?['nama'] ?? 'Surabaya'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. Card: Rincian Layanan / Barang
                      _buildSectionContainer(
                        title: 'Rincian Layanan / Barang',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Table Header
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                              child: Row(
                                children: [
                                  Expanded(flex: 3, child: Text('Deskripsi', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                  Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                  Expanded(flex: 2, child: Text('Harga Satuan', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                  Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)))),
                                ],
                              ),
                            ),

                            // Items List
                            if (rincianList.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text('Tidak ada item rincian', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                              )
                            else
                              ...rincianList.map((r) {
                                final deskripsi = r['deskripsi'] ?? '-';
                                final num qty = num.tryParse(r['qty']?.toString() ?? '1') ?? 1;
                                final num harga = num.tryParse(r['harga']?.toString() ?? '0') ?? 0;
                                final num totalItem = qty * harga;

                                return Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                  decoration: const BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 3, child: Text(deskripsi, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)))),
                                      Expanded(flex: 1, child: Text(qty.toString(), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)))),
                                      Expanded(flex: 2, child: Text(_formatCurrency(harga), textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)))),
                                      Expanded(flex: 2, child: Text(_formatCurrency(totalItem), textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)))),
                                    ],
                                  ),
                                );
                              }),

                            const SizedBox(height: 14),

                            // Totals Breakdown
                            _buildPriceRow('Subtotal', _formatCurrency(subtotal)),
                            if (diskon > 0) ...[
                              const SizedBox(height: 6),
                              _buildPriceRow('Diskon', '- ${_formatCurrency(diskon)}', color: Colors.red),
                            ],
                            if (ppnNominal > 0) ...[
                              const SizedBox(height: 6),
                              _buildPriceRow('PPN (11.00%)', '+ ${_formatCurrency(ppnNominal)}'),
                            ],
                            if (pphNominal > 0) ...[
                              const SizedBox(height: 6),
                              _buildPriceRow('PPh (2.00%)', '- ${_formatCurrency(pphNominal)}', color: Colors.red),
                            ],

                            const SizedBox(height: 12),

                            // GRAND TOTAL Banner
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryMid.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primaryMid.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'GRAND TOTAL',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryMid, letterSpacing: 0.5),
                                  ),
                                  Text(
                                    _formatCurrency(grandTotal),
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primaryMid),
                                  ),
                                ],
                              ),
                            ),

                            // Alat & Chemical Banner
                            if (hasAlatChemical) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Termasuk Alat & Chemical dari KlinKlin',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF15803D)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. Card: Status Persetujuan
                      _buildSectionContainer(
                        title: 'Status Persetujuan',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Status Saat Ini', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item['status'] ?? 'Menunggu',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                                  ),
                                ),
                              ],
                            ),
                            if (item['penyetuju'] != null || item['tanggal_persetujuan'] != null) ...[
                              const SizedBox(height: 10),
                              _buildInfoItem(
                                'Diproses Oleh',
                                '${item['penyetuju']?['name'] ?? item['penyetuju']?['nama'] ?? '-'} (${item['tanggal_persetujuan'] != null ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.tryParse(item['tanggal_persetujuan'].toString()) ?? DateTime.now()) : '-'})',
                              ),
                            ],
                            if (item['catatan_persetujuan'] != null && item['catatan_persetujuan'].toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _buildInfoItem('Catatan Persetujuan', item['catatan_persetujuan'].toString()),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Bottom Action Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
                  ],
                ),
                child: Builder(
                  builder: (context) {
                    final isMenunggu = item['status'] == 'Menunggu' || item['status'] == 'Dibuat' || item['status'] == 'Pending';
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Row(
                      children: [
                        // 1. Cetak PDF Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _downloadOrPrintInvoice(item);
                            },
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.white),
                            label: Text(
                              'Cetak PDF',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 2. Share WA Button
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _shareToWhatsApp(item);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.chat_rounded, size: 15, color: Color(0xFF16A34A)),
                                const SizedBox(width: 4),
                                Text(
                                  'Kirim WA',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // 3. Edit Data Button (Hanya Operasional / Admin)
                        if (_isOperasionalOrAdmin) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _openForm(item);
                            },
                            icon: const Icon(Icons.edit_outlined, size: 15, color: AppColors.primaryMid),
                            label: Text(
                              'Edit',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryMid),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              side: const BorderSide(color: AppColors.primaryMid),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isMenunggu && _isOperasionalOrAdmin) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _openApprovalDialog(item, 'Ditolak');
                              },
                              icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFDC2626)),
                              label: Text('Tolak Penawaran', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                side: const BorderSide(color: Color(0xFFFCA5A5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _openApprovalDialog(item, 'Disetujui');
                              },
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 15, color: Colors.white),
                              label: Text('Setujui Penawaran', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  void _openApprovalDialog(dynamic item, String actionStatus) {
    final noteController = TextEditingController();
    final bool isApprove = actionStatus == 'Disetujui';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isApprove ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isApprove ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                  color: isApprove ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isApprove ? 'Setujui Penawaran' : 'Tolak Penawaran',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              Text(
                isApprove
                    ? 'Apakah Anda yakin ingin menyetujui penawaran ini?'
                    : 'Apakah Anda yakin ingin menolak penawaran ini?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                maxLines: 2,
                style: GoogleFonts.inter(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Tambahkan catatan persetujuan (opsional)...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isApprove ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Batal', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context); // close dialog
                      final notes = noteController.text.trim();
                      
                      setState(() => _isLoading = true);
                      Map<String, dynamic> res;
                      if (isApprove) {
                        res = await _service.approveQuotation(item['id'], notes: notes.isNotEmpty ? notes : null);
                      } else {
                        res = await _service.rejectQuotation(item['id'], notes: notes.isNotEmpty ? notes : null);
                      }

                      if (mounted) {
                        setState(() => _isLoading = false);
                        if (res['status'] == true) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'Status penawaran berhasil diperbarui'),
                              backgroundColor: isApprove ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            ),
                          );
                          _fetchQuotations(page: 1);
                        } else {
                          messenger.showSnackBar(
                            SnackBar(content: Text(res['message'] ?? 'Gagal memproses penawaran'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isApprove ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      isApprove ? 'Ya, Setujui' : 'Ya, Tolak',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionContainer({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark),
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
        const SizedBox(height: 3),
        Text(value, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      ],
    );
  }

  Widget _buildPriceRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color ?? AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Future<void> _deleteQuotation(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Penawaran?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Penawaran (Quotation) ini akan dihapus secara permanen dari sistem.', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 0),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final res = await _service.deleteQuotation(id);

    if (res['status'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Penawaran berhasil dihapus'), backgroundColor: Colors.green),
        );
      }
      _fetchQuotations(page: 1);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal menghapus penawaran'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate stats
    final totalCount = _quotations.length;
    final waitingCount = _quotations.where((q) {
      final s = (q['status'] ?? '').toString().toLowerCase();
      return s.contains('menunggu') || s == 'pending' || s == 'dibuat';
    }).length;
    final approvedCount = _quotations.where((q) => (q['status'] ?? '').toString().toLowerCase().contains('setuju')).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: !_isOperasionalOrAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: AppColors.primaryMid,
              elevation: 4,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                'Buat Penawaran',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
              ),
            )
          : null,
      body: Column(
        children: [
          // Gradient Header
          GradientHeader(
            child: Row(
              children: [
                HeaderBackButton(onTap: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Penawaran',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kelola & buat penawaran untuk customer',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _fetchQuotations(page: 1),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          
          // Search Bar & Unified Filter Button
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Cari No Quotation / Customer...',
                        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  _fetchQuotations(page: 1);
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _fetchQuotations(page: 1),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Single Unified Filter Button
                GestureDetector(
                  onTap: _showFilterModal,
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _activeFilterCount > 0 ? AppColors.primaryMid : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _activeFilterCount > 0 ? AppColors.primaryMid : Colors.grey.shade300,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _activeFilterCount > 0
                              ? AppColors.primaryMid.withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: _activeFilterCount > 0 ? Colors.white : AppColors.textDark,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _activeFilterCount > 0 ? 'Filter ($_activeFilterCount)' : 'Filter',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _activeFilterCount > 0 ? Colors.white : AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Mini Stats Summary
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                _buildMiniStat('Total', '$totalCount', AppColors.textDark, Colors.grey.shade100),
                const SizedBox(width: 8),
                _buildMiniStat('Menunggu', '$waitingCount', const Color(0xFFD97706), const Color(0xFFFEF3C7)),
                const SizedBox(width: 8),
                _buildMiniStat('Disetujui', '$approvedCount', const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
              ],
            ),
          ),
          
          // Quotation List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 40, color: Colors.red),
                              const SizedBox(height: 8),
                              Text(_error, style: GoogleFonts.inter(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _fetchQuotations(page: 1),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMid),
                                child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String count, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
            Text(count, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_quotations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryMid.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.request_quote_outlined, size: 48, color: AppColors.primaryMid),
              ),
              const SizedBox(height: 14),
              Text(
                'Belum Ada Data Penawaran',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 4),
              Text(
                'Tekan tombol "+ Buat Penawaran" untuk membuat quotation baru.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchQuotations(page: 1),
      color: AppColors.primaryMid,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _quotations.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _quotations.length) {
            return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
          }

          final item = _quotations[index];
          final statusColor = _getStatusColor(item['status']);
          final customer = item['nama_customer'] ?? '-';
          final noQuo = item['no_quotation'] ?? '-';
          final cabang = item['cabang']?['nama_cabang'] ?? item['cabang']?['nama'] ?? item['nama_cabang'] ?? 'Surabaya';
          final dibuatOleh = item['pembuat']?['nama'] ?? item['pembuat']?['name'] ?? item['dibuat_oleh_nama'] ?? item['pembuat_nama'] ?? '-';
          final grandTotal = item['grand_total_calc'] ?? item['grand_total'] ?? 0;

          String tglStr = '-';
          if (item['tanggal'] != null) {
            try {
              tglStr = DateFormat('dd MMM yyyy').format(DateTime.parse(item['tanggal'].toString()));
            } catch (_) {
              tglStr = item['tanggal'].toString();
            }
          }

          String expStr = '-';
          if (item['exp_date'] != null) {
            try {
              expStr = DateFormat('dd MMM yyyy').format(DateTime.parse(item['exp_date'].toString()));
            } catch (_) {
              expStr = item['exp_date'].toString();
            }
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Clickable Card Area (Header + Body -> Opens Detail)
                  InkWell(
                    onTap: () => _showDetailModal(item),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.request_quote_rounded, size: 16, color: AppColors.primaryMid),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  noQuo,
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item['status'] ?? 'Menunggu',
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Body Card
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Customer & Total
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Customer', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                                        const SizedBox(height: 2),
                                        Text(
                                          customer,
                                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                        ),
                                        if (item['no_wa_customer'] != null && item['no_wa_customer'].toString().isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(Icons.chat_bubble_outline, size: 11, color: Color(0xFF16A34A)),
                                              const SizedBox(width: 4),
                                              Text(
                                                item['no_wa_customer'].toString(),
                                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF16A34A), fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Total Penawaran', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatCurrency(grandTotal),
                                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryMid),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Info Box: Dibuat Oleh, Cabang & Dates
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFF1F5F9)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.person_outline_rounded, size: 13, color: AppColors.primaryMid),
                                            const SizedBox(width: 4),
                                            RichText(
                                              text: TextSpan(
                                                text: 'Dibuat: ',
                                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                                children: [
                                                  TextSpan(
                                                    text: dibuatOleh,
                                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                                            const SizedBox(width: 3),
                                            Text(cabang, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textMuted),
                                            const SizedBox(width: 4),
                                            Text('Tgl: $tglStr', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                          ],
                                        ),
                                        Text('Exp: $expStr', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFDC2626), fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  
                  // Action Buttons Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        // Cetak PDF Button (Labelled Pill)
                        InkWell(
                          onTap: () => _downloadOrPrintInvoice(item),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.picture_as_pdf_rounded, size: 13, color: Color(0xFF2563EB)),
                                const SizedBox(width: 4),
                                Text(
                                  'PDF',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // WA Share Button (Labelled Pill)
                        InkWell(
                          onTap: () => _shareToWhatsApp(item),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.chat_rounded, size: 13, color: Color(0xFF16A34A)),
                                const SizedBox(width: 4),
                                Text(
                                  'WA',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isOperasionalOrAdmin) ...[
                          const Spacer(),

                          // Edit Button (Labelled Pill)
                          InkWell(
                            onTap: () => _openForm(item),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.edit_outlined, size: 13, color: Color(0xFFD97706)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Edit',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Hapus Button (Labelled Pill)
                          InkWell(
                            onTap: () => _deleteQuotation(item['id']),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.delete_outline_rounded, size: 13, color: Color(0xFFDC2626)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Hapus',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

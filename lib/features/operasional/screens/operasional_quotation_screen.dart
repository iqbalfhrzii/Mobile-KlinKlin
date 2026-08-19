import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
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
  
  int _currentPage = 1;
  int _lastPage = 1;
  String _selectedStatus = 'Semua Status';
  final List<String> _statusOptions = ['Semua Status', 'Pending', 'Disetujui', 'Ditolak'];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchQuotations();
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
        search: _searchController.text,
        status: _selectedStatus == 'Semua Status' ? null : _selectedStatus,
      );

      if (res['status'] == true) {
        setState(() {
          if (append) {
            _quotations.addAll(res['data']['data'] ?? []);
          } else {
            _quotations = res['data']['data'] ?? [];
          }
          _currentPage = res['data']['current_page'] ?? 1;
          _lastPage = res['data']['last_page'] ?? 1;
        });
      } else {
        setState(() => _error = res['message'] ?? 'Unknown error');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui':
        return const Color(0xFF16A34A);
      case 'ditolak':
        return const Color(0xFFDC2626);
      case 'pending':
      default:
        return const Color(0xFFD97706);
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
          SnackBar(content: Text('Gagal membuat PDF: $e'), backgroundColor: Colors.red),
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
    final statusColor = _getStatusColor(item['status'] ?? 'Pending');
    
    // Parse rincian
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

    String approvalDate = '-';
    if (item['updated_at'] != null) {
      try {
        final dt = DateTime.parse(item['updated_at'].toString());
        approvalDate = DateFormat('dd MMM yyyy, HH:mm').format(dt);
      } catch (_) {
        approvalDate = item['updated_at'].toString();
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
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.description_rounded, color: Color(0xFF16A34A), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Review Penawaran: ${item['no_quotation'] ?? '-'}',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Dibuat oleh ${item['pembuat']?['name'] ?? 'Sistem'} pada $tglStr',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
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
                      // 1. Card: Informasi Customer
                      _buildSectionContainer(
                        title: 'Informasi Customer',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoItem('Nama Customer', item['nama_customer'] ?? '-'),
                            const SizedBox(height: 10),
                            _buildInfoItem('No WA', item['no_wa_customer'] ?? '-'),
                            const SizedBox(height: 10),
                            _buildInfoItem('Alamat', item['alamat'] ?? '-'),
                            if (item['job_location'] != null && item['job_location'].toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _buildInfoItem('Lokasi Pengerjaan', item['job_location'].toString()),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. Card: Status Persetujuan
                      _buildSectionContainer(
                        title: 'Status Persetujuan',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status Saat Ini', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                item['status'] ?? 'Pending',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoItem('Diproses Oleh', '${item['penyetuju']?['name'] ?? '-'} ($approvalDate)'),
                            const SizedBox(height: 10),
                            _buildInfoItem('Catatan Persetujuan', item['catatan_approval'] ?? 'Tidak ada catatan'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. Card: Rincian Layanan / Barang
                      _buildSectionContainer(
                        title: 'Rincian Layanan/Barang',
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

                            const SizedBox(height: 12),

                            // Totals Breakdown
                            _buildPriceRow('Subtotal', _formatCurrency(subtotal)),
                            if (diskon > 0) ...[
                              const SizedBox(height: 6),
                              _buildPriceRow('Diskon', '- ${_formatCurrency(diskon)}', color: Colors.red),
                            ],
                            if (ppnNominal > 0) ...[
                              const SizedBox(height: 6),
                              _buildPriceRow('PPN (11.00%)', _formatCurrency(ppnNominal)),
                            ],
                            if (pphNominal > 0) ...[
                              const SizedBox(height: 6),
                              _buildPriceRow('PPh', '- ${_formatCurrency(pphNominal)}', color: Colors.red),
                            ],

                            const SizedBox(height: 12),

                            // GRAND TOTAL Banner
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'GRAND TOTAL',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF065F46), letterSpacing: 0.5),
                                  ),
                                  Text(
                                    _formatCurrency(grandTotal),
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF059669)),
                                  ),
                                ],
                              ),
                            ),

                            // Alat & Chemical Info Banner
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
                                    const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Terdapat Alat & Chemical dari Klinklin',
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
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Bottom Action Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
                  ],
                ),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Tutup', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadOrPrintInvoice(item),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download Invoice'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openForm(item);
                      },
                      icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF2563EB)),
                      label: Text('Edit Data', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        backgroundColor: const Color(0xFFEFF6FF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
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
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildPriceRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color ?? const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteQuotation(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Quotation'),
        content: const Text('Apakah Anda yakin ingin menghapus quotation ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final res = await _service.deleteQuotation(id);
    if (mounted) Navigator.pop(context);

    if (res['status'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quotation berhasil dihapus'), backgroundColor: Colors.green),
        );
      }
      _fetchQuotations(page: 1);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal menghapus'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          GradientHeader(
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Approval Penawaran',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tinjau dan setujui penawaran (Quotation)',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Cari No atau Customer...',
                        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _fetchQuotations(page: 1),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStatus,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                        items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedStatus = val);
                            _fetchQuotations(page: 1);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                    : _buildList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildList() {
    if (_quotations.isEmpty) {
      return const Center(child: Text('Tidak ada quotation'));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _quotations.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _quotations.length) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }

        final item = _quotations[index];
        final statusColor = _getStatusColor(item['status'] ?? 'Pending');

        return InkWell(
          onTap: () => _showDetailModal(item),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['no_quotation'] ?? '-',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['tanggal'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['tanggal'])) : '-',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item['status'] ?? 'Pending',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Body
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dibuat Oleh', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                            const SizedBox(height: 2),
                            Text(
                              item['pembuat']?['name'] ?? 'Sistem',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                            ),
                            Text(
                              item['cabang']?['nama_cabang'] ?? item['cabang']?['nama'] ?? '-',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Customer', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                            const SizedBox(height: 2),
                            Text(
                              item['nama_customer'] ?? '-',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Total Nominal', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                            const SizedBox(height: 2),
                            Text(
                              _formatCurrency(item['grand_total_calc'] ?? 0),
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                
                // Actions
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showDetailModal(item),
                        icon: const Icon(Icons.remove_red_eye_outlined, size: 16, color: Color(0xFF0284C7)),
                        label: Text('Detail', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0284C7))),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () => _downloadOrPrintInvoice(item),
                        icon: const Icon(Icons.download_rounded, size: 16, color: Color(0xFF16A34A)),
                        label: Text('Invoice', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A))),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () => _openForm(item),
                        icon: const Icon(Icons.edit_document, size: 16, color: Colors.orange),
                        label: Text('Edit', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () => _deleteQuotation(item['id']),
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        label: Text('Hapus', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

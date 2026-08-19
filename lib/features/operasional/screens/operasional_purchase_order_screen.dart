import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/operasional_purchase_order_service.dart';
import '../../../core/api/api_client.dart';

class OperasionalPurchaseOrderScreen extends StatefulWidget {
  const OperasionalPurchaseOrderScreen({super.key});

  @override
  State<OperasionalPurchaseOrderScreen> createState() => _OperasionalPurchaseOrderScreenState();
}

class _OperasionalPurchaseOrderScreenState extends State<OperasionalPurchaseOrderScreen> {
  bool _isLoading = false;
  List<dynamic> _purchaseOrders = [];
  List<dynamic> _cabangs = [];
  String? _authToken;

  int? _selectedCabangId;
  String? _selectedStatus;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadAuthTokenAndCabangs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadAuthTokenAndCabangs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('auth_token');
    } catch (_) {}
    _loadCabangs();
  }

  Future<void> _loadCabangs() async {
    try {
      final dio = ApiClient.instance;
      final res = await dio.get('/operasional/cabangs');
      if (mounted) {
        setState(() {
          _cabangs = res.data['data'] ?? [];
        });
        _loadData();
      }
    } catch (e) {
      debugPrint('Error loading cabangs: $e');
      _loadData();
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await OperasionalPurchaseOrderService.getPurchaseOrders(
        search: _searchController.text,
        cabangId: _selectedCabangId,
        status: _selectedStatus,
      );
      if (mounted) {
        setState(() {
          _purchaseOrders = data['data'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getFileUrl(dynamic rawPath) {
    if (rawPath == null) return '';
    String p = rawPath.toString().trim().replaceAll(r'\', '/');
    if (p.isEmpty || p == 'null') return '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;

    final baseDomain = ApiClient.baseUrl.replaceAll(RegExp(r'/api/?$'), '');

    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    if (p.startsWith('public/')) {
      p = p.substring(7);
    }
    if (p.startsWith('storage/')) {
      return '$baseDomain/$p';
    }

    return '$baseDomain/storage/$p';
  }

  bool _isImageFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  void _viewFileInApp(String path, String title) {
    final fullUrl = _getFileUrl(path);
    if (fullUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lampiran berkas tidak valid.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _FileViewerDialog(
        url: fullUrl,
        title: title,
        authToken: _authToken,
        isImage: _isImageFile(fullUrl),
      ),
    );
  }

  Future<void> _deleteData(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Purchase Order', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text('Apakah kamu yakin ingin menghapus data purchase order ini?', style: GoogleFonts.inter(color: const Color(0xFF475569))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Hapus', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await OperasionalPurchaseOrderService.deletePurchaseOrder(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase Order berhasil dihapus'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isLoading = false);
    }
  }

  void _showFormModal({Map<String, dynamic>? item}) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FormBottomSheet(
        item: item,
        cabangs: _cabangs,
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 18),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Purchase Order',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kelola data purchase order kantor cabang',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: AppColors.primary,
                    child: _purchaseOrders.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 84),
                            itemCount: _purchaseOrders.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              return _buildItemCard(_purchaseOrders[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormModal(),
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: Text(
          'Tambah PO',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // Search Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Cari No PO, barang, supplier...',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF64748B)),
                    onPressed: () {
                      _searchController.clear();
                      _loadData();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Filters: Cabang & Status Dropdown
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedCabangId,
                      isExpanded: true,
                      hint: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 20),
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                      items: [
                        DropdownMenuItem<int>(value: null, child: Text('Semua Cabang', style: GoogleFonts.inter(fontWeight: FontWeight.normal))),
                        ..._cabangs.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text(c['nama_cabang'] ?? '-'))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedCabangId = val);
                        _loadData();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatus,
                      isExpanded: true,
                      hint: Text('Semua Status', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 20),
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                      items: [
                        DropdownMenuItem(value: null, child: Text('Semua Status', style: GoogleFonts.inter(fontWeight: FontWeight.normal))),
                        DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                        DropdownMenuItem(value: 'Dikirim supplier', child: Text('Dikirim supplier', style: GoogleFonts.inter(color: const Color(0xFF0284C7)))),
                        DropdownMenuItem(value: 'Diterima Sebagian', child: Text('Diterima Sebagian', style: GoogleFonts.inter(color: const Color(0xFFD97706)))),
                        DropdownMenuItem(value: 'Diterima Penuh', child: Text('Diterima Penuh', style: GoogleFonts.inter(color: const Color(0xFF16A34A)))),
                        DropdownMenuItem(value: 'Batal', child: Text('Batal', style: GoogleFonts.inter(color: const Color(0xFFDC2626)))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedStatus = val);
                        _loadData();
                      },
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak Ada Purchase Order',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            Text(
              'Belum ada data purchase order yang sesuai dengan filter pencarian Anda.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final tgl = item['tanggal_po'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['tanggal_po'])) : '-';
    final noPo = item['no_po'] ?? '-';
    final cabang = item['cabang']?['nama_cabang'] ?? '-';
    final supplier = item['supplier'] ?? '-';
    final barang = item['nama_barang'] ?? '-';

    final qtyNumber = double.tryParse(item['jumlah']?.toString() ?? '0') ?? 0;
    final qtyStr = qtyNumber == qtyNumber.toInt() ? qtyNumber.toInt().toString() : qtyNumber.toStringAsFixed(2);
    final satuan = item['satuan'] ?? '';
    final total = item['total_harga'] != null
        ? NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(double.parse(item['total_harga'].toString()))
        : '-';

    final status = item['status_po'] ?? 'Draft';
    final filePo = item['file_po'];
    final bool hasFile = filePo != null && filePo.toString().trim().isNotEmpty && filePo.toString() != 'null';

    Color statusColor = const Color(0xFF64748B);
    Color statusBg = const Color(0xFFF1F5F9);

    final statusLower = status.toLowerCase();
    if (statusLower.contains('sebagian')) {
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFEF3C7);
    } else if (statusLower.contains('dikirim')) {
      statusColor = const Color(0xFF0284C7);
      statusBg = const Color(0xFFE0F2FE);
    } else if (statusLower.contains('penuh') || statusLower.contains('selesai')) {
      statusColor = const Color(0xFF16A34A);
      statusBg = const Color(0xFFDCFCE7);
    } else if (statusLower.contains('batal')) {
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEE2E2);
    }

    final fullFileUrl = hasFile ? _getFileUrl(filePo) : '';
    final bool isImage = hasFile && _isImageFile(fullFileUrl);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Avatar
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),

                // Main Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row No PO & Tanggal
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            noPo,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                          ),
                          Text(
                            tgl,
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Nama Barang & Jumlah
                      Text(
                        barang,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '$qtyStr $satuan',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                          Text('•', style: GoogleFonts.inter(color: const Color(0xFFCBD5E1))),
                          const SizedBox(width: 8),
                          Text(
                            total,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Cabang & Supplier
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              cabang,
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              supplier,
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Bottom Bar: Status Badge & Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor),
                  ),
                ),

                // Action Buttons
                Row(
                  children: [
                    // IN-APP FILE VIEWER BUTTON
                    if (hasFile) ...[
                      InkWell(
                        onTap: () => _viewFileInApp(filePo, noPo),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isImage ? Icons.image_rounded : Icons.attach_file_rounded,
                                color: const Color(0xFF1D4ED8),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isImage ? 'Lihat Foto' : 'Lihat Berkas',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],

                    // Edit Button
                    InkWell(
                      onTap: () => _showFormModal(item: item),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_rounded, color: Color(0xFFD97706), size: 16),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Delete Button
                    InkWell(
                      onTap: () => _deleteData(item['id']),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// IN-APP FILE / IMAGE VIEWER DIALOG (DOES NOT REDIRECT TO WEB)
// ---------------------------------------------------------

class _FileViewerDialog extends StatelessWidget {
  final String url;
  final String title;
  final String? authToken;
  final bool isImage;

  const _FileViewerDialog({
    required this.url,
    required this.title,
    this.authToken,
    required this.isImage,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(14),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isImage)
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SmartNetworkImage(
                    url: url,
                    token: authToken,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Gagal memuat berkas PO',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            url,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 14),
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: url));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('URL berhasil disalin')),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Salin URL'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.description_rounded, size: 48, color: Color(0xFF1D4ED8)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Lampiran Berkas PO',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    url,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('URL berkas berhasil disalin')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Salin URL Berkas'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),

          // Close Button on Top Right
          Positioned(
            top: 10,
            right: 10,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// SMART NETWORK IMAGE WITH AUTO HTTP/HTTPS FALLBACK
// ---------------------------------------------------------

class SmartNetworkImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final String? token;
  final Widget? placeholder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const SmartNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.token,
    this.placeholder,
    this.errorBuilder,
  });

  @override
  State<SmartNetworkImage> createState() => _SmartNetworkImageState();
}

class _SmartNetworkImageState extends State<SmartNetworkImage> {
  late String _activeUrl;
  bool _triedFallback = false;

  @override
  void initState() {
    super.initState();
    _activeUrl = widget.url;
  }

  @override
  void didUpdateWidget(covariant SmartNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _activeUrl = widget.url;
      _triedFallback = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeUrl.isEmpty) {
      return widget.errorBuilder?.call(context, 'Empty URL', null) ??
          const Center(child: Icon(Icons.image_not_supported_rounded, color: Color(0xFF94A3B8), size: 20));
    }

    final headers = widget.token != null && widget.token!.isNotEmpty
        ? {
            'Authorization': 'Bearer ${widget.token}',
            'Accept': 'image/*,*/*',
          }
        : const {'Accept': 'image/*,*/*'};

    return Image.network(
      _activeUrl,
      fit: widget.fit,
      headers: headers,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return widget.placeholder ??
            Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Image load error on $_activeUrl: $error');
        if (!_triedFallback) {
          _triedFallback = true;
          if (_activeUrl.startsWith('http://')) {
            final fallback = _activeUrl.replaceFirst('http://', 'https://');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _activeUrl = fallback);
            });
            return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
          } else if (_activeUrl.startsWith('https://')) {
            final fallback = _activeUrl.replaceFirst('https://', 'http://');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _activeUrl = fallback);
            });
            return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
          }
        }
        return widget.errorBuilder?.call(context, error, stackTrace) ??
            const Center(child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 20));
      },
    );
  }
}

// ---------------------------------------------------------
// Bottom Sheet Form (Create / Edit)
// ---------------------------------------------------------
class _FormBottomSheet extends StatefulWidget {
  final Map<String, dynamic>? item;
  final List<dynamic> cabangs;

  const _FormBottomSheet({this.item, required this.cabangs});

  @override
  State<_FormBottomSheet> createState() => _FormBottomSheetState();
}

class _FormBottomSheetState extends State<_FormBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _noPoController = TextEditingController();
  final _supplierController = TextEditingController();
  final _noTelpController = TextEditingController();
  final _kodeBarangController = TextEditingController();
  final _namaBarangController = TextEditingController();
  final _jumlahController = TextEditingController();
  final _satuanController = TextEditingController();
  final _hargaSatuanController = TextEditingController();
  final _jumlahDiterimaController = TextEditingController();
  final _keteranganController = TextEditingController();

  DateTime? _tanggalPo;
  DateTime? _tanggalDiterima;
  int? _cabangId;
  String _statusPo = 'Draft';
  File? _selectedFile;

  double _totalHarga = 0.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      final data = widget.item!;
      _noPoController.text = data['no_po'] ?? '';
      _tanggalPo = data['tanggal_po'] != null ? DateTime.parse(data['tanggal_po']) : null;
      _cabangId = data['cabang_id'];
      _supplierController.text = data['supplier'] ?? '';
      _noTelpController.text = data['no_telepon_supplier'] ?? '';
      _kodeBarangController.text = data['kode_barang'] ?? '';
      _namaBarangController.text = data['nama_barang'] ?? '';

      final qty = double.tryParse(data['jumlah']?.toString() ?? '0') ?? 0;
      _jumlahController.text = qty == qty.toInt() ? qty.toInt().toString() : qty.toString();

      _satuanController.text = data['satuan'] ?? '';

      final harga = double.tryParse(data['harga_satuan']?.toString() ?? '0') ?? 0;
      _hargaSatuanController.text = harga == harga.toInt() ? harga.toInt().toString() : harga.toString();

      final rawStatus = data['status_po']?.toString() ?? 'Draft';
      if (rawStatus == 'Selesai') {
        _statusPo = 'Diterima Penuh';
      } else {
        _statusPo = rawStatus;
      }
      _tanggalDiterima = data['tanggal_diterima'] != null ? DateTime.parse(data['tanggal_diterima']) : null;

      if (data['jumlah_diterima'] != null) {
        final qtyDiterima = double.tryParse(data['jumlah_diterima']?.toString() ?? '0') ?? 0;
        _jumlahDiterimaController.text = qtyDiterima == qtyDiterima.toInt() ? qtyDiterima.toInt().toString() : qtyDiterima.toString();
      }

      _keteranganController.text = data['keterangan'] ?? '';
      _calculateTotal();
    }
  }

  @override
  void dispose() {
    _noPoController.dispose();
    _supplierController.dispose();
    _noTelpController.dispose();
    _kodeBarangController.dispose();
    _namaBarangController.dispose();
    _jumlahController.dispose();
    _satuanController.dispose();
    _hargaSatuanController.dispose();
    _jumlahDiterimaController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    final qty = double.tryParse(_jumlahController.text.replaceAll(',', '.')) ?? 0.0;
    final harga = double.tryParse(_hargaSatuanController.text.replaceAll(',', '.')) ?? 0.0;
    setState(() {
      _totalHarga = qty * harga;
    });
  }

  Future<void> _pickDate(bool isTanggalPo) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isTanggalPo ? (_tanggalPo ?? DateTime.now()) : (_tanggalDiterima ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isTanggalPo) {
          _tanggalPo = picked;
        } else {
          _tanggalDiterima = picked;
        }
      });
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tanggalPo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tanggal PO wajib diisi')));
      return;
    }
    if (_cabangId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cabang wajib diisi')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = {
        'no_po': _noPoController.text,
        'tanggal_po': DateFormat('yyyy-MM-dd').format(_tanggalPo!),
        'cabang_id': _cabangId,
        'supplier': _supplierController.text,
        'no_telepon_supplier': _noTelpController.text,
        'kode_barang': _kodeBarangController.text,
        'nama_barang': _namaBarangController.text,
        'jumlah': _jumlahController.text.replaceAll(',', '.'),
        'satuan': _satuanController.text,
        'harga_satuan': _hargaSatuanController.text.replaceAll(',', '.'),
        'total_harga': _totalHarga,
        'status_po': _statusPo,
        'keterangan': _keteranganController.text,
      };

      if (_tanggalDiterima != null) {
        payload['tanggal_diterima'] = DateFormat('yyyy-MM-dd').format(_tanggalDiterima!);
      }
      if (_jumlahDiterimaController.text.isNotEmpty) {
        payload['jumlah_diterima'] = _jumlahDiterimaController.text.replaceAll(',', '.');
      }

      if (widget.item == null) {
        await OperasionalPurchaseOrderService.createPurchaseOrder(payload, file: _selectedFile);
      } else {
        await OperasionalPurchaseOrderService.updatePurchaseOrder(widget.item!['id'], payload, file: _selectedFile);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(3)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.item == null ? 'Tambah Purchase Order' : 'Edit Purchase Order',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('INFORMASI PURCHASE ORDER'),
                    _buildTextField('No PO *', _noPoController, hint: 'mis. PO-2026-001'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildDatePicker('Tanggal PO *', _tanggalPo, true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDropdownCabang()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Supplier *', _supplierController)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('No Telepon Supplier', _noTelpController, keyboardType: TextInputType.phone)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('DETAIL BARANG'),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Kode Barang', _kodeBarangController)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('Nama Barang *', _namaBarangController)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Jumlah *', _jumlahController, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => _calculateTotal())),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('Satuan', _satuanController, hint: 'mis. Pcs, Box, Kg')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Harga Satuan', _hargaSatuanController, prefixText: 'Rp ', keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => _calculateTotal())),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Harga', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(10)),
                                child: Text('Rp ${_totalHarga.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(height: 4),
                              Text('Dihitung otomatis', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('STATUS & PENERIMAAN'),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status PO *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(10), color: const Color(0xFFF8FAFC)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _statusPo,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B)),
                              items: const [
                                DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                                DropdownMenuItem(value: 'Dikirim supplier', child: Text('Dikirim supplier')),
                                DropdownMenuItem(value: 'Diterima Sebagian', child: Text('Diterima Sebagian')),
                                DropdownMenuItem(value: 'Diterima Penuh', child: Text('Diterima Penuh')),
                                DropdownMenuItem(value: 'Batal', child: Text('Batal')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _statusPo = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildDatePicker('Tanggal Diterima', _tanggalDiterima, false)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('Jumlah Diterima', _jumlahDiterimaController, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField('Keterangan', _keteranganController, maxLines: 3),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('File PO (Bukti / Invoice)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickFile,
                              icon: const Icon(Icons.attach_file, size: 16),
                              label: const Text('Pilih Berkas'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedFile != null ? _selectedFile!.path.split(Platform.pathSeparator).last : (widget.item?['file_po'] != null ? 'File tersimpan' : 'Belum ada file'),
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -3))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Batal', style: GoogleFonts.inter(color: const Color(0xFF334155), fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Simpan Data', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
        const Divider(color: Color(0xFFF1F5F9)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hint, String? prefixText, int maxLines = 1, TextInputType? keyboardType, Function(String)? onChanged}) {
    bool isRequired = label.contains('*');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: isRequired ? (val) => val == null || val.isEmpty ? 'Wajib diisi' : null : null,
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? value, bool isTanggalPo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pickDate(isTanggalPo),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(10), color: const Color(0xFFF8FAFC)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value != null ? DateFormat('dd/MM/yyyy').format(value) : 'dd/mm/yyyy', style: GoogleFonts.inter(fontSize: 13, color: value != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8))),
                const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownCabang() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cabang *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(10), color: const Color(0xFFF8FAFC)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _cabangId,
              isExpanded: true,
              hint: Text('Pilih Cabang', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B)),
              items: widget.cabangs.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text(c['nama_cabang'] ?? '-'))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _cabangId = val);
              },
            ),
          ),
        ),
      ],
    );
  }
}

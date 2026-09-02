import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/operasional_purchase_order_service.dart';
import '../../../core/api/api_client.dart';

class OperasionalPurchaseOrderScreen extends StatefulWidget {
  final bool isReadOnly;
  const OperasionalPurchaseOrderScreen({
    super.key,
    this.isReadOnly = false,
  });

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
  String? _selectedTipePo = 'pembelian'; // Default to PO Pembelian tab like Web
  DateTime? _startDate;
  DateTime? _endDate;
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
        tipePo: _selectedTipePo,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        List<dynamic> list = data['data'] ?? [];

        // Client-side fallback filter to guarantee precise results
        if (_selectedTipePo != null && _selectedTipePo!.isNotEmpty && _selectedTipePo != 'all') {
          list = list.where((po) {
            final rawT = (po['tipe_po'] ?? '').toString().toLowerCase().trim();
            final bool isDist = rawT == 'distribusi' || (po['cabang_id'] == null && po['cabang'] == null);
            final effectiveType = isDist ? 'distribusi' : 'pembelian';
            return effectiveType == _selectedTipePo!.toLowerCase();
          }).toList();
        }

        if (_selectedStatus != null && _selectedStatus!.isNotEmpty && _selectedStatus != 'Semua Status') {
          list = list.where((po) {
            final s = (po['status_po'] ?? '').toString().toLowerCase().trim();
            return s == _selectedStatus!.toLowerCase().trim();
          }).toList();
        }

        if (_selectedCabangId != null) {
          list = list.where((po) {
            final cId = po['cabang_id'];
            return cId == _selectedCabangId || (po['cabang']?['id'] == _selectedCabangId);
          }).toList();
        }

        if (_startDate != null) {
          list = list.where((po) {
            final tglStr = po['tanggal_po'];
            if (tglStr == null) return true;
            try {
              final dt = DateTime.parse(tglStr.toString());
              return dt.isAfter(_startDate!.subtract(const Duration(seconds: 1)));
            } catch (_) {
              return true;
            }
          }).toList();
        }

        if (_endDate != null) {
          list = list.where((po) {
            final tglStr = po['tanggal_po'];
            if (tglStr == null) return true;
            try {
              final dt = DateTime.parse(tglStr.toString());
              return dt.isBefore(_endDate!.add(const Duration(days: 1)));
            } catch (_) {
              return true;
            }
          }).toList();
        }

        setState(() {
          _purchaseOrders = list;
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

  Future<void> _printInvoicePdf(Map<String, dynamic> item) async {
    final id = item['id'];
    final noPo = (item['no_po'] ?? 'PO').toString();
    final fileName = 'Purchase_Order_${noPo.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.pdf';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Text(
                'Menyiapkan Dokumen PDF...',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final dio = ApiClient.instance;
      Response<List<int>>? res;
      final endpoints = [
        '/operasional/purchase-orders/$id/print',
        '/operasional/purchase-order/$id/print',
        '/purchase-order/$id/print',
      ];

      for (var endpoint in endpoints) {
        try {
          res = await dio.get<List<int>>(
            endpoint,
            options: Options(responseType: ResponseType.bytes),
          );
          if (res.data != null && res.data!.isNotEmpty) {
            break;
          }
        } catch (_) {}
      }

      if (mounted) Navigator.pop(context); // Dismiss loading dialog

      if (res != null && res.data != null && res.data!.isNotEmpty) {
        final bytes = Uint8List.fromList(res.data!);
        await Printing.layoutPdf(
          name: fileName,
          onLayout: (format) async => bytes,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal memuat file PDF dari server.'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat Invoice PDF: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _showFormModal({Map<String, dynamic>? item}) async {
    final result = await showModalBottomSheet(
      useSafeArea: true,
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
            padding: EdgeInsets.fromLTRB(20, 52, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 14 : 18),
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
          _buildMainTabBar(),
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
                            padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 80 : 84),
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
      floatingActionButton: widget.isReadOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showFormModal(
                item: null,
              ),
              backgroundColor: AppColors.primary,
              elevation: 4,
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              label: Text(
                _selectedTipePo == 'distribusi' ? 'Tambah PO Distribusi' : 'Tambah PO Pembelian',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }

  Widget _buildMainTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildMainTabItem(
                title: 'PO Pembelian',
                icon: Icons.shopping_cart_outlined,
                isSelected: _selectedTipePo == 'pembelian',
                activeColor: AppColors.primary,
                onTap: () {
                  setState(() => _selectedTipePo = 'pembelian');
                  _loadData();
                },
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildMainTabItem(
                title: 'PO Distribusi',
                icon: Icons.local_shipping_outlined,
                isSelected: _selectedTipePo == 'distribusi',
                activeColor: AppColors.primary,
                onTap: () {
                  setState(() => _selectedTipePo = 'distribusi');
                  _loadData();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainTabItem({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? activeColor : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_selectedTipePo != null) count++;
    if (_selectedCabangId != null) count++;
    if (_selectedStatus != null) count++;
    if (_startDate != null || _endDate != null) count++;
    return count;
  }

  Widget _buildFilterBar() {
    final activeCount = _activeFiltersCount;
    final bool hasActiveFilters = activeCount > 0;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 8 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input & Filter Button Row
          Row(
            children: [
              // Search Input Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
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
              ),
              const SizedBox(width: 10),

              // Filter Button (HRD Style)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showComprehensiveFilterModal,
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: hasActiveFilters ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasActiveFilters ? AppColors.primary : const Color(0xFFCBD5E1),
                        width: 1.5,
                      ),
                      boxShadow: hasActiveFilters
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: hasActiveFilters ? Colors.white : const Color(0xFF334155),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hasActiveFilters ? 'Filter ($activeCount)' : 'Filter',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: hasActiveFilters ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Active Filter Badges Bar
          if (hasActiveFilters) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_selectedTipePo != null)
                    _buildActiveBadge(
                      label: _selectedTipePo == 'pembelian' ? 'PO Pembelian' : 'PO Distribusi',
                      onRemove: () {
                        setState(() => _selectedTipePo = null);
                        _loadData();
                      },
                    ),
                  if (_selectedCabangId != null)
                    _buildActiveBadge(
                      label: _cabangs.firstWhere(
                        (c) => c['id'] == _selectedCabangId,
                        orElse: () => {'nama_cabang': 'Cabang'},
                      )['nama_cabang'],
                      onRemove: () {
                        setState(() => _selectedCabangId = null);
                        _loadData();
                      },
                    ),
                  if (_selectedStatus != null)
                    _buildActiveBadge(
                      label: _selectedStatus!,
                      onRemove: () {
                        setState(() => _selectedStatus = null);
                        _loadData();
                      },
                    ),
                  if (_startDate != null && _endDate != null)
                    _buildActiveBadge(
                      label: '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM').format(_endDate!)}',
                      onRemove: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                        _loadData();
                      },
                    ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTipePo = null;
                        _selectedCabangId = null;
                        _selectedStatus = null;
                        _startDate = null;
                        _endDate = null;
                      });
                      _loadData();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6, right: 4),
                      child: Text(
                        'Reset Semua',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveBadge({required String label, required VoidCallback onRemove}) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 13, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  void _showComprehensiveFilterModal() {
    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PurchaseOrderFilterBottomSheet(
        selectedTipePo: _selectedTipePo,
        selectedCabangId: _selectedCabangId,
        selectedStatus: _selectedStatus,
        startDate: _startDate,
        endDate: _endDate,
        cabangs: _cabangs,
        onApply: (tipePo, cabangId, status, start, end) {
          setState(() {
            _selectedTipePo = tipePo;
            _selectedCabangId = cabangId;
            _selectedStatus = status;
            _startDate = start;
            _endDate = end;
          });
          _loadData();
        },
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
    final tgl = item['tanggal_po'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['tanggal_po']))
        : '-';
    final noPo = item['no_po']?.toString().trim() ?? '-';
    final cabang = item['cabang']?['nama_cabang']?.toString().trim() ?? '-';
    final supplier = item['supplier']?.toString().trim() ?? '-';
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

    final rawT = (item['tipe_po'] ?? '').toString().toLowerCase().trim();
    final bool isDistribusi = rawT == 'distribusi' || (item['cabang_id'] == null && item['cabang'] == null);

    final fullFileUrl = hasFile ? _getFileUrl(filePo) : '';
    final bool isImage = hasFile && _isImageFile(fullFileUrl);

    final bool hasCabang = cabang != '-' && cabang.isNotEmpty;
    final bool hasSupplier = supplier != '-' && supplier.isNotEmpty;
    final keterangan = item['keterangan']?.toString().trim() ?? '';
    final hasKeterangan = keterangan.isNotEmpty && keterangan != '-';

    // 1. Calculate Items & Total for PO Pembelian (Matching Web)
    final rawPembelianDetails = item['pembelian_details'] ?? item['pembelianDetails'];
    List<dynamic> pembelianList = [];
    if (rawPembelianDetails is List) {
      pembelianList = rawPembelianDetails;
    }

    double totalPembelian = 0;
    int itemCount = pembelianList.length;
    String firstItemName = '';

    if (pembelianList.isNotEmpty) {
      for (var d in pembelianList) {
        final dTot = double.tryParse(d['total_harga']?.toString() ?? '0') ??
            ((double.tryParse(d['qty']?.toString() ?? '0') ?? 0) * (double.tryParse(d['harga']?.toString() ?? '0') ?? 0));
        totalPembelian += dTot;
      }
      firstItemName = (pembelianList.first['nama_barang'] ?? pembelianList.first['deskripsi_barang'] ?? '').toString().trim();
    }

    if (totalPembelian == 0 && item['total_harga'] != null) {
      totalPembelian = double.tryParse(item['total_harga'].toString()) ?? 0;
    }

    if (itemCount == 0 && item['nama_barang'] != null && item['nama_barang'].toString().trim().isNotEmpty) {
      itemCount = 1;
      firstItemName = item['nama_barang'].toString().trim();
    }

    final currency = (item['currency']?.toString().trim().isNotEmpty == true)
        ? item['currency'].toString().trim()
        : 'IDR';

    final totalFormatted = '$currency ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(totalPembelian).trim()}';

    // 2. Calculate distribution summary if PO Distribusi (Matching Web)
    int distJenisCount = 1;
    int distCabangCount = 1;
    final rawDistDetails = item['distribusi_details'] ?? item['distribusiDetails'];
    if (rawDistDetails is List && rawDistDetails.isNotEmpty) {
      distJenisCount = rawDistDetails.map((d) => d['nama_barang']).where((n) => n != null).toSet().length;
      distCabangCount = rawDistDetails.map((d) => d['cabang_id']).where((c) => c != null).toSet().length;
      if (distJenisCount == 0) distJenisCount = 1;
      if (distCabangCount == 0) distCabangCount = 1;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFDBEAFE),
                    ),
                  ),
                  child: Icon(
                    isDistribusi ? Icons.local_shipping_rounded : Icons.receipt_long_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Main Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row No PO & Tanggal
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              noPo,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 11, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                tgl,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Cabang & Supplier Row (Matching Web Column 2)
                      if (isDistribusi) ...[
                        if (hasSupplier)
                          Text(
                            supplier,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F766E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (hasKeterangan) ...[
                          const SizedBox(height: 2),
                          Text(
                            keterangan,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ] else ...[
                        Row(
                          children: [
                            if (hasCabang)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.storefront_rounded, size: 11, color: Color(0xFF059669)),
                                    const SizedBox(width: 3),
                                    Text(
                                      cabang,
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (hasCabang && hasSupplier) const SizedBox(width: 6),
                            if (hasSupplier)
                              Expanded(
                                child: Text(
                                  supplier,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),

                      // Items & Total Box (Matching Web Column 3)
                      if (isDistribusi) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 12.5, color: Color(0xFF1D4ED8)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$distJenisCount Jenis Barang',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 12.5, color: Color(0xFF1D4ED8)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Ke $distCabangCount Cabang',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.shopping_bag_outlined, size: 13, color: Color(0xFF475569)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$itemCount Items${firstItemName.isNotEmpty ? ' ($firstItemName)' : ''}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                totalFormatted,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Badges Row (Type & Status)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Type Badge (Pembelian / Distribusi)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFBFDBFE),
                    ),
                  ),
                  child: Text(
                    isDistribusi ? '📦 Distribusi' : '🛒 Pembelian',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1D4ED8),
                    ),
                  ),
                ),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action Bar: Text + Icon Buttons (Print, Berkas, Edit, Hapus)
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // 1. INVOICE PRINT BUTTON
                Expanded(
                  child: Material(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => _printInvoicePdf(item),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.print_rounded, size: 15, color: Color(0xFF1D4ED8)),
                            const SizedBox(width: 4),
                            Text(
                              'Print',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1D4ED8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 2. ATTACHMENT BUTTON (IF HAS FILE)
                if (hasFile) ...[
                  Expanded(
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => _viewFileInApp(filePo, noPo),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isImage ? Icons.image_rounded : Icons.attach_file_rounded,
                                size: 15,
                                color: const Color(0xFF475569),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isImage ? 'Foto' : 'Berkas',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // 3. EDIT BUTTON (Hidden in Read-Only Mode)
                if (!widget.isReadOnly) ...[
                  Expanded(
                    child: Material(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => _showFormModal(item: item),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.edit_rounded, size: 15, color: Color(0xFFD97706)),
                              const SizedBox(width: 4),
                              Text(
                                'Edit',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // 4. DELETE BUTTON (Hidden in Read-Only Mode)
                if (!widget.isReadOnly) ...[
                  Expanded(
                    child: Material(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => _deleteData(item['id']),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFDC2626)),
                              const SizedBox(width: 4),
                              Text(
                                'Hapus',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
// ---------------------------------------------------------
// Bottom Sheet Form (Create / Edit: PO Pembelian & PO Distribusi)
// ---------------------------------------------------------
class _FormBottomSheet extends StatefulWidget {
  final Map<String, dynamic>? item;
  final List<dynamic> cabangs;

  const _FormBottomSheet({this.item, required this.cabangs});

  @override
  State<_FormBottomSheet> createState() => _FormBottomSheetState();
}

class _PembelianItemState {
  final TextEditingController deskripsi;
  final TextEditingController qty;
  final TextEditingController hargaSatuan;
  double totalHarga;

  _PembelianItemState({
    required this.deskripsi,
    required this.qty,
    required this.hargaSatuan,
    this.totalHarga = 0.0,
  });

  void dispose() {
    deskripsi.dispose();
    qty.dispose();
    hargaSatuan.dispose();
  }
}

class _DistribusiRowState {
  int? cabangId;
  final Map<String, TextEditingController> itemControllers;

  _DistribusiRowState({
    this.cabangId,
    required this.itemControllers,
  });

  void dispose() {
    for (var ctrl in itemControllers.values) {
      ctrl.dispose();
    }
  }
}

class _FormBottomSheetState extends State<_FormBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  // Mode: 'pembelian' or 'distribusi'
  String _tipePo = 'pembelian';

  // Header Controllers
  final _noPoController = TextEditingController();
  final _currencyController = TextEditingController(text: 'IDR');
  DateTime? _tanggalPo;
  int? _cabangId; // For PO Pembelian

  // Supplier Controllers
  final _supplierController = TextEditingController();
  final _picSupplierController = TextEditingController();
  final _noTelpController = TextEditingController();
  final _alamatSupplierController = TextEditingController();

  // Completion Controllers
  String _statusPo = 'Draft';
  final _keteranganController = TextEditingController();
  File? _selectedFile;
  String? _existingFile;
  bool _isSaving = false;

  // PO Pembelian Items
  final List<_PembelianItemState> _pembelianItems = [];

  // PO Distribusi Matrix
  final List<String> _distribusiColumns = [];
  final _newColumnController = TextEditingController();
  final List<_DistribusiRowState> _distribusiRows = [];

  @override
  void initState() {
    super.initState();

    if (widget.item != null) {
      _populateFromData(widget.item!);
      _fetchFullDetail();
    } else {
      // New Item
      _noPoController.text = '[Otomatis]';
      _tanggalPo = DateTime.now();
      _addPembelianItem();
      _distribusiColumns.addAll(['Tas Kecil', 'Cover Tas Kecil', 'Tas Besar', 'Cover Tas Besar']);
      _addDistribusiRow();
    }
  }

  Future<void> _fetchFullDetail() async {
    if (widget.item == null || widget.item!['id'] == null) return;
    try {
      final id = widget.item!['id'];
      final dio = ApiClient.instance;
      dynamic res;
      try {
        res = await dio.get('/operasional/purchase-orders/$id');
      } catch (_) {
        res = await dio.get('/operasional/purchase-order/$id');
      }
      if (res.data != null && res.data['data'] != null && mounted) {
        setState(() {
          _populateFromData(Map<String, dynamic>.from(res.data['data']));
        });
      }
    } catch (e) {
      debugPrint('Error fetching full PO details: $e');
    }
  }

  void _populateFromData(Map<String, dynamic> data) {
    // Detect Tipe PO
    final rawT = (data['tipe_po'] ?? '').toString().toLowerCase().trim();
    final bool isDist = rawT == 'distribusi' || (data['cabang_id'] == null && data['cabang'] == null);
    _tipePo = isDist ? 'distribusi' : 'pembelian';

    _noPoController.text = data['no_po'] ?? '';
    _tanggalPo = data['tanggal_po'] != null ? DateTime.tryParse(data['tanggal_po'].toString()) : DateTime.now();
    _currencyController.text = data['currency']?.toString().trim().isNotEmpty == true ? data['currency'] : 'IDR';
    _cabangId = data['cabang_id'] ?? data['cabang']?['id'];

    _supplierController.text = data['supplier'] ?? '';
    _picSupplierController.text = data['supplier_pic'] ?? '';
    _noTelpController.text = data['no_telepon_supplier'] ?? '';
    _alamatSupplierController.text = data['supplier_alamat'] ?? '';

    _statusPo = data['status_po']?.toString() ?? 'Draft';
    _keteranganController.text = data['keterangan'] ?? '';
    _existingFile = data['file_po'];

    if (_tipePo == 'pembelian') {
      final details = (data['pembelian_details'] ?? data['pembelianDetails']) as List<dynamic>?;
      for (var it in _pembelianItems) {
        it.dispose();
      }
      _pembelianItems.clear();

      if (details != null && details.isNotEmpty) {
        for (var d in details) {
          final qty = double.tryParse(d['qty']?.toString() ?? '1') ?? 1;
          final harga = double.tryParse(d['harga_satuan']?.toString() ?? '0') ?? 0;
          final tot = double.tryParse(d['total_harga']?.toString() ?? '0') ?? (qty * harga);

          final it = _PembelianItemState(
            deskripsi: TextEditingController(text: d['deskripsi_barang'] ?? ''),
            qty: TextEditingController(text: qty == qty.toInt() ? qty.toInt().toString() : qty.toString()),
            hargaSatuan: TextEditingController(text: harga == harga.toInt() ? harga.toInt().toString() : harga.toString()),
            totalHarga: tot,
          );
          _pembelianItems.add(it);
        }
      } else {
        final qty = double.tryParse(data['jumlah']?.toString() ?? '1') ?? 1;
        final harga = double.tryParse(data['harga_satuan']?.toString() ?? '0') ?? 0;
        final tot = double.tryParse(data['total_harga']?.toString() ?? '0') ?? (qty * harga);

        _pembelianItems.add(
          _PembelianItemState(
            deskripsi: TextEditingController(text: data['nama_barang'] ?? ''),
            qty: TextEditingController(text: qty == qty.toInt() ? qty.toInt().toString() : qty.toString()),
            hargaSatuan: TextEditingController(text: harga == harga.toInt() ? harga.toInt().toString() : harga.toString()),
            totalHarga: tot,
          ),
        );
      }
    } else {
      final details = (data['distribusi_details'] ?? data['distribusiDetails']) as List<dynamic>?;
      if (details != null && details.isNotEmpty) {
        _distribusiColumns.clear();
        for (var r in _distribusiRows) {
          r.dispose();
        }
        _distribusiRows.clear();

        final uniqueCols = <String>{};
        for (var d in details) {
          final nb = d['nama_barang']?.toString().trim();
          if (nb != null && nb.isNotEmpty) uniqueCols.add(nb);
        }
        _distribusiColumns.addAll(uniqueCols);

        // Group by cabang_id
        final grouped = <int?, Map<String, double>>{};
        for (var d in details) {
          final cId = int.tryParse(d['cabang_id']?.toString() ?? '');
          final nb = d['nama_barang']?.toString().trim() ?? '';
          final qty = double.tryParse(d['qty']?.toString() ?? '0') ?? 0.0;
          if (!grouped.containsKey(cId)) grouped[cId] = {};
          grouped[cId]![nb] = qty;
        }

        grouped.forEach((cId, items) {
          final ctrlMap = <String, TextEditingController>{};
          for (var col in _distribusiColumns) {
            final val = items[col] ?? 0.0;
            ctrlMap[col] = TextEditingController(text: val == val.toInt() ? val.toInt().toString() : val.toString());
          }
          _distribusiRows.add(_DistribusiRowState(cabangId: cId, itemControllers: ctrlMap));
        });
      }
    }

    if (_pembelianItems.isEmpty) {
      _addPembelianItem();
    }
    if (_distribusiColumns.isEmpty) {
      _distribusiColumns.addAll(['Tas Kecil', 'Cover Tas Kecil']);
    }
    if (_distribusiRows.isEmpty) {
      _addDistribusiRow();
    }
  }

  @override
  void dispose() {
    _noPoController.dispose();
    _currencyController.dispose();
    _supplierController.dispose();
    _picSupplierController.dispose();
    _noTelpController.dispose();
    _alamatSupplierController.dispose();
    _keteranganController.dispose();
    _newColumnController.dispose();

    for (var it in _pembelianItems) {
      it.dispose();
    }
    for (var r in _distribusiRows) {
      r.dispose();
    }

    super.dispose();
  }

  // --- PEMBELIAN HELPERS ---
  void _addPembelianItem() {
    setState(() {
      _pembelianItems.add(
        _PembelianItemState(
          deskripsi: TextEditingController(),
          qty: TextEditingController(text: '1'),
          hargaSatuan: TextEditingController(text: '0'),
          totalHarga: 0.0,
        ),
      );
    });
  }

  void _removePembelianItem(int index) {
    if (_pembelianItems.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal harus ada 1 barang pembelian')),
      );
      return;
    }
    setState(() {
      _pembelianItems[index].dispose();
      _pembelianItems.removeAt(index);
    });
  }

  void _calcPembelianItemTotal(int index) {
    final it = _pembelianItems[index];
    final qty = double.tryParse(it.qty.text.replaceAll(',', '.')) ?? 0.0;
    final harga = double.tryParse(it.hargaSatuan.text.replaceAll(',', '.')) ?? 0.0;
    setState(() {
      it.totalHarga = qty * harga;
    });
  }

  double get _grandTotalPembelian {
    return _pembelianItems.fold(0.0, (sum, it) => sum + it.totalHarga);
  }

  // --- DISTRIBUSI HELPERS ---
  void _addDistribusiColumn() {
    final colName = _newColumnController.text.trim();
    if (colName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nama barang kolom terlebih dahulu')),
      );
      return;
    }
    if (_distribusiColumns.contains(colName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kolom barang ini sudah ada')),
      );
      return;
    }

    setState(() {
      _distribusiColumns.add(colName);
      for (var row in _distribusiRows) {
        row.itemControllers[colName] = TextEditingController(text: '0');
      }
      _newColumnController.clear();
    });
  }

  void _removeDistribusiColumn(String colName) {
    if (_distribusiColumns.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal harus ada 1 kolom barang distribusi')),
      );
      return;
    }

    setState(() {
      _distribusiColumns.remove(colName);
      for (var row in _distribusiRows) {
        row.itemControllers[colName]?.dispose();
        row.itemControllers.remove(colName);
      }
    });
  }

  void _addDistribusiRow() {
    final ctrlMap = <String, TextEditingController>{};
    for (var col in _distribusiColumns) {
      ctrlMap[col] = TextEditingController(text: '0');
    }
    setState(() {
      _distribusiRows.add(_DistribusiRowState(cabangId: null, itemControllers: ctrlMap));
    });
  }

  void _removeDistribusiRow(int index) {
    if (_distribusiRows.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal harus ada 1 baris cabang distribusi')),
      );
      return;
    }
    setState(() {
      _distribusiRows[index].dispose();
      _distribusiRows.removeAt(index);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggalPo ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _tanggalPo = picked);
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
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

    if (_tipePo == 'pembelian' && _cabangId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cabang pemesan wajib dipilih untuk PO Pembelian')));
      return;
    }

    if (_tipePo == 'distribusi') {
      final invalidRow = _distribusiRows.any((r) => r.cabangId == null);
      if (invalidRow) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih cabang untuk setiap baris distribusi')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> payload = {
        'no_po': _noPoController.text.trim(),
        'tipe_po': _tipePo,
        'tanggal_po': DateFormat('yyyy-MM-dd').format(_tanggalPo!),
        'currency': _currencyController.text.trim(),
        'supplier': _supplierController.text.trim(),
        'supplier_pic': _picSupplierController.text.trim(),
        'no_telepon_supplier': _noTelpController.text.trim(),
        'supplier_alamat': _alamatSupplierController.text.trim(),
        'status_po': _statusPo,
        'keterangan': _keteranganController.text.trim(),
      };

      if (_tipePo == 'pembelian') {
        payload['cabang_id'] = _cabangId;

        // Primary info for backwards compatibility
        if (_pembelianItems.isNotEmpty) {
          final first = _pembelianItems.first;
          payload['nama_barang'] = first.deskripsi.text.trim();
          payload['jumlah'] = first.qty.text.trim().replaceAll(',', '.');
          payload['harga_satuan'] = first.hargaSatuan.text.trim().replaceAll(',', '.');
          payload['total_harga'] = _grandTotalPembelian;
        }

        // Full items list JSON
        final pembelianList = _pembelianItems.map((it) {
          final qty = double.tryParse(it.qty.text.trim().replaceAll(',', '.')) ?? 1;
          final harga = double.tryParse(it.hargaSatuan.text.trim().replaceAll(',', '.')) ?? 0;
          return {
            'deskripsi_barang': it.deskripsi.text.trim(),
            'qty': qty,
            'harga_satuan': harga,
            'total_harga': it.totalHarga,
          };
        }).toList();
        payload['pembelian_items'] = jsonEncode(pembelianList);
      } else {
        // Full distribution matrix rows JSON
        final rowsList = _distribusiRows.map((r) {
          final itemsMap = <String, double>{};
          r.itemControllers.forEach((col, ctrl) {
            itemsMap[col] = double.tryParse(ctrl.text.trim().replaceAll(',', '.')) ?? 0.0;
          });
          return {
            'cabang_id': r.cabangId,
            'items': itemsMap,
          };
        }).toList();
        payload['distribusi_rows'] = jsonEncode(rowsList);
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
    final bool isEdit = widget.item != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(3)),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (_tipePo == 'pembelian' ? AppColors.primary : const Color(0xFF1D4ED8)).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _tipePo == 'pembelian' ? Icons.shopping_cart_outlined : Icons.local_shipping_outlined,
                        color: _tipePo == 'pembelian' ? AppColors.primary : const Color(0xFF1D4ED8),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit
                              ? (_tipePo == 'pembelian' ? 'Edit PO Pembelian' : 'Edit PO Distribusi')
                              : 'Tambah Purchase Order',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                        ),
                        Text(
                          _tipePo == 'pembelian' ? 'Pembelian barang cabang' : 'Distribusi multi cabang',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    padding: const EdgeInsets.all(6),
                  ),
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
                    // Mode Switcher (If creating new)
                    if (!isEdit) ...[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTypeSwitcherTab(
                                label: 'PO Pembelian',
                                icon: Icons.shopping_cart_outlined,
                                isSelected: _tipePo == 'pembelian',
                                onTap: () => setState(() => _tipePo = 'pembelian'),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _buildTypeSwitcherTab(
                                label: 'PO Distribusi',
                                icon: Icons.local_shipping_outlined,
                                isSelected: _tipePo == 'distribusi',
                                onTap: () => setState(() => _tipePo = 'distribusi'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ==========================================
                    // 1. INFORMASI UMUM
                    // ==========================================
                    _buildSectionHeader('INFORMASI UMUM', Icons.info_outline_rounded),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField('No PO *', _noPoController, hint: 'mis. PO-2026-001'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDatePickerField('Tanggal PO *', _tanggalPo),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField('Mata Uang *', _currencyController, hint: 'IDR'),
                        ),
                        if (_tipePo == 'pembelian') ...[
                          const SizedBox(width: 12),
                          Expanded(child: _buildDropdownCabang()),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ==========================================
                    // 2. INFORMASI SUPPLIER
                    // ==========================================
                    _buildSectionHeader('INFORMASI SUPPLIER', Icons.store_mall_directory_outlined),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField('Nama Supplier *', _supplierController, hint: 'mis. Komatsu'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField('PIC Supplier', _picSupplierController, hint: 'Nama PIC'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            'No Telepon Supplier',
                            _noTelpController,
                            hint: '0812xxxx',
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            'Alamat Supplier',
                            _alamatSupplierController,
                            hint: 'Alamat lengkap',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ==========================================
                    // 3. (A) DAFTAR BARANG PEMBELIAN
                    // ==========================================
                    if (_tipePo == 'pembelian') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader('DAFTAR BARANG PEMBELIAN', Icons.inventory_2_outlined),
                          OutlinedButton.icon(
                            onPressed: _addPembelianItem,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Tambah Barang'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              textStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _pembelianItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, idx) {
                          final it = _pembelianItems[idx];
                          return Container(
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Barang #${idx + 1}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                    if (_pembelianItems.length > 1)
                                      InkWell(
                                        onTap: () => _removePembelianItem(idx),
                                        borderRadius: BorderRadius.circular(6),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 18),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildTextField('Deskripsi Barang *', it.deskripsi, hint: 'Nama / Deskripsi barang'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildTextField(
                                        'Qty *',
                                        it.qty,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (_) => _calcPembelianItemTotal(idx),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 3,
                                      child: _buildTextField(
                                        'Harga Satuan *',
                                        it.hargaSatuan,
                                        prefixText: 'Rp ',
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (_) => _calcPembelianItemTotal(idx),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Total Harga',
                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              border: Border.all(color: const Color(0xFFDBEAFE)),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(it.totalHarga),
                                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Grand Total Summary Banner
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Nilai PO Pembelian:',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                            ),
                            Text(
                              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(_grandTotalPembelian),
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ==========================================
                    // 3. (B) MATRIKS DISTRIBUSI BARANG
                    // ==========================================
                    if (_tipePo == 'distribusi') ...[
                      _buildSectionHeader('MATRIKS DISTRIBUSI BARANG', Icons.grid_view_rounded),
                      const SizedBox(height: 12),

                      // Add Column Bar
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _newColumnController,
                              style: GoogleFonts.inter(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Nama Barang Baru...',
                                hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _addDistribusiColumn,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Tambah Kolom'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D4ED8),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Columns List (Chips with delete)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _distribusiColumns.map((col) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFDBEAFE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  col,
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _removeDistribusiColumn(col),
                                  child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF1D4ED8)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Distribution Branch Rows
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _distribusiRows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, idx) {
                          final row = _distribusiRows[idx];
                          return Container(
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
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                          borderRadius: BorderRadius.circular(10),
                                          color: Colors.white,
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: row.cabangId,
                                            isExpanded: true,
                                            hint: Text('Pilih Cabang *', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                                            items: widget.cabangs
                                                .map((c) => DropdownMenuItem<int>(value: c['id'], child: Text(c['nama_cabang'] ?? '-')))
                                                .toList(),
                                            onChanged: (val) => setState(() => row.cabangId = val),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_distribusiRows.length > 1) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () => _removeDistribusiRow(idx),
                                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Inputs per column
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _distribusiColumns.map((col) {
                                    final ctrl = row.itemControllers[col] ?? TextEditingController(text: '0');
                                    return SizedBox(
                                      width: 140,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            col,
                                            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          TextFormField(
                                            controller: ctrl,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                            decoration: InputDecoration(
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              isDense: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      OutlinedButton.icon(
                        onPressed: _addDistribusiRow,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('+ Tambah Baris Cabang'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1D4ED8),
                          side: const BorderSide(color: Color(0xFF1D4ED8)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ==========================================
                    // 4. PENYELESAIAN & LAMPIRAN
                    // ==========================================
                    _buildSectionHeader('PENYELESAIAN & LAMPIRAN', Icons.assignment_turned_in_outlined),
                    const SizedBox(height: 12),

                    // Status PO
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
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
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

                    // File / Gambar PO Picker
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('File/Gambar PO', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _pickFile,
                                icon: const Icon(Icons.attach_file_rounded, size: 16),
                                label: const Text('Pilih Berkas'),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedFile != null
                                      ? _selectedFile!.path.split(Platform.pathSeparator).last
                                      : (_existingFile != null && _existingFile!.isNotEmpty ? 'Berkas tersimpan' : 'Belum ada berkas dipilih'),
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Keterangan
                    _buildTextField('Keterangan', _keteranganController, hint: 'Tambahkan catatan jika ada...', maxLines: 3),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          // Footer Action Bar
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
                      backgroundColor: _tipePo == 'pembelian' ? AppColors.primary : const Color(0xFF1D4ED8),
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

  Widget _buildTypeSwitcherTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.primary : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
    String? prefixText,
    int maxLines = 1,
    TextInputType? keyboardType,
    Function(String)? onChanged,
  }) {
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
          validator: isRequired ? (val) => val == null || val.trim().isEmpty ? 'Wajib diisi' : null : null,
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField(String label, DateTime? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFF8FAFC),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value != null ? DateFormat('dd/MM/yyyy').format(value) : 'dd/mm/yyyy',
                  style: GoogleFonts.inter(fontSize: 13, color: value != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8)),
                ),
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

// --- COMPREHENSIVE FILTER BOTTOM SHEET (HRD STYLE) FOR PURCHASE ORDER ---
class _PurchaseOrderFilterBottomSheet extends StatefulWidget {
  final String? selectedTipePo;
  final int? selectedCabangId;
  final String? selectedStatus;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<dynamic> cabangs;
  final Function(String? tipePo, int? cabangId, String? status, DateTime? start, DateTime? end) onApply;

  const _PurchaseOrderFilterBottomSheet({
    required this.selectedTipePo,
    required this.selectedCabangId,
    required this.selectedStatus,
    required this.startDate,
    required this.endDate,
    required this.cabangs,
    required this.onApply,
  });

  @override
  State<_PurchaseOrderFilterBottomSheet> createState() => _PurchaseOrderFilterBottomSheetState();
}

class _PurchaseOrderFilterBottomSheetState extends State<_PurchaseOrderFilterBottomSheet> {
  String? _tipePo;
  int? _cabangId;
  String? _status;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tipePo = widget.selectedTipePo;
    _cabangId = widget.selectedCabangId;
    _status = widget.selectedStatus;
    _startDate = widget.startDate;
    _endDate = widget.endDate;
  }

  void _applyQuickDatePreset(String preset) {
    final now = DateTime.now();
    setState(() {
      if (preset == 'today') {
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (preset == '7days') {
        _startDate = now.subtract(const Duration(days: 7));
        _endDate = now;
      } else if (preset == 'this_month') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      } else {
        _startDate = null;
        _endDate = null;
      }
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_startDate != null && _startDate!.isAfter(_endDate!)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Filter Purchase Order',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 1. TIPE PO FILTER ---
                    Text(
                      'TIPE PURCHASE ORDER',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildTypeOption(
                          label: 'Semua Tipe',
                          value: null,
                          icon: Icons.all_inclusive_rounded,
                        ),
                        const SizedBox(width: 8),
                        _buildTypeOption(
                          label: 'PO Pembelian',
                          value: 'pembelian',
                          icon: Icons.shopping_cart_outlined,
                        ),
                        const SizedBox(width: 8),
                        _buildTypeOption(
                          label: 'PO Distribusi',
                          value: 'distribusi',
                          icon: Icons.local_shipping_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // --- 2. STATUS PO FILTER ---
                    Text(
                      'STATUS PURCHASE ORDER',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildStatusChip('Semua Status', null),
                        _buildStatusChip('Draft', 'Draft'),
                        _buildStatusChip('Dikirim supplier', 'Dikirim supplier'),
                        _buildStatusChip('Diterima Sebagian', 'Diterima Sebagian'),
                        _buildStatusChip('Diterima Penuh', 'Diterima Penuh'),
                        _buildStatusChip('Batal', 'Batal'),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // --- 3. CABANG FILTER ---
                    Text(
                      'CABANG',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<dynamic>(
                          value: _cabangId,
                          isExpanded: true,
                          hint: Row(
                            children: [
                              const Icon(Icons.storefront_outlined, size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Text(
                                'Semua Cabang',
                                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Row(
                                children: [
                                  const Icon(Icons.storefront_outlined, size: 16, color: Color(0xFF64748B)),
                                  const SizedBox(width: 8),
                                  Text('Semua Cabang', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            ...widget.cabangs.map(
                              (c) => DropdownMenuItem(
                                value: c['id'],
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
                                    const SizedBox(width: 8),
                                    Text(c['nama_cabang'] ?? '-'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) => setState(() => _cabangId = val as int?),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // --- 4. TANGGAL FILTER ---
                    Text(
                      'RENTANG TANGGAL PO',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Date Presets
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildDatePresetChip('Semua Waktu', () => _applyQuickDatePreset('all'), _startDate == null && _endDate == null),
                          const SizedBox(width: 6),
                          _buildDatePresetChip('Hari Ini', () => _applyQuickDatePreset('today'), false),
                          const SizedBox(width: 6),
                          _buildDatePresetChip('7 Hari Terakhir', () => _applyQuickDatePreset('7days'), false),
                          const SizedBox(width: 6),
                          _buildDatePresetChip('Bulan Ini', () => _applyQuickDatePreset('this_month'), false),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Date Pickers (Dari - Sampai)
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickDate(isStart: true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _startDate != null ? AppColors.primary : const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dari Tanggal',
                                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, size: 14, color: _startDate != null ? AppColors.primary : const Color(0xFF94A3B8)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : 'Pilih...',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _startDate != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickDate(isStart: false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _endDate != null ? AppColors.primary : const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sampai Tanggal',
                                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, size: 14, color: _endDate != null ? AppColors.primary : const Color(0xFF94A3B8)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : 'Pilih...',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _endDate != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // --- ACTION BUTTONS ---
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _tipePo = null;
                                _cabangId = null;
                                _status = null;
                                _startDate = null;
                                _endDate = null;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Reset',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            onPressed: () {
                              widget.onApply(_tipePo, _cabangId, _status, _startDate, _endDate);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Terapkan Filter',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }

  Widget _buildTypeOption({
    required String label,
    required String? value,
    required IconData icon,
  }) {
    final isSelected = _tipePo == value;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tipePo = value),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? AppColors.primary : const Color(0xFF64748B)),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.primary : const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, String? value) {
    final isSelected = _status == value;

    return InkWell(
      onTap: () => setState(() => _status = value),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? AppColors.primary : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePresetChip(String label, VoidCallback onTap, bool isSelected) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primary : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

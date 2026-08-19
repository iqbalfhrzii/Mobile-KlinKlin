import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/api/api_client.dart';
import '../services/operasional_approval_pengajuan_service.dart';

class OperasionalApprovalPengajuanScreen extends StatefulWidget {
  const OperasionalApprovalPengajuanScreen({super.key});

  @override
  State<OperasionalApprovalPengajuanScreen> createState() => _OperasionalApprovalPengajuanScreenState();
}

class _OperasionalApprovalPengajuanScreenState extends State<OperasionalApprovalPengajuanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = false;
  List<dynamic> _cabangs = [];
  String? _authToken;

  // Pending Tab State
  List<dynamic> _pendingList = [];

  // History Tab State
  List<dynamic> _historyList = [];
  int? _selectedCabangId;
  String? _selectedStatus; // 'approved' or 'rejected'
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadDataForCurrentTab();
      }
    });
    _loadAuthTokenAndCabangs();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      final cabangs = await OperasionalApprovalPengajuanService.getCabangs();
      if (mounted) {
        setState(() => _cabangs = cabangs);
        _loadDataForCurrentTab();
      }
    } catch (e) {
      debugPrint('Error loading cabangs: $e');
    }
  }

  void _loadDataForCurrentTab() {
    if (_tabController.index == 0) {
      _loadPendingData();
    } else {
      _loadHistoryData();
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _loadHistoryData();
    });
  }

  Future<void> _loadPendingData() async {
    setState(() => _isLoading = true);
    try {
      final data = await OperasionalApprovalPengajuanService.getPengajuan(
        status: 'pending',
      );
      if (mounted) {
        setState(() {
          _pendingList = data['data'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHistoryData() async {
    setState(() => _isLoading = true);
    try {
      String? startStr = _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null;
      String? endStr = _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null;

      final data = await OperasionalApprovalPengajuanService.getPengajuan(
        status: _selectedStatus ?? 'history',
        cabangId: _selectedCabangId,
        search: _searchController.text,
        startDate: startStr,
        endDate: endStr,
      );
      if (mounted) {
        setState(() {
          _historyList = data['data'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDetailModal(Map<String, dynamic> item, bool isPending) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetailBottomSheet(
        item: item,
        isPending: isPending,
        authToken: _authToken,
      ),
    );

    if (result == true) {
      _loadDataForCurrentTab();
      if (_tabController.index == 1) _loadPendingData();
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
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
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadHistoryData();
    }
  }

  String _getImageUrl(dynamic rawPath) {
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

  List<String> _getItemPhotos(Map<String, dynamic> item) {
    final List<String> list = [];
    for (final key in ['foto_1', 'foto_2', 'foto_3', 'foto_4', 'foto_5', 'foto_bukti', 'foto']) {
      final val = item[key];
      if (val != null && val.toString().trim().isNotEmpty && val.toString() != 'null') {
        list.add(_getImageUrl(val));
      }
    }
    return list;
  }

  String _getApplicantName(Map<String, dynamic> item) {
    final pemohonObj = item['pemohon'];
    if (pemohonObj is Map) {
      final name = pemohonObj['nama_lengkap'] ?? pemohonObj['nama'] ?? pemohonObj['name'] ?? pemohonObj['nama_karyawan'];
      if (name != null && name.toString().trim().isNotEmpty) return name.toString();
    }
    final directName = item['pemohon_nama'] ?? item['nama_pemohon'] ?? item['nama_karyawan'];
    if (directName != null && directName.toString().trim().isNotEmpty) return directName.toString();
    if (pemohonObj is String && pemohonObj.trim().isNotEmpty && pemohonObj != 'null') return pemohonObj;
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Enhanced Gradient Header with Mobile-First Tab Bar
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                            'Approval Pengajuan',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Persetujuan alat & chemical cabang',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Mobile Tab Pills
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    dividerColor: Colors.transparent,
                    dividerHeight: 0,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.white,
                    labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
                    unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Perlu Diproses'),
                            if (_pendingList.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade500,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_pendingList.length}',
                                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF78350F), fontWeight: FontWeight.w900),
                                ),
                              )
                            ]
                          ],
                        ),
                      ),
                      const Tab(text: 'Riwayat Approval'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPendingTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : RefreshIndicator(
            onRefresh: _loadPendingData,
            color: AppColors.primary,
            child: _pendingList.isEmpty
                ? _buildEmptyState(
                    title: 'Tidak Ada Pengajuan',
                    subtitle: 'Semua pengajuan alat & chemical telah diproses.',
                    icon: Icons.check_circle_outline_rounded,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    itemCount: _pendingList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      return _buildMobileCard(_pendingList[index], true);
                    },
                  ),
          );
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        _buildMobileFilterBar(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : RefreshIndicator(
                  onRefresh: _loadHistoryData,
                  color: AppColors.primary,
                  child: _historyList.isEmpty
                      ? _buildEmptyState(
                          title: 'Riwayat Kosong',
                          subtitle: 'Belum ada data riwayat pengajuan dengan filter ini.',
                          icon: Icons.history_rounded,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          itemCount: _historyList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            return _buildMobileCard(_historyList[index], false);
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildMobileFilterBar() {
    String dateRangeStr = 'Pilih Tanggal';
    if (_startDate != null && _endDate != null) {
      dateRangeStr = '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM').format(_endDate!)}';
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                      hintText: 'Cari barang, nama pemohon...',
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
                      _loadHistoryData();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Horizontal Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Cabang Filter Chip
                _buildFilterChip(
                  label: _selectedCabangId == null
                      ? 'Semua Cabang'
                      : _cabangs.firstWhere(
                          (c) => c['id'] == _selectedCabangId,
                          orElse: () => {'nama_cabang': 'Cabang'},
                        )['nama_cabang'],
                  isActive: _selectedCabangId != null,
                  icon: Icons.storefront_rounded,
                  onTap: _showCabangPicker,
                ),
                const SizedBox(width: 8),

                // Status Filter Chip
                _buildFilterChip(
                  label: _selectedStatus == null
                      ? 'Semua Status'
                      : (_selectedStatus == 'approved' ? 'Disetujui' : 'Ditolak'),
                  isActive: _selectedStatus != null,
                  icon: Icons.filter_list_rounded,
                  onTap: _showStatusPicker,
                ),
                const SizedBox(width: 8),

                // Date Filter Chip
                _buildFilterChip(
                  label: dateRangeStr,
                  isActive: _startDate != null,
                  icon: Icons.calendar_today_rounded,
                  onTap: _selectDateRange,
                  onClear: _startDate != null
                      ? () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                          });
                          _loadHistoryData();
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? AppColors.primary : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? AppColors.primary : const Color(0xFF334155),
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onClear,
                child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
              ),
            ] else ...[
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: isActive ? AppColors.primary : const Color(0xFF94A3B8)),
            ]
          ],
        ),
      ),
    );
  }

  void _showCabangPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Pilih Cabang',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ListTile(
              title: Text('Semua Cabang', style: GoogleFonts.inter(fontWeight: _selectedCabangId == null ? FontWeight.w800 : FontWeight.w500)),
              trailing: _selectedCabangId == null ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
              onTap: () {
                setState(() => _selectedCabangId = null);
                Navigator.pop(context);
                _loadHistoryData();
              },
            ),
            ..._cabangs.map((c) => ListTile(
                  title: Text(c['nama_cabang'], style: GoogleFonts.inter(fontWeight: _selectedCabangId == c['id'] ? FontWeight.w800 : FontWeight.w500)),
                  trailing: _selectedCabangId == c['id'] ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                  onTap: () {
                    setState(() => _selectedCabangId = c['id'] as int);
                    Navigator.pop(context);
                    _loadHistoryData();
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showStatusPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Pilih Status',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ListTile(
              title: Text('Semua Status', style: GoogleFonts.inter(fontWeight: _selectedStatus == null ? FontWeight.w800 : FontWeight.w500)),
              trailing: _selectedStatus == null ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
              onTap: () {
                setState(() => _selectedStatus = null);
                Navigator.pop(context);
                _loadHistoryData();
              },
            ),
            ListTile(
              title: Text('Disetujui (Approved)', style: GoogleFonts.inter(color: const Color(0xFF16A34A), fontWeight: _selectedStatus == 'approved' ? FontWeight.w800 : FontWeight.w500)),
              trailing: _selectedStatus == 'approved' ? const Icon(Icons.check_rounded, color: Color(0xFF16A34A)) : null,
              onTap: () {
                setState(() => _selectedStatus = 'approved');
                Navigator.pop(context);
                _loadHistoryData();
              },
            ),
            ListTile(
              title: Text('Ditolak (Rejected)', style: GoogleFonts.inter(color: const Color(0xFFDC2626), fontWeight: _selectedStatus == 'rejected' ? FontWeight.w800 : FontWeight.w500)),
              trailing: _selectedStatus == 'rejected' ? const Icon(Icons.check_rounded, color: Color(0xFFDC2626)) : null,
              onTap: () {
                setState(() => _selectedStatus = 'rejected');
                Navigator.pop(context);
                _loadHistoryData();
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- MOBILE-FIRST REQUEST CARD ---
  Widget _buildMobileCard(Map<String, dynamic> item, bool isPending) {
    final tgl = item['tanggal_pengajuan'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['tanggal_pengajuan'])) : '-';
    final pemohon = _getApplicantName(item);
    final cabang = item['cabang']?['nama_cabang'] ?? '-';
    final barang = item['nama_barang'] ?? '-';
    final jenis = item['jenis_pembelian'] ?? '-';
    final merk = item['merk_spesifikasi'] ?? '-';
    final qty = '${item['jumlah']} ${item['satuan'] == 'Lainnya' ? (item['satuan_lainnya'] ?? '') : (item['satuan'] ?? 'Pcs')}';
    final urgensi = (item['tingkat_urgensi'] ?? 'Low').toString();
    final alasan = item['alasan_pengajuan'] ?? '';

    final List<String> photos = _getItemPhotos(item);
    final isChemical = jenis.toString().toLowerCase().contains('chemical');

    Color urgensiColor = const Color(0xFF16A34A);
    Color urgensiBg = const Color(0xFFDCFCE7);

    if (urgensi.toLowerCase() == 'high') {
      urgensiColor = const Color(0xFFDC2626);
      urgensiBg = const Color(0xFFFEE2E2);
    } else if (urgensi.toLowerCase() == 'medium') {
      urgensiColor = const Color(0xFFD97706);
      urgensiBg = const Color(0xFFFEF3C7);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header: Item Name, Category Avatar, and Urgency Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Icon Avatar
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isChemical ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isChemical ? Icons.science_rounded : Icons.build_rounded,
                    color: isChemical ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Sub-details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        barang,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isChemical ? const Color(0xFFDBEAFE) : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              jenis,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isChemical ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                              ),
                            ),
                          ),
                          if (merk != '-' && merk.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                merk,
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Urgency Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: urgensiBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: urgensiColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        urgensi.toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: urgensiColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Middle Key Info Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Pemohon & Cabang
                Row(
                  children: [
                    const Icon(Icons.person_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      pemohon,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                    ),
                    const SizedBox(width: 6),
                    Text('•', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cabang,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Row: Kuantitas & Tanggal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text('Jumlah Diajukan: ', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        Text(
                          qty,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          tgl,
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),

                if (alasan.isNotEmpty && alasan != '-') ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 6),
                  Text(
                    'Alasan: "$alasan"',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Foto Bukti Preview Strip
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Foto Bukti:',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: photos.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final photoUrl = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () => _openImagePreview(context, photos, idx),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SmartNetworkImage(
                                          url: photoUrl,
                                          token: _authToken,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.zoom_in_rounded, size: 10, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Bottom Action Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: isPending
                ? Row(
                    children: [
                      // View Detail Button
                      Expanded(
                        flex: 3,
                        child: OutlinedButton.icon(
                          onPressed: () => _showDetailModal(item, true),
                          icon: const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF475569)),
                          label: Text('Detail', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Reject Button
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          onPressed: () => _showDetailModal(item, true),
                          icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                          label: Text('Tolak', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFEE2E2),
                            foregroundColor: const Color(0xFFDC2626),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Approve Button
                      Expanded(
                        flex: 4,
                        child: ElevatedButton.icon(
                          onPressed: () => _showDetailModal(item, true),
                          icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                          label: Text('Setujui', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Status Badge
                      _buildStatusBadge(item['status_pengajuan']),

                      // View Detail Button
                      OutlinedButton.icon(
                        onPressed: () => _showDetailModal(item, false),
                        icon: const Icon(Icons.remove_red_eye_rounded, size: 15, color: AppColors.primary),
                        label: Text('Lihat Detail', style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color color = const Color(0xFF64748B);
    Color bg = const Color(0xFFF1F5F9);
    String label = 'PENDING';
    IconData icon = Icons.access_time_rounded;

    if (status == 'approved') {
      color = const Color(0xFF16A34A);
      bg = const Color(0xFFDCFCE7);
      label = 'DISETUJUI';
      icon = Icons.check_circle_rounded;
    } else if (status == 'rejected') {
      color = const Color(0xFFDC2626);
      bg = const Color(0xFFFEE2E2);
      label = 'DITOLAK';
      icon = Icons.cancel_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
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
              child: Icon(icon, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  void _openImagePreview(BuildContext context, List<String> photos, int initialIndex) {
    if (photos.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => _GalleryPreviewDialog(
        photos: photos,
        initialIndex: initialIndex,
        authToken: _authToken,
      ),
    );
  }
}

// ---------------------------------------------------------
// MOBILE-FIRST DETAIL BOTTOM SHEET
// ---------------------------------------------------------

class _DetailBottomSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isPending;
  final String? authToken;

  const _DetailBottomSheet({
    required this.item,
    required this.isPending,
    this.authToken,
  });

  @override
  State<_DetailBottomSheet> createState() => _DetailBottomSheetState();
}

class _DetailBottomSheetState extends State<_DetailBottomSheet> {
  final TextEditingController _catatanController = TextEditingController();
  late int _jumlahDisetujui;

  bool _isLoadingApprove = false;
  bool _isLoadingReject = false;

  @override
  void initState() {
    super.initState();
    final rawJumlah = int.tryParse(widget.item['jumlah']?.toString() ?? '1') ?? 1;
    _jumlahDisetujui = rawJumlah;
  }

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  String _getImageUrl(dynamic rawPath) {
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

  List<String> _getItemPhotos() {
    final List<String> list = [];
    for (final key in ['foto_1', 'foto_2', 'foto_3', 'foto_4', 'foto_5', 'foto_bukti', 'foto']) {
      final val = widget.item[key];
      if (val != null && val.toString().trim().isNotEmpty && val.toString() != 'null') {
        list.add(_getImageUrl(val));
      }
    }
    return list;
  }

  String _getApplicantName() {
    final pemohonObj = widget.item['pemohon'];
    if (pemohonObj is Map) {
      final name = pemohonObj['nama_lengkap'] ?? pemohonObj['nama'] ?? pemohonObj['name'] ?? pemohonObj['nama_karyawan'];
      if (name != null && name.toString().trim().isNotEmpty) return name.toString();
    }
    final directName = widget.item['pemohon_nama'] ?? widget.item['nama_pemohon'] ?? widget.item['nama_karyawan'];
    if (directName != null && directName.toString().trim().isNotEmpty) return directName.toString();
    if (pemohonObj is String && pemohonObj.trim().isNotEmpty && pemohonObj != 'null') return pemohonObj;
    return '-';
  }

  Future<void> _processApprove() async {
    if (_jumlahDisetujui < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jumlah disetujui minimal 1')));
      return;
    }

    setState(() => _isLoadingApprove = true);
    try {
      await OperasionalApprovalPengajuanService.approvePengajuan(
        id: widget.item['id'],
        jumlahDisetujui: _jumlahDisetujui,
        catatanPersetujuan: _catatanController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingApprove = false);
    }
  }

  Future<void> _processReject() async {
    if (_catatanController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Catatan wajib diisi jika menolak pengajuan'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoadingReject = true);
    try {
      await OperasionalApprovalPengajuanService.rejectPengajuan(
        id: widget.item['id'],
        catatanPersetujuan: _catatanController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingReject = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final status = item['status_pengajuan'];
    final tgl = item['tanggal_pengajuan'] != null ? DateFormat('dd MMMM yyyy').format(DateTime.parse(item['tanggal_pengajuan'])) : '-';
    final pemohon = _getApplicantName();
    final cabang = item['cabang']?['nama_cabang'] ?? '-';
    final barang = item['nama_barang'] ?? '-';
    final jenis = item['jenis_pembelian'] ?? '-';
    final merk = item['merk_spesifikasi'] ?? '-';
    final satuan = item['satuan'] == 'Lainnya' ? (item['satuan_lainnya'] ?? '') : (item['satuan'] ?? 'Pcs');
    final qty = '${item['jumlah']} $satuan';
    final urgensi = (item['tingkat_urgensi'] ?? 'Low').toString();
    final alasan = item['alasan_pengajuan'] ?? '-';

    final List<String> photos = _getItemPhotos();

    final Map<String, dynamic>? approverData = (item['disetujuiOleh'] is Map)
        ? item['disetujuiOleh']
        : (item['disetujui_oleh'] is Map ? item['disetujui_oleh'] : null);
    final String approverName = approverData?['nama_lengkap'] ?? approverData?['nama'] ?? '-';

    Color urgensiColor = const Color(0xFF16A34A);

    if (urgensi.toLowerCase() == 'high') {
      urgensiColor = const Color(0xFFDC2626);
    } else if (urgensi.toLowerCase() == 'medium') {
      urgensiColor = const Color(0xFFD97706);
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(3)),
            ),
          ),

          // Modal Top Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 14),
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
                      child: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detail Pengajuan',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                        ),
                        Text(
                          'ID #${item['id'] ?? '-'}',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                        ),
                      ],
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

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner if not pending
                  if (!widget.isPending) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: status == 'approved' ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: status == 'approved' ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                status == 'approved' ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                color: status == 'approved' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                status == 'approved' ? 'Pengajuan Disetujui' : 'Pengajuan Ditolak',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: status == 'approved' ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Diperiksa oleh $approverName pada tanggal ${item['tanggal_persetujuan'] != null ? DateFormat('dd MMMM yyyy').format(DateTime.parse(item['tanggal_persetujuan'])) : '-'}.',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155), height: 1.4),
                          ),
                          if (status == 'approved' && item['jumlah_disetujui'] != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Jumlah Disetujui: ${item['jumlah_disetujui']} $satuan',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF15803D)),
                            ),
                          ],
                          if (item['catatan_persetujuan'] != null && item['catatan_persetujuan'].toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '"${item['catatan_persetujuan']}"',
                                style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Section 1: Detail Barang
                  _buildSectionHeader('INFORMASI BARANG', Icons.category_rounded),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Nama Barang', barang, isBold: true),
                        _buildDetailRow('Kategori / Jenis', jenis),
                        _buildDetailRow('Merk / Spesifikasi', merk),
                        _buildDetailRow('Jumlah Pengajuan', qty, valueColor: AppColors.primary, isBold: true),
                        _buildDetailRow('Tingkat Urgensi', urgensi.toUpperCase(), valueColor: urgensiColor, isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Section 2: Pemohon & Lokasi
                  _buildSectionHeader('PEMOHON & CABANG', Icons.account_circle_rounded),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Nama Pemohon', pemohon, isBold: true),
                        _buildDetailRow('Cabang', cabang),
                        _buildDetailRow('Tanggal Pengajuan', tgl),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Section 3: Alasan Pengajuan
                  _buildSectionHeader('ALASAN PENGAJUAN', Icons.format_quote_rounded),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      alasan.isNotEmpty ? alasan : 'Tidak ada alasan khusus yang dicantumkan.',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155), height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Section 4: Foto Bukti
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader('FOTO BUKTI BARANG LAMA / RUSAK', Icons.photo_library_rounded),
                      if (photos.isNotEmpty)
                        Text(
                          '${photos.length} Foto (Tap Zoom)',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (photos.isNotEmpty)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: photos.asMap().entries.map((entry) {
                        final index = entry.key;
                        final photoUrl = entry.value;
                        return InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => _GalleryPreviewDialog(
                                photos: photos,
                                initialIndex: index,
                                authToken: widget.authToken,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: SmartNetworkImage(
                                      url: photoUrl,
                                      token: widget.authToken,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Center(
                        child: Text(
                          'Tidak ada foto bukti yang dilampirkan.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Section 5: Form Persetujuan jika pending
                  if (widget.isPending) ...[
                    _buildSectionHeader('KEPUTUSAN PERSETUJUAN', Icons.rate_review_rounded),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jumlah yang Disetujui',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              InkWell(
                                onTap: _jumlahDisetujui > 1
                                    ? () => setState(() => _jumlahDisetujui--)
                                    : null,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: const Icon(Icons.remove_rounded, size: 20, color: Color(0xFF1E293B)),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.primary, width: 1.5),
                                ),
                                child: Text(
                                  '$_jumlahDisetujui $satuan',
                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 14),
                              InkWell(
                                onTap: () => setState(() => _jumlahDisetujui++),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: const Icon(Icons.add_rounded, size: 20, color: Color(0xFF1E293B)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Text(
                            'Catatan Persetujuan / Alasan Penolakan',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _catatanController,
                            maxLines: 3,
                            style: GoogleFonts.inter(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Tulis pesan atau catatan untuk pemohon (Wajib diisi jika menolak)...',
                              hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.all(12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ]
                ],
              ),
            ),
          ),

          // Sticky Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -3))],
            ),
            child: widget.isPending
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoadingReject ? null : _processReject,
                          icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFDC2626)),
                          label: _isLoadingReject
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)))
                              : Text('Tolak', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626))),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFDC2626)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isLoadingApprove ? null : _processApprove,
                          icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                          label: _isLoadingApprove
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text('Setujui Pengajuan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Tutup', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF334155))),
                    ),
                  ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
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

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: valueColor ?? const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// GALLERY PREVIEW DIALOG WITH FULLSCREEN ZOOM & PAGINATION
// ---------------------------------------------------------

class _GalleryPreviewDialog extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  final String? authToken;

  const _GalleryPreviewDialog({
    required this.photos,
    this.initialIndex = 0,
    this.authToken,
  });

  @override
  State<_GalleryPreviewDialog> createState() => _GalleryPreviewDialogState();
}

class _GalleryPreviewDialogState extends State<_GalleryPreviewDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Image PageView with InteractiveViewer
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final photoUrl = widget.photos[index];
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SmartNetworkImage(
                      url: photoUrl,
                      token: widget.authToken,
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
                              'Gagal memuat gambar',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              photoUrl,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 14),
                            TextButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: photoUrl));
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
              );
            },
          ),

          // Top Header: Counter & Close Button
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.photos.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.photos.length}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                InkWell(
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
              ],
            ),
          ),

          // Previous & Next Navigation Controls for multi-image
          if (widget.photos.length > 1) ...[
            if (_currentIndex > 0)
              Positioned(
                left: 10,
                child: InkWell(
                  onTap: () => _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            if (_currentIndex < widget.photos.length - 1)
              Positioned(
                right: 10,
                child: InkWell(
                  onTap: () => _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
          ],
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

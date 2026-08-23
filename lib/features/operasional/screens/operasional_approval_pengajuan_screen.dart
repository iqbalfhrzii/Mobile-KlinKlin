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

  String _getUrgensiLabel(dynamic raw) {
    final str = (raw ?? '').toString().toLowerCase().trim();
    if (str == 'high' || str == 'tinggi') return 'Tinggi';
    if (str == 'medium' || str == 'sedang') return 'Sedang';
    return 'Rendah';
  }

  Color _getUrgensiColor(dynamic raw) {
    final str = (raw ?? '').toString().toLowerCase().trim();
    if (str == 'high' || str == 'tinggi') return const Color(0xFFDC2626);
    if (str == 'medium' || str == 'sedang') return const Color(0xFFD97706);
    return const Color(0xFF16A34A);
  }

  Color _getUrgensiBg(dynamic raw) {
    final str = (raw ?? '').toString().toLowerCase().trim();
    if (str == 'high' || str == 'tinggi') return const Color(0xFFFEE2E2);
    if (str == 'medium' || str == 'sedang') return const Color(0xFFFEF3C7);
    return const Color(0xFFDCFCE7);
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
                    if (Navigator.canPop(context)) ...[
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
                    ],
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

  int get _activeFiltersCount {
    int count = 0;
    if (_selectedCabangId != null) count++;
    if (_selectedStatus != null) count++;
    if (_startDate != null || _endDate != null) count++;
    return count;
  }

  Widget _buildMobileFilterBar() {
    final activeCount = _activeFiltersCount;
    final bool hasActiveFilters = activeCount > 0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
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
                  if (_selectedCabangId != null)
                    _buildActiveBadge(
                      label: _cabangs.firstWhere(
                        (c) => c['id'] == _selectedCabangId,
                        orElse: () => {'nama_cabang': 'Cabang'},
                      )['nama_cabang'],
                      onRemove: () {
                        setState(() => _selectedCabangId = null);
                        _loadHistoryData();
                      },
                    ),
                  if (_selectedStatus != null)
                    _buildActiveBadge(
                      label: _selectedStatus == 'approved' ? 'Disetujui' : 'Ditolak',
                      onRemove: () {
                        setState(() => _selectedStatus = null);
                        _loadHistoryData();
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
                        _loadHistoryData();
                      },
                    ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCabangId = null;
                        _selectedStatus = null;
                        _startDate = null;
                        _endDate = null;
                      });
                      _loadHistoryData();
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
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HistoryFilterBottomSheet(
        selectedCabangId: _selectedCabangId,
        selectedStatus: _selectedStatus,
        startDate: _startDate,
        endDate: _endDate,
        cabangs: _cabangs,
        onApply: (cabangId, status, start, end) {
          setState(() {
            _selectedCabangId = cabangId;
            _selectedStatus = status;
            _startDate = start;
            _endDate = end;
          });
          _loadHistoryData();
        },
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
    final rawUrgensi = (item['tingkat_urgensi'] ?? 'Low').toString();
    final urgensi = _getUrgensiLabel(rawUrgensi);
    final urgensiColor = _getUrgensiColor(rawUrgensi);
    final urgensiBg = _getUrgensiBg(rawUrgensi);
    final alasan = item['alasan_pengajuan'] ?? '';

    final List<String> photos = _getItemPhotos(item);
    final isChemical = jenis.toString().toLowerCase().contains('chemical');

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

  String _getUrgensiLabel(dynamic raw) {
    final str = (raw ?? '').toString().toLowerCase().trim();
    if (str == 'high' || str == 'tinggi') return 'Tinggi';
    if (str == 'medium' || str == 'sedang') return 'Sedang';
    return 'Rendah';
  }

  Color _getUrgensiColor(dynamic raw) {
    final str = (raw ?? '').toString().toLowerCase().trim();
    if (str == 'high' || str == 'tinggi') return const Color(0xFFDC2626);
    if (str == 'medium' || str == 'sedang') return const Color(0xFFD97706);
    return const Color(0xFF16A34A);
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
    final rawUrgensi = (item['tingkat_urgensi'] ?? 'Low').toString();
    final urgensi = _getUrgensiLabel(rawUrgensi);
    final urgensiColor = _getUrgensiColor(rawUrgensi);
    final alasan = item['alasan_pengajuan'] ?? '-';

    final List<String> photos = _getItemPhotos();

    final Map<String, dynamic>? approverData = (item['disetujuiOleh'] is Map)
        ? item['disetujuiOleh']
        : (item['disetujui_oleh'] is Map ? item['disetujui_oleh'] : null);
    final String approverName = approverData?['nama_lengkap'] ?? approverData?['nama'] ?? '-';

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
                        _buildDetailRow('Tingkat Urgensi', urgensi, valueColor: urgensiColor, isBold: true),
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

// --- COMPREHENSIVE FILTER BOTTOM SHEET (HRD STYLE) ---
class _HistoryFilterBottomSheet extends StatefulWidget {
  final int? selectedCabangId;
  final String? selectedStatus;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<dynamic> cabangs;
  final Function(int? cabangId, String? status, DateTime? start, DateTime? end) onApply;

  const _HistoryFilterBottomSheet({
    required this.selectedCabangId,
    required this.selectedStatus,
    required this.startDate,
    required this.endDate,
    required this.cabangs,
    required this.onApply,
  });

  @override
  State<_HistoryFilterBottomSheet> createState() => _HistoryFilterBottomSheetState();
}

class _HistoryFilterBottomSheetState extends State<_HistoryFilterBottomSheet> {
  int? _cabangId;
  String? _status;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
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
                          'Filter Riwayat Approval',
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
                    // --- 1. STATUS FILTER ---
                    Text(
                      'STATUS KEPUTUSAN',
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
                        _buildStatusOption(
                          label: 'Semua',
                          value: null,
                          icon: Icons.all_inclusive_rounded,
                          accentColor: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        _buildStatusOption(
                          label: 'Disetujui',
                          value: 'approved',
                          icon: Icons.check_circle_rounded,
                          accentColor: const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusOption(
                          label: 'Ditolak',
                          value: 'rejected',
                          icon: Icons.cancel_rounded,
                          accentColor: const Color(0xFFDC2626),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // --- 2. CABANG FILTER ---
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

                    // --- 3. TANGGAL FILTER ---
                    Text(
                      'RENTANG TANGGAL PENGAJUAN',
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
                              widget.onApply(_cabangId, _status, _startDate, _endDate);
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

  Widget _buildStatusOption({
    required String label,
    required String? value,
    required IconData icon,
    required Color accentColor,
  }) {
    final isSelected = _status == value;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _status = value),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? accentColor : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? accentColor : const Color(0xFF64748B)),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? accentColor : const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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

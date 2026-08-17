import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/operasional_approval_pengajuan_service.dart';

class OperasionalApprovalPengajuanScreen extends StatefulWidget {
  const OperasionalApprovalPengajuanScreen({super.key});

  @override
  State<OperasionalApprovalPengajuanScreen> createState() => _OperasionalApprovalPengajuanScreenState();
}

class _OperasionalApprovalPengajuanScreenState extends State<OperasionalApprovalPengajuanScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isLoading = false;
  List<dynamic> _cabangs = [];
  
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
    _loadCabangs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCabangs() async {
    try {
      final cabangs = await OperasionalApprovalPengajuanService.getCabangs();
      setState(() => _cabangs = cabangs);
      _loadDataForCurrentTab();
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
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadHistoryData();
    });
  }

  Future<void> _loadPendingData() async {
    setState(() => _isLoading = true);
    try {
      final data = await OperasionalApprovalPengajuanService.getPengajuan(
        status: 'pending',
      );
      setState(() {
        _pendingList = data['data'] ?? [];
      });
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
      setState(() {
        _historyList = data['data'] ?? [];
      });
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
      ),
    );
    
    // Refresh if action taken
    if (result == true) {
      _loadDataForCurrentTab();
      if (_tabController.index == 1) _loadPendingData(); // Refresh pending count in tab if on history tab
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
              onSurface: AppColors.textDark,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Approval Pengajuan Alat & Chemical',
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kelola persetujuan pengadaan barang operasional cabang.',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Menunggu Persetujuan'),
                          if (_pendingList.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(10)),
                              child: Text('${_pendingList.length}', style: GoogleFonts.inter(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
                            )
                          ]
                        ],
                      ),
                    ),
                    const Tab(text: 'Riwayat Approval'),
                  ],
                ),
              ],
            ),
          ),
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
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadPendingData,
            child: _pendingList.isEmpty
                ? _buildEmptyState('Tidak ada pengajuan yang menunggu persetujuan.')
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _pendingList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildItemCard(_pendingList[index], true);
                    },
                  ),
          );
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        _buildHistoryFilterBar(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadHistoryData,
                  child: _historyList.isEmpty
                      ? _buildEmptyState('Tidak ada riwayat persetujuan.')
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _historyList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildItemCard(_historyList[index], false);
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryFilterBar() {
    String dateRangeStr = 'Pilih Tanggal';
    if (_startDate != null && _endDate != null) {
      dateRangeStr = '${DateFormat('dd MMM yy').format(_startDate!)} - ${DateFormat('dd MMM yy').format(_endDate!)}';
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10), color: AppColors.surface),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Cari barang, pemohon...',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: _selectDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10), color: AppColors.surface),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(dateRangeStr, style: GoogleFonts.inter(fontSize: 12, color: _startDate != null ? AppColors.textDark : AppColors.textMuted, fontWeight: _startDate != null ? FontWeight.w600 : FontWeight.normal)),
                        const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
              if (_startDate != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                    _loadHistoryData();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.close, size: 16, color: Colors.red),
                  ),
                )
              ]
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10), color: AppColors.surface),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<dynamic>(
                      value: _selectedCabangId,
                      isExpanded: true,
                      hint: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600),
                      items: [
                        DropdownMenuItem(value: null, child: Text('Semua Cabang', style: GoogleFonts.inter(fontWeight: FontWeight.normal))),
                        ..._cabangs.map((c) => DropdownMenuItem(value: c['id'], child: Text(c['nama_cabang']))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedCabangId = val as int?);
                        _loadHistoryData();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10), color: AppColors.surface),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatus,
                      isExpanded: true,
                      hint: Text('Semua Status', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600),
                      items: [
                        DropdownMenuItem(value: null, child: Text('Semua Status', style: GoogleFonts.inter(fontWeight: FontWeight.normal))),
                        DropdownMenuItem(value: 'approved', child: Text('Approved', style: GoogleFonts.inter(color: Colors.green))),
                        DropdownMenuItem(value: 'rejected', child: Text('Rejected', style: GoogleFonts.inter(color: Colors.red))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedStatus = val);
                        _loadHistoryData();
                      },
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, bool isPending) {
    final tgl = item['tanggal_pengajuan'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['tanggal_pengajuan'])) : '-';
    final pemohon = item['pemohon']?['nama_lengkap'] ?? '-';
    final cabang = item['cabang']?['nama_cabang'] ?? '-';
    final barang = item['nama_barang'] ?? '-';
    final jenis = item['jenis_pembelian'] ?? '-';
    final merk = item['merk_spesifikasi'] ?? '-';
    final qty = '${item['jumlah']} ${item['satuan'] == 'Lainnya' ? item['satuan_lainnya'] : item['satuan']}';
    final urgensi = item['tingkat_urgensi'] ?? '-';
    
    final Map<String, dynamic>? approverData = (item['disetujuiOleh'] is Map) 
        ? item['disetujuiOleh'] 
        : (item['disetujui_oleh'] is Map ? item['disetujui_oleh'] : null);
    final String approverName = approverData?['nama_lengkap'] ?? '-';

    Color urgensiColor = Colors.grey;
    if (urgensi == 'Low') urgensiColor = Colors.green;
    if (urgensi == 'Medium') urgensiColor = Colors.orange;
    if (urgensi == 'High') urgensiColor = Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tgl, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const SizedBox(height: 4),
                      Text(cabang, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                      if (isPending) ...[
                        const SizedBox(height: 6),
                        Text('Pemohon: $pemohon', style: GoogleFonts.inter(fontSize: 11, color: AppColors.primary)),
                      ]
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(barang, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('$jenis  ', style: GoogleFonts.inter(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                          Expanded(child: Text(merk, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(qty, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: urgensiColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text('URGENSI: ${urgensi.toUpperCase()}', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: urgensiColor)),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!isPending) ...[
                  Row(
                    children: [
                      _buildStatusBadge(item['status_pengajuan']),
                      const SizedBox(width: 8),
                      if (item['status_pengajuan'] == 'approved' && item['jumlah_disetujui'] != null)
                        Text('ACC: ${item['jumlah_disetujui']}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                      if (approverName != '-' && item['tanggal_persetujuan'] != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$approverName • ${DateFormat('dd MMM yy').format(DateTime.parse(item['tanggal_persetujuan']))}', 
                            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      const Icon(Icons.image_outlined, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('Foto Bukti', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ],
                Row(
                  children: [
                    if (!isPending) ...[
                      OutlinedButton.icon(
                        onPressed: () => _showDetailModal(item, false),
                        icon: const Icon(Icons.remove_red_eye, size: 16, color: AppColors.primary),
                        label: Text('Detail', style: GoogleFonts.inter(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                    ] else ...[
                      IconButton(
                        onPressed: () => _showDetailModal(item, true),
                        icon: const Icon(Icons.remove_red_eye, color: AppColors.textMuted),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showDetailModal(item, true),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.check, size: 18, color: Colors.green),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showDetailModal(item, true),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.close, size: 18, color: Colors.red),
                        ),
                      ),
                    ]
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    String label = 'PENDING';
    if (status == 'approved') {
      color = Colors.green;
      label = 'APPROVED';
    } else if (status == 'rejected') {
      color = Colors.red;
      label = 'REJECTED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

// ---------------------------------------------------------
// Bottom Sheet untuk Detail Pengajuan & Eksekusi Aksi
// ---------------------------------------------------------

class _DetailBottomSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isPending;

  const _DetailBottomSheet({
    required this.item,
    required this.isPending,
  });

  @override
  State<_DetailBottomSheet> createState() => _DetailBottomSheetState();
}

class _DetailBottomSheetState extends State<_DetailBottomSheet> {
  final TextEditingController _catatanController = TextEditingController();
  final TextEditingController _jumlahController = TextEditingController();
  
  bool _isLoadingApprove = false;
  bool _isLoadingReject = false;

  @override
  void initState() {
    super.initState();
    _jumlahController.text = widget.item['jumlah']?.toString() ?? '1';
  }

  @override
  void dispose() {
    _catatanController.dispose();
    _jumlahController.dispose();
    super.dispose();
  }

  Future<void> _processApprove() async {
    final qty = int.tryParse(_jumlahController.text);
    if (qty == null || qty < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jumlah disetujui tidak valid')));
      return;
    }

    setState(() => _isLoadingApprove = true);
    try {
      await OperasionalApprovalPengajuanService.approvePengajuan(
        id: widget.item['id'],
        jumlahDisetujui: qty,
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Catatan wajib diisi jika menolak')));
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
    final tgl = item['tanggal_pengajuan'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['tanggal_pengajuan'])) : '-';
    final pemohon = item['pemohon']?['nama_lengkap'] ?? '-';
    final cabang = item['cabang']?['nama_cabang'] ?? '-';
    final barang = item['nama_barang'] ?? '-';
    final jenis = item['jenis_pembelian'] ?? '-';
    final merk = item['merk_spesifikasi'] ?? '-';
    final qty = '${item['jumlah']} ${item['satuan'] == 'Lainnya' ? item['satuan_lainnya'] : item['satuan']}';
    final urgensi = item['tingkat_urgensi'] ?? '-';
    final alasan = item['alasan_pengajuan'] ?? '-';
    final foto1 = item['foto_1'];

    final Map<String, dynamic>? approverData = (item['disetujuiOleh'] is Map) 
        ? item['disetujuiOleh'] 
        : (item['disetujui_oleh'] is Map ? item['disetujui_oleh'] : null);
    final String approverName = approverData?['nama_lengkap'] ?? '-';

    Color urgensiColor = Colors.grey;
    if (urgensi == 'Low') urgensiColor = Colors.green;
    if (urgensi == 'Medium') urgensiColor = Colors.orange;
    if (urgensi == 'High') urgensiColor = Colors.red;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text('Detail Pengajuan Barang', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.isPending) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: status == 'approved' ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: status == 'approved' ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(status == 'approved' ? Icons.check_circle_outline : Icons.cancel_outlined, color: status == 'approved' ? Colors.green : Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Text(status == 'approved' ? 'Pengajuan Approved' : 'Pengajuan Rejected', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: status == 'approved' ? Colors.green : Colors.red)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Diperiksa oleh $approverName pada tanggal ${item['tanggal_persetujuan'] != null ? DateFormat('dd MMMM yyyy').format(DateTime.parse(item['tanggal_persetujuan'])) : '-'}.',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark),
                          ),
                          if (item['catatan_persetujuan'] != null) ...[
                            const SizedBox(height: 8),
                            Text('"${item['catatan_persetujuan']}"', style: GoogleFonts.inter(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.textDark)),
                          ]
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('INFORMASI PEMOHON', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(pemohon, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                            Text('$cabang • $tgl', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('KUANTITAS & URGENSI', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(qty, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: urgensiColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                  child: Text('URGENSI: ${urgensi.toUpperCase()}', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: urgensiColor)),
                                ),
                              ],
                            ),
                            if (!widget.isPending && status == 'approved' && item['jumlah_disetujui'] != null) ...[
                              const SizedBox(height: 4),
                              Text('Jumlah Disetujui: ${item['jumlah_disetujui']}', style: GoogleFonts.inter(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                            ]
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('INFORMASI BARANG', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(barang, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                            Text('Merk/Spek: $merk', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                            Text('Jenis: $jenis', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ALASAN PENGAJUAN', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(alasan, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark)),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 16),
                  Text('FOTO BUKTI BARANG LAMA / RUSAK', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPhotoThumbnail(foto1),
                      _buildPhotoThumbnail(item['foto_2']),
                      _buildPhotoThumbnail(item['foto_3']),
                      _buildPhotoThumbnail(item['foto_4']),
                      _buildPhotoThumbnail(item['foto_5']),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  if (widget.isPending) ...[
                    Text('FORM PERSETUJUAN', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Jumlah Disetujui', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _jumlahController,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.inter(fontSize: 14),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Catatan', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _catatanController,
                                style: GoogleFonts.inter(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Tulis pesan/alasan...',
                                  hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 24),
                  ]
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: Row(
              children: [
                if (widget.isPending) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoadingReject ? null : _processReject,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoadingReject
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                          : Text('Tolak', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoadingApprove ? null : _processApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: _isLoadingApprove
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Setujui Pengajuan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Tutup', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    ),
                  )
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail(String? path) {
    if (path == null || path.isEmpty) return const SizedBox.shrink();
    
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          'http://erp.klinklin.online/storage/$path', 
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.grey),
        ),
      ),
    );
  }
}

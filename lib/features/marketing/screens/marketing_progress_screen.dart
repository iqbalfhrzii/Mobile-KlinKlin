import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/marketing_service.dart';

class MarketingProgressScreen extends StatefulWidget {
  const MarketingProgressScreen({super.key});

  @override
  State<MarketingProgressScreen> createState() => _MarketingProgressScreenState();
}

class _MarketingProgressScreenState extends State<MarketingProgressScreen> {
  final MarketingService _service = MarketingService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = true;
  int _selectedYear = DateTime.now().year;
  String _selectedStatus = 'all'; // 'all', 'Belum Tercapai', 'Tercapai'

  List<dynamic> _progressList = [];

  final List<int> _availableYears = [
    DateTime.now().year + 1,
    DateTime.now().year,
    DateTime.now().year - 1,
    DateTime.now().year - 2,
  ];

  @override
  void initState() {
    super.initState();
    _fetchProgress();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchProgress();
    });
  }

  Future<void> _fetchProgress() async {
    setState(() => _isLoading = true);
    try {
      final res = await _service.fetchProgress(
        tahun: _selectedYear,
        search: _searchController.text.trim(),
        status: _selectedStatus == 'all' ? null : _selectedStatus,
      );

      if (res['status'] == true && res['data'] != null) {
        final data = res['data'];
        List<dynamic> list = [];
        if (data is Map && data['data'] != null) {
          list = data['data'];
        } else if (data is List) {
          list = data;
        }

        if (mounted) {
          setState(() {
            _progressList = list;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openProgressModal({dynamic item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProgressFormModalSheet(
        item: item,
        initialYear: _selectedYear,
        onSuccess: _fetchProgress,
      ),
    );
  }

  Future<void> _confirmDelete(dynamic item) async {
    final id = item['id'];
    final name = item['nama_target'] ?? 'Target';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Progres Marketing?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Yakin ingin menghapus target "$name"?', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _service.deleteProgress(id);
      if (mounted) {
        if (res['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Target progress berhasil dihapus'), backgroundColor: Color(0xFF059669)),
          );
          _fetchProgress();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Gagal menghapus target'), backgroundColor: const Color(0xFFDC2626)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int totalCount = _progressList.length;
    final int achievedCount = _progressList.where((p) => (p['status'] ?? '').toString().toLowerCase() == 'tercapai').length;
    final int inProgressCount = _progressList.where((p) => (p['status'] ?? '').toString().toLowerCase().contains('proses')).length;
    final int pendingCount = _progressList.where((p) => (p['status'] ?? '').toString().toLowerCase().contains('belum')).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProgressModal(),
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_task_rounded, size: 20),
        label: Text('Tambah Progres', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProgress,
        color: AppColors.primaryMid,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. GRADIENT HEADER WITH METRICS
            SliverToBoxAdapter(
              child: GradientHeader(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Data Progress Marketing',
                                style: GoogleFonts.inter(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pantau target bulanan & tahunan tim marketing.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _openProgressModal(),
                          icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 24),
                          tooltip: 'Tambah Target',
                        ),
                        IconButton(
                          onPressed: _fetchProgress,
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                          tooltip: 'Muat Ulang',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Metrics Strip
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Total',
                            count: totalCount.toString(),
                            color: Colors.white,
                            bgColor: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Tercapai',
                            count: achievedCount.toString(),
                            color: const Color(0xFFA7F3D0),
                            bgColor: const Color(0xFF059669).withValues(alpha: 0.35),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Proses',
                            count: inProgressCount.toString(),
                            color: const Color(0xFFBFDBFE),
                            bgColor: const Color(0xFF2563EB).withValues(alpha: 0.35),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Belum',
                            count: pendingCount.toString(),
                            color: const Color(0xFFFDE68A),
                            bgColor: const Color(0xFFD97706).withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 2. MAIN CONTENT & FILTERS
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Filter Bar
                  _buildFilterBar(),
                  const SizedBox(height: 14),

                  // Progress Cards
                  if (_isLoading)
                    _buildLoadingList()
                  else if (_progressList.isEmpty)
                    _buildEmptyState()
                  else
                    ..._progressList.map((item) => _buildProgressCard(item)),

                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String count,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  // ================= FILTER BAR =================
  Widget _buildFilterBar() {
    return Column(
      children: [
        Row(
          children: [
            // Search Input
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Cari nama target / goal...',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                            onPressed: () {
                              _searchController.clear();
                              _fetchProgress();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Tahun Dropdown
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedYear,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  items: _availableYears.map((y) {
                    return DropdownMenuItem<int>(value: y, child: Text(y.toString()));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedYear = val);
                      _fetchProgress();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Status Choice Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatusChip('all', 'Semua Status'),
              const SizedBox(width: 8),
              _buildStatusChip('Belum Tercapai', 'Belum Tercapai'),
              const SizedBox(width: 8),
              _buildStatusChip('Dalam Proses', 'Dalam Proses'),
              const SizedBox(width: 8),
              _buildStatusChip('Tercapai', 'Tercapai'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String key, String label) {
    final isSelected = _selectedStatus == key;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF059669),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0)),
      ),
      showCheckmark: false,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedStatus = key);
          _fetchProgress();
        }
      },
    );
  }

  // ================= PROGRESS CARD =================
  Widget _buildProgressCard(dynamic item) {
    final String tahun = (item['tahun'] ?? '').toString();
    final String namaTarget = item['nama_target'] ?? '-';
    final String target = item['target'] ?? '-';
    final String capaian = item['capaian_saat_ini'] ?? item['capaian'] ?? '-';
    final String status = item['status'] ?? 'Belum Tercapai';
    final String? keterangan = item['keterangan']?.toString();

    final statusLower = status.toLowerCase();
    final bool isTercapai = statusLower == 'tercapai';
    final bool isDalamProses = statusLower.contains('proses');

    Color badgeBg = const Color(0xFFFEF3C7);
    Color badgeBorder = const Color(0xFFFDE68A);
    Color badgeText = const Color(0xFFD97706);
    IconData badgeIcon = Icons.access_time_rounded;

    if (isTercapai) {
      badgeBg = const Color(0xFFECFDF5);
      badgeBorder = const Color(0xFFA7F3D0);
      badgeText = const Color(0xFF059669);
      badgeIcon = Icons.check_circle_rounded;
    } else if (isDalamProses) {
      badgeBg = const Color(0xFFEFF6FF);
      badgeBorder = const Color(0xFFBFDBFE);
      badgeText = const Color(0xFF2563EB);
      badgeIcon = Icons.sync_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card (Tahun, Nama, Status)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    tahun,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        namaTarget,
                        style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      if (keterangan != null && keterangan.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          keterangan,
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        badgeIcon,
                        size: 12,
                        color: badgeText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: badgeText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Body (Target vs Capaian Grid)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Target / Goal Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.flag_rounded, size: 13, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text('Target / Goal:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(target, style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF334155), height: 1.3)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Capaian Saat Ini Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isTercapai ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isTercapai ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isTercapai ? Icons.check_circle_outline_rounded : Icons.trending_up_rounded,
                            size: 13,
                            color: isTercapai ? const Color(0xFF059669) : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Capaian Saat Ini:',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isTercapai ? const Color(0xFF059669) : const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(capaian, style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF334155), height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Footer Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openProgressModal(item: item),
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _confirmDelete(item),
                  icon: const Icon(Icons.delete_outline_rounded, size: 14),
                  label: const Text('Hapus'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingList() {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          height: 120,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.analytics_outlined, size: 36, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          Text(
            'Belum Ada Progres Target',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            'Belum ada data target marketing yang tercatat untuk tahun ini.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

// ================= MODAL TAMBAH / EDIT PROGRESS =================
class _ProgressFormModalSheet extends StatefulWidget {
  final dynamic item;
  final int initialYear;
  final VoidCallback onSuccess;

  const _ProgressFormModalSheet({
    this.item,
    required this.initialYear,
    required this.onSuccess,
  });

  @override
  State<_ProgressFormModalSheet> createState() => _ProgressFormModalSheetState();
}

class _ProgressFormModalSheetState extends State<_ProgressFormModalSheet> {
  final MarketingService _service = MarketingService();

  late TextEditingController _yearController;
  final _namaTargetController = TextEditingController();
  final _targetController = TextEditingController();
  final _capaianController = TextEditingController();
  final _keteranganController = TextEditingController();

  String _selectedStatus = 'Belum Tercapai';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _yearController = TextEditingController(text: widget.initialYear.toString());

    if (widget.item != null) {
      _yearController.text = (widget.item['tahun'] ?? widget.initialYear).toString();
      _namaTargetController.text = (widget.item['nama_target'] ?? '').toString();
      _targetController.text = (widget.item['target'] ?? '').toString();
      _capaianController.text = (widget.item['capaian_saat_ini'] ?? '').toString();
      _keteranganController.text = (widget.item['keterangan'] ?? '').toString();
      _selectedStatus = (widget.item['status'] ?? 'Belum Tercapai').toString();
    }
  }

  @override
  void dispose() {
    _yearController.dispose();
    _namaTargetController.dispose();
    _targetController.dispose();
    _capaianController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _submitData() async {
    final year = int.tryParse(_yearController.text.trim());
    final nama = _namaTargetController.text.trim();
    final target = _targetController.text.trim();

    if (year == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tahun wajib diisi!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (nama.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama target wajib diisi!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Target / goal wajib diisi!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    final payload = {
      'tahun': year,
      'nama_target': nama,
      'target': target,
      'capaian_saat_ini': _capaianController.text.trim(),
      'status': _selectedStatus,
      'keterangan': _keteranganController.text.trim(),
    };

    Map<String, dynamic> res;
    if (widget.item != null) {
      res = await _service.updateProgress(widget.item['id'], payload);
    } else {
      res = await _service.storeProgress(payload);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (res['status'] == true) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.item != null ? 'Progres target berhasil diperbarui' : 'Progres target berhasil ditambahkan'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal menyimpan target'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),

            // Header Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.trending_up_rounded, color: Color(0xFF059669), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEdit ? 'Edit Progress' : 'Tambah Progress',
                      style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 14),

            // Row: Tahun & Nama Target
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tahun *', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _yearController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: '2026',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nama Target *', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _namaTargetController,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Contoh: Leads Cabang Surabaya',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Target / Goal Textarea
            Text('Target / Goal *', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            TextField(
              controller: _targetController,
              maxLines: 2,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Deskripsikan target / sasaran yang ingin dicapai...',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 14),

            // Capaian Saat Ini Textarea
            Text('Capaian Saat Ini', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            TextField(
              controller: _capaianController,
              maxLines: 2,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Progres / hasil yang sudah diperoleh saat ini...',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 14),

            // Status Selector (3 Segmented Tab Buttons)
            Text('Status *', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedStatus = 'Belum Tercapai'),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                      decoration: BoxDecoration(
                        color: _selectedStatus == 'Belum Tercapai'
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedStatus == 'Belum Tercapai'
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFFE2E8F0),
                          width: _selectedStatus == 'Belum Tercapai' ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: _selectedStatus == 'Belum Tercapai'
                                ? const Color(0xFFD97706)
                                : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Belum',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: _selectedStatus == 'Belum Tercapai' ? FontWeight.bold : FontWeight.w500,
                              color: _selectedStatus == 'Belum Tercapai'
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedStatus = 'Dalam Proses'),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                      decoration: BoxDecoration(
                        color: _selectedStatus == 'Dalam Proses'
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedStatus == 'Dalam Proses'
                              ? const Color(0xFFBFDBFE)
                              : const Color(0xFFE2E8F0),
                          width: _selectedStatus == 'Dalam Proses' ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sync_rounded,
                            size: 13,
                            color: _selectedStatus == 'Dalam Proses'
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Proses',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: _selectedStatus == 'Dalam Proses' ? FontWeight.bold : FontWeight.w500,
                              color: _selectedStatus == 'Dalam Proses'
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedStatus = 'Tercapai'),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                      decoration: BoxDecoration(
                        color: _selectedStatus == 'Tercapai'
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedStatus == 'Tercapai'
                              ? const Color(0xFFA7F3D0)
                              : const Color(0xFFE2E8F0),
                          width: _selectedStatus == 'Tercapai' ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 13,
                            color: _selectedStatus == 'Tercapai'
                                ? const Color(0xFF059669)
                                : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tercapai',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: _selectedStatus == 'Tercapai' ? FontWeight.bold : FontWeight.w500,
                              color: _selectedStatus == 'Tercapai'
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Keterangan Tambahan
            Text('Keterangan Tambahan', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            TextField(
              controller: _keteranganController,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Opsional, misal: Perlu follow up tim cabang',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),

            // Actions (Batal & Simpan)
            if (_isSaving)
              const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
            else
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Batal', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: _submitData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Simpan Data', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

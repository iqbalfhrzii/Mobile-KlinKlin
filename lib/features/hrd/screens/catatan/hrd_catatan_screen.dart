import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import '../../services/hrd_catatan_service.dart';
import 'hrd_catatan_form_sheet.dart';

class HrdCatatanScreen extends StatefulWidget {
  final int initialTab;
  final int? preselectedKaryawanId;

  const HrdCatatanScreen({
    super.key,
    this.initialTab = 0,
    this.preselectedKaryawanId,
  });

  @override
  State<HrdCatatanScreen> createState() => _HrdCatatanScreenState();
}

class _HrdCatatanScreenState extends State<HrdCatatanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final HrdCatatanService _catatanService = HrdCatatanService();
  final HrdService _hrdService = HrdService();

  final TextEditingController _searchCtrl = TextEditingController();
  dynamic _selectedCabangId = 'all';

  List<CabangModel> _cabangs = [];
  

  // Data per tab: 0: komplain, 1: sakit, 2: individu
  final Map<int, List<CatatanHrdModel>> _items = {0: [], 1: [], 2: []};
  final Map<int, bool> _isLoading = {0: true, 1: true, 2: true};
  final Map<int, int> _total = {0: 0, 1: 0, 2: 0};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final idx = _tabController.index;
        if (_items[idx]!.isEmpty) {
          _fetchData(idx);
        }
      }
    });

    _loadCabangs();
    _fetchData(_tabController.index);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCabangs() async {
    try {
      final res = await _hrdService.fetchCabang();
      if (mounted) {
        setState(() {
          _cabangs = res;
          
        });
      }
    } catch (_) {
      // loaded
    }
  }

  String _getJenisByIndex(int index) {
    switch (index) {
      case 0:
        return 'komplain';
      case 1:
        return 'sakit';
      case 2:
      default:
        return 'individu';
    }
  }

  Future<void> _fetchData(int tabIndex) async {
    setState(() => _isLoading[tabIndex] = true);
    try {
      final res = await _catatanService.fetchCatatan(
        jenis: _getJenisByIndex(tabIndex),
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        cabangId: _selectedCabangId == 'all' ? null : _selectedCabangId,
        karyawanId: widget.preselectedKaryawanId,
      );

      if (mounted) {
        setState(() {
          _items[tabIndex] = res['items'] as List<CatatanHrdModel>;
          _total[tabIndex] = res['total'] as int;
          _isLoading[tabIndex] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading[tabIndex] = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat catatan: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _refreshCurrent() {
    _fetchData(_tabController.index);
  }

  void _openAddSheet() async {
    final currentJenis = _getJenisByIndex(_tabController.index);
    final res = await HrdCatatanFormSheet.show(
      context,
      initialJenis: currentJenis,
      preselectedKaryawanId: widget.preselectedKaryawanId,
    );
    if (res == true) {
      _refreshCurrent();
    }
  }

  void _openEditSheet(CatatanHrdModel item) async {
    final res = await HrdCatatanFormSheet.show(
      context,
      catatan: item,
    );
    if (res == true) {
      _refreshCurrent();
    }
  }

  Future<void> _confirmDelete(CatatanHrdModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
            const SizedBox(width: 8),
            Text(
              'Hapus Catatan?',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus catatan ${_getJenisLabel(item.jenis).toLowerCase()} ini? Tindakan ini tidak dapat dibatalkan.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Hapus', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _catatanService.deleteCatatan(item.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Catatan berhasil dihapus'),
              backgroundColor: const Color(0xFF15803D),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          _refreshCurrent();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  void _showDetailSheet(CatatanHrdModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CatatanDetailSheet(
        item: item,
        onEdit: () {
          Navigator.pop(ctx);
          _openEditSheet(item);
        },
        onDelete: () {
          Navigator.pop(ctx);
          _confirmDelete(item);
        },
      ),
    );
  }

  String _getJenisLabel(String j) {
    switch (j.toLowerCase()) {
      case 'komplain':
        return 'Komplain';
      case 'sakit':
        return 'Sakit';
      case 'individu':
      default:
        return 'Individu';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // 1. Header with Gradient
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Evaluasi & Rekam Jejak',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Catatan SDM HRD',
                            style: GoogleFonts.inter(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: _openAddSheet,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Tambah',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2. Search & Cabang Filters
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white),
                          cursorColor: Colors.white,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _refreshCurrent(),
                          decoration: InputDecoration(
                            hintText: 'Cari cleaner/ket...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                            prefixIcon: const Icon(Icons.search_rounded, color: Colors.white, size: 18),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchCtrl.clear();
                                      _refreshCurrent();
                                    },
                                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 9),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<dynamic>(
                            value: _selectedCabangId,
                            dropdownColor: AppColors.primary,
                            icon: const Icon(Icons.filter_list_rounded, color: Colors.white, size: 18),
                            isExpanded: true,
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('Semua Cabang', overflow: TextOverflow.ellipsis),
                              ),
                              ..._cabangs.map((c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.namaCabang, overflow: TextOverflow.ellipsis),
                                  )),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedCabangId = val);
                              _refreshCurrent();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3. Tab Bar
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.white.withValues(alpha: 0.8),
                    labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                    unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.report_problem_rounded, size: 15),
                            SizedBox(width: 5),
                            Text('Komplain'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.healing_rounded, size: 15),
                            SizedBox(width: 5),
                            Text('Sakit'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_ind_rounded, size: 15),
                            SizedBox(width: 5),
                            Text('Individu'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 4. Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabContent(0, 'komplain'),
                _buildTabContent(1, 'sakit'),
                _buildTabContent(2, 'individu'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            final idx = _tabController.index;
            return Text(
              'Tambah ${_getJenisLabel(_getJenisByIndex(idx))}',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabContent(int tabIndex, String jenis) {
    final loading = _isLoading[tabIndex] ?? false;
    final items = _items[tabIndex] ?? [];

    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchData(tabIndex),
      color: AppColors.primary,
      child: items.isEmpty
          ? _buildEmptyState(jenis)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildCatatanCard(item);
              },
            ),
    );
  }

  Widget _buildEmptyState(String jenis) {
    IconData icon;
    String title;
    String desc;
    switch (jenis) {
      case 'komplain':
        icon = Icons.sentiment_satisfied_alt_rounded;
        title = 'Belum Ada Komplain';
        desc = 'Kinerja cleaner prima! Belum ada catatan komplain yang tercatat.';
        break;
      case 'sakit':
        icon = Icons.health_and_safety_rounded;
        title = 'Belum Ada Catatan Sakit';
        desc = 'Seluruh cleaner dalam kondisi sehat dan siap bertugas.';
        break;
      case 'individu':
      default:
        icon = Icons.assignment_outlined;
        title = 'Belum Ada Catatan Individu';
        desc = 'Belum ada catatan khusus mengenai perilaku atau evaluasi cleaner.';
        break;
    }

    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, size: 52, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  desc,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _openAddSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'Buat Catatan Baru',
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCatatanCard(CatatanHrdModel item) {
    Color badgeColor;
    Color badgeBg;
    IconData badgeIcon;

    switch (item.jenis.toLowerCase()) {
      case 'komplain':
        badgeColor = const Color(0xFFE11D48);
        badgeBg = const Color(0xFFFFE4E6);
        badgeIcon = Icons.report_problem_rounded;
        break;
      case 'sakit':
        badgeColor = const Color(0xFF0D9488);
        badgeBg = const Color(0xFFCCFBF1);
        badgeIcon = Icons.healing_rounded;
        break;
      case 'individu':
      default:
        badgeColor = const Color(0xFF6366F1);
        badgeBg = const Color(0xFFEEF2FF);
        badgeIcon = Icons.assignment_ind_rounded;
        break;
    }

    final cleanerName = item.karyawan?.nama ?? 'Cleaner #${item.karyawanId}';
    final cabangName = item.karyawan?.cabang?.namaCabang ?? 'Cabang';
    final formattedDate = DateFormat('dd MMM yyyy').format(item.tanggal);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showDetailSheet(item),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card: Cleaner name + Badges + Menu button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: badgeBg,
                    child: Icon(badgeIcon, color: badgeColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cleanerName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              cabangName,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('•', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10)),
                            const SizedBox(width: 6),
                            Text(
                              formattedDate,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8), size: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) {
                      if (val == 'edit') {
                        _openEditSheet(item);
                      } else if (val == 'delete') {
                        _confirmDelete(item);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Text('Edit', style: GoogleFonts.inter(fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                            const SizedBox(width: 8),
                            Text('Hapus', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFDC2626))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),

              // Specific badge row
              if (item.jenis == 'komplain' && item.pelanggan != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFE4E6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFFE11D48)),
                      const SizedBox(width: 4),
                      Text(
                        'Customer: ${item.pelanggan!.namaPelanggan}',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFBE123C),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (item.jenis == 'sakit') ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: item.pengajuanIzinCutiId != null ? const Color(0xFFF0FDFA) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: item.pengajuanIzinCutiId != null ? const Color(0xFFCCFBF1) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.pengajuanIzinCutiId != null ? Icons.link_rounded : Icons.edit_note_rounded,
                        size: 13,
                        color: item.pengajuanIzinCutiId != null ? const Color(0xFF0D9488) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.pengajuanIzinCutiId != null ? 'Terkait Pengajuan Izin Sakit' : 'Input Sakit Manual HRD',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: item.pengajuanIzinCutiId != null ? const Color(0xFF0F766E) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Keterangan preview
              Text(
                item.keterangan,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF334155),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              // Tindakan (if komplain and available)
              if (item.tindakan != null && item.tindakan!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDCFCE7)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 15, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Tindakan: ${item.tindakan}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF15803D),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CatatanDetailSheet extends StatelessWidget {
  final CatatanHrdModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CatatanDetailSheet({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Color themeColor;
    IconData themeIcon;
    switch (item.jenis.toLowerCase()) {
      case 'komplain':
        themeColor = const Color(0xFFE11D48);
        themeIcon = Icons.report_problem_rounded;
        break;
      case 'sakit':
        themeColor = const Color(0xFF0D9488);
        themeIcon = Icons.healing_rounded;
        break;
      case 'individu':
      default:
        themeColor = const Color(0xFF6366F1);
        themeIcon = Icons.assignment_ind_rounded;
        break;
    }

    final cleanerName = item.karyawan?.nama ?? 'Cleaner #${item.karyawanId}';
    final cabangName = item.karyawan?.cabang?.namaCabang ?? '-';
    final jabatanName = item.karyawan?.jabatan?.namaJabatan ?? 'Cleaner';
    final formattedDate = DateFormat('EEEE, dd MMMM yyyy').format(item.tanggal);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle pill
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header with Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(themeIcon, color: themeColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detail Catatan ${item.jenis.toUpperCase()}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          Expanded(
            child: ListView(
              children: [
                // Info Cleaner Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cleanerName,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$jabatanName • $cabangName',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Komplain: Customer Info
                if (item.jenis == 'komplain' && item.pelanggan != null) ...[
                  _buildSectionLabel('Customer / Pelanggan'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFE4E6)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_rounded, size: 20, color: Color(0xFFE11D48)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.pelanggan!.namaPelanggan,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF9F1239),
                                ),
                              ),
                              if (item.pelanggan!.noWa != null && item.pelanggan!.noWa!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.pelanggan!.noWa!,
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFBE123C)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Sakit: Status Tautan
                if (item.jenis == 'sakit') ...[
                  _buildSectionLabel('Status Tautan Sakit'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCCFBF1)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.pengajuanIzinCutiId != null ? Icons.link_rounded : Icons.edit_note_rounded,
                          color: const Color(0xFF0D9488),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.pengajuanIzinCutiId != null
                                ? 'Terhubung dengan Pengajuan Izin Cuti #${item.pengajuanIzinCutiId}'
                                : 'Dicatat manual oleh HRD (tanpa pengajuan cuti)',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F766E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Keterangan
                _buildSectionLabel(
                  item.jenis == 'komplain'
                      ? 'Keterangan Komplain'
                      : item.jenis == 'sakit'
                          ? 'Keterangan Sakit'
                          : 'Catatan Individu',
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    item.keterangan,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF1E293B),
                      height: 1.5,
                    ),
                  ),
                ),

                // Tindakan (if komplain)
                if (item.jenis == 'komplain' && item.tindakan != null && item.tindakan!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildSectionLabel('Tindakan / Solusi HRD'),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDCFCE7)),
                    ),
                    child: Text(
                      item.tindakan!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF15803D),
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),

          // Bottom Buttons: Edit & Hapus
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text('Hapus', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: Text('Edit Catatan', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF64748B),
      ),
    );
  }
}

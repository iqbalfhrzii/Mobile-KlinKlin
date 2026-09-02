import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'layanan_form_sheet.dart';

class LayananListScreen extends StatefulWidget {
  const LayananListScreen({super.key});

  @override
  State<LayananListScreen> createState() => _LayananListScreenState();
}

class _LayananListScreenState extends State<LayananListScreen> {
  final HrdService _hrdService = HrdService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String _error = '';
  List<LayananModel> _layanans = [];
  List<CabangModel> _cabangs = [];
  String _searchQuery = '';
  int? _selectedCabangId;
  String _selectedStatus = ''; // '' (semua), 'aktif', 'nonaktif'

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final futures = await Future.wait([
        _hrdService.fetchLayanan(),
        _hrdService.fetchCabang(),
      ]);

      if (mounted) {
        setState(() {
          _layanans = futures[0] as List<LayananModel>;
          _cabangs = futures[1] as List<CabangModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openFormModal({LayananModel? layanan}) async {
    final res = await LayananFormSheet.show(
      context,
      layanan: layanan,
      cabangs: _cabangs,
    );
    if (res == true) {
      _fetchData();
    }
  }

  Future<void> _delete(LayananModel layanan) async {
    final confirm = await AppConfirmationDialog.show(
      context,
      title: 'Hapus Layanan',
      message: 'Apakah Anda yakin ingin menghapus layanan "${layanan.namaLayanan}"?',
      type: ConfirmationDialogType.danger,
      customIcon: Icons.delete_forever_rounded,
      confirmText: 'Ya, Hapus',
      cancelText: 'Batal',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await _hrdService.deleteLayanan(layanan.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Layanan "${layanan.namaLayanan}" berhasil dihapus'),
              backgroundColor: const Color(0xFF475569),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        _fetchData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus layanan: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  Map<String, dynamic> _getLayananVisual(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('pindah') || lower.contains('angkut') || lower.contains('buang')) {
      return {
        'icon': Icons.local_shipping_rounded,
        'color': const Color(0xFFD97706),
        'bgColor': const Color(0xFFFEF3C7),
      };
    } else if (lower.contains('deep') || lower.contains('bersih')) {
      return {
        'icon': Icons.auto_awesome_rounded,
        'color': const Color(0xFF0284C7),
        'bgColor': const Color(0xFFE0F2FE),
      };
    } else if (lower.contains('kasur') || lower.contains('sofa') || lower.contains('salon')) {
      return {
        'icon': Icons.chair_rounded,
        'color': const Color(0xFF6366F1),
        'bgColor': const Color(0xFFEEF2FF),
      };
    } else if (lower.contains('rumah') || lower.contains('kantor') || lower.contains('ruko') || lower.contains('apartemen') || lower.contains('kos') || lower.contains('gc')) {
      return {
        'icon': Icons.home_work_rounded,
        'color': const Color(0xFF059669),
        'bgColor': const Color(0xFFD1FAE5),
      };
    } else if (lower.contains('cancel') || lower.contains('batal')) {
      return {
        'icon': Icons.cancel_outlined,
        'color': const Color(0xFFE11D48),
        'bgColor': const Color(0xFFFFE4E6),
      };
    }
    return {
      'icon': Icons.cleaning_services_rounded,
      'color': const Color(0xFF0F766E),
      'bgColor': const Color(0xFFCCFBF1),
    };
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _layanans.where((l) {
      final query = _searchQuery.toLowerCase();
      final matchName = l.namaLayanan.toLowerCase().contains(query);
      final matchCabang = _selectedCabangId == null || l.cabangId == _selectedCabangId;
      final matchStatus = _selectedStatus.isEmpty || l.status.toLowerCase() == _selectedStatus;
      return matchName && matchCabang && matchStatus;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFormModal(),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: Text(
          'Tambah Layanan',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header
          GradientHeader(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 10 : 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
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
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Master',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Layanan Operasional',
                        style: GoogleFonts.inter(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_layanans.length} Layanan',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search and Filters Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Search Input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF64748B).withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Cari nama layanan...',
                      hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),

                const SizedBox(height: 10),

                // Horizontal Filters (Cabang & Status)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Cabang Filter Dropdown Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: _selectedCabangId != null ? const Color(0xFFEFF6FF) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedCabangId != null ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _selectedCabangId,
                            isDense: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                            hint: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                              ..._cabangs.map((c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.namaCabang, style: GoogleFonts.inter(fontSize: 12)),
                                  )),
                            ],
                            onChanged: (val) => setState(() => _selectedCabangId = val),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Status Filter Chips
                      _buildFilterChip('Semua Status', '', _selectedStatus == ''),
                      const SizedBox(width: 6),
                      _buildFilterChip('Aktif', 'aktif', _selectedStatus == 'aktif'),
                      const SizedBox(width: 6),
                      _buildFilterChip('Nonaktif', 'nonaktif', _selectedStatus == 'nonaktif'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 44, color: Color(0xFFEF4444)),
                            const SizedBox(height: 10),
                            Text(
                              _error,
                              style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _fetchData,
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cleaning_services_rounded, size: 44, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 10),
                                Text(
                                  _searchQuery.isNotEmpty || _selectedCabangId != null || _selectedStatus.isNotEmpty
                                      ? 'Tidak ada layanan yang sesuai filter'
                                      : 'Belum ada data layanan',
                                  style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchData,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final layanan = filtered[index];
                                return _buildLayananCard(layanan);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isSelected) {
    return InkWell(
      onTap: () => setState(() => _selectedStatus = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildLayananCard(LayananModel layanan) {
    final visual = _getLayananVisual(layanan.namaLayanan);
    final isAktif = layanan.status.toLowerCase() == 'aktif';
    final cabangName = _cabangs
        .firstWhere((c) => c.id == layanan.cabangId, orElse: () => CabangModel(id: 0, namaCabang: 'Semua Cabang', status: 'aktif'))
        .namaCabang;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: visual['bgColor'],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(visual['icon'], color: visual['color'], size: 22),
                ),
                const SizedBox(width: 12),

                // Name & Branch
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        layanan.namaLayanan,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.storefront_rounded, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              cabangName,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isAktif ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isAktif ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isAktif ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAktif ? 'Aktif' : 'Nonaktif',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isAktif ? const Color(0xFF059669) : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),

            // Actions Row: Edit & Hapus
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () => _openFormModal(layanan: layanan),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _delete(layanan),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                        const SizedBox(width: 4),
                        Text(
                          'Hapus',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFDC2626),
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
    );
  }
}

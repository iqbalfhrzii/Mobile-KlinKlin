import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'gaji_pokok_detail_sheet.dart';
import 'gaji_pokok_form_sheet.dart';

class GajiPokokListScreen extends StatefulWidget {
  const GajiPokokListScreen({super.key});

  @override
  State<GajiPokokListScreen> createState() => _GajiPokokListScreenState();
}

class _GajiPokokListScreenState extends State<GajiPokokListScreen> {
  final HrdService _hrdService = HrdService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<GajiPokokModel> _gajiPokoks = [];
  List<CabangModel> _cabangs = [];
  List<JabatanModel> _jabatans = [];

  int? _selectedCabang;
  String _selectedStatus = ''; // '' = semua
  String _searchQuery = '';
  bool _isLoading = true;
  String _error = '';

  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  final List<String> _statusFilters = [
    'TETAP',
    'FREELANCE',
    'SEMI',
    'TETAP KOOR',
    'VENDOR',
    'KONTRAK',
    'TRAINING',
  ];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final futures = await Future.wait([
        _hrdService.fetchCabang(),
        _hrdService.fetchGajiPokok(),
        _hrdService.fetchJabatan(),
      ]);

      if (mounted) {
        setState(() {
          _cabangs = futures[0] as List<CabangModel>;
          _gajiPokoks = futures[1] as List<GajiPokokModel>;
          _jabatans = futures[2] as List<JabatanModel>;
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

  Future<void> _fetchGajiPokok() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final gajiPokoks = await _hrdService.fetchGajiPokok();
      if (mounted) {
        setState(() {
          _gajiPokoks = gajiPokoks;
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

  Future<void> _openFormModal({GajiPokokModel? gajiPokok}) async {
    final res = await GajiPokokFormSheet.show(
      context,
      gajiPokok: gajiPokok,
      cabangs: _cabangs,
      jabatans: _jabatans,
    );
    if (res == true) {
      _fetchGajiPokok();
    }
  }

  Future<void> _openDetailModal(GajiPokokModel gajiPokok) async {
    final res = await GajiPokokDetailSheet.show(
      context,
      gajiPokok: gajiPokok,
      onDataChanged: _fetchGajiPokok,
    );
    if (res == true) {
      _fetchGajiPokok();
    }
  }

  Future<void> _deleteGajiPokok(GajiPokokModel gaji) async {
    final bool? confirm = await AppConfirmationDialog.show(
      context,
      title: 'Hapus Standar Gaji?',
      message: 'Apakah Anda yakin ingin menghapus standar gaji ${gaji.jabatan?.namaJabatan ?? ''} (${gaji.statusKaryawan}) di cabang ${gaji.cabang?.namaCabang ?? ''}?',
      type: ConfirmationDialogType.danger,
      customIcon: Icons.delete_forever_rounded,
      confirmText: 'Ya, Hapus',
      cancelText: 'Batal',
      isDestructive: true,
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _hrdService.deleteGajiPokok(gaji.id);
        await _fetchGajiPokok();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Standar gaji berhasil dihapus'),
              backgroundColor: Color(0xFF475569),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus data: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    final s = status.toUpperCase();
    if (s == 'TETAP') return const Color(0xFF059669);
    if (s == 'TETAP KOOR') return const Color(0xFF7C3AED);
    if (s == 'SEMI') return const Color(0xFFD97706);
    if (s == 'FREELANCE') return const Color(0xFF0284C7);
    if (s == 'VENDOR') return const Color(0xFF475569);
    if (s == 'KONTRAK') return const Color(0xFF2563EB);
    return const Color(0xFF0D9488);
  }

  Color _getStatusBgColor(String status) {
    final s = status.toUpperCase();
    if (s == 'TETAP') return const Color(0xFFECFDF5);
    if (s == 'TETAP KOOR') return const Color(0xFFF5F3FF);
    if (s == 'SEMI') return const Color(0xFFFFFBEB);
    if (s == 'FREELANCE') return const Color(0xFFE0F2FE);
    if (s == 'VENDOR') return const Color(0xFFF1F5F9);
    if (s == 'KONTRAK') return const Color(0xFFEFF6FF);
    return const Color(0xFFCCFBF1);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _gajiPokoks.where((gaji) {
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          gaji.statusKaryawan.toLowerCase().contains(q) ||
          (gaji.cabang?.namaCabang.toLowerCase().contains(q) ?? false) ||
          (gaji.jabatan?.namaJabatan.toLowerCase().contains(q) ?? false);

      final matchCabang = _selectedCabang == null || gaji.cabangId == _selectedCabang;
      final matchStatus = _selectedStatus.isEmpty || gaji.statusKaryawan.toUpperCase() == _selectedStatus.toUpperCase();

      return matchSearch && matchCabang && matchStatus;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFormModal(),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: Text(
          'Tambah Standar Gaji',
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
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
                        'Standar Gaji Pokok',
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
                    '${_gajiPokoks.length} Standar',
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
                    controller: _searchCtrl,
                    style: GoogleFonts.inter(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Cari status, cabang, atau jabatan...',
                      hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchCtrl.clear();
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
                          color: _selectedCabang != null ? const Color(0xFFEFF6FF) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedCabang != null ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _selectedCabang,
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
                            onChanged: (val) => setState(() => _selectedCabang = val),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Status Filter Chips
                      _buildFilterChip('Semua Status', '', _selectedStatus == ''),
                      const SizedBox(width: 6),
                      ..._statusFilters.map((s) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _buildFilterChip(s, s, _selectedStatus == s),
                        );
                      }),
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
                              onPressed: _fetchInitialData,
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
                                const Icon(Icons.monetization_on_outlined, size: 44, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 10),
                                Text(
                                  _searchQuery.isNotEmpty || _selectedCabang != null || _selectedStatus.isNotEmpty
                                      ? 'Tidak ada standar gaji sesuai filter'
                                      : 'Belum ada data standar gaji pokok',
                                  style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchGajiPokok,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final gaji = filtered[index];
                                return _buildGajiCard(gaji);
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

  Widget _buildGajiCard(GajiPokokModel gaji) {
    final statusColor = _getStatusColor(gaji.statusKaryawan);
    final statusBgColor = _getStatusBgColor(gaji.statusKaryawan);
    final cabangName = gaji.cabang?.namaCabang ?? '-';
    final jabatanName = gaji.jabatan?.namaJabatan ?? 'Semua Jabatan';

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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openDetailModal(gaji),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Icon + Jabatan + Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.attach_money_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            jabatanName,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
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
                                    fontWeight: FontWeight.w500,
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        gaji.statusKaryawan.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Amount Breakdown Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      // Gaji Pokok Bulanan
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gaji Pokok (Bulan)',
                              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currencyFormatter.format(gaji.gajiPokok),
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 26, color: const Color(0xFFCBD5E1)),
                      const SizedBox(width: 12),

                      // Gaji Pokok Harian
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gaji Harian',
                              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currencyFormatter.format(gaji.gajiPokokHarian),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),

                // Action Buttons Row: Detail, Edit, Hapus
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () => _openDetailModal(gaji),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF475569)),
                            const SizedBox(width: 4),
                            Text(
                              'Detail',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _openFormModal(gajiPokok: gaji),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF1D4ED8)),
                            const SizedBox(width: 4),
                            Text(
                              'Edit',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
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
                      onTap: () => _deleteGajiPokok(gaji),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded, size: 13, color: Color(0xFFDC2626)),
                            const SizedBox(width: 4),
                            Text(
                              'Hapus',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
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
        ),
      ),
    );
  }
}

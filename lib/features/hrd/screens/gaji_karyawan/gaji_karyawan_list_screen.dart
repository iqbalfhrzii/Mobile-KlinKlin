import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../../../../core/services/pdf_slip_gaji_service.dart';
import '../../services/hrd_service.dart';
import 'gaji_karyawan_form_screen.dart';
import '../insentif/insentif_cleaner_list_screen.dart';
import 'gaji_karyawan_detail_screen.dart';

class GajiKaryawanListScreen extends StatefulWidget {
  const GajiKaryawanListScreen({super.key});

  @override
  State<GajiKaryawanListScreen> createState() => _GajiKaryawanListScreenState();
}

class _GajiKaryawanListScreenState extends State<GajiKaryawanListScreen> with SingleTickerProviderStateMixin {
  final HrdService _hrdService = HrdService();
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool _isLoading = true;
  List<GajiKaryawanModel> _allData = [];
  List<CabangModel> _cabangList = [];
  
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  int? _selectedCabangId;
  int? _selectedBulan;
  int? _selectedTahun;

  late TabController _tabController;

  static const List<Map<String, dynamic>> _daftarBulan = [
    {'id': 1, 'nama': 'Januari'},
    {'id': 2, 'nama': 'Februari'},
    {'id': 3, 'nama': 'Maret'},
    {'id': 4, 'nama': 'April'},
    {'id': 5, 'nama': 'Mei'},
    {'id': 6, 'nama': 'Juni'},
    {'id': 7, 'nama': 'Juli'},
    {'id': 8, 'nama': 'Agustus'},
    {'id': 9, 'nama': 'September'},
    {'id': 10, 'nama': 'Oktober'},
    {'id': 11, 'nama': 'November'},
    {'id': 12, 'nama': 'Desember'},
  ];

  List<int> get _daftarTahun {
    final currentYear = DateTime.now().year;
    return [currentYear + 1, currentYear, currentYear - 1, currentYear - 2];
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCabangId != null) count++;
    if (_selectedBulan != null) count++;
    if (_selectedTahun != null) count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadCabangs();
    _fetchData();
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
      if (mounted) setState(() => _cabangList = res);
    } catch (_) {}
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      _allData = await _hrdService.fetchGajiKaryawan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data gaji: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _printSlip(GajiKaryawanModel gaji) async {
    Uint8List pdfBytes;
    try {
      final bytes = await _hrdService.fetchPrintSlipPdfBytes(gaji.id);
      if (bytes.length > 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
        pdfBytes = bytes;
      } else {
        pdfBytes = await PdfSlipGajiService.generateSlip(gaji);
      }
    } catch (_) {
      pdfBytes = await PdfSlipGajiService.generateSlip(gaji);
    }

    await Printing.layoutPdf(
      name: 'Slip_Gaji_${gaji.karyawan?.nama ?? gaji.id}',
      onLayout: (format) => pdfBytes,
    );
  }

  List<GajiKaryawanModel> _getFilteredData(String jenis) {
    return _allData.where((e) {
      if (e.jenisGaji != jenis) return false;

      // Search Query Filter
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final name = (e.karyawan?.nama ?? '').toLowerCase();
        final cabang = (e.snapshotCabang ?? '').toLowerCase();
        if (!name.contains(query) && !cabang.contains(query)) return false;
      }

      // Cabang Filter
      if (_selectedCabangId != null) {
        final cabangMatch = _cabangList.where((c) => c.id == _selectedCabangId).toList();
        final selectedCabangName = cabangMatch.isNotEmpty ? cabangMatch.first.namaCabang.toLowerCase() : '';
        final matchId = e.karyawan?.cabangId == _selectedCabangId;
        final matchName = (e.snapshotCabang ?? '').toLowerCase().contains(selectedCabangName);
        if (!matchId && !matchName) return false;
      }

      // Bulan Filter
      if (_selectedBulan != null) {
        if (e.periodeBulan != _selectedBulan) return false;
      }

      // Tahun Filter
      if (_selectedTahun != null) {
        if (e.periodeTahun != _selectedTahun) return false;
      }

      return true;
    }).toList();
  }

  Widget _buildSearchAndFilterBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: _searchQuery.isNotEmpty ? const Color(0xFF3B82F6) : Colors.grey.withValues(alpha: 0.25),
                width: _searchQuery.isNotEmpty ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _searchQuery.isNotEmpty ? const Color(0xFF3B82F6).withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: _searchQuery.isNotEmpty ? const Color(0xFF2563EB) : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Cari nama karyawan...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, size: 14, color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _showFilterBottomSheet(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: _activeFilterCount > 0
                  ? const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF4F46E5)])
                  : null,
              color: _activeFilterCount > 0 ? null : Colors.white,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: _activeFilterCount > 0 ? Colors.transparent : Colors.grey.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                if (_activeFilterCount > 0)
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: _activeFilterCount > 0 ? Colors.white : AppColors.textDark,
                ),
                if (_activeFilterCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Text(
                      '$_activeFilterCount',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFilterChips() {
    if (_activeFilterCount == 0 && _searchQuery.isEmpty) {
      return const SizedBox.shrink();
    }

    final String? namaCabang = _selectedCabangId != null
        ? _cabangList.firstWhere(
            (c) => c.id == _selectedCabangId, 
            orElse: () => CabangModel(id: -1, namaCabang: 'Cabang')
          ).namaCabang
        : null;

    final String? namaBulan = _selectedBulan != null
        ? _daftarBulan.firstWhere(
            (b) => b['id'] == _selectedBulan, 
            orElse: () => {'nama': 'Bulan'}
          )['nama']
        : null;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (namaCabang != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text('Cabang: $namaCabang', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1D4ED8))),
                  backgroundColor: const Color(0xFFEFF6FF),
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF1D4ED8)),
                  onDeleted: () => setState(() => _selectedCabangId = null),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            if (namaBulan != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text('Bulan: $namaBulan', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF047857))),
                  backgroundColor: const Color(0xFFECFDF5),
                  side: const BorderSide(color: Color(0xFFA7F3D0)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF047857)),
                  onDeleted: () => setState(() => _selectedBulan = null),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            if (_selectedTahun != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text('Tahun: $_selectedTahun', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF6D28D9))),
                  backgroundColor: const Color(0xFFF5F3FF),
                  side: const BorderSide(color: Color(0xFFDDD6FE)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF6D28D9)),
                  onDeleted: () => setState(() => _selectedTahun = null),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            if (_activeFilterCount > 0 || _searchQuery.isNotEmpty)
              ActionChip(
                label: Text('Reset Filter', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                backgroundColor: Colors.red.shade50,
                side: BorderSide(color: Colors.red.shade200),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedCabangId = null;
                    _selectedBulan = null;
                    _selectedTahun = null;
                  });
                },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
      ),
    );
  }

  void _showFilterBottomSheet() {
    int? tempCabangId = _selectedCabangId;
    int? tempBulan = _selectedBulan;
    int? tempTahun = _selectedTahun;

    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 12, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 8 : 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Filter Gaji Karyawan', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Cabang Filter
                          if (_cabangList.isNotEmpty) ...[
                            Text('Cabang', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('Semua Cabang'),
                                  selected: tempCabangId == null,
                                  onSelected: (val) {
                                    if (val) setModalState(() => tempCabangId = null);
                                  },
                                  selectedColor: const Color(0xFFEFF6FF),
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 12, 
                                    fontWeight: tempCabangId == null ? FontWeight.bold : FontWeight.w500, 
                                    color: tempCabangId == null ? const Color(0xFF1D4ED8) : AppColors.textDark
                                  ),
                                  side: BorderSide(color: tempCabangId == null ? const Color(0xFF3B82F6) : Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  showCheckmark: false,
                                ),
                                ..._cabangList.map((c) {
                                  final isSel = tempCabangId == c.id;
                                  return ChoiceChip(
                                    label: Text(c.namaCabang),
                                    selected: isSel,
                                    onSelected: (val) {
                                      setModalState(() => tempCabangId = val ? c.id : null);
                                    },
                                    selectedColor: const Color(0xFFEFF6FF),
                                    labelStyle: GoogleFonts.inter(
                                      fontSize: 12, 
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500, 
                                      color: isSel ? const Color(0xFF1D4ED8) : AppColors.textDark
                                    ),
                                    side: BorderSide(color: isSel ? const Color(0xFF3B82F6) : Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    showCheckmark: false,
                                  );
                                }),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],

                          // 2. Periode Bulan
                          Text('Periode Bulan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Semua Bulan'),
                                selected: tempBulan == null,
                                onSelected: (val) {
                                  if (val) setModalState(() => tempBulan = null);
                                },
                                selectedColor: const Color(0xFFECFDF5),
                                labelStyle: GoogleFonts.inter(
                                  fontSize: 12, 
                                  fontWeight: tempBulan == null ? FontWeight.bold : FontWeight.w500, 
                                  color: tempBulan == null ? const Color(0xFF047857) : AppColors.textDark
                                ),
                                side: BorderSide(color: tempBulan == null ? const Color(0xFF10B981) : Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                showCheckmark: false,
                              ),
                              ..._daftarBulan.map((b) {
                                final isSel = tempBulan == b['id'];
                                return ChoiceChip(
                                  label: Text(b['nama']),
                                  selected: isSel,
                                  onSelected: (val) {
                                    setModalState(() => tempBulan = val ? b['id'] : null);
                                  },
                                  selectedColor: const Color(0xFFECFDF5),
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 12, 
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500, 
                                    color: isSel ? const Color(0xFF047857) : AppColors.textDark
                                  ),
                                  side: BorderSide(color: isSel ? const Color(0xFF10B981) : Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  showCheckmark: false,
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // 3. Periode Tahun
                          Text('Periode Tahun', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Semua Tahun'),
                                selected: tempTahun == null,
                                onSelected: (val) {
                                  if (val) setModalState(() => tempTahun = null);
                                },
                                selectedColor: const Color(0xFFF5F3FF),
                                labelStyle: GoogleFonts.inter(
                                  fontSize: 12, 
                                  fontWeight: tempTahun == null ? FontWeight.bold : FontWeight.w500, 
                                  color: tempTahun == null ? const Color(0xFF6D28D9) : AppColors.textDark
                                ),
                                side: BorderSide(color: tempTahun == null ? const Color(0xFF8B5CF6) : Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                showCheckmark: false,
                              ),
                              ..._daftarTahun.map((t) {
                                final isSel = tempTahun == t;
                                return ChoiceChip(
                                  label: Text('$t'),
                                  selected: isSel,
                                  onSelected: (val) {
                                    setModalState(() => tempTahun = val ? t : null);
                                  },
                                  selectedColor: const Color(0xFFF5F3FF),
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 12, 
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500, 
                                    color: isSel ? const Color(0xFF6D28D9) : AppColors.textDark
                                  ),
                                  side: BorderSide(color: isSel ? const Color(0xFF8B5CF6) : Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  showCheckmark: false,
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 20 : 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                tempCabangId = null;
                                tempBulan = null;
                                tempTahun = null;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text('Reset', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedCabangId = tempCabangId;
                                _selectedBulan = tempBulan;
                                _selectedTahun = tempTahun;
                              });
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: Text('Terapkan Filter', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
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
      },
    );
  }

  Widget _buildEmptyState(String jenis) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                _activeFilterCount > 0 || _searchQuery.isNotEmpty
                    ? 'Tidak ada gaji $jenis yang cocok'
                    : 'Belum ada data gaji $jenis',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
              const SizedBox(height: 4),
              Text(
                _activeFilterCount > 0 || _searchQuery.isNotEmpty
                    ? 'Coba ubah kata kunci atau bersihkan filter pencarian.'
                    : 'Tekan tombol + di kanan atas untuk membuat slip gaji baru.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              if (_activeFilterCount > 0 || _searchQuery.isNotEmpty) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _searchQuery = '';
                      _selectedCabangId = null;
                      _selectedBulan = null;
                      _selectedTahun = null;
                    });
                  },
                  child: Text('Reset Semua Filter', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(String jenis) {
    final filteredData = _getFilteredData(jenis);

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchAndFilterBar(),
                _buildActiveFilterChips(),
              ],
            ),
          ),
          Expanded(
            child: filteredData.isEmpty
                ? _buildEmptyState(jenis)
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                    itemCount: filteredData.length,
                    itemBuilder: (context, index) {
                      final gaji = filteredData[index];
                      return _buildItem(gaji, jenis);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Widget _buildItem(GajiKaryawanModel gaji, String jenis) {
    final rawName = gaji.karyawan?.nama ?? '-';
    final name = _toTitleCase(rawName);
    final initial = name.isNotEmpty && name != '-' ? name[0].toUpperCase() : 'K';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showGajiKaryawanDetailModal(context, gaji),
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF3B82F6),
                            Color(0xFF1D4ED8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1D4ED8).withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  jenis == 'bulanan'
                                      ? '${gaji.periodeBulan.toString().padLeft(2, '0')}/${gaji.periodeTahun}'
                                      : '${gaji.jumlahHariKerja} Hari',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.account_balance_wallet_rounded, size: 12, color: Color(0xFF059669)),
                                    const SizedBox(width: 4),
                                    Text(
                                      currencyFormatter.format(gaji.takeHomePay),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF047857),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (gaji.snapshotCabang != null && gaji.snapshotCabang!.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.storefront_rounded, size: 11, color: Color(0xFFEA580C)),
                                    const SizedBox(width: 3),
                                    Text(
                                      gaji.snapshotCabang!,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFEA580C),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => showGajiKaryawanDetailModal(context, gaji),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.visibility_outlined, size: 15, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              Text('Detail Slip', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(width: 1, height: 16, color: const Color(0xFFE2E8F0)),
                    Expanded(
                      child: InkWell(
                        onTap: () => _printSlip(gaji),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.picture_as_pdf_outlined, size: 15, color: Color(0xFFD97706)),
                              const SizedBox(width: 6),
                              Text('Cetak PDF', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFD97706))),
                            ],
                          ),
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: _tabController.index != 2
          ? FloatingActionButton.extended(
              onPressed: () async {
                final String currentJenis = _tabController.index == 1 ? 'harian' : 'bulanan';
                final res = await showGajiKaryawanFormModal(
                  context,
                  initialJenisGaji: currentJenis,
                );
                if (res == true) _fetchData();
              },
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                _tabController.index == 1 ? 'Tambah Gaji Harian' : 'Tambah Gaji Bulanan',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: Column(
        children: [
          GradientHeader(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 8 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (Navigator.canPop(context)) ...[
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
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rekapitulasi',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Gaji Karyawan',
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
                        '${_allData.length} Slip',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.white.withValues(alpha: 0.8),
                    labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                    tabs: const [
                      Tab(text: 'Bulanan'),
                      Tab(text: 'Harian'),
                      Tab(text: 'Insentif'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList('bulanan'),
                      _buildList('harian'),
                      const InsentifCleanerListScreen(showHeader: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

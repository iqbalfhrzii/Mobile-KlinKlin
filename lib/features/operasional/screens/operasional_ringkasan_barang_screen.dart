import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/operasional_ringkasan_barang_service.dart';

class OperasionalRingkasanBarangScreen extends StatefulWidget {
  const OperasionalRingkasanBarangScreen({super.key});

  @override
  State<OperasionalRingkasanBarangScreen> createState() => _OperasionalRingkasanBarangScreenState();
}

class _OperasionalRingkasanBarangScreenState extends State<OperasionalRingkasanBarangScreen> {
  bool _isLoading = false;
  List<dynamic> _cabangs = [];
  Map<String, dynamic> _summary = {};
  List<dynamic> _items = [];

  int? _selectedCabangId;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCabangs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCabangs() async {
    try {
      final cabangs = await OperasionalRingkasanBarangService.getCabangs();
      setState(() => _cabangs = cabangs);
      _loadData(); // Load all data initially
    } catch (e) {
      debugPrint('Error loading cabangs: $e');
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await OperasionalRingkasanBarangService.getSummary(
        cabangId: _selectedCabangId,
        search: _searchController.text,
      );
      setState(() {
        _summary = data['summary'] ?? {};
        _items = data['list'] ?? [];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDetailModal(Map<String, dynamic> item) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetailBottomSheet(
        barangId: item['id'],
        namaBarang: item['nama_barang'],
        selectedCabangId: _selectedCabangId,
        cabangs: _cabangs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            child: Row(
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
                        'Ringkasan Barang',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pantau ketersediaan dan kondisi aset di seluruh cabang',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
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
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryGrid(),
                          _buildListItems(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
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
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10), color: AppColors.surface),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<dynamic>(
                      value: _selectedCabangId,
                      isExpanded: true,
                      hint: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w600),
                      items: [
                        DropdownMenuItem(value: null, child: Text('Semua Cabang', style: GoogleFonts.inter(fontWeight: FontWeight.normal))),
                        ..._cabangs.map((c) => DropdownMenuItem(value: c['id'], child: Text(c['nama_cabang']))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedCabangId = val as int?);
                        _loadData();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                      hintText: 'Cari nama barang...',
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
        ],
      ),
    );
  }

  Widget _buildSummaryGrid() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
        children: [
          _buildSummaryCard('Total Aset (CLA)', _summary['total_cla']?.toString() ?? '0', Icons.inventory_2_outlined, AppColors.primary),
          _buildSummaryCard('Total Aset (MSN)', _summary['total_msn']?.toString() ?? '0', Icons.precision_manufacturing_outlined, AppColors.primary),
          _buildSummaryCard('Kondisi Baik', _summary['kondisi_baik']?.toString() ?? '0', Icons.check_circle_outline, Colors.green),
          _buildSummaryCard('Bermasalah', _summary['bermasalah']?.toString() ?? '0', Icons.warning_amber_rounded, Colors.red),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('Unit', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildListItems() {
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                'Belum ada data ringkasan barang.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _items[index];
        final kategori = item['kategori'] ?? '-';
        final nama = item['nama_barang'] ?? '-';
        final total = item['total_unit'] ?? 0;
        final baik = item['kondisi_baik'] ?? 0;
        final bermasalah = item['bermasalah'] ?? 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(kategori, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                  ),
                  InkWell(
                    onTap: () => _showDetailModal(item),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          Text('Lihat Detail', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          const Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(nama, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniStat('Total Unit', total.toString(), AppColors.textDark),
                  _buildMiniStat('Kondisi Baik', baik.toString(), Colors.green),
                  _buildMiniStat('Bermasalah', bermasalah > 0 ? bermasalah.toString() : '-', bermasalah > 0 ? Colors.red : AppColors.textMuted),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }
}

// ---------------------------------------------------------
// Bottom Sheet untuk Detail Item Fisik (Modal)
// ---------------------------------------------------------

class _DetailBottomSheet extends StatefulWidget {
  final int barangId;
  final String namaBarang;
  final int? selectedCabangId;
  final List<dynamic> cabangs;

  const _DetailBottomSheet({
    required this.barangId,
    required this.namaBarang,
    this.selectedCabangId,
    required this.cabangs,
  });

  @override
  State<_DetailBottomSheet> createState() => _DetailBottomSheetState();
}

class _DetailBottomSheetState extends State<_DetailBottomSheet> {
  bool _isLoading = true;
  List<dynamic> _items = [];
  int? _localCabangId;

  @override
  void initState() {
    super.initState();
    _localCabangId = widget.selectedCabangId;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      final data = await OperasionalRingkasanBarangService.getDetailItem(widget.barangId, cabangId: _localCabangId);
      setState(() {
        _items = data['items'] ?? [];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rincian Item: ${widget.namaBarang}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const SizedBox(height: 2),
                      Text('Menampilkan kondisi setiap QR Code terdaftar.', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10), color: Colors.white),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<dynamic>(
                  value: _localCabangId,
                  isExpanded: true,
                  hint: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w600),
                  items: [
                    DropdownMenuItem(value: null, child: Text('Semua Cabang', style: GoogleFonts.inter(fontWeight: FontWeight.normal))),
                    ...widget.cabangs.map((c) => DropdownMenuItem(value: c['id'], child: Text(c['nama_cabang']))),
                  ],
                  onChanged: (val) {
                    setState(() => _localCabangId = val as int?);
                    _loadDetail();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(child: Text('Tidak ada rincian item.', style: GoogleFonts.inter(color: AppColors.textMuted)))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final qr = item['kode_qr'] ?? '-';
                          final cabang = item['cabang'] ?? '-';
                          final ketersediaan = item['status_ketersediaan'] ?? '-';
                          final kondisi = item['kondisi_fisik'] ?? '-';
                          final foto = item['foto_path'];

                          Color kondisiColor = Colors.grey;
                          if (kondisi == 'Baik') kondisiColor = Colors.green;
                          if (kondisi == 'Rusak') kondisiColor = Colors.red;
                          if (kondisi == 'Hilang') kondisiColor = Colors.orange;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: foto != null 
                                      ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network('http://erp.klinklin.online/storage/$foto', fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.grey)))
                                      : const Icon(Icons.image_not_supported, color: Colors.grey),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(qr, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                                      const SizedBox(height: 4),
                                      Text('Cabang: $cabang', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(ketersediaan, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: kondisiColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                      child: Text(kondisi, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: kondisiColor)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Tutup', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              ),
            ),
          )
        ],
      ),
    );
  }
}

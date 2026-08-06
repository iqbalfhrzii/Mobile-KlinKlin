import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/master_barang_service.dart';

class MasterBarangScreen extends StatefulWidget {
  const MasterBarangScreen({super.key});

  @override
  State<MasterBarangScreen> createState() => _MasterBarangScreenState();
}

class _MasterBarangScreenState extends State<MasterBarangScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> _kategoris = [];
  bool _isLoadingKategori = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadDataForCurrentTab();
      }
    });
    _loadDataForCurrentTab();
  }

  void _loadDataForCurrentTab() {
    if (_tabController.index == 0) {
      _loadKategori();
    } else if (_tabController.index == 1) {
      // _loadBarang();
    } else if (_tabController.index == 2) {
      // _loadItemFisik();
    }
  }

  Future<void> _loadKategori() async {
    setState(() => _isLoadingKategori = true);
    final kats = await MasterBarangService.getKategori();
    setState(() {
      _kategoris = kats;
      _isLoadingKategori = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Master Barang & Aset',
          style: GoogleFonts.inter(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 13),
          tabs: const [
            Tab(text: 'Kategori'),
            Tab(text: 'Data Barang'),
            Tab(text: 'Item Fisik'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildKategoriTab(),
          _buildPlaceholder('Halaman Data Barang akan menampilkan\ndaftar semua barang inventaris.', Icons.inventory_2_outlined),
          _buildPlaceholder('Halaman Item Fisik & QR akan digunakan\nuntuk mencetak dan manajemen kode QR.', Icons.qr_code_2_rounded),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.border),
          const SizedBox(height: 16),
          Text(text, style: GoogleFonts.inter(color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildKategoriTab() {
    return Column(
      children: [
        // Info Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceBlue,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kategori barang ini dibagikan ke semua cabang. Silakan gunakan kategori yang sudah ada atau tambahkan jika belum tersedia.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        
        // Add Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Show Add Kategori Dialog
              },
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: Text('Tambah Kategori', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E5CE6), // Purple color from web
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Table Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text('NAMA KATEGORI', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              ),
              Expanded(
                flex: 1,
                child: Text('TIPE TRACKING', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: AppColors.border),

        // Table Body
        Expanded(
          child: _isLoadingKategori
              ? const Center(child: CircularProgressIndicator())
              : _kategoris.isEmpty
                  ? Center(
                      child: Text('Tidak ada data kategori', style: GoogleFonts.inter(color: AppColors.textMuted)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _kategoris.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final k = _kategoris[index];
                        final isKuantitas = k['tipe_tracking'] == 'kuantitas';
                        return InkWell(
                          onTap: () {}, // For edit
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    k['nama_kategori'] ?? '-',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isKuantitas ? 'Kuantitas' : 'Per Item (QR)',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

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

  List<dynamic> _barangs = [];
  bool _isLoadingBarang = false;

  List<dynamic> _itemFisiks = [];
  bool _isLoadingItemFisik = false;

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
      _loadBarang();
    } else if (_tabController.index == 2) {
      _loadItemFisik();
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

  Future<void> _loadBarang() async {
    setState(() => _isLoadingBarang = true);
    final barangs = await MasterBarangService.getBarang();
    if (_kategoris.isEmpty) {
      _kategoris = await MasterBarangService.getKategori();
    }
    setState(() {
      _barangs = barangs;
      _isLoadingBarang = false;
    });
  }

  Future<void> _loadItemFisik() async {
    setState(() => _isLoadingItemFisik = true);
    final items = await MasterBarangService.getItemFisik(cabangId: 1); // Mock cabang 1
    if (_barangs.isEmpty) {
      _barangs = await MasterBarangService.getBarang();
    }
    setState(() {
      _itemFisiks = items;
      _isLoadingItemFisik = false;
    });
  }

  void _showAddKategoriDialog() {
    final namaController = TextEditingController();
    String selectedTipe = 'kuantitas';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Form Kategori', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Nama Kategori', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: namaController,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Contoh: Alat Kebersihan',
                        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Tipe Tracking', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedTipe,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark),
                          items: const [
                            DropdownMenuItem(value: 'kuantitas', child: Text('Kuantitas (Bahan Habis Pakai)')),
                            DropdownMenuItem(value: 'per_item', child: Text('Per Item (QR Code / Alat)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setStateDialog(() => selectedTipe = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textDark, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (namaController.text.trim().isEmpty) return;
                            
                            final success = await MasterBarangService.addKategori({
                              'nama_kategori': namaController.text.trim(),
                              'tipe_tracking': selectedTipe,
                            });
                            
                            if (context.mounted) {
                              Navigator.pop(context);
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kategori berhasil disimpan')));
                                _loadKategori();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan kategori')));
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textDark, // Dark color like in screenshot
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            elevation: 0,
                          ),
                          child: Text('Simpan Kategori', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddBarangDialog() {
    final namaController = TextEditingController();
    final satuanController = TextEditingController();
    int? selectedKategoriId;

    if (_kategoris.isNotEmpty) {
      selectedKategoriId = _kategoris.first['id'];
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Form Barang', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Kategori', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedKategoriId,
                          isExpanded: true,
                          hint: Text('Pilih Kategori', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark),
                          items: _kategoris.map((k) {
                            return DropdownMenuItem<int>(
                              value: k['id'],
                              child: Text(k['nama_kategori'] ?? ''),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setStateDialog(() => selectedKategoriId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Nama Barang', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: namaController,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Contoh: Sapu Lidi',
                        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Satuan (Misal: Pcs, Botol, Liter)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: satuanController,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Pcs',
                        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textDark, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (namaController.text.trim().isEmpty || selectedKategoriId == null) return;
                            
                            final success = await MasterBarangService.addBarang({
                              'kategori_id': selectedKategoriId,
                              'nama_barang': namaController.text.trim(),
                              'satuan': satuanController.text.trim(),
                            });
                            
                            if (context.mounted) {
                              Navigator.pop(context);
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barang berhasil disimpan')));
                                _loadBarang();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan barang')));
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textDark,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            elevation: 0,
                          ),
                          child: Text('Simpan Barang', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddItemFisikDialog() {
    int? selectedBarangId;
    int jumlahItem = 1;
    // Filter only barangs that are per_item
    final perItemBarangs = _barangs.where((b) {
      final kat = b['kategori'];
      return kat != null && kat['tipe_tracking'] == 'per_item';
    }).toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tambah Item Fisik (Generate QR)', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Pilih Barang (Hanya tipe per_item)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedBarangId,
                          isExpanded: true,
                          hint: Text('-- Pilih Barang --', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark),
                          items: perItemBarangs.map((b) {
                            return DropdownMenuItem<int>(
                              value: b['id'],
                              child: Text(b['nama_barang'] ?? ''),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setStateDialog(() => selectedBarangId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Jumlah Item (Berapa QR Code)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (jumlahItem > 1) setStateDialog(() => jumlahItem--);
                          },
                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary),
                        ),
                        Text('$jumlahItem', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(
                          onPressed: () {
                            if (jumlahItem < 50) setStateDialog(() => jumlahItem++);
                          },
                          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Sistem akan men-generate QR code otomatis sebanyak jumlah ini untuk Cabang Anda.', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                    const SizedBox(height: 16),
                    Text('Foto Barang Fisik *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.surfaceBlue,
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.camera_alt_outlined, color: AppColors.primary, size: 32),
                          const SizedBox(height: 8),
                          Text('Klik untuk upload foto', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('PNG, JPG atau JPEG', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textDark, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (selectedBarangId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih barang terlebih dahulu')));
                              return;
                            }
                            // Mocking API call since we don't have file upload in mobile yet
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mencetak $jumlahItem QR Code. Simulasi berhasil.')));
                            _loadItemFisik();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.qr_code, size: 16, color: Colors.white),
                          label: Text('Generate QR', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
          _buildBarangTab(),
          _buildItemFisikTab(),
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
              onPressed: _showAddKategoriDialog,
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

  Widget _buildBarangTab() {
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
                  'Nama barang ini dibagikan ke semua cabang agar standar. Silakan cari apakah barang sudah ada sebelum menambahkan baru.',
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
              onPressed: _showAddBarangDialog,
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: Text('Tambah Barang', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
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
                child: Text('KATEGORI', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              ),
              Expanded(
                flex: 2,
                child: Text('NAMA BARANG', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              ),
              Expanded(
                flex: 1,
                child: Text('SATUAN', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: AppColors.border),

        // Table Body
        Expanded(
          child: _isLoadingBarang
              ? const Center(child: CircularProgressIndicator())
              : _barangs.isEmpty
                  ? Center(
                      child: Text('Tidak ada data barang', style: GoogleFonts.inter(color: AppColors.textMuted)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _barangs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final b = _barangs[index];
                        final katName = b['kategori'] != null ? b['kategori']['nama_kategori'] : '-';
                        return InkWell(
                          onTap: () {}, // For edit
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    katName,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.normal,
                                      fontSize: 13,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    b['nama_barang'] ?? '-',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    b['satuan'] ?? '-',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.textMuted,
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

  Widget _buildItemFisikTab() {
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
                  'Daftar item fisik ini khusus untuk Cabang Anda. Jika ada sapu/alat baru, tambahkan stok fisik di sini agar QR Code-nya di-generate.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        
        // Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.print_outlined, size: 16, color: AppColors.textDark),
                label: Text('Print QR Terpilih', style: GoogleFonts.inter(color: AppColors.textDark, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showAddItemFisikDialog,
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: Text('Tambah Stok Fisik (QR)', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E5CE6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Table Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Icon(Icons.check_box_outline_blank, size: 18, color: AppColors.border),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text('KODE QR', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              ),
              Expanded(
                flex: 2,
                child: Text('BARANG', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              ),
              Expanded(
                flex: 2,
                child: Text('KONDISI', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: AppColors.border),

        // Table Body
        Expanded(
          child: _isLoadingItemFisik
              ? const Center(child: CircularProgressIndicator())
              : _itemFisiks.isEmpty
                  ? Center(
                      child: Text('Tidak ada item fisik', style: GoogleFonts.inter(color: AppColors.textMuted)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _itemFisiks.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final item = _itemFisiks[index];
                        final barang = item['barang'];
                        final isBaik = item['kondisi_terakhir'] == 'Baik';
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.check_box_outline_blank, size: 18, color: AppColors.border),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  item['kode_qr'] ?? '-',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  barang != null ? barang['nama_barang'] : '-',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.normal,
                                    fontSize: 13,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isBaik ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item['kondisi_terakhir'] ?? '-',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isBaik ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

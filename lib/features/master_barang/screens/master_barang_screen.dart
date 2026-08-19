import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/api/api_client.dart';
import '../services/master_barang_service.dart';

class MasterBarangScreen extends StatefulWidget {
  const MasterBarangScreen({super.key});

  @override
  State<MasterBarangScreen> createState() => _MasterBarangScreenState();
}

class _MasterBarangScreenState extends State<MasterBarangScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Data lists
  List<dynamic> _kategoris = [];
  bool _isLoadingKategori = false;

  List<dynamic> _barangs = [];
  bool _isLoadingBarang = false;

  List<dynamic> _itemFisiks = [];
  bool _isLoadingItemFisik = false;

  List<dynamic> _cabangs = [];

  // Search & Filter
  String _searchKategoriQuery = '';
  String _searchBarangQuery = '';
  String _searchItemFisikQuery = '';
  int? _filterKategoriForBarang;
  int? _filterCabangForItemFisik;

  // Multi-select for QR print
  final Set<int> _selectedItemFisikIds = {};

  // User Role & Branch Context
  int? _userCabangId;
  String _userCabangName = '';
  String _userRole = '';
  bool _isOperasionalOrAdmin = true;

  final Color _primaryPurple = const Color(0xFF4F46E5);
  final Color _tealAccent = const Color(0xFF0D9488);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadDataForCurrentTab();
      }
    });
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    _userCabangId = prefs.getInt('user_cabang_id');
    _userCabangName = prefs.getString('user_cabang_name') ?? '';

    final r = _userRole.toLowerCase();
    _isOperasionalOrAdmin = r.contains('operasional') || r.contains('admin') || r.contains('ceo') || r.contains('superadmin');

    if (!_isOperasionalOrAdmin && _userCabangId != null) {
      _filterCabangForItemFisik = _userCabangId;
    }

    await _loadCabang();

    if (_userCabangName.isEmpty && _userCabangId != null && _cabangs.isNotEmpty) {
      final match = _cabangs.firstWhere((c) => c['id'] == _userCabangId, orElse: () => null);
      if (match != null) {
        _userCabangName = match['nama_cabang'] ?? match['nama'] ?? 'Cabang $_userCabangId';
      }
    }

    if (mounted) setState(() {});
    _loadDataForCurrentTab();
  }

  Future<void> _loadCabang() async {
    final list = await MasterBarangService.getCabang();
    if (mounted) {
      setState(() => _cabangs = list);
    }
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
    if (mounted) {
      setState(() {
        _kategoris = kats;
        _isLoadingKategori = false;
      });
    }
  }

  Future<void> _loadBarang() async {
    setState(() => _isLoadingBarang = true);
    final barangs = await MasterBarangService.getBarang();
    if (_kategoris.isEmpty) {
      _kategoris = await MasterBarangService.getKategori();
    }
    if (mounted) {
      setState(() {
        _barangs = barangs;
        _isLoadingBarang = false;
      });
    }
  }

  Future<void> _loadItemFisik() async {
    setState(() => _isLoadingItemFisik = true);
    final items = await MasterBarangService.getItemFisik(cabangId: _filterCabangForItemFisik);
    if (_barangs.isEmpty) {
      _barangs = await MasterBarangService.getBarang();
    }
    if (mounted) {
      setState(() {
        _itemFisiks = items;
        _isLoadingItemFisik = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ==========================================
  // DIALOGS
  // ==========================================

  void _showAddEditKategoriDialog({Map<String, dynamic>? kategori}) {
    final isEdit = kategori != null;
    final namaController = TextEditingController(text: isEdit ? kategori['nama_kategori'] : '');
    String selectedTipe = isEdit ? (kategori['tipe_tracking'] ?? 'kuantitas') : 'kuantitas';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primaryPurple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.category_rounded, color: _primaryPurple, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isEdit ? 'Edit Kategori' : 'Tambah Kategori',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text('Nama Kategori *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: namaController,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Contoh: Mesin Alat, Cleaning Alat, dll',
                        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _primaryPurple, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Tipe Tracking *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedTipe,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                          items: const [
                            DropdownMenuItem(value: 'kuantitas', child: Text('Kuantitas (Bahan Habis Pakai)')),
                            DropdownMenuItem(value: 'per_item', child: Text('Per Item (QR Code / Alat Fisik)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setStateDialog(() => selectedTipe = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textDark, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (namaController.text.trim().isEmpty) return;

                            bool success;
                            if (isEdit) {
                              success = await MasterBarangService.updateKategori(kategori['id'], {
                                'nama_kategori': namaController.text.trim(),
                                'tipe_tracking': selectedTipe,
                              });
                            } else {
                              success = await MasterBarangService.addKategori({
                                'nama_kategori': namaController.text.trim(),
                                'tipe_tracking': selectedTipe,
                              });
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success ? 'Kategori berhasil disimpan' : 'Gagal menyimpan kategori'),
                                  backgroundColor: success ? Colors.green : Colors.red,
                                ),
                              );
                              if (success) _loadKategori();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryPurple,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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

  void _showAddEditBarangDialog({Map<String, dynamic>? barang}) {
    final isEdit = barang != null;
    final namaController = TextEditingController(text: isEdit ? barang['nama_barang'] : '');
    final satuanController = TextEditingController(text: isEdit ? barang['satuan'] : 'Pcs');
    int? selectedKategoriId = isEdit ? barang['kategori_id'] : (_kategoris.isNotEmpty ? _kategoris.first['id'] : null);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _tealAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.inventory_2_rounded, color: _tealAccent, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isEdit ? 'Edit Data Barang' : 'Tambah Data Barang',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text('Kategori *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedKategoriId,
                          isExpanded: true,
                          hint: Text('Pilih Kategori', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
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
                    const SizedBox(height: 14),
                    Text('Nama Barang *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: namaController,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Contoh: Sirena Hydrovacuum, Sabun Cuci...',
                        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _tealAccent, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Satuan *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: satuanController,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Pcs, Unit, Botol, Box...',
                        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _tealAccent, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textDark, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (namaController.text.trim().isEmpty || selectedKategoriId == null) return;

                            bool success;
                            if (isEdit) {
                              success = await MasterBarangService.updateBarang(barang['id'], {
                                'kategori_id': selectedKategoriId,
                                'nama_barang': namaController.text.trim(),
                                'satuan': satuanController.text.trim(),
                              });
                            } else {
                              success = await MasterBarangService.addBarang({
                                'kategori_id': selectedKategoriId,
                                'nama_barang': namaController.text.trim(),
                                'satuan': satuanController.text.trim(),
                              });
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success ? 'Barang berhasil disimpan' : 'Gagal menyimpan barang'),
                                  backgroundColor: success ? Colors.green : Colors.red,
                                ),
                              );
                              if (success) _loadBarang();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _tealAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
    int? selectedCabangId = (!_isOperasionalOrAdmin && _userCabangId != null)
        ? _userCabangId
        : (_filterCabangForItemFisik ?? (_cabangs.isNotEmpty ? _cabangs.first['id'] : null));
    int jumlahItem = 1;
    String? selectedPhotoPath;
    bool isSubmitting = false;

    // Filter only barangs that are per_item
    final perItemBarangs = _barangs.where((b) {
      final kat = b['kategori'];
      return kat != null && kat['tipe_tracking'] == 'per_item';
    }).toList();

    if (perItemBarangs.isNotEmpty) {
      selectedBarangId = perItemBarangs.first['id'];
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> pickImage(ImageSource source) async {
              try {
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: source, imageQuality: 80);
                if (picked != null) {
                  setStateDialog(() => selectedPhotoPath = picked.path);
                }
              } catch (e) {
                // Ignore
              }
            }

            void showImageSourceOptions() {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                builder: (ctx) => SafeArea(
                  child: Wrap(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                        title: Text('Ambil dari Kamera', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(ctx);
                          pickImage(ImageSource.camera);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                        title: Text('Pilih dari Galeri', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(ctx);
                          pickImage(ImageSource.gallery);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Expanded title to prevent overflow!
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primaryPurple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.qr_code_2_rounded, color: _primaryPurple, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tambah Item Fisik (Generate QR)',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Cabang Penempatan Dropdown (Locked for CS, Selectable for Operasional)
                    Text('Cabang Penempatan *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 6),
                    if (!_isOperasionalOrAdmin && _userCabangId != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: AppColors.primaryMid),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _userCabangName.isNotEmpty ? _userCabangName : 'Cabang $_userCabangId',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryMid.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Cabang Anda',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryMid),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedCabangId,
                            isExpanded: true,
                            hint: Text('Pilih Cabang', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                            items: _cabangs.map((c) {
                              return DropdownMenuItem<int>(
                                value: c['id'],
                                child: Text(c['nama_cabang'] ?? c['nama'] ?? 'Cabang ${c['id']}'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setStateDialog(() => selectedCabangId = val);
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),

                    // Pilih Barang Dropdown
                    Text('Pilih Barang (Hanya tipe per_item) *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedBarangId,
                          isExpanded: true,
                          hint: Text('-- Pilih Barang --', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                          items: perItemBarangs.isEmpty
                              ? [const DropdownMenuItem<int>(value: null, child: Text('Belum ada barang bertipe per-item'))]
                              : perItemBarangs.map((b) {
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
                    const SizedBox(height: 14),

                    // Jumlah Item Counter
                    Text('Jumlah Item (Berapa QR Code)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: jumlahItem > 1 ? () => setStateDialog(() => jumlahItem--) : null,
                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary, size: 22),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '$jumlahItem',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            onPressed: jumlahItem < 50 ? () => setStateDialog(() => jumlahItem++) : null,
                            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 22),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const Spacer(),
                          Text('Maks. 50 QR', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sistem akan men-generate kode QR unik secara otomatis sebanyak jumlah ini untuk cabang yang dipilih.',
                      style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 14),

                    // Foto Barang Fisik
                    Text('Foto Barang Fisik', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 6),
                    if (selectedPhotoPath != null)
                      Stack(
                        children: [
                          Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                              image: DecorationImage(
                                image: FileImage(File(selectedPhotoPath!)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: InkWell(
                              onTap: () => setStateDialog(() => selectedPhotoPath = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      InkWell(
                        onTap: showImageSourceOptions,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            border: Border.all(color: _primaryPurple.withValues(alpha: 0.4), style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(12),
                            color: _primaryPurple.withValues(alpha: 0.04),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.camera_alt_outlined, color: _primaryPurple, size: 28),
                              const SizedBox(height: 6),
                              Text('Klik untuk upload / ambil foto', style: GoogleFonts.inter(color: _primaryPurple, fontWeight: FontWeight.bold, fontSize: 12)),
                              Text('PNG, JPG atau JPEG (Maks 2MB)', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Submit buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: isSubmitting ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textDark, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (selectedBarangId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Pilih barang per-item terlebih dahulu')),
                                    );
                                    return;
                                  }
                                  if (selectedCabangId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Pilih cabang penempatan terlebih dahulu')),
                                    );
                                    return;
                                  }

                                  setStateDialog(() => isSubmitting = true);

                                  final res = await MasterBarangService.addItemFisikWithFile(
                                    barangId: selectedBarangId!,
                                    cabangId: selectedCabangId!,
                                    jumlahTambah: jumlahItem,
                                    photoPath: selectedPhotoPath,
                                  );

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res['message'] ?? (res['success'] == true ? 'Item fisik berhasil ditambahkan' : 'Gagal menambahkan')),
                                        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
                                      ),
                                    );
                                    if (res['success'] == true) {
                                      _loadItemFisik();
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryPurple,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            elevation: 0,
                          ),
                          icon: isSubmitting
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.qr_code, size: 16, color: Colors.white),
                          label: Text('Simpan & Generate', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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

  void _showDetailItemFisik(Map<String, dynamic> item) {
    final barang = item['barang'];
    final cabang = item['cabang'];
    final isBaik = item['kondisi_terakhir'] == 'Baik';
    final isTersedia = item['status_ketersediaan'] == 'Tersedia';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _primaryPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.qr_code_scanner_rounded, color: _primaryPurple, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Detail Item Fisik', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Divider(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _primaryPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _primaryPurple.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_2, color: _primaryPurple, size: 20),
                      const SizedBox(width: 8),
                      Text(item['kode_qr'] ?? '-', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryPurple)),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: item['kode_qr'] ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kode QR disalin ke clipboard'), duration: Duration(seconds: 1)));
                        },
                        child: Icon(Icons.copy_rounded, color: _primaryPurple.withValues(alpha: 0.7), size: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Nama Barang', barang != null ? barang['nama_barang'] : '-'),
              _buildDetailRow('Kategori', (barang != null && barang['kategori'] != null) ? barang['kategori']['nama_kategori'] : '-'),
              _buildDetailRow('Cabang Penempatan', cabang != null ? (cabang['nama_cabang'] ?? cabang['nama']) : '-'),
              _buildDetailRow(
                'Kondisi',
                item['kondisi_terakhir'] ?? '-',
                badgeColor: isBaik ? Colors.green : Colors.red,
              ),
              _buildDetailRow(
                'Status Ketersediaan',
                item['status_ketersediaan'] ?? '-',
                badgeColor: isTersedia ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Tutup', style: GoogleFonts.inter(color: AppColors.textDark, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _printQr([item['id']], singleItem: item);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryMid,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.print_outlined, size: 16, color: Colors.white),
                      label: Text('Print QR', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _printQr(List<int> ids, {Map<String, dynamic>? singleItem}) async {
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu item untuk dicetak!')),
      );
      return;
    }

    final baseUrl = ApiClient.baseUrl.replaceAll('/api', '');
    final url = '$baseUrl/master-barang/print-qr?ids=${ids.join(',')}';

    if (singleItem != null) {
      final qrCode = (singleItem['kode_qr'] ?? '').toString();
      final barangName = (singleItem['barang']?['nama_barang'] ?? 'Barang').toString();
      final cabangName = (singleItem['cabang']?['nama_cabang'] ?? singleItem['cabang']?['nama'] ?? '').toString();
      final qrImageUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(qrCode)}';

      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMid.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.qr_code_2_rounded, color: AppColors.primaryMid, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Cetak QR Code',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // QR Sticker Card Preview
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          qrImageUrl,
                          width: 160,
                          height: 160,
                          fit: BoxFit.contain,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              width: 160,
                              height: 160,
                              color: Colors.grey.shade50,
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            width: 160,
                            height: 160,
                            color: Colors.grey.shade100,
                            child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        qrCode,
                        style: GoogleFonts.sourceCodePro(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        barangName,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                        textAlign: TextAlign.center,
                      ),
                      if (cabangName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          cabangName,
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Tutup', style: GoogleFonts.inter(color: AppColors.textDark, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } else {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Tidak dapat membuka halaman cetak PDF')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.print_outlined, size: 16, color: Colors.white),
                        label: Text('Print PDF', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryMid,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak dapat membuka halaman cetak PDF')),
          );
        }
      }
    }
  }

  Widget _buildDetailRow(String label, String value, {Color? badgeColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(width: 12),
          badgeColor != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: badgeColor)),
                )
              : Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                  ),
                ),
        ],
      ),
    );
  }

  // ==========================================
  // BUILD SCREEN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          GradientHeader(
            child: Row(
              children: [
                HeaderBackButton(onTap: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Master Barang & Aset',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Kelola kategori, barang & QR code fisik',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadDataForCurrentTab,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                  tooltip: 'Segarkan',
                ),
              ],
            ),
          ),
          
          // Modern Tab Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: TabBar(
              controller: _tabController,
              labelColor: _primaryPurple,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: _primaryPurple,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Icons.category_outlined, size: 18),
                  text: 'Kategori',
                ),
                Tab(
                  icon: Icon(Icons.inventory_2_outlined, size: 18),
                  text: 'Data Barang',
                ),
                Tab(
                  icon: Icon(Icons.qr_code_2_outlined, size: 18),
                  text: 'Item Fisik',
                ),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildKategoriTab(),
                _buildBarangTab(),
                _buildItemFisikTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: KATEGORI
  // ==========================================

  Widget _buildKategoriTab() {
    final filteredKategoris = _kategoris.where((k) {
      final name = (k['nama_kategori'] ?? '').toString().toLowerCase();
      final tipe = (k['tipe_tracking'] ?? '').toString().toLowerCase();
      return name.contains(_searchKategoriQuery.toLowerCase()) || tipe.contains(_searchKategoriQuery.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadKategori,
      color: _primaryPurple,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info Box
          _buildInfoBox(
            'Kategori barang dibagikan ke semua cabang. Silakan gunakan kategori yang sudah ada atau buat kategori baru.',
          ),
          const SizedBox(height: 14),

          // Search Bar & Add Button
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchKategoriQuery = v),
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Cari kategori...',
                      hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _showAddEditKategoriDialog(),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: Text('Tambah', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoadingKategori)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (filteredKategoris.isEmpty)
            _buildEmptyState('Tidak ada kategori ditemukan', Icons.category_outlined)
          else
            ...filteredKategoris.map((k) {
              final isKuantitas = k['tipe_tracking'] == 'kuantitas';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isKuantitas ? Colors.amber.shade50 : _primaryPurple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isKuantitas ? Icons.format_list_numbered_rounded : Icons.qr_code_2_rounded,
                        color: isKuantitas ? Colors.amber.shade800 : _primaryPurple,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            k['nama_kategori'] ?? '-',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isKuantitas ? Colors.amber.shade50 : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isKuantitas ? 'Kuantitas (Habis Pakai)' : 'Per Item (QR Code)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isKuantitas ? Colors.amber.shade900 : Colors.blue.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                      onPressed: () => _showAddEditKategoriDialog(kategori: k),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      onPressed: () => _deleteKategori(k['id']),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _deleteKategori(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Kategori?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Kategori ini akan dihapus dari daftar sistem.', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final success = await MasterBarangService.deleteKategori(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Kategori berhasil dihapus' : 'Gagal menghapus kategori'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) _loadKategori();
    }
  }

  // ==========================================
  // TAB 2: DATA BARANG
  // ==========================================

  Widget _buildBarangTab() {
    final filteredBarangs = _barangs.where((b) {
      final name = (b['nama_barang'] ?? '').toString().toLowerCase();
      final kat = (b['kategori']?['nama_kategori'] ?? '').toString().toLowerCase();
      final satuan = (b['satuan'] ?? '').toString().toLowerCase();
      final matchSearch = name.contains(_searchBarangQuery.toLowerCase()) || kat.contains(_searchBarangQuery.toLowerCase()) || satuan.contains(_searchBarangQuery.toLowerCase());
      final matchKategori = _filterKategoriForBarang == null || b['kategori_id'] == _filterKategoriForBarang;
      return matchSearch && matchKategori;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadBarang,
      color: _tealAccent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info Box
          _buildInfoBox(
            'Nama barang dibagikan ke semua cabang agar data standar. Pastikan barang belum ada sebelum menambahkan.',
          ),
          const SizedBox(height: 14),

          // Search Bar & Add Button
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchBarangQuery = v),
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Cari nama barang / satuan...',
                      hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _showAddEditBarangDialog(),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: Text('Tambah', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tealAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Kategori Filter Dropdown
          if (_kategoris.isNotEmpty)
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _filterKategoriForBarang,
                  isExpanded: true,
                  hint: Text('Semua Kategori', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark)),
                  icon: const Icon(Icons.filter_list, size: 16, color: AppColors.textMuted),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Semua Kategori')),
                    ..._kategoris.map((k) => DropdownMenuItem<int?>(value: k['id'], child: Text(k['nama_kategori'] ?? ''))),
                  ],
                  onChanged: (val) => setState(() => _filterKategoriForBarang = val),
                ),
              ),
            ),
          const SizedBox(height: 16),

          if (_isLoadingBarang)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (filteredBarangs.isEmpty)
            _buildEmptyState('Tidak ada data barang ditemukan', Icons.inventory_2_outlined)
          else
            ...filteredBarangs.map((b) {
              final katName = b['kategori'] != null ? b['kategori']['nama_kategori'] : '-';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _tealAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.inventory_2_rounded, color: _tealAccent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b['nama_barang'] ?? '-',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  katName,
                                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _tealAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Satuan: ${b['satuan'] ?? '-'}',
                                  style: GoogleFonts.inter(fontSize: 11, color: _tealAccent, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                      onPressed: () => _showAddEditBarangDialog(barang: b),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      onPressed: () => _deleteBarang(b['id']),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _deleteBarang(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Barang?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Barang ini akan dihapus dari sistem master data.', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final success = await MasterBarangService.deleteBarang(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Barang berhasil dihapus' : 'Gagal menghapus barang'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) _loadBarang();
    }
  }

  // ==========================================
  // TAB 3: ITEM FISIK (QR CODE)
  // ==========================================

  Widget _buildItemFisikTab() {
    final filteredItems = _itemFisiks.where((item) {
      final qr = (item['kode_qr'] ?? '').toString().toLowerCase();
      final barangName = (item['barang']?['nama_barang'] ?? '').toString().toLowerCase();
      final cabangName = (item['cabang']?['nama_cabang'] ?? item['cabang']?['nama'] ?? '').toString().toLowerCase();
      return qr.contains(_searchItemFisikQuery.toLowerCase()) ||
          barangName.contains(_searchItemFisikQuery.toLowerCase()) ||
          cabangName.contains(_searchItemFisikQuery.toLowerCase());
    }).toList();

    final allSelected = filteredItems.isNotEmpty && filteredItems.every((it) => _selectedItemFisikIds.contains(it['id']));

    return RefreshIndicator(
      onRefresh: _loadItemFisik,
      color: _primaryPurple,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info Box
          _buildInfoBox(
            'Daftar item fisik khusus per cabang. Tambahkan stok fisik baru untuk men-generate kode QR stiker alat.',
          ),
          const SizedBox(height: 14),

          // Search Bar & Filter Cabang
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchItemFisikQuery = v),
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Cari Kode QR / Barang...',
                      hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (!_isOperasionalOrAdmin && _userCabangId != null)
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMid.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primaryMid.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, size: 15, color: AppColors.primaryMid),
                      const SizedBox(width: 4),
                      Text(
                        _userCabangName.isNotEmpty ? _userCabangName : 'Cabang $_userCabangId',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryMid),
                      ),
                    ],
                  ),
                )
              else if (_cabangs.isNotEmpty)
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _filterCabangForItemFisik,
                      hint: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark)),
                      icon: const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Semua Cabang')),
                        ..._cabangs.map((c) => DropdownMenuItem<int?>(
                              value: c['id'],
                              child: Text(c['nama_cabang'] ?? c['nama'] ?? 'Cabang ${c['id']}'),
                            )),
                      ],
                      onChanged: (val) {
                        setState(() => _filterCabangForItemFisik = val);
                        _loadItemFisik();
                      },
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Action Buttons Bar (Print QR & Tambah Stok)
          Row(
            children: [
              if (_selectedItemFisikIds.isNotEmpty)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _printQr(_selectedItemFisikIds.toList()),
                    icon: const Icon(Icons.print_outlined, size: 16, color: Colors.white),
                    label: Text(
                      'Print QR Terpilih (${_selectedItemFisikIds.length})',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryMid,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                  ),
                )
              else
                Expanded(
                  child: Row(
                    children: [
                      Checkbox(
                        value: allSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedItemFisikIds.addAll(filteredItems.map((e) => e['id'] as int));
                            } else {
                              _selectedItemFisikIds.clear();
                            }
                          });
                        },
                        activeColor: _primaryPurple,
                      ),
                      Text('Pilih Semua', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showAddItemFisikDialog,
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: Text('Tambah Stok (QR)', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_isLoadingItemFisik)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (filteredItems.isEmpty)
            _buildEmptyState('Tidak ada item fisik ditemukan', Icons.qr_code_2_outlined)
          else
            ...filteredItems.map((item) {
              final barang = item['barang'];
              final cabang = item['cabang'];
              final isBaik = item['kondisi_terakhir'] == 'Baik';
              final isTersedia = item['status_ketersediaan'] == 'Tersedia';
              final isSelected = _selectedItemFisikIds.contains(item['id']);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _primaryPurple : AppColors.border.withValues(alpha: 0.6),
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top QR badge + checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedItemFisikIds.add(item['id']);
                              } else {
                                _selectedItemFisikIds.remove(item['id']);
                              }
                            });
                          },
                          activeColor: _primaryPurple,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _primaryPurple.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.qr_code, size: 14, color: _primaryPurple),
                              const SizedBox(width: 4),
                              Text(
                                item['kode_qr'] ?? '-',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryPurple),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => _showDetailItemFisik(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Detail', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                                const SizedBox(width: 2),
                                const Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Barang Name & Cabang
                    Text(
                      barang != null ? barang['nama_barang'] : '-',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 13, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          cabang != null ? (cabang['nama_cabang'] ?? cabang['nama'] ?? 'Cabang ${cabang['id']}') : 'Global',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Badges & Delete Button
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isBaik ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item['kondisi_terakhir'] ?? 'Baik',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isBaik ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isTersedia ? Colors.blue.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item['status_ketersediaan'] ?? 'Tersedia',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isTersedia ? Colors.blue.shade800 : Colors.orange.shade800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => _printQr([item['id']], singleItem: item),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryMid.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.primaryMid.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.print_outlined, size: 13, color: AppColors.primaryMid),
                                const SizedBox(width: 4),
                                Text(
                                  'Print QR',
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryMid),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () => _deleteItemFisik(item['id']),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _deleteItemFisik(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Item Fisik?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Item fisik dan kode QR ini akan dihapus dari sistem.', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final success = await MasterBarangService.deleteItemFisik(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Item fisik berhasil dihapus' : 'Gagal menghapus item fisik'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) _loadItemFisik();
    }
  }

  // ==========================================
  // SHARED WIDGETS
  // ==========================================

  Widget _buildInfoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.primary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../services/pengadaan_barang_service.dart';

class PengadaanBarangFormSheet extends StatefulWidget {
  final VoidCallback onSave;

  const PengadaanBarangFormSheet({
    super.key,
    required this.onSave,
  });

  @override
  State<PengadaanBarangFormSheet> createState() => _PengadaanBarangFormSheetState();
}

class _PengadaanBarangFormSheetState extends State<PengadaanBarangFormSheet> {
  final _service = PengadaanBarangService();
  final _picker = ImagePicker();

  bool _isLoading = false;
  
  // Controllers
  final _tanggalController = TextEditingController();
  final _namaBarangController = TextEditingController();
  final _merkController = TextEditingController();
  final _jumlahController = TextEditingController(text: '1');
  final _satuanLainnyaController = TextEditingController();
  final _alasanController = TextEditingController();

  String _jenisPembelian = 'Alat';
  final List<String> _jenisOptions = ['Alat', 'Chemical', 'BHP'];

  String _tingkatUrgensi = 'Rendah (Biasa)';
  final List<String> _urgensiOptions = [
    'Rendah (Biasa)',
    'Sedang',
    'Tinggi (Mendesak)',
    'Darurat'
  ];

  String _satuan = 'Pcs';
  final List<String> _satuanOptions = [
    'Pcs',
    'Botol',
    'Jerigen',
    'Unit',
    'Pack',
    'Roll',
    'Kg',
    'Liter',
    'Lainnya'
  ];

  // Branch & User info
  int? _cabangId;
  String _cabangName = 'Surabaya';
  List<dynamic> _cabangs = [];

  // Photos (up to 5)
  final List<File?> _photos = [null, null, null, null, null];

  @override
  void initState() {
    super.initState();
    _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadUserBranch();
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _namaBarangController.dispose();
    _merkController.dispose();
    _jumlahController.dispose();
    _satuanLainnyaController.dispose();
    _alasanController.dispose();
    super.dispose();
  }

  Future<void> _loadUserBranch() async {
    final prefs = await SharedPreferences.getInstance();
    final userCabangId = prefs.getInt('user_cabang_id');
    final userCabangName = prefs.getString('user_cabang_name') ?? '';

    if (userCabangId != null) {
      setState(() {
        _cabangId = userCabangId;
        if (userCabangName.isNotEmpty) _cabangName = userCabangName;
      });
    }

    try {
      final cabangs = await _service.getCabangs();
      if (mounted) {
        setState(() {
          _cabangs = cabangs;
          if (_cabangId == null && _cabangs.isNotEmpty) {
            _cabangId = _cabangs.first['id'];
            _cabangName = _cabangs.first['nama_cabang'] ?? _cabangs.first['nama'] ?? 'Cabang $_cabangId';
          } else if (_cabangId != null && _cabangs.isNotEmpty) {
            final found = _cabangs.firstWhere((c) => c['id'] == _cabangId, orElse: () => null);
            if (found != null) {
              _cabangName = found['nama_cabang'] ?? found['nama'] ?? _cabangName;
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _pickImage(int index) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pilih Sumber Foto ${index + 1}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primaryMid),
                title: Text('Kamera', style: GoogleFonts.inter(fontSize: 14)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                  if (picked != null) {
                    setState(() => _photos[index] = File(picked.path));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primaryMid),
                title: Text('Galeri', style: GoogleFonts.inter(fontSize: 14)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (picked != null) {
                    setState(() => _photos[index] = File(picked.path));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_namaBarangController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama Barang wajib diisi!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_merkController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merk / Spesifikasi wajib diisi!'), backgroundColor: Colors.red),
      );
      return;
    }

    final jumlah = int.tryParse(_jumlahController.text.trim()) ?? 0;
    if (jumlah <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah barang minimal 1!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_satuan == 'Lainnya' && _satuanLainnyaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Satuan lainnya wajib diisi!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_alasanController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alasan Pengajuan wajib diisi!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_photos[0] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto 1 (Minimal 1 Foto) wajib diunggah sebagai bukti!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'tanggal_pengajuan': _tanggalController.text,
        'cabang_id': _cabangId ?? 1,
        'jenis_pembelian': _jenisPembelian,
        'nama_barang': _namaBarangController.text.trim(),
        'merk_spesifikasi': _merkController.text.trim(),
        'jumlah': jumlah,
        'satuan': _satuan == 'Lainnya' ? 'Other' : _satuan,
        'satuan_lainnya': _satuan == 'Lainnya' ? _satuanLainnyaController.text.trim() : null,
        'alasan_pengajuan': _alasanController.text.trim(),
        'tingkat_urgensi': _tingkatUrgensi,
      };

      final res = await _service.createPengajuan(
        data: data,
        photos: _photos,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Pengajuan berhasil disimpan'), backgroundColor: Colors.green),
        );
        widget.onSave();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMid.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryMid, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Form Pengadaan Barang',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        Text(
                          'Permintaan barang operasional cabang',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Form Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. INFORMASI PENGAJUAN
                  _buildSectionContainer(
                    icon: Icons.calendar_today_outlined,
                    title: 'Informasi Pengajuan',
                    subtitle: 'Informasi tanggal dan cabang sudah terisi otomatis oleh sistem.',
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            'Tanggal Pengajuan',
                            _tanggalController,
                            readOnly: true,
                            suffixIcon: Icons.calendar_month_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Nama Cabang', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                              const SizedBox(height: 6),
                              Container(
                                height: 46,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _cabangName,
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. DETAIL BARANG DIMINTA
                  _buildSectionContainer(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Detail Barang Diminta',
                    subtitle: 'Spesifikasikan barang yang Anda butuhkan dengan jelas.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Jenis Pembelian & Tingkat Urgensi
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      text: 'Jenis Pembelian',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                      children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 46,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _jenisPembelian,
                                        isExpanded: true,
                                        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w500),
                                        items: _jenisOptions.map((j) => DropdownMenuItem(value: j, child: Text(j))).toList(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => _jenisPembelian = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      text: 'Tingkat Urgensi',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                      children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 46,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _tingkatUrgensi,
                                        isExpanded: true,
                                        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w500),
                                        items: _urgensiOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => _tingkatUrgensi = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Nama Barang
                        _buildTextField(
                          'Nama Barang',
                          _namaBarangController,
                          required: true,
                          hintText: 'Contoh: Sapu Lidi, Obat Kaca, Kanebo',
                        ),

                        const SizedBox(height: 14),

                        // Merk / Spesifikasi
                        _buildTextField(
                          'Merk / Spesifikasi',
                          _merkController,
                          required: true,
                          hintText: 'Contoh: Swallow, 500ml, Standar KlinKlin',
                        ),

                        const SizedBox(height: 14),

                        // Jumlah & Satuan
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildTextField(
                                'Jumlah',
                                _jumlahController,
                                required: true,
                                keyboardType: TextInputType.number,
                                hintText: '1',
                                suffixIcon: Icons.numbers,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      text: 'Satuan',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                      children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 46,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _satuan,
                                        isExpanded: true,
                                        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                                        items: _satuanOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => _satuan = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        if (_satuan == 'Lainnya') ...[
                          const SizedBox(height: 14),
                          _buildTextField(
                            'Satuan Lainnya',
                            _satuanLainnyaController,
                            required: true,
                            hintText: 'Tuliskan satuan lainnya (misal: Box, Galon)',
                          ),
                        ],

                        const SizedBox(height: 14),

                        // Alasan Pengajuan
                        _buildTextField(
                          'Alasan Pengajuan',
                          _alasanController,
                          required: true,
                          maxLines: 3,
                          hintText: 'Ceritakan singkat mengapa barang ini perlu diajukan...',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3. FOTO BUKTI BARANG LAMA / RUSAK
                  _buildSectionContainer(
                    icon: Icons.photo_camera_outlined,
                    title: 'Foto Barang Lama / Rusak',
                    subtitle: 'Unggah foto sebagai bukti pengajuan Anda.',
                    badge: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        'MINIMAL 1 FOTO WAJIB',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Row 1: Foto 1, Foto 2, Foto 3
                        Row(
                          children: [
                            Expanded(child: _buildPhotoSlot(0, 'Foto 1 *', required: true)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildPhotoSlot(1, 'Foto 2')),
                            const SizedBox(width: 8),
                            Expanded(child: _buildPhotoSlot(2, 'Foto 3')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Row 2: Foto 4, Foto 5
                        Row(
                          children: [
                            Expanded(child: _buildPhotoSlot(3, 'Foto 4')),
                            const SizedBox(width: 8),
                            Expanded(child: _buildPhotoSlot(4, 'Foto 5')),
                            const SizedBox(width: 8),
                            const Expanded(child: SizedBox()), // spacer
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Batal', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryMid,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text('Simpan Pengajuan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
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

  Widget _buildPhotoSlot(int index, String label, {bool required = false}) {
    final photo = _photos[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark),
            children: required ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))] : [],
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pickImage(index),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 86,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: photo != null ? AppColors.primaryMid : Colors.grey.shade300, style: photo != null ? BorderStyle.solid : BorderStyle.solid),
            ),
            child: photo != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.file(
                          photo,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () => setState(() => _photos[index] = null),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 22, color: Colors.grey.shade500),
                      const SizedBox(height: 4),
                      Text('+ Pilih File', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryMid)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionContainer({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryMid.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: AppColors.primaryMid),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        if (badge != null) badge,
                      ],
                    ),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool required = false,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hintText,
    IconData? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
            children: required ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))] : [],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              suffixIcon: suffixIcon != null ? Icon(suffixIcon, size: 18, color: Colors.grey.shade500) : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }
}

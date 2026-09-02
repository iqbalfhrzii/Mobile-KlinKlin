import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';
import '../services/pembelian_bhp_service.dart';
import '../../../core/utils/image_compress_helper.dart';

class PembelianBhpFormSheet extends StatefulWidget {
  final VoidCallback onSave;

  const PembelianBhpFormSheet({
    super.key,
    required this.onSave,
  });

  @override
  State<PembelianBhpFormSheet> createState() => _PembelianBhpFormSheetState();
}

class _PembelianBhpFormSheetState extends State<PembelianBhpFormSheet> {
  final _service = PembelianBhpService();
  final _picker = ImagePicker();

  bool _isLoading = false;

  final _tanggalController = TextEditingController();
  final _namaBarangController = TextEditingController();
  final _merkController = TextEditingController();
  final _tokoController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _customSatuanController = TextEditingController();

  String _selectedSatuan = 'Pcs';
  final List<String> _satuanOptions = [
    'Pcs',
    'Botol',
    'Jerigen',
    'Pack',
    'Unit',
    'Roll',
    'Kg',
    'Liter',
    'Dus',
    'Lainnya',
  ];

  File? _photo;

  @override
  void initState() {
    super.initState();
    _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _namaBarangController.dispose();
    _merkController.dispose();
    _tokoController.dispose();
    _qtyController.dispose();
    _customSatuanController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    DateTime initial = DateTime.now();
    try {
      initial = DateTime.parse(_tanggalController.text);
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryMid,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _tanggalController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  String _formatDisplayDate(String dateStr) {
    if (dateStr.isEmpty) return 'Pilih Tanggal';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    if (picked != null) {
      final compressed = await ImageCompressHelper.compressXFileIfNeeded(picked);
      if (compressed != null) {
        setState(() => _photo = compressed);
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              Text(
                'Pilih Sumber Foto Barang',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.camera);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryMid.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryMid, size: 26),
                            ),
                            const SizedBox(height: 10),
                            Text('Kamera', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.gallery);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981), size: 26),
                            ),
                            const SizedBox(height: 10),
                            Text('Galeri', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                          ],
                        ),
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
  }

  Future<void> _save() async {
    if (_namaBarangController.text.trim().isEmpty) {
      _showErrorDialog('Nama Barang / Bahan wajib diisi!');
      return;
    }

    if (_photo == null) {
      _showErrorDialog('Foto Bukti Barang Dibeli wajib dilampirkan!');
      return;
    }

    if (_merkController.text.trim().isEmpty) {
      _showErrorDialog('Merk Barang wajib diisi!');
      return;
    }

    if (_tokoController.text.trim().isEmpty) {
      _showErrorDialog('Nama Toko Tempat Beli wajib diisi!');
      return;
    }

    final qty = double.tryParse(_qtyController.text.trim()) ?? 0;
    if (qty <= 0) {
      _showErrorDialog('Qty / Jumlah Dibeli minimal 1!');
      return;
    }

    final finalSatuan = _selectedSatuan == 'Lainnya'
        ? _customSatuanController.text.trim()
        : _selectedSatuan;

    if (finalSatuan.isEmpty) {
      _showErrorDialog('Satuan barang wajib diisi!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'tanggal_pembelian': _tanggalController.text,
        'nama_barang': _namaBarangController.text.trim(),
        'merk_barang': _merkController.text.trim(),
        'toko_pembelian': _tokoController.text.trim(),
        'qty': qty,
        'satuan': finalSatuan,
      };

      final res = await _service.createPembelianBhp(
        data: data,
        photo: _photo!,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(res['message'] ?? 'Pembelian BHP berhasil dicatat!')),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
        widget.onSave();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _showErrorDialog(String message) {
    AppConfirmationDialog.show(
      context,
      title: 'Perhatian',
      message: message,
      type: ConfirmationDialogType.danger,
      confirmText: 'OK',
      cancelText: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
            padding: EdgeInsets.fromLTRB(20, 8, 12, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 16 : 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMid.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.primaryMid, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Catat Pembelian Baru',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      Text(
                        'Barang Habis Pakai (BHP)',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
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
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Form Scrollable Area
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Tanggal Pembelian
                  _buildLabel('Tanggal Pembelian', required: true),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _selectDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primaryMid),
                              const SizedBox(width: 10),
                              Text(
                                _formatDisplayDate(_tanggalController.text),
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Foto Bukti Barang Dibeli (Hero Upload Slot)
                  _buildLabel('Foto Bukti Barang Dibeli', required: true),
                  const SizedBox(height: 6),
                  if (_photo != null)
                    Container(
                      width: double.infinity,
                      height: 170,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primaryMid.withValues(alpha: 0.4)),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.file(_photo!, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: InkWell(
                              onTap: () => setState(() => _photo = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: InkWell(
                              onTap: _showImageSourcePicker,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.camera_alt_outlined, size: 12, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text('Ganti Foto', style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    InkWell(
                      onTap: _showImageSourcePicker,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryMid.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_a_photo_outlined, size: 24, color: AppColors.primaryMid),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Ambil Foto / Upload Bukti Fisik',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryMid),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Format JPG/PNG bukti nota atau barang yang dibeli',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // 3. Nama Barang / Bahan
                  _buildLabel('Nama Barang / Bahan', required: true),
                  const SizedBox(height: 6),
                  _buildInputField(
                    controller: _namaBarangController,
                    hintText: 'Contoh: Sabun Cuci Piring, Kain Lap, Sikat',
                    prefixIcon: Icons.shopping_bag_outlined,
                  ),

                  const SizedBox(height: 16),

                  // 4. Merk Barang
                  _buildLabel('Merk Barang', required: true),
                  const SizedBox(height: 6),
                  _buildInputField(
                    controller: _merkController,
                    hintText: 'Contoh: Sunlight, Wipol, Stella, dll',
                    prefixIcon: Icons.branding_watermark_outlined,
                  ),

                  const SizedBox(height: 16),

                  // 5. Nama Toko Tempat Beli
                  _buildLabel('Nama Toko Tempat Beli', required: true),
                  const SizedBox(height: 6),
                  _buildInputField(
                    controller: _tokoController,
                    hintText: 'Contoh: Indomaret, Toko Plastik Jaya, Alfamart',
                    prefixIcon: Icons.storefront_outlined,
                  ),

                  const SizedBox(height: 16),

                  // 6. Qty & Satuan
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Qty
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Jumlah (Qty)', required: true),
                            const SizedBox(height: 6),
                            _buildInputField(
                              controller: _qtyController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              hintText: '1',
                              prefixIcon: Icons.numbers_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Satuan Dropdown
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Satuan', required: true),
                            const SizedBox(height: 6),
                            Container(
                              height: 46,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedSatuan,
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                  items: _satuanOptions.map((s) {
                                    return DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedSatuan = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Custom Satuan input if "Lainnya" chosen
                  if (_selectedSatuan == 'Lainnya') ...[
                    const SizedBox(height: 12),
                    _buildInputField(
                      controller: _customSatuanController,
                      hintText: 'Ketik nama satuan khusus...',
                      prefixIcon: Icons.edit_note_rounded,
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Footer Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Batal', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
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
                              const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                              const SizedBox(width: 6),
                              Text('Simpan Pembelian', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
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

  Widget _buildLabel(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
        children: required ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))] : [],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
    IconData? prefixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: AppColors.primaryMid) : null,
        ),
      ),
    );
  }
}

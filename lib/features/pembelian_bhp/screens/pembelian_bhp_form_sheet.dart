import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../services/pembelian_bhp_service.dart';

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
  final _satuanController = TextEditingController(text: 'Pcs');

  File? _photo;

  final List<String> _commonSatuan = ['Pcs', 'Botol', 'Jerigen', 'Pack', 'Unit', 'Roll', 'Kg', 'Liter'];

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
    _satuanController.dispose();
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

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pilih Sumber Foto Barang', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primaryMid),
                title: Text('Kamera', style: GoogleFonts.inter(fontSize: 14)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                  if (picked != null) {
                    setState(() => _photo = File(picked.path));
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
                    setState(() => _photo = File(picked.path));
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
        const SnackBar(content: Text('Nama Barang / Bahan wajib diisi!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto Barang Dibeli wajib diunggah!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_merkController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merk Barang wajib diisi!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_tokoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama Toko Tempat Beli wajib diisi!'), backgroundColor: Colors.red),
      );
      return;
    }

    final qty = double.tryParse(_qtyController.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Qty / Jumlah Dibeli minimal 1!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_satuanController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Satuan barang wajib diisi!'), backgroundColor: Colors.red),
      );
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
        'satuan': _satuanController.text.trim(),
      };

      final res = await _service.createPembelianBhp(
        data: data,
        photo: _photo!,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Pembelian BHP berhasil disimpan'), backgroundColor: Colors.green),
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
                      child: const Icon(Icons.shopping_cart_outlined, color: AppColors.primaryMid, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Catat Pembelian Baru',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        Text(
                          'Pembelian Barang Habis Pakai (BHP)',
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

          // Form Fields
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Tanggal Pembelian
                  _buildLabel('Tanggal Pembelian', required: true),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _selectDate,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _tanggalController.text.isNotEmpty ? _tanggalController.text : 'Pilih Tanggal',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w500),
                          ),
                          const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primaryMid),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Nama Barang / Bahan
                  _buildLabel('Nama Barang / Bahan', required: true),
                  const SizedBox(height: 6),
                  _buildInputField(
                    controller: _namaBarangController,
                    hintText: 'Contoh: Sabun Cuci Piring, Kain Lap, Sikat',
                  ),

                  const SizedBox(height: 16),

                  // 3. Foto Barang Dibeli
                  _buildLabel('Foto Barang Dibeli', required: true),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      height: _photo != null ? 180 : 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _photo != null ? AppColors.primaryMid : Colors.grey.shade300,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: _photo != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.file(
                                    _photo!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: InkWell(
                                    onTap: () => setState(() => _photo = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryMid.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt_outlined, size: 26, color: AppColors.primaryMid),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Klik untuk upload foto',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryMid),
                                ),
                                Text(
                                  'Bukti fisik barang yang baru dibeli',
                                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Merk Barang
                  _buildLabel('Merk Barang', required: true),
                  const SizedBox(height: 6),
                  _buildInputField(
                    controller: _merkController,
                    hintText: 'Contoh: Sunlight, Wipol, Stella, dll',
                  ),

                  const SizedBox(height: 16),

                  // 5. Nama Toko Tempat Beli
                  _buildLabel('Nama Toko Tempat Beli', required: true),
                  const SizedBox(height: 6),
                  _buildInputField(
                    controller: _tokoController,
                    hintText: 'Contoh: Indomaret, Toko Plastik Jaya, Alfamart',
                  ),

                  const SizedBox(height: 16),

                  // 6. Qty & Satuan
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Qty / Jumlah Dibeli', required: true),
                            const SizedBox(height: 6),
                            _buildInputField(
                              controller: _qtyController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              hintText: '1',
                              prefixIcon: Icons.numbers,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Satuan', required: true),
                            const SizedBox(height: 6),
                            _buildInputField(
                              controller: _satuanController,
                              hintText: 'Pcs, Botol, Pack...',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Quick Satuan Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _commonSatuan.map((s) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(s),
                            labelStyle: GoogleFonts.inter(fontSize: 10, color: AppColors.textDark),
                            backgroundColor: Colors.grey.shade100,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onPressed: () {
                              setState(() => _satuanController.text = s);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Footer Action Bar
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
                              const Icon(Icons.check, size: 18, color: Colors.white),
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
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
        children: required ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))] : [],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(fontSize: 13),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: Colors.grey.shade500) : null,
        ),
      ),
    );
  }
}

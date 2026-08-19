import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/api/api_client.dart';
import '../services/uang_kas_service.dart';

class CashflowFormSheet extends StatefulWidget {
  final dynamic item;
  final int cabangId;
  final VoidCallback onSave;

  const CashflowFormSheet({
    super.key,
    this.item,
    required this.cabangId,
    required this.onSave,
  });

  @override
  State<CashflowFormSheet> createState() => _CashflowFormSheetState();
}

class _CashflowFormSheetState extends State<CashflowFormSheet> {
  final _service = UangKasService();
  final _picker = ImagePicker();

  bool _isLoading = false;

  final _tanggalController = TextEditingController();
  final _kategoriController = TextEditingController();
  final _nominalController = TextEditingController();
  final _metodeController = TextEditingController(text: 'cash');
  final _keteranganController = TextEditingController();

  String _arus = 'Masuk';

  File? _fileBukti;
  String? _existingBuktiUrl;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      final i = widget.item;
      _tanggalController.text = i['tanggal'] != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(i['tanggal'].toString())) : DateFormat('yyyy-MM-dd').format(DateTime.now());
      _arus = (i['arus'] ?? 'Masuk').toString().contains('Keluar') ? 'Keluar' : 'Masuk';
      _kategoriController.text = i['kategori_kas'] ?? '';
      _nominalController.text = (i['nominal'] ?? '').toString();
      _metodeController.text = i['metode'] ?? 'cash';
      _keteranganController.text = i['keterangan'] ?? '';
      if (i['bukti'] != null && i['bukti'].toString().isNotEmpty) {
        _existingBuktiUrl = i['bukti'].toString();
      }
    } else {
      _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _kategoriController.dispose();
    _nominalController.dispose();
    _metodeController.dispose();
    _keteranganController.dispose();
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

  Future<void> _pickBukti() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pilih Sumber Bukti Transaksi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primaryMid),
                title: Text('Kamera', style: GoogleFonts.inter(fontSize: 14)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                  if (picked != null) {
                    setState(() {
                      _fileBukti = File(picked.path);
                      _existingBuktiUrl = null;
                    });
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
                    setState(() {
                      _fileBukti = File(picked.path);
                      _existingBuktiUrl = null;
                    });
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
    final nominal = double.tryParse(_nominalController.text.trim().replaceAll('.', '').replaceAll(',', '')) ?? 0;
    if (nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal wajib diisi dan lebih dari 0!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'tanggal': _tanggalController.text,
        'cabang_id': widget.cabangId,
        'arus': _arus,
        'kategori_kas': _kategoriController.text.trim().isNotEmpty ? _kategoriController.text.trim() : null,
        'nominal': nominal,
        'metode': _metodeController.text.trim().isNotEmpty ? _metodeController.text.trim() : 'cash',
        'keterangan': _keteranganController.text.trim().isNotEmpty ? _keteranganController.text.trim() : null,
      };

      if (widget.item != null) {
        await _service.updateCashflow(widget.item['id'], data, file: _fileBukti);
      } else {
        await _service.createCashflow(data, file: _fileBukti);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.item != null ? 'Data cashflow berhasil diperbarui' : 'Data cashflow berhasil disimpan'),
            backgroundColor: Colors.green,
          ),
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
    final isEdit = widget.item != null;

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
                      child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primaryMid, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Data Cashflow Cabang' : 'Tambah Data Cashflow Cabang',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        Text(
                          'Catat pemasukan atau pengeluaran kas',
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
                  Text('TRANSAKSI', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5)),
                  const SizedBox(height: 12),

                  // Row: Tanggal & Arus
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tanggal
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Tanggal', required: true),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _selectDate,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 46,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _tanggalController.text,
                                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w500),
                                    ),
                                    const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primaryMid),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Arus
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Arus', required: true),
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
                                  value: _arus,
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w600),
                                  items: const [
                                    DropdownMenuItem(value: 'Masuk', child: Text('Masuk (Pemasukan)')),
                                    DropdownMenuItem(value: 'Keluar', child: Text('Keluar (Pengeluaran)')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _arus = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Kategori Kas & Nominal
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kategori Kas
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Kategori Kas'),
                            const SizedBox(height: 6),
                            _buildInputField(
                              controller: _kategoriController,
                              hintText: 'Contoh: customer, operasional',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Nominal
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Nominal', required: true),
                            const SizedBox(height: 6),
                            _buildInputField(
                              controller: _nominalController,
                              keyboardType: TextInputType.number,
                              hintText: 'Rp 200000',
                              prefixText: 'Rp ',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Metode Pembayaran
                  _buildLabel('Metode Pembayaran'),
                  const SizedBox(height: 6),
                  _buildInputField(
                    controller: _metodeController,
                    hintText: 'Contoh: cash, transfer bca, qris',
                  ),

                  const SizedBox(height: 16),

                  // Keterangan
                  _buildLabel('Keterangan'),
                  const SizedBox(height: 6),
                  _buildInputField(
                    controller: _keteranganController,
                    maxLines: 3,
                    hintText: 'Tambahkan catatan jika diperlukan...',
                  ),

                  const SizedBox(height: 16),

                  // Bukti Transaksi
                  _buildLabel('Bukti Transaksi (Opsional)'),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickBukti,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: _fileBukti != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: Image.file(_fileBukti!, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: InkWell(
                                    onTap: () => setState(() => _fileBukti = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _existingBuktiUrl != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(9),
                                      child: Image.network(
                                        _existingBuktiUrl!.startsWith('http') ? _existingBuktiUrl! : '${ApiClient.baseUrl.replaceAll('/api', '')}/$_existingBuktiUrl',
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 30)),
                                      ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: InkWell(
                                        onTap: () => setState(() => _existingBuktiUrl = null),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
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
                                    const Icon(Icons.cloud_upload_outlined, size: 24, color: AppColors.primaryMid),
                                    const SizedBox(height: 4),
                                    Text('Klik untuk unggah bukti foto/nota', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryMid)),
                                  ],
                                ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Footer
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
                        : Text(isEdit ? 'Perbarui Data' : 'Simpan Data', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
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
    int maxLines = 1,
    TextInputType? keyboardType,
    String? prefixText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(fontSize: 13),
        decoration: InputDecoration(
          hintText: hintText,
          prefixText: prefixText,
          prefixStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        ),
      ),
    );
  }
}

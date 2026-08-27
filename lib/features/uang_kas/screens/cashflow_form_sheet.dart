import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';
import '../../../core/api/api_client.dart';
import '../services/uang_kas_service.dart';
import '../../../core/utils/image_compress_helper.dart';

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
  final _nominalController = TextEditingController();
  final _keteranganController = TextEditingController();

  String _arus = 'Masuk';
  String _metode = 'cash';
  String? _selectedKategori;

  final List<String> _kategoriOptions = [
    'Chemical',
    'Alat',
    'Operasional',
    'Pengajuan Uang Kas',
  ];

  File? _fileBukti;
  String? _existingBuktiUrl;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      final i = widget.item;
      _tanggalController.text = i['tanggal'] != null
          ? DateFormat('yyyy-MM-dd').format(DateTime.parse(i['tanggal'].toString()))
          : DateFormat('yyyy-MM-dd').format(DateTime.now());
      _arus = (i['arus'] ?? 'Masuk').toString().contains('Keluar') ? 'Keluar' : 'Masuk';
      final rawKat = i['kategori_kas']?.toString();
      if (rawKat != null && rawKat.isNotEmpty && rawKat != '-' && rawKat.toLowerCase() != 'null') {
        _selectedKategori = rawKat;
        if (!_kategoriOptions.contains(rawKat)) {
          _kategoriOptions.add(rawKat);
        }
      } else {
        _selectedKategori = null;
      }
      _nominalController.text = (i['nominal'] ?? '').toString();
      _metode = (i['metode'] ?? 'cash').toString().toLowerCase().contains('transfer') ? 'transfer' : 'cash';
      _keteranganController.text = i['keterangan'] ?? '';
      if (i['bukti'] != null && i['bukti'].toString().isNotEmpty) {
        _existingBuktiUrl = i['bukti'].toString();
      }
    } else {
      _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _selectedKategori = null;
    }
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _nominalController.dispose();
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

  String _formatDisplayDate(String dateStr) {
    if (dateStr.isEmpty) return 'Pilih Tanggal';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final baseUrl = ApiClient.baseUrl.replaceAll('/api', '');
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    if (cleanPath.startsWith('storage/')) {
      return '$baseUrl/$cleanPath';
    }
    return '$baseUrl/storage/$cleanPath';
  }

  Future<void> _pickBukti(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    if (picked != null) {
      final compressed = await ImageCompressHelper.compressXFileIfNeeded(picked);
      if (compressed != null) {
        setState(() {
          _fileBukti = compressed;
          _existingBuktiUrl = null;
        });
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
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
              Text('Pilih Sumber Bukti Transaksi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickBukti(ImageSource.camera);
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
                        _pickBukti(ImageSource.gallery);
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
    final nominal = double.tryParse(_nominalController.text.trim().replaceAll('.', '').replaceAll(',', '')) ?? 0;
    if (nominal <= 0) {
      _showErrorDialog('Nominal transaksi wajib diisi dan harus lebih dari 0!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'tanggal': _tanggalController.text,
        'cabang_id': widget.cabangId,
        'arus': _arus,
        'kategori_kas': _selectedKategori != null && _selectedKategori!.isNotEmpty ? _selectedKategori : null,
        'nominal': nominal,
        'metode': _metode,
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
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.item != null ? 'Data cashflow berhasil diperbarui' : 'Data cashflow berhasil dicatat!')),
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
    final isEdit = widget.item != null;

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
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMid.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primaryMid, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Edit Data Cashflow' : 'Catat Transaksi Cashflow',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      Text(
                        'Pemasukan dan pengeluaran uang kas cabang',
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

          // Form Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Segmented Arus Switcher
                  _buildLabel('Jenis Arus Kas', required: true),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _arus = 'Masuk'),
                            borderRadius: BorderRadius.circular(9),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _arus == 'Masuk' ? const Color(0xFF16A34A) : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _arus == 'Masuk'
                                    ? [
                                        BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2)),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_downward_rounded, size: 16, color: _arus == 'Masuk' ? Colors.white : const Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Kas Masuk (Pemasukan)',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: _arus == 'Masuk' ? FontWeight.bold : FontWeight.w600,
                                      color: _arus == 'Masuk' ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _arus = 'Keluar'),
                            borderRadius: BorderRadius.circular(9),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _arus == 'Keluar' ? const Color(0xFFDC2626) : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _arus == 'Keluar'
                                    ? [
                                        BoxShadow(color: const Color(0xFFDC2626).withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2)),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_upward_rounded, size: 16, color: _arus == 'Keluar' ? Colors.white : const Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Kas Keluar (Pengeluaran)',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: _arus == 'Keluar' ? FontWeight.bold : FontWeight.w600,
                                      color: _arus == 'Keluar' ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Tanggal Transaksi
                  _buildLabel('Tanggal Transaksi', required: true),
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

                  // 3. Nominal (Rp)
                  _buildLabel('Nominal (Rp)', required: true),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _nominalController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 15),
                        prefixText: 'Rp ',
                        prefixStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryMid),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Kategori Kas (Dropdown)
                  _buildLabel('Kategori Kas'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedKategori,
                        isExpanded: true,
                        hint: Text(
                          'Pilih Kategori (Opsional)',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500),
                        ),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'Pilih Kategori (Opsional)',
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500),
                            ),
                          ),
                          ..._kategoriOptions.map((kat) {
                            return DropdownMenuItem<String?>(
                              value: kat,
                              child: Text(
                                kat,
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w500),
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedKategori = val;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 5. Metode Pembayaran
                  _buildLabel('Metode Pembayaran', required: true),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _metode = 'cash'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _metode == 'cash' ? AppColors.primaryMid.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _metode == 'cash' ? AppColors.primaryMid : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.payments_outlined, size: 16, color: _metode == 'cash' ? AppColors.primaryMid : const Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text(
                                  'Tunai (Cash)',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: _metode == 'cash' ? FontWeight.bold : FontWeight.w500,
                                    color: _metode == 'cash' ? AppColors.primaryMid : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _metode = 'transfer'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _metode == 'transfer' ? AppColors.primaryMid.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _metode == 'transfer' ? AppColors.primaryMid : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.account_balance_outlined, size: 16, color: _metode == 'transfer' ? AppColors.primaryMid : const Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text(
                                  'Transfer Bank',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: _metode == 'transfer' ? FontWeight.bold : FontWeight.w500,
                                    color: _metode == 'transfer' ? AppColors.primaryMid : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 6. Keterangan
                  _buildLabel('Keterangan / Rincian'),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _keteranganController,
                      maxLines: 2,
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: 'Contoh: Pembayaran invoice pesanan #1234 atau beli pulsa kantor',
                        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 7. Bukti Transaksi (Opsional)
                  _buildLabel('Bukti Transaksi (Opsional / Nota)'),
                  const SizedBox(height: 6),
                  if (_fileBukti != null || (_existingBuktiUrl != null && _existingBuktiUrl!.isNotEmpty))
                    Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: _fileBukti != null
                                ? Image.file(_fileBukti!, fit: BoxFit.cover)
                                : Image.network(_getImageUrl(_existingBuktiUrl), fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: InkWell(
                              onTap: () => setState(() {
                                _fileBukti = null;
                                _existingBuktiUrl = null;
                              }),
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
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.camera_alt_outlined, size: 20, color: AppColors.primaryMid),
                            const SizedBox(width: 8),
                            Text(
                              'Lampirkan Bukti / Nota (Opsional)',
                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primaryMid),
                            ),
                          ],
                        ),
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
                              Text(isEdit ? 'Perbarui Data' : 'Simpan Transaksi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
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
}

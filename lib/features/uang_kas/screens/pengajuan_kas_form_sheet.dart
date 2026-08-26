import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';
import '../services/uang_kas_service.dart';

class PengajuanKasFormSheet extends StatefulWidget {
  final dynamic item;
  final int cabangId;
  final VoidCallback onSave;

  const PengajuanKasFormSheet({
    super.key,
    this.item,
    required this.cabangId,
    required this.onSave,
  });

  @override
  State<PengajuanKasFormSheet> createState() => _PengajuanKasFormSheetState();
}

class _PengajuanKasFormSheetState extends State<PengajuanKasFormSheet> {
  final _service = UangKasService();

  bool _isLoading = false;

  final _tanggalController = TextEditingController();
  final _nominalController = TextEditingController();
  final _keteranganController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      final i = widget.item;
      _tanggalController.text = i['tanggal'] != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(i['tanggal'].toString())) : DateFormat('yyyy-MM-dd').format(DateTime.now());
      _nominalController.text = (i['nominal'] ?? '').toString();
      _keteranganController.text = i['keterangan'] ?? '';
    } else {
      _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
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

  Future<void> _save() async {
    final nominal = double.tryParse(_nominalController.text.trim().replaceAll('.', '').replaceAll(',', '')) ?? 0;
    if (nominal <= 0) {
      _showErrorDialog('Nominal permohonan dana wajib diisi dan harus lebih dari 0!');
      return;
    }

    if (_keteranganController.text.trim().isEmpty) {
      _showErrorDialog('Keterangan / Keperluan pengajuan dana wajib diisi!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'tanggal': _tanggalController.text,
        'cabang_id': widget.cabangId,
        'nominal': nominal,
        'keterangan': _keteranganController.text.trim(),
      };

      if (widget.item != null) {
        await _service.updatePengajuanKas(widget.item['id'], data);
      } else {
        await _service.createPengajuanKas(data);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.item != null ? 'Pengajuan kas berhasil diperbarui' : 'Pengajuan uang kas berhasil dibuat!')),
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
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.monetization_on_outlined, color: Color(0xFF10B981), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Edit Pengajuan Uang Kas' : 'Buat Pengajuan Uang Kas',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      Text(
                        'Permohonan dana operasional kas ke Finance',
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

          // Form Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pengajuan dana kas ini akan masuk ke antrean tim Finance untuk diverifikasi dan dicairkan via transfer bank.',
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF1E40AF), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 1. Tanggal Pengajuan
                  _buildLabel('Tanggal Pengajuan', required: true),
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

                  // 2. Nominal Permohonan (Rp)
                  _buildLabel('Nominal Permohonan (Rp)', required: true),
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
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 16),
                        prefixText: 'Rp ',
                        prefixStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Keterangan / Keperluan Dana
                  _buildLabel('Keterangan / Keperluan Dana', required: true),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _keteranganController,
                      maxLines: 3,
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: 'Contoh: Pengisian kas kecil cabang bulan ini untuk operasional laundry & kebersihan',
                        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(isEdit ? 'Perbarui Pengajuan' : 'Kirim Pengajuan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
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

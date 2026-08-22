import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../services/operasional_monthly_report_service.dart';

class OperasionalMonthlyReportFormSheet extends StatefulWidget {
  final dynamic initialData;
  final List<dynamic> cabangList;
  final VoidCallback onSave;

  const OperasionalMonthlyReportFormSheet({
    super.key,
    this.initialData,
    required this.cabangList,
    required this.onSave,
  });

  @override
  State<OperasionalMonthlyReportFormSheet> createState() => _OperasionalMonthlyReportFormSheetState();
}

class _OperasionalMonthlyReportFormSheetState extends State<OperasionalMonthlyReportFormSheet> {
  final _service = OperasionalMonthlyReportService();
  
  bool _isLoading = false;
  
  // Controllers
  final _periodeController = TextEditingController();
  final _judulController = TextEditingController();
  final _picController = TextEditingController();
  final _ringkasanController = TextEditingController();
  final _capaianController = TextEditingController();
  final _kendalaController = TextEditingController();
  final _rencanaController = TextEditingController();
  
  String? _selectedCabangId;
  String _statusLaporan = 'Draft';
  String? _selectedFilePath;
  String? _existingFilePath;

  final Color _primaryColor = AppColors.primaryMid; // #0284C7 / Theme primary

  @override
  void initState() {
    super.initState();
    _initData();
  }
  
  void _initData() {
    if (widget.initialData != null) {
      final data = widget.initialData;
      _periodeController.text = data['periode']?.toString().split(' ')[0] ?? '';
      _judulController.text = data['judul'] ?? '';
      _selectedCabangId = data['cabang_id']?.toString();
      _picController.text = data['pic'] ?? '';
      _ringkasanController.text = data['ringkasan'] ?? '';
      _capaianController.text = data['capaian'] ?? '';
      _kendalaController.text = data['kendala'] ?? '';
      _rencanaController.text = data['rencana_bulan_depan'] ?? '';
      final rawStatus = (data['status_laporan'] ?? data['status'] ?? 'Draft').toString().trim();
      if (rawStatus.toLowerCase().contains('proses') || rawStatus.toLowerCase().contains('submitted') || rawStatus.toLowerCase().contains('review')) {
        _statusLaporan = 'Proses';
      } else if (rawStatus.toLowerCase().contains('revisi')) {
        _statusLaporan = 'Revisi';
      } else if (rawStatus.toLowerCase().contains('selesai') || rawStatus.toLowerCase().contains('approved')) {
        _statusLaporan = 'Selesai';
      } else {
        _statusLaporan = 'Draft';
      }
      _existingFilePath = data['file_laporan'] ?? data['file_lampiran'] ?? data['file'];
    } else {
      _periodeController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  @override
  void dispose() {
    _periodeController.dispose();
    _judulController.dispose();
    _picController.dispose();
    _ringkasanController.dispose();
    _capaianController.dispose();
    _kendalaController.dispose();
    _rencanaController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime initial = DateTime.now();
    if (controller.text.isNotEmpty) {
      final parsed = DateTime.tryParse(controller.text);
      if (parsed != null) initial = parsed;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor, 
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
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'zip', 'jpg', 'jpeg', 'png'],
    );

    if (result != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
      });
    }
  }

  Future<void> _save() async {
    if (_periodeController.text.trim().isEmpty || _judulController.text.trim().isEmpty || _ringkasanController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap lengkapi semua field wajib bertanda bintang (*)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'periode': _periodeController.text.trim(),
      'judul': _judulController.text.trim(),
      'cabang_id': _selectedCabangId, // can be null for global
      'pic': _picController.text.trim(),
      'ringkasan': _ringkasanController.text.trim(),
      'capaian': _capaianController.text.trim(),
      'kendala': _kendalaController.text.trim(),
      'rencana_bulan_depan': _rencanaController.text.trim(),
      'status_laporan': _statusLaporan,
    };

    Map<String, dynamic> res;
    if (widget.initialData != null) {
      res = await _service.updateReport(widget.initialData['id'], data, filePath: _selectedFilePath);
    } else {
      res = await _service.storeReport(data, filePath: _selectedFilePath);
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (res['status'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Laporan bulanan berhasil disimpan'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onSave();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Gagal menyimpan laporan'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String? fileDisplayName;
    if (_selectedFilePath != null) {
      fileDisplayName = _selectedFilePath!.split('/').last.split('\\').last;
    } else if (_existingFilePath != null) {
      fileDisplayName = _existingFilePath!.split('/').last.split('\\').last;
    }

    String formattedPeriodeDisplay = 'Pilih Tanggal Periode...';
    if (_periodeController.text.isNotEmpty) {
      try {
        final dt = DateTime.parse(_periodeController.text);
        formattedPeriodeDisplay = DateFormat('dd MMMM yyyy (MMMM yyyy)').format(dt);
      } catch (_) {
        formattedPeriodeDisplay = _periodeController.text;
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Sheet Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 14, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.assessment_outlined, color: _primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.initialData != null ? 'Edit Laporan Bulanan' : 'Buat Laporan Bulanan',
                        style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Lengkapi form evaluasi dan capaian bulanan',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          
          // Form Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─────────────────────────────────────────────────────────
                  // SECTION 1: Informasi & Identitas Laporan
                  // ─────────────────────────────────────────────────────────
                  _buildSectionHeader(
                    icon: Icons.info_outline_rounded,
                    title: 'Informasi Laporan',
                    subtitle: 'Periode, judul, dan penanggung jawab laporan',
                  ),
                  const SizedBox(height: 14),

                  // Judul Laporan (Full Width)
                  _buildInputField(
                    label: 'Judul Laporan',
                    controller: _judulController,
                    required: true,
                    icon: Icons.title_rounded,
                    hint: 'Contoh: Laporan Kinerja Operasional Agustus 2026',
                  ),
                  const SizedBox(height: 14),

                  // Periode Picker (Full Width)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: 'Periode Laporan',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                          children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _selectDate(_periodeController),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month_rounded, size: 18, color: _primaryColor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  formattedPeriodeDisplay,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: _periodeController.text.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                                    color: _periodeController.text.isNotEmpty ? AppColors.textDark : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Pilih tanggal mana saja dalam bulan periode tersebut', style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade500)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Cabang Dropdown (Full Width)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cabang Operasional',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: widget.cabangList.any((c) => c['id'].toString() == _selectedCabangId) ? _selectedCabangId : null,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8)),
                            hint: Row(
                              children: [
                                const Icon(Icons.storefront_outlined, size: 18, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 10),
                                Text('-- Laporan Terpusat / Global --', style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF64748B))),
                              ],
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Row(
                                  children: [
                                    const Icon(Icons.public_rounded, size: 18, color: Color(0xFF0284C7)),
                                    const SizedBox(width: 10),
                                    Text('-- Laporan Terpusat / Global --', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF0284C7))),
                                  ],
                                ),
                              ),
                              ...widget.cabangList.map((c) => DropdownMenuItem<String>(
                                value: c['id'].toString(),
                                child: Row(
                                  children: [
                                    const Icon(Icons.storefront_outlined, size: 18, color: Color(0xFF64748B)),
                                    const SizedBox(width: 10),
                                    Text(c['nama_cabang'] ?? c['nama'] ?? '', style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textDark)),
                                  ],
                                ),
                              )),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedCabangId = val;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // PIC Penanggung Jawab (Full Width)
                  _buildInputField(
                    label: 'PIC (Penanggung Jawab)',
                    controller: _picController,
                    icon: Icons.person_outline_rounded,
                    hint: 'Nama PIC atau penanggung jawab laporan...',
                  ),
                  const SizedBox(height: 24),

                  // ─────────────────────────────────────────────────────────
                  // SECTION 2: Isi & Evaluasi Laporan
                  // ─────────────────────────────────────────────────────────
                  _buildSectionHeader(
                    icon: Icons.article_outlined,
                    title: 'Isi & Evaluasi Laporan',
                    subtitle: 'Ringkasan, capaian, kendala, dan rencana bulan depan',
                  ),
                  const SizedBox(height: 14),

                  // Ringkasan Laporan (Full Width Textarea)
                  _buildTextAreaField(
                    label: 'Ringkasan Laporan',
                    controller: _ringkasanController,
                    required: true,
                    minLines: 3,
                    maxLines: 6,
                    icon: Icons.notes_rounded,
                    hint: 'Ringkasan atau kesimpulan umum laporan operasional pada periode ini...',
                  ),
                  const SizedBox(height: 16),

                  // Capaian (Achievements) (Full Width Textarea)
                  _buildTextAreaField(
                    label: 'Capaian (Achievements)',
                    controller: _capaianController,
                    minLines: 3,
                    maxLines: 6,
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: const Color(0xFF16A34A),
                    hint: 'Apa saja target atau hasil positif yang berhasil dicapai...',
                  ),
                  const SizedBox(height: 16),

                  // Kendala (Issues) (Full Width Textarea)
                  _buildTextAreaField(
                    label: 'Kendala & Hambatan (Issues)',
                    controller: _kendalaController,
                    minLines: 3,
                    maxLines: 6,
                    icon: Icons.warning_amber_rounded,
                    iconColor: const Color(0xFFD97706),
                    hint: 'Kendala, masalah operasional, atau hambatan yang dialami...',
                  ),
                  const SizedBox(height: 16),

                  // Rencana Bulan Depan (Full Width Textarea)
                  _buildTextAreaField(
                    label: 'Rencana Bulan Depan (Action Plan)',
                    controller: _rencanaController,
                    minLines: 3,
                    maxLines: 6,
                    icon: Icons.trending_up_rounded,
                    iconColor: const Color(0xFF2563EB),
                    hint: 'Langkah strategis atau target tindak lanjut untuk bulan depan...',
                  ),
                  const SizedBox(height: 24),

                  // ─────────────────────────────────────────────────────────
                  // SECTION 3: Status & Dokumen Pendukung
                  // ─────────────────────────────────────────────────────────
                  _buildSectionHeader(
                    icon: Icons.attach_file_rounded,
                    title: 'Status & Berkas Lampiran',
                    subtitle: 'Status dokumen dan unggahan file pendukung',
                  ),
                  const SizedBox(height: 14),

                  // Status Laporan Selector
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status Laporan',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusCard(
                              value: 'Draft',
                              label: 'Draft',
                              color: const Color(0xFF64748B),
                              icon: Icons.edit_note_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatusCard(
                              value: 'Proses',
                              label: 'Sedang Diproses',
                              color: const Color(0xFF2563EB),
                              icon: Icons.autorenew_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusCard(
                              value: 'Revisi',
                              label: 'Perlu Revisi',
                              color: const Color(0xFFDC2626),
                              icon: Icons.rate_review_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatusCard(
                              value: 'Selesai',
                              label: 'Selesai / Approved',
                              color: const Color(0xFF16A34A),
                              icon: Icons.check_circle_outline_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // File Lampiran Box (Modern Full Width Upload Tile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File Laporan Tambahan / Lampiran',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickFile,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: fileDisplayName != null ? _primaryColor.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: fileDisplayName != null ? _primaryColor.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
                              width: fileDisplayName != null ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: fileDisplayName != null ? _primaryColor.withValues(alpha: 0.12) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Icon(
                                  fileDisplayName != null ? Icons.insert_drive_file_rounded : Icons.cloud_upload_outlined,
                                  color: fileDisplayName != null ? _primaryColor : const Color(0xFF64748B),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fileDisplayName ?? 'Pilih Berkas Lampiran',
                                      style: GoogleFonts.inter(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: fileDisplayName != null ? AppColors.textDark : const Color(0xFF334155),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      fileDisplayName != null ? 'Ketuk untuk mengganti file' : 'Format: PDF, Word, Excel, ZIP, Gambar (Maks. 10MB)',
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              if (_selectedFilePath != null) ...[
                                IconButton(
                                  icon: const Icon(Icons.cancel_rounded, color: Colors.red, size: 20),
                                  onPressed: () => setState(() => _selectedFilePath = null),
                                  tooltip: 'Hapus file terpilih',
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(
                                    'Pilih File',
                                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: _primaryColor),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          
          // Bottom Action Footer
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF64748B), fontSize: 13.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _save,
                      icon: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                      label: Text(
                        _isLoading ? 'Menyimpan...' : 'Simpan Laporan',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Helper Widgets
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF475569)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    bool required = false,
    IconData? icon,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
            children: required ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))] : [],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textDark),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF94A3B8)) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextAreaField({
    required String label,
    required TextEditingController controller,
    bool required = false,
    int minLines = 3,
    int maxLines = 6,
    IconData? icon,
    Color? iconColor,
    String? hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: iconColor ?? const Color(0xFF64748B)),
                const SizedBox(width: 6),
              ],
              RichText(
                text: TextSpan(
                  text: label,
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  children: required ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))] : [],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: controller,
              minLines: minLines,
              maxLines: maxLines,
              style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textDark, height: 1.45),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400, height: 1.4),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required String value,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = _statusLaporan == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _statusLaporan = value),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle_rounded : icon,
                size: 16,
                color: isSelected ? color : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? color : const Color(0xFF334155),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

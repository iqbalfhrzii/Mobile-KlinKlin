import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../services/operasional_kajian_rd_service.dart';

class OperasionalKajianRdFormSheet extends StatefulWidget {
  final dynamic initialData;
  final List<dynamic> cabangList;
  final VoidCallback onSave;

  const OperasionalKajianRdFormSheet({
    super.key,
    this.initialData,
    required this.cabangList,
    required this.onSave,
  });

  @override
  State<OperasionalKajianRdFormSheet> createState() => _OperasionalKajianRdFormSheetState();
}

class _OperasionalKajianRdFormSheetState extends State<OperasionalKajianRdFormSheet> {
  final _service = OperasionalKajianRdService();
  
  bool _isLoading = false;
  
  // Controllers
  final _tanggalController = TextEditingController();
  final _judulController = TextEditingController();
  final _kategoriController = TextEditingController();
  final _picController = TextEditingController();
  final _latarBelakangController = TextEditingController();
  final _metodeController = TextEditingController();
  final _hasilKajianController = TextEditingController();
  final _rekomendasiController = TextEditingController();
  final _estimasiBiayaController = TextEditingController();
  
  String? _selectedCabangId;
  String _statusKajian = 'Sedang Dikaji';
  String? _selectedFilePath;
  String? _existingFilePath;

  final Color _primaryColor = const Color(0xFF6366F1); // Indigo theme for R&D

  @override
  void initState() {
    super.initState();
    _initData();
  }
  
  void _initData() {
    if (widget.initialData != null) {
      final data = widget.initialData;
      _tanggalController.text = data['tanggal']?.toString().split(' ')[0] ?? '';
      _judulController.text = data['judul'] ?? '';
      _kategoriController.text = data['kategori'] ?? '';
      _selectedCabangId = data['cabang_id']?.toString();
      _picController.text = data['pic'] ?? '';
      _latarBelakangController.text = data['latar_belakang'] ?? '';
      _metodeController.text = data['metode'] ?? '';
      _hasilKajianController.text = data['hasil_kajian'] ?? '';
      _rekomendasiController.text = data['rekomendasi'] ?? '';
      _estimasiBiayaController.text = data['estimasi_biaya'] ?? '';
      
      final rawStatus = (data['status_kajian'] ?? data['status'] ?? 'Sedang Dikaji').toString().trim();
      if (rawStatus.toLowerCase().contains('menunggu')) {
        _statusKajian = 'Menunggu Persetujuan';
      } else if (rawStatus.toLowerCase().contains('disetujui') || rawStatus.toLowerCase().contains('diterima')) {
        _statusKajian = 'Disetujui';
      } else if (rawStatus.toLowerCase().contains('implementasi')) {
        _statusKajian = 'Implementasi';
      } else if (rawStatus.toLowerCase().contains('ditolak') || rawStatus.toLowerCase().contains('batal')) {
        _statusKajian = 'Ditolak';
      } else {
        _statusKajian = 'Sedang Dikaji';
      }

      _existingFilePath = data['lampiran'] ?? data['file_lampiran'] ?? data['file'];
    } else {
      _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _judulController.dispose();
    _kategoriController.dispose();
    _picController.dispose();
    _latarBelakangController.dispose();
    _metodeController.dispose();
    _hasilKajianController.dispose();
    _rekomendasiController.dispose();
    _estimasiBiayaController.dispose();
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
    if (_tanggalController.text.trim().isEmpty || _judulController.text.trim().isEmpty || _hasilKajianController.text.trim().isEmpty) {
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
      'tanggal': _tanggalController.text.trim(),
      'judul': _judulController.text.trim(),
      'kategori': _kategoriController.text.trim(),
      'cabang_id': _selectedCabangId, // can be null for global
      'pic': _picController.text.trim(),
      'latar_belakang': _latarBelakangController.text.trim(),
      'metode': _metodeController.text.trim(),
      'hasil_kajian': _hasilKajianController.text.trim(),
      'rekomendasi': _rekomendasiController.text.trim(),
      'estimasi_biaya': _estimasiBiayaController.text.trim(),
      'status_kajian': _statusKajian,
    };

    Map<String, dynamic> res;
    if (widget.initialData != null) {
      res = await _service.updateKajian(widget.initialData['id'], data, filePath: _selectedFilePath);
    } else {
      res = await _service.storeKajian(data, filePath: _selectedFilePath);
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (res['status'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Kajian R&D berhasil disimpan'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onSave();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Gagal menyimpan kajian R&D'),
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

    String formattedTanggalDisplay = 'Pilih Tanggal Kajian...';
    if (_tanggalController.text.isNotEmpty) {
      try {
        final dt = DateTime.parse(_tanggalController.text);
        formattedTanggalDisplay = DateFormat('dd MMMM yyyy').format(dt);
      } catch (_) {
        formattedTanggalDisplay = _tanggalController.text;
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
                  child: Icon(Icons.science_outlined, color: _primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.initialData != null ? 'Edit Kajian R&D' : 'Buat Kajian R&D Baru',
                        style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Form pengujian alat, chemical, dan metode operasional',
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
                  // SECTION 1: Informasi & Identitas Kajian
                  // ─────────────────────────────────────────────────────────
                  _buildSectionHeader(
                    icon: Icons.info_outline_rounded,
                    title: 'Informasi Kajian',
                    subtitle: 'Judul, tanggal, kategori, dan penanggung jawab kajian',
                  ),
                  const SizedBox(height: 14),

                  // Judul Kajian (Full Width)
                  _buildInputField(
                    label: 'Judul Kajian',
                    controller: _judulController,
                    required: true,
                    icon: Icons.title_rounded,
                    hint: 'Contoh: Pengujian Chemical Descaler Baru untuk Kerak Kaca',
                  ),
                  const SizedBox(height: 14),

                  // Tanggal Kajian (Full Width Date Picker)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: 'Tanggal Pengujian / Kajian',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                          children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _selectDate(_tanggalController),
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
                                  formattedTanggalDisplay,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: _tanggalController.text.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                                    color: _tanggalController.text.isNotEmpty ? AppColors.textDark : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Kategori Kajian (Full Width)
                  _buildInputField(
                    label: 'Kategori Kajian',
                    controller: _kategoriController,
                    icon: Icons.category_outlined,
                    hint: 'Mis. Chemical, Alat, Metode Kerja, SOP...',
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
                                Text('-- Kajian Terpusat / Global --', style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF64748B))),
                              ],
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Row(
                                  children: [
                                    const Icon(Icons.public_rounded, size: 18, color: Color(0xFF6366F1)),
                                    const SizedBox(width: 10),
                                    Text('-- Kajian Terpusat / Global --', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1))),
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

                  // PIC (Person In Charge) (Full Width)
                  _buildInputField(
                    label: 'PIC (Person In Charge)',
                    controller: _picController,
                    icon: Icons.person_outline_rounded,
                    hint: 'Nama penanggung jawab pengujian...',
                  ),
                  const SizedBox(height: 24),

                  // ─────────────────────────────────────────────────────────
                  // SECTION 2: Analisis & Hasil Pengujian
                  // ─────────────────────────────────────────────────────────
                  _buildSectionHeader(
                    icon: Icons.biotech_rounded,
                    title: 'Analisis & Hasil Pengujian',
                    subtitle: 'Latar belakang, metodologi, dan temuan pengujian',
                  ),
                  const SizedBox(height: 14),

                  // Latar Belakang (Full Width Textarea)
                  _buildTextAreaField(
                    label: 'Latar Belakang',
                    controller: _latarBelakangController,
                    minLines: 3,
                    maxLines: 6,
                    icon: Icons.help_outline_rounded,
                    hint: 'Mengapa pengujian / kajian ini diperlukan...',
                  ),
                  const SizedBox(height: 16),

                  // Metode (Full Width Textarea)
                  _buildTextAreaField(
                    label: 'Metode Pengujian',
                    controller: _metodeController,
                    minLines: 3,
                    maxLines: 6,
                    icon: Icons.science_outlined,
                    iconColor: const Color(0xFF2563EB),
                    hint: 'Cara, takaran, alat, atau metode yang digunakan dalam pengujian...',
                  ),
                  const SizedBox(height: 16),

                  // Hasil Kajian * (Full Width Textarea)
                  _buildTextAreaField(
                    label: 'Hasil Kajian',
                    controller: _hasilKajianController,
                    required: true,
                    minLines: 4,
                    maxLines: 8,
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: const Color(0xFF16A34A),
                    hint: 'Hasil temuan, data, efektivitas, dan kesimpulan dari pengujian...',
                  ),
                  const SizedBox(height: 16),

                  // Rekomendasi (Full Width Textarea)
                  _buildTextAreaField(
                    label: 'Rekomendasi Tindak Lanjut',
                    controller: _rekomendasiController,
                    minLines: 3,
                    maxLines: 6,
                    icon: Icons.recommend_outlined,
                    iconColor: const Color(0xFF0284C7),
                    hint: 'Saran implementasi, kelayakan penggunaan di cabang operasional...',
                  ),
                  const SizedBox(height: 16),

                  // Estimasi Biaya (Full Width)
                  _buildInputField(
                    label: 'Estimasi Biaya / Kelayakan Finansial',
                    controller: _estimasiBiayaController,
                    icon: Icons.payments_outlined,
                    hint: 'Mis. Rp 5.000.000 / Lebih hemat 20% dibanding sebelumnya',
                  ),
                  const SizedBox(height: 24),

                  // ─────────────────────────────────────────────────────────
                  // SECTION 3: Status & Lampiran Berkas
                  // ─────────────────────────────────────────────────────────
                  _buildSectionHeader(
                    icon: Icons.attach_file_rounded,
                    title: 'Status & Lampiran Berkas',
                    subtitle: 'Status persetujuan dan unggahan dokumen bukti',
                  ),
                  const SizedBox(height: 14),

                  // Status Kajian Selector (Modern Clean 2-Column Grid / List)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status Kajian',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 8),

                      // Row 1
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusCard(
                              value: 'Sedang Dikaji',
                              label: 'Sedang Dikaji / Tahap Pengujian',
                              color: const Color(0xFF2563EB),
                              icon: Icons.autorenew_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatusCard(
                              value: 'Menunggu Persetujuan',
                              label: 'Menunggu Persetujuan',
                              color: const Color(0xFFD97706),
                              icon: Icons.hourglass_empty_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Row 2
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusCard(
                              value: 'Disetujui',
                              label: 'Disetujui',
                              color: const Color(0xFF16A34A),
                              icon: Icons.check_circle_outline_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatusCard(
                              value: 'Implementasi',
                              label: 'Tahap Implementasi',
                              color: const Color(0xFF6366F1),
                              icon: Icons.rocket_launch_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Row 3 (Ditolak / Batal Full Width)
                      _buildStatusCard(
                        value: 'Ditolak',
                        label: 'Ditolak / Batal',
                        color: const Color(0xFFDC2626),
                        icon: Icons.cancel_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // File Lampiran Box (Modern Full Width Upload Tile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lampiran Dokumen Tambahan',
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
                                      fileDisplayName != null ? 'Ketuk untuk mengganti file' : 'Foto, PDF hasil lab, penawaran harga, atau presentasi (Maks. 10MB)',
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
                        _isLoading ? 'Menyimpan...' : 'Simpan Kajian',
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
    final isSelected = _statusKajian == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _statusKajian = value),
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

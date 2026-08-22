import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../services/operasional_evaluasi_rapat_service.dart';

class OperasionalEvaluasiRapatFormSheet extends StatefulWidget {
  final dynamic initialData;
  final List<dynamic> cabangList;
  final VoidCallback onSave;

  const OperasionalEvaluasiRapatFormSheet({
    super.key,
    this.initialData,
    required this.cabangList,
    required this.onSave,
  });

  @override
  State<OperasionalEvaluasiRapatFormSheet> createState() => _OperasionalEvaluasiRapatFormSheetState();
}

class _OperasionalEvaluasiRapatFormSheetState extends State<OperasionalEvaluasiRapatFormSheet> {
  final _service = OperasionalEvaluasiRapatService();
  
  bool _isLoading = false;
  
  // Controllers
  final _periodeController = TextEditingController();
  final _tanggalController = TextEditingController();
  final _pesertaController = TextEditingController();
  final _topikController = TextEditingController();
  final _kendalaController = TextEditingController();
  final _hasilEvaluasiController = TextEditingController();
  final _tindakLanjutController = TextEditingController();
  final _picController = TextEditingController();
  final _tenggatController = TextEditingController();
  
  String? _selectedCabangId;
  String _statusTindakLanjut = 'Belum';
  String? _selectedFilePath;
  String? _existingFilePath;

  @override
  void initState() {
    super.initState();
    _initData();
  }
  
  void _initData() {
    if (widget.initialData != null) {
      final data = widget.initialData;
      _periodeController.text = data['periode'] ?? '';
      _tanggalController.text = data['tanggal']?.toString().split(' ')[0] ?? '';
      _selectedCabangId = data['cabang_id']?.toString();
      _pesertaController.text = data['peserta'] ?? '';
      _topikController.text = data['topik'] ?? '';
      _kendalaController.text = data['kendala'] ?? '';
      _hasilEvaluasiController.text = data['hasil_evaluasi'] ?? '';
      _tindakLanjutController.text = data['tindak_lanjut'] ?? '';
      _picController.text = data['pic'] ?? '';
      _tenggatController.text = data['tenggat']?.toString().split(' ')[0] ?? '';
      _statusTindakLanjut = data['status_tindak_lanjut'] ?? 'Belum';
      _existingFilePath = data['notulen'];
    } else {
      _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _periodeController.text = DateFormat('MMMM yyyy').format(DateTime.now());
    }
  }

  @override
  void dispose() {
    _periodeController.dispose();
    _tanggalController.dispose();
    _pesertaController.dispose();
    _topikController.dispose();
    _kendalaController.dispose();
    _hasilEvaluasiController.dispose();
    _tindakLanjutController.dispose();
    _picController.dispose();
    _tenggatController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty ? (DateTime.tryParse(controller.text) ?? DateTime.now()) : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
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
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
    );

    if (result != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
      });
    }
  }

  Future<void> _save() async {
    if (_periodeController.text.isEmpty || _tanggalController.text.isEmpty || _selectedCabangId == null || _topikController.text.isEmpty || _hasilEvaluasiController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi field yang wajib (*)'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'periode': _periodeController.text,
      'tanggal': _tanggalController.text,
      'cabang_id': _selectedCabangId,
      'peserta': _pesertaController.text,
      'topik': _topikController.text,
      'kendala': _kendalaController.text,
      'hasil_evaluasi': _hasilEvaluasiController.text,
      'tindak_lanjut': _tindakLanjutController.text,
      'pic': _picController.text,
      'tenggat': _tenggatController.text.isNotEmpty ? _tenggatController.text : null,
      'status_tindak_lanjut': _statusTindakLanjut,
    };

    Map<String, dynamic> res;
    if (widget.initialData != null) {
      res = await _service.updateEvaluasiRapat(widget.initialData['id'], data, filePath: _selectedFilePath);
    } else {
      res = await _service.storeEvaluasiRapat(data, filePath: _selectedFilePath);
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (res['status'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Berhasil disimpan'), backgroundColor: Colors.green),
      );
      widget.onSave();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Gagal menyimpan'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool required = false,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
            children: required ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))] : [],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: readOnly && onTap == null ? const Color(0xFFF1F5F9) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            maxLines: maxLines,
            style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textDark),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              suffixIcon: onTap != null
                  ? const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B))
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String fileDisplay = 'Belum ada file dipilih';
    if (_selectedFilePath != null) {
      fileDisplay = _selectedFilePath!.split('/').last;
    } else if (_existingFilePath != null && _existingFilePath!.isNotEmpty) {
      fileDisplay = '1 file telah terlampir';
    }

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
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 38,
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
                  child: const Icon(Icons.description_rounded, color: AppColors.primaryMid, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.initialData != null ? 'Edit Evaluasi Rapat' : 'Tambah Evaluasi Rapat',
                    style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          
          // Scrollable Form Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SECTION 1: Informasi Rapat
                  _buildSectionHeader(Icons.info_outline_rounded, 'Informasi Rapat', AppColors.primaryMid),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField('Periode', _periodeController, required: true, hint: 'Cth: August 2026'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField('Tanggal', _tanggalController, required: true, readOnly: true, onTap: () => _selectDate(_tanggalController)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                text: 'Cabang',
                                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: widget.cabangList.any((c) => c['id'].toString() == _selectedCabangId) ? _selectedCabangId : null,
                                  isExpanded: true,
                                  hint: Text('Pilih Cabang', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
                                  items: widget.cabangList.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['nama_cabang'] ?? c['nama'] ?? '', style: GoogleFonts.inter(fontSize: 13)))).toList(),
                                  onChanged: (val) {
                                    setState(() => _selectedCabangId = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField('Peserta', _pesertaController, hint: 'Peserta hadir...'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 16),
                  
                  // SECTION 2: Evaluasi & Catatan
                  _buildSectionHeader(Icons.fact_check_outlined, 'Evaluasi & Kesimpulan', const Color(0xFF0284C7)),
                  const SizedBox(height: 12),

                  _buildTextField('Topik / Agenda', _topikController, required: true, maxLines: 2, hint: 'Topik pembahasan rapat...'),
                  const SizedBox(height: 12),
                  _buildTextField('Kendala', _kendalaController, maxLines: 2, hint: 'Kendala atau hambatan yang dibahas...'),
                  const SizedBox(height: 12),
                  _buildTextField('Hasil Evaluasi / Kesimpulan', _hasilEvaluasiController, required: true, maxLines: 3, hint: 'Kesimpulan dan hasil keputusan rapat...'),
                  
                  const SizedBox(height: 20),
                  
                  // SECTION 3: Tindak Lanjut & Notulen (Prominent Box)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(Icons.trending_up_rounded, 'Tindak Lanjut & Notulen', const Color(0xFF15803D)),
                        const SizedBox(height: 14),

                        _buildTextField('Tindak Lanjut', _tindakLanjutController, maxLines: 2, hint: 'Langkah konkrit yang akan diambil...'),
                        const SizedBox(height: 12),

                        // PIC
                        _buildTextField('PIC (Penanggung Jawab)', _picController, hint: 'Nama penanggung jawab tindak lanjut...'),
                        const SizedBox(height: 12),

                        // Tenggat Waktu & Status (Spacious 2-column layout so text never wraps!)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField('Tenggat Waktu', _tenggatController, readOnly: true, onTap: () => _selectDate(_tenggatController), hint: 'yyyy-mm-dd'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Status', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 44,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: const ['Belum', 'Proses', 'Selesai'].contains(_statusTindakLanjut) ? _statusTindakLanjut : 'Belum',
                                        isExpanded: true,
                                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w600),
                                        items: const [
                                          DropdownMenuItem(value: 'Belum', child: Text('Belum')),
                                          DropdownMenuItem(value: 'Proses', child: Text('Proses')),
                                          DropdownMenuItem(value: 'Selesai', child: Text('Selesai')),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) setState(() => _statusTindakLanjut = val);
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

                        // File Notulen
                        Text('File Notulen (Opsional)', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: _pickFile,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.only(topLeft: Radius.circular(9), bottomLeft: Radius.circular(9)),
                                    border: Border(right: BorderSide(color: Color(0xFFCBD5E1))),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.upload_file_rounded, size: 16, color: AppColors.primaryMid),
                                      const SizedBox(width: 6),
                                      Text('Pilih File', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primaryMid)),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    fileDisplay,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: fileDisplay == 'Belum ada file dipilih' ? const Color(0xFF94A3B8) : AppColors.textDark,
                                      fontWeight: fileDisplay == 'Belum ada file dipilih' ? FontWeight.normal : FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              if (_selectedFilePath != null)
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                                  onPressed: () => setState(() => _selectedFilePath = null),
                                )
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Format: PDF, Word, atau Gambar (Maks. 5MB)', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom Sticky Footer with SafeArea
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Batal', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryMid,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Simpan Perubahan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
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
}

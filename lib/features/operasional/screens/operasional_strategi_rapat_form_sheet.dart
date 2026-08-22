import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../services/operasional_strategi_rapat_service.dart';

class OperasionalStrategiRapatFormSheet extends StatefulWidget {
  final dynamic initialData;
  final List<dynamic> cabangList;
  final VoidCallback onSave;

  const OperasionalStrategiRapatFormSheet({
    super.key,
    this.initialData,
    required this.cabangList,
    required this.onSave,
  });

  @override
  State<OperasionalStrategiRapatFormSheet> createState() => _OperasionalStrategiRapatFormSheetState();
}

class _OperasionalStrategiRapatFormSheetState extends State<OperasionalStrategiRapatFormSheet> {
  final _service = OperasionalStrategiRapatService();
  
  bool _isLoading = false;
  
  // Controllers
  final _periodeController = TextEditingController();
  final _tanggalController = TextEditingController();
  final _strategiController = TextEditingController();
  final _latarBelakangController = TextEditingController();
  final _targetController = TextEditingController();
  final _indikatorController = TextEditingController();
  final _picController = TextEditingController();
  final _tenggatController = TextEditingController();
  
  String? _selectedCabangId;
  String _statusStrategi = 'Belum';
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
      _strategiController.text = data['strategi'] ?? '';
      _latarBelakangController.text = data['latar_belakang'] ?? '';
      _targetController.text = data['target'] ?? '';
      _indikatorController.text = data['indikator_keberhasilan'] ?? '';
      _picController.text = data['pic'] ?? '';
      _tenggatController.text = data['tenggat']?.toString().split(' ')[0] ?? '';
      _statusStrategi = data['status_strategi'] ?? 'Belum';
      _existingFilePath = data['lampiran'];
    } else {
      _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _periodeController.text = DateFormat('MMMM yyyy').format(DateTime.now());
    }
  }

  @override
  void dispose() {
    _periodeController.dispose();
    _tanggalController.dispose();
    _strategiController.dispose();
    _latarBelakangController.dispose();
    _targetController.dispose();
    _indikatorController.dispose();
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
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png'],
    );

    if (result != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
      });
    }
  }

  Future<void> _save() async {
    if (_periodeController.text.isEmpty || _tanggalController.text.isEmpty || _selectedCabangId == null || _strategiController.text.isEmpty) {
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
      'strategi': _strategiController.text,
      'latar_belakang': _latarBelakangController.text,
      'target': _targetController.text,
      'indikator_keberhasilan': _indikatorController.text,
      'pic': _picController.text,
      'tenggat': _tenggatController.text.isNotEmpty ? _tenggatController.text : null,
      'status_strategi': _statusStrategi,
    };

    Map<String, dynamic> res;
    if (widget.initialData != null) {
      res = await _service.updateStrategiRapat(widget.initialData['id'], data, filePath: _selectedFilePath);
    } else {
      res = await _service.storeStrategiRapat(data, filePath: _selectedFilePath);
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
                  child: const Icon(Icons.timeline_rounded, color: AppColors.primaryMid, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.initialData != null ? 'Edit Strategi Rapat' : 'Tambah Strategi Rapat',
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

                  Column(
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
                  
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 16),

                  // SECTION 2: Formulasi Strategi
                  _buildSectionHeader(Icons.track_changes_rounded, 'Formulasi Strategi', const Color(0xFF0284C7)),
                  const SizedBox(height: 12),

                  _buildTextField('Strategi', _strategiController, required: true, maxLines: 2, hint: 'Rumusan strategi yang disepakati...'),
                  const SizedBox(height: 12),
                  _buildTextField('Latar Belakang', _latarBelakangController, maxLines: 2, hint: 'Latar belakang & konteks strategi...'),
                  const SizedBox(height: 12),
                  _buildTextField('Target', _targetController, maxLines: 2, hint: 'Target spesifik dari strategi...'),
                  const SizedBox(height: 12),
                  _buildTextField('Indikator Keberhasilan', _indikatorController, maxLines: 2, hint: 'Parameter ukuran sukses...'),
                  
                  const SizedBox(height: 20),

                  // SECTION 3: Eksekusi & Status (Prominent Box)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(Icons.assignment_turned_in_rounded, 'Eksekusi & PIC', const Color(0xFF1D4ED8)),
                        const SizedBox(height: 14),

                        _buildTextField('PIC (Penanggung Jawab)', _picController, hint: 'Nama PIC...'),
                        const SizedBox(height: 12),

                        // Tenggat Waktu & Status (Spacious 2-column layout)
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
                                        value: const ['Belum', 'Proses', 'Selesai'].contains(_statusStrategi) ? _statusStrategi : 'Belum',
                                        isExpanded: true,
                                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w600),
                                        items: const [
                                          DropdownMenuItem(value: 'Belum', child: Text('Belum')),
                                          DropdownMenuItem(value: 'Proses', child: Text('Proses')),
                                          DropdownMenuItem(value: 'Selesai', child: Text('Selesai')),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) setState(() => _statusStrategi = val);
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

                        // File Lampiran
                        Text('Lampiran Dokumen (Opsional)', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
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
                        Text('Format: PDF, Word, Excel, JPG, PNG (Maks. 5MB)', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
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

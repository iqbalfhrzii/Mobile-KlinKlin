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

  final Color _indigoColor = const Color(0xFF4F46E5);

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
      _statusLaporan = data['status_laporan'] ?? 'Draft';
      _existingFilePath = data['file_laporan'];
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
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty ? (DateTime.tryParse(controller.text) ?? DateTime.now()) : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _indigoColor, 
              onPrimary: Colors.white,
              onSurface: Colors.black,
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
    if (_periodeController.text.isEmpty || _judulController.text.isEmpty || _ringkasanController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi field yang wajib (*)'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'periode': _periodeController.text,
      'judul': _judulController.text,
      'cabang_id': _selectedCabangId, // can be null for global
      'pic': _picController.text,
      'ringkasan': _ringkasanController.text,
      'capaian': _capaianController.text,
      'kendala': _kendalaController.text,
      'rencana_bulan_depan': _rencanaController.text,
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
        SnackBar(content: Text(res['message'] ?? 'Berhasil disimpan'), backgroundColor: Colors.green),
      );
      widget.onSave();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Gagal menyimpan'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool required = false, bool readOnly = false, VoidCallback? onTap, int maxLines = 1, String? hint, String? helper}) {
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
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: readOnly && onTap == null ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            maxLines: maxLines,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade400),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(helper, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500)),
        ]
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String fileDisplay = 'No file chosen';
    if (_selectedFilePath != null) {
      fileDisplay = _selectedFilePath!.split('/').last;
    } else if (_existingFilePath != null) {
      fileDisplay = _existingFilePath!.split('/').last;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.initialData != null ? 'Edit Laporan Bulanan' : 'Buat Laporan Bulanan',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField('Periode', _periodeController, required: true, readOnly: true, onTap: () => _selectDate(_periodeController), hint: 'mm/dd/yyyy', helper: 'Pilih tanggal mana saja dalam bulan tersebut'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField('Judul Laporan', _judulController, required: true, hint: 'Mis. Laporan Evaluasi Kinerja Karyawan...'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cabang', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                            const SizedBox(height: 8),
                            Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCabangId,
                                  isExpanded: true,
                                  hint: Text('-- Laporan Terpusat/Global --', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade400)),
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('-- Laporan Terpusat/Global --')),
                                    ...widget.cabangList.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['nama_cabang'] ?? c['nama'] ?? ''))),
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
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField('PIC (Penanggung Jawab)', _picController, hint: 'Nama PIC...'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  _buildTextField('Ringkasan Laporan', _ringkasanController, required: true, maxLines: 3, hint: 'Ringkasan atau kesimpulan umum laporan...'),
                  
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField('Capaian (Achievements)', _capaianController, maxLines: 3, hint: 'Apa yang telah dicapai pada periode ini...'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField('Kendala (Issues)', _kendalaController, maxLines: 3, hint: 'Kendala atau hambatan yang dialami...'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  _buildTextField('Rencana Bulan Depan', _rencanaController, maxLines: 3, hint: 'Langkah atau rencana selanjutnya...'),
                  
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status Laporan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                            const SizedBox(height: 8),
                            Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _statusLaporan,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                                    DropdownMenuItem(value: 'Submitted', child: Text('Submitted')),
                                    DropdownMenuItem(value: 'In Review', child: Text('In Review')),
                                    DropdownMenuItem(value: 'Selesai', child: Text('Selesai')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _statusLaporan = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('File Laporan Tambahan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  InkWell(
                                    onTap: _pickFile,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                                        border: Border(right: BorderSide(color: Colors.grey.shade300)),
                                      ),
                                      child: Text('Choose File', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _indigoColor)),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        fileDisplay,
                                        style: GoogleFonts.inter(fontSize: 12, color: fileDisplay == 'No file chosen' ? Colors.grey.shade500 : AppColors.textDark),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  if (_selectedFilePath != null)
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 14, color: Colors.red),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => setState(() => _selectedFilePath = null),
                                    ),
                                  const SizedBox(width: 4),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Format: PDF, Word, Excel, ZIP (Max. 10MB)', style: GoogleFonts.inter(fontSize: 9, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          // Footer Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Batal', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _indigoColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Simpan Laporan', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

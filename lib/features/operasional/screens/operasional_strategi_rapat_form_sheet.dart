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

  Widget _buildTextField(String label, TextEditingController controller, {bool required = false, bool readOnly = false, VoidCallback? onTap, int maxLines = 1, String? hint}) {
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
                Row(
                  children: [
                    const Icon(Icons.timeline, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      widget.initialData != null ? 'Edit Strategi Rapat' : 'Tambah Strategi Rapat',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                  ],
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
                    children: [
                      Expanded(
                        child: _buildTextField('Periode', _periodeController, required: true, hint: 'Contoh: August 2026'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField('Tanggal', _tanggalController, required: true, readOnly: true, onTap: () => _selectDate(_tanggalController)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: 'Cabang',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                          children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
                        ),
                      ),
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
                            hint: Text('Pilih Cabang', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade400)),
                            items: widget.cabangList.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['nama_cabang'] ?? c['nama'] ?? ''))).toList(),
                            onChanged: (val) {
                              setState(() => _selectedCabangId = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField('Strategi', _strategiController, required: true, hint: 'Strategi rapat...'),
                  const SizedBox(height: 16),
                  _buildTextField('Latar Belakang', _latarBelakangController, maxLines: 2, hint: 'Latar belakang strategi...'),
                  const SizedBox(height: 16),
                  _buildTextField('Target', _targetController, maxLines: 2, hint: 'Target dari strategi...'),
                  const SizedBox(height: 16),
                  _buildTextField('Indikator Keberhasilan', _indikatorController, maxLines: 2, hint: 'Indikator keberhasilan...'),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildTextField('PIC', _picController, hint: 'Nama PIC'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: _buildTextField('Tenggat', _tenggatController, readOnly: true, onTap: () => _selectDate(_tenggatController), hint: 'mm/dd/yyyy'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status Strategi', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                            const SizedBox(height: 8),
                            Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _statusStrategi,
                                  isExpanded: true,
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark),
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
                  
                  const SizedBox(height: 16),
                  Text('Lampiran', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                              border: Border(right: BorderSide(color: Colors.grey.shade300)),
                            ),
                            child: Text('Choose File', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              fileDisplay,
                              style: GoogleFonts.inter(fontSize: 14, color: fileDisplay == 'No file chosen' ? Colors.grey.shade500 : AppColors.textDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (_selectedFilePath != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.red),
                            onPressed: () => setState(() => _selectedFilePath = null),
                          )
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Format: PDF, Word, Excel, JPG, PNG (Max. 5MB)', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500)),
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
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Simpan Data', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

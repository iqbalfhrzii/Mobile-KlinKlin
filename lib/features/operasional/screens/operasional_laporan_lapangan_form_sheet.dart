import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../services/operasional_laporan_lapangan_service.dart';

class OperasionalLaporanLapanganFormSheet extends StatefulWidget {
  final dynamic initialData;
  final List<dynamic> cabangList;
  final VoidCallback onSave;

  const OperasionalLaporanLapanganFormSheet({
    super.key,
    this.initialData,
    required this.cabangList,
    required this.onSave,
  });

  @override
  State<OperasionalLaporanLapanganFormSheet> createState() => _OperasionalLaporanLapanganFormSheetState();
}

class _OperasionalLaporanLapanganFormSheetState extends State<OperasionalLaporanLapanganFormSheet> {
  final _service = OperasionalLaporanLapanganService();
  
  bool _isLoading = false;
  
  // Controllers
  final _tanggalController = TextEditingController();
  final _pelaporController = TextEditingController();
  final _lokasiController = TextEditingController();
  final _temuanController = TextEditingController();
  final _tindakanController = TextEditingController();
  final _picController = TextEditingController();
  final _tenggatController = TextEditingController();
  
  String? _selectedCabangId;
  String? _selectedTingkatRisiko;
  String? _selectedStatusTemuan;
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
      _tanggalController.text = data['tanggal']?.toString().split(' ')[0] ?? '';
      _selectedCabangId = data['cabang_id']?.toString();
      _pelaporController.text = data['pelapor'] ?? '';
      _lokasiController.text = data['lokasi'] ?? '';
      _temuanController.text = data['temuan'] ?? '';
      _selectedTingkatRisiko = data['tingkat_risiko'];
      _selectedStatusTemuan = data['status_temuan'];
      _tindakanController.text = data['tindakan_perbaikan'] ?? '';
      _picController.text = data['pic'] ?? '';
      _tenggatController.text = data['tenggat']?.toString().split(' ')[0] ?? '';
      _existingFilePath = data['foto'];
    } else {
      _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _pelaporController.dispose();
    _lokasiController.dispose();
    _temuanController.dispose();
    _tindakanController.dispose();
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
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
      });
    }
  }

  Future<void> _save() async {
    if (_tanggalController.text.isEmpty || _selectedCabangId == null || 
        _pelaporController.text.isEmpty || _lokasiController.text.isEmpty || _temuanController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi field yang wajib (*)'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'tanggal': _tanggalController.text,
      'cabang_id': _selectedCabangId,
      'pelapor': _pelaporController.text,
      'lokasi': _lokasiController.text,
      'temuan': _temuanController.text,
      'tingkat_risiko': _selectedTingkatRisiko,
      'status_temuan': _selectedStatusTemuan,
      'tindakan_perbaikan': _tindakanController.text,
      'pic': _picController.text,
      'tenggat': _tenggatController.text.isNotEmpty ? _tenggatController.text : null,
    };

    Map<String, dynamic> res;
    if (widget.initialData != null) {
      res = await _service.updateLaporanLapangan(widget.initialData['id'], data, filePath: _selectedFilePath);
    } else {
      res = await _service.storeLaporanLapangan(data, filePath: _selectedFilePath);
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

  Widget _buildTextField(String label, TextEditingController controller, {bool required = false, bool readOnly = false, VoidCallback? onTap, int maxLines = 1, String? hint, TextInputType? keyboardType}) {
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
            keyboardType: keyboardType,
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
                    const Icon(Icons.description_outlined, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      widget.initialData != null ? 'Edit Laporan Lapangan' : 'Tambah Laporan Lapangan',
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
                        child: _buildTextField('Tanggal', _tanggalController, required: true, readOnly: true, onTap: () => _selectDate(_tanggalController)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
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
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField('Pelapor', _pelaporController, required: true, hint: 'Nama pelapor...'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField('Lokasi', _lokasiController, required: true, hint: 'Lokasi spesifik temuan...'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  _buildTextField('Temuan', _temuanController, required: true, maxLines: 3, hint: 'Jelaskan temuan secara detail...'),
                  
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tingkat Risiko', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
                                  value: _selectedTingkatRisiko,
                                  isExpanded: true,
                                  hint: Text('Pilih Tingkat', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade400)),
                                  items: const [
                                    DropdownMenuItem(value: 'Rendah', child: Text('Rendah')),
                                    DropdownMenuItem(value: 'Sedang', child: Text('Sedang')),
                                    DropdownMenuItem(value: 'Menengah', child: Text('Menengah')),
                                    DropdownMenuItem(value: 'Tinggi', child: Text('Tinggi')),
                                    DropdownMenuItem(value: 'Kritis', child: Text('Kritis')),
                                  ],
                                  onChanged: (val) {
                                    setState(() => _selectedTingkatRisiko = val);
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
                            Text('Status Temuan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
                                  value: _selectedStatusTemuan,
                                  isExpanded: true,
                                  hint: Text('Pilih Status', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade400)),
                                  items: const [
                                    DropdownMenuItem(value: 'Open', child: Text('Open')),
                                    DropdownMenuItem(value: 'On Progress', child: Text('On Progress')),
                                    DropdownMenuItem(value: 'Closed', child: Text('Closed')),
                                    DropdownMenuItem(value: 'Baru', child: Text('Baru')),
                                    DropdownMenuItem(value: 'Proses', child: Text('Proses')),
                                    DropdownMenuItem(value: 'Tertunda', child: Text('Tertunda')),
                                    DropdownMenuItem(value: 'Selesai', child: Text('Selesai')),
                                  ],
                                  onChanged: (val) {
                                    setState(() => _selectedStatusTemuan = val);
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
                  _buildTextField('Tindakan Perbaikan', _tindakanController, maxLines: 2, hint: 'Rencana tindakan perbaikan...'),
                  
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField('PIC (Penanggung Jawab)', _picController, hint: 'Nama PIC...'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField('Tenggat Waktu', _tenggatController, readOnly: true, onTap: () => _selectDate(_tenggatController), hint: 'yyyy-mm-dd'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  Text('Foto / Lampiran', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
                            child: Text('Choose File', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red)),
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
                  Text('Format: Gambar/PDF/Word (Max. 5MB)', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500)),
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
                    backgroundColor: Colors.red,
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

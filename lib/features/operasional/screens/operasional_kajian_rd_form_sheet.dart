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
  String _statusKajian = 'Sedang Dikaji / Tahap Pengujian';
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
      _statusKajian = data['status_kajian'] ?? 'Sedang Dikaji / Tahap Pengujian';
      _existingFilePath = data['lampiran'];
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
    if (_tanggalController.text.isEmpty || _judulController.text.isEmpty || _hasilKajianController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi field yang wajib (*)'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'tanggal': _tanggalController.text,
      'judul': _judulController.text,
      'kategori': _kategoriController.text,
      'cabang_id': _selectedCabangId, // can be null for global
      'pic': _picController.text,
      'latar_belakang': _latarBelakangController.text,
      'metode': _metodeController.text,
      'hasil_kajian': _hasilKajianController.text,
      'rekomendasi': _rekomendasiController.text,
      'estimasi_biaya': _estimasiBiayaController.text,
      'status_kajian': _statusKajian,
    };

    Map<String, dynamic> res;
    if (widget.initialData != null) {
      res = await _service.updateKajian(widget.initialData['id'], data, filePath: _selectedFilePath);
    } else {
      res = await _service.storeKajian(data, filePath: _selectedFilePath);
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
                Row(
                  children: [
                    Icon(Icons.science_outlined, color: _indigoColor),
                    const SizedBox(width: 8),
                    Text(
                      widget.initialData != null ? 'Edit Kajian R&D' : 'Buat Kajian R&D',
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: _indigoColor),
                            const SizedBox(width: 8),
                            Text('Informasi Kajian', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _indigoColor)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildTextField('Tanggal', _tanggalController, required: true, readOnly: true, onTap: () => _selectDate(_tanggalController), hint: 'mm/dd/yyyy'),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField('Judul Kajian', _judulController, required: true, hint: 'Mis. Uji Coba Chemical Baru...'),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildTextField('Kategori Kajian', _kategoriController, hint: 'Mis. Chemical, Alat, Metode Kerja...'),
                            ),
                            const SizedBox(width: 16),
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
                                        hint: Text('-- Kajian Terpusat/Global --', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade400)),
                                        items: [
                                          const DropdownMenuItem(value: null, child: Text('-- Kajian Terpusat/Global --')),
                                          ...widget.cabangList.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['nama'] ?? ''))),
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
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        _buildTextField('PIC (Person In Charge)', _picController, hint: 'Nama penanggung jawab kajian...'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField('Latar Belakang', _latarBelakangController, maxLines: 3, hint: 'Mengapa kajian ini diperlukan...'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField('Metode', _metodeController, maxLines: 3, hint: 'Cara atau metode yang digunakan dalam pengujian...'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  _buildTextField('Hasil Kajian', _hasilKajianController, required: true, maxLines: 3, hint: 'Hasil temuan, data, dan kesimpulan dari pengujian yang telah dilakukan...'),
                  
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField('Rekomendasi', _rekomendasiController, maxLines: 3, hint: 'Saran tindak lanjut, kelayakan implementasi...'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            _buildTextField('Estimasi Biaya', _estimasiBiayaController, hint: 'Mis. Rp 5.000.000 / Layak secara finansial'),
                            const SizedBox(height: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Status Kajian', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
                                      value: _statusKajian,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(value: 'Sedang Dikaji / Tahap Pengujian', child: Text('Sedang Dikaji / Tahap Pengujian')),
                                        DropdownMenuItem(value: 'Selesai - Layak Implementasi', child: Text('Selesai - Layak Implementasi')),
                                        DropdownMenuItem(value: 'Selesai - Tidak Layak', child: Text('Selesai - Tidak Layak')),
                                        DropdownMenuItem(value: 'Batal / Ditunda', child: Text('Batal / Ditunda')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) setState(() => _statusKajian = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _indigoColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _indigoColor.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.attach_file, size: 16, color: _indigoColor),
                            const SizedBox(width: 8),
                            Text('Lampiran Dokumen Tambahan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Foto, PDF hasil lab, penawaran harga, atau presentasi (Max. 10MB)', style: GoogleFonts.inter(fontSize: 10, color: _indigoColor.withValues(alpha: 0.7))),
                        const SizedBox(height: 12),
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
                                    color: Colors.grey.shade50,
                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                                    border: Border(right: BorderSide(color: Colors.grey.shade300)),
                                  ),
                                  child: Text('Choose File', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _indigoColor)),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => setState(() => _selectedFilePath = null),
                                ),
                              const SizedBox(width: 4),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                      : Text('Simpan Kajian', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

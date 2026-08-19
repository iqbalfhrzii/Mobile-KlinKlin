import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/api/api_client.dart';
import '../services/operasional_kesehatan_berkala_service.dart';

class OperasionalKesehatanBerkalaFormSheet extends StatefulWidget {
  final dynamic initialData;
  final List<dynamic> cabangList;
  final VoidCallback onSave;

  const OperasionalKesehatanBerkalaFormSheet({
    super.key,
    this.initialData,
    required this.cabangList,
    required this.onSave,
  });

  @override
  State<OperasionalKesehatanBerkalaFormSheet> createState() => _OperasionalKesehatanBerkalaFormSheetState();
}

class _OperasionalKesehatanBerkalaFormSheetState extends State<OperasionalKesehatanBerkalaFormSheet> {
  final _service = OperasionalKesehatanBerkalaService();
  
  bool _isLoading = false;
  
  // Controllers
  final _tanggalController = TextEditingController();
  final _namaKaryawanController = TextEditingController();
  final _jabatanController = TextEditingController();
  final _jenisPemeriksaanController = TextEditingController();
  final _tempatPeriksaController = TextEditingController();
  final _catatanController = TextEditingController();
  final _rekomendasiController = TextEditingController();
  final _periksaBerikutnyaController = TextEditingController();
  
  String? _selectedCabangId;
  String? _selectedHasil;
  String? _selectedFilePath;
  String? _existingFilePath;

  List<dynamic> _karyawanList = [];
  String? _selectedKaryawanId;

  final Color _tealColor = const Color(0xFF0F766E);

  @override
  void initState() {
    super.initState();
    _initData();
  }
  
  void _initData() {
    if (widget.initialData != null) {
      final data = widget.initialData;
      _tanggalController.text = data['tanggal_periksa']?.toString().split(' ')[0] ?? '';
      _selectedCabangId = data['cabang_id']?.toString();
      _namaKaryawanController.text = data['nama_karyawan'] ?? '';
      _jabatanController.text = data['jabatan'] ?? '';
      _jenisPemeriksaanController.text = data['jenis_pemeriksaan'] ?? '';
      _tempatPeriksaController.text = data['tempat_periksa'] ?? '';
      _selectedHasil = data['hasil'];
      _catatanController.text = data['catatan_medis'] ?? '';
      _rekomendasiController.text = data['rekomendasi'] ?? '';
      _periksaBerikutnyaController.text = data['periksa_berikutnya']?.toString().split(' ')[0] ?? '';
      _existingFilePath = data['file_hasil'];
      
      if (_selectedCabangId != null) {
        _fetchKaryawan(_selectedCabangId!);
      }
    } else {
      _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _namaKaryawanController.dispose();
    _jabatanController.dispose();
    _jenisPemeriksaanController.dispose();
    _tempatPeriksaController.dispose();
    _catatanController.dispose();
    _rekomendasiController.dispose();
    _periksaBerikutnyaController.dispose();
    super.dispose();
  }

  Future<void> _fetchKaryawan(String cabangId) async {
    try {
      final res = await ApiClient.instance.get('/operasional/karyawans?cabang_id=$cabangId&per_page=100');
      if (res.data['status'] == true) {
        setState(() {
          _karyawanList = res.data['data']['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching karyawan: $e");
    }
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
              primary: _tealColor, 
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
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
      });
    }
  }

  Future<void> _save() async {
    if (_tanggalController.text.isEmpty || _selectedCabangId == null || _namaKaryawanController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi field yang wajib (*)'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'tanggal_periksa': _tanggalController.text,
      'cabang_id': _selectedCabangId,
      'nama_karyawan': _namaKaryawanController.text,
      'jabatan': _jabatanController.text,
      'jenis_pemeriksaan': _jenisPemeriksaanController.text,
      'tempat_periksa': _tempatPeriksaController.text,
      'hasil': _selectedHasil,
      'catatan_medis': _catatanController.text,
      'rekomendasi': _rekomendasiController.text,
      'periksa_berikutnya': _periksaBerikutnyaController.text.isNotEmpty ? _periksaBerikutnyaController.text : null,
    };

    Map<String, dynamic> res;
    if (widget.initialData != null) {
      res = await _service.updateDataKesehatanBerkala(widget.initialData['id'], data, filePath: _selectedFilePath);
    } else {
      res = await _service.storeDataKesehatanBerkala(data, filePath: _selectedFilePath);
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
                    Icon(Icons.monitor_heart_outlined, color: _tealColor),
                    const SizedBox(width: 8),
                    Text(
                      widget.initialData != null ? 'Edit Data Kesehatan' : 'Tambah Data Kesehatan',
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
                        child: _buildTextField('Tanggal Periksa', _tanggalController, required: true, readOnly: true, onTap: () => _selectDate(_tanggalController)),
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
                                      _selectedKaryawanId = null;
                                      if (val != null) _fetchKaryawan(val);
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pilih Dari Data Karyawan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      const SizedBox(height: 8),
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: _selectedCabangId == null ? Colors.grey.shade100 : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedKaryawanId,
                            isExpanded: true,
                            hint: Text(_selectedCabangId == null ? 'Pilih cabang terlebih dahulu' : 'Pilih karyawan...', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade400)),
                            items: _karyawanList.map((k) => DropdownMenuItem(value: k['id'].toString(), child: Text(k['nama'] ?? ''))).toList(),
                            onChanged: _selectedCabangId == null ? null : (val) {
                              setState(() {
                                _selectedKaryawanId = val;
                                final k = _karyawanList.firstWhere((element) => element['id'].toString() == val, orElse: () => null);
                                if (k != null) {
                                  _namaKaryawanController.text = k['nama'] ?? '';
                                  _jabatanController.text = k['jabatan']?['nama_jabatan'] ?? 'Cleaner';
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Otomatis mengisi Nama & Jabatan', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField('Nama Karyawan', _namaKaryawanController, required: true, hint: 'Nama lengkap...'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField('Jabatan', _jabatanController, hint: 'Jabatan...'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField('Jenis Pemeriksaan', _jenisPemeriksaanController, hint: 'Mis. MCU tahunan...'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField('Tempat Periksa', _tempatPeriksaController, hint: 'Klinik/Rumah Sakit...'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hasil', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
                            value: _selectedHasil,
                            isExpanded: true,
                            hint: Text('Pilih Hasil', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade400)),
                            items: const [
                              DropdownMenuItem(value: 'Sehat', child: Text('Sehat')),
                              DropdownMenuItem(value: 'Sehat dengan Catatan', child: Text('Sehat dengan Catatan')),
                              DropdownMenuItem(value: 'Perlu Tindak Lanjut', child: Text('Perlu Tindak Lanjut')),
                              DropdownMenuItem(value: 'Tidak Layak Kerja', child: Text('Tidak Layak Kerja')),
                              DropdownMenuItem(value: 'Kurang Sehat', child: Text('Kurang Sehat')),
                              DropdownMenuItem(value: 'Tidak Sehat', child: Text('Tidak Sehat')),
                              DropdownMenuItem(value: 'N/A', child: Text('N/A')),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedHasil = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  _buildTextField('Catatan Medis', _catatanController, maxLines: 3, hint: 'Detail catatan medis...'),
                  const SizedBox(height: 16),
                  _buildTextField('Rekomendasi', _rekomendasiController, maxLines: 2, hint: 'Rekomendasi dokter...'),
                  const SizedBox(height: 16),
                  _buildTextField('Periksa Berikutnya', _periksaBerikutnyaController, readOnly: true, onTap: () => _selectDate(_periksaBerikutnyaController), hint: 'mm/dd/yyyy'),
                  
                  const SizedBox(height: 16),
                  Text('File Hasil / Lampiran', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
                            child: Text('Choose File', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _tealColor)),
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
                    backgroundColor: _tealColor,
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

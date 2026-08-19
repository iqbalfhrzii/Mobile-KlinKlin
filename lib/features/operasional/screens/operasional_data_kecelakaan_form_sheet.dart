import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/api/api_client.dart';
import '../services/operasional_data_kecelakaan_service.dart';

class OperasionalDataKecelakaanFormSheet extends StatefulWidget {
  final dynamic initialData;
  final List<dynamic> cabangList;
  final VoidCallback onSave;

  const OperasionalDataKecelakaanFormSheet({
    super.key,
    this.initialData,
    required this.cabangList,
    required this.onSave,
  });

  @override
  State<OperasionalDataKecelakaanFormSheet> createState() => _OperasionalDataKecelakaanFormSheetState();
}

class _OperasionalDataKecelakaanFormSheetState extends State<OperasionalDataKecelakaanFormSheet> {
  final _service = OperasionalDataKecelakaanService();
  
  bool _isLoading = false;
  
  // Controllers
  final _tanggalController = TextEditingController();
  final _jamController = TextEditingController();
  final _lokasiController = TextEditingController();
  final _namaKaryawanController = TextEditingController();
  final _jabatanController = TextEditingController();
  final _kronologiController = TextEditingController();
  final _rincianController = TextEditingController();
  final _penyebabController = TextEditingController();
  final _bagianTubuhController = TextEditingController();
  final _penangananController = TextEditingController();
  final _dirujukKeController = TextEditingController();
  final _hkhController = TextEditingController();
  final _biayaController = TextEditingController();
  final _tindakanController = TextEditingController();
  
  String? _selectedCabangId;
  String? _selectedTingkat;
  String? _selectedFilePath;
  String? _existingFilePath;

  List<dynamic> _karyawanList = [];
  String? _selectedKaryawanId;

  @override
  void initState() {
    super.initState();
    _initData();
  }
  
  void _initData() {
    if (widget.initialData != null) {
      final data = widget.initialData;
      _tanggalController.text = data['tanggal']?.toString().split(' ')[0] ?? '';
      _jamController.text = data['jam'] ?? '';
      _selectedCabangId = data['cabang_id']?.toString();
      _lokasiController.text = data['lokasi'] ?? '';
      _namaKaryawanController.text = data['nama_karyawan'] ?? '';
      _jabatanController.text = data['jabatan'] ?? '';
      _selectedTingkat = data['tingkat'];
      _kronologiController.text = data['kronologi'] ?? '';
      _rincianController.text = data['rincian'] ?? '';
      _penyebabController.text = data['penyebab'] ?? '';
      _bagianTubuhController.text = data['bagian_tubuh_terluka'] ?? '';
      _penangananController.text = data['penanganan'] ?? '';
      _dirujukKeController.text = data['dirujuk_ke'] ?? '';
      _hkhController.text = data['hari_kerja_hilang']?.toString() ?? '';
      _biayaController.text = data['biaya_pengobatan']?.toString() ?? '';
      _tindakanController.text = data['tindakan_pencegahan'] ?? '';
      _existingFilePath = data['foto_kejadian'];
      
      if (_selectedCabangId != null) {
        _fetchKaryawan(_selectedCabangId!);
      }
    } else {
      _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _jamController.text = DateFormat('HH:mm').format(DateTime.now());
    }
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _jamController.dispose();
    _lokasiController.dispose();
    _namaKaryawanController.dispose();
    _jabatanController.dispose();
    _kronologiController.dispose();
    _rincianController.dispose();
    _penyebabController.dispose();
    _bagianTubuhController.dispose();
    _penangananController.dispose();
    _dirujukKeController.dispose();
    _hkhController.dispose();
    _biayaController.dispose();
    _tindakanController.dispose();
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
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
        _jamController.text = DateFormat('HH:mm').format(dt);
      });
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );

    if (result != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
      });
    }
  }

  Future<void> _save() async {
    if (_tanggalController.text.isEmpty || _selectedCabangId == null || _lokasiController.text.isEmpty || 
        _namaKaryawanController.text.isEmpty || _selectedTingkat == null || _kronologiController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi field yang wajib (*)'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'tanggal': _tanggalController.text,
      'jam': _jamController.text,
      'cabang_id': _selectedCabangId,
      'nama_karyawan': _namaKaryawanController.text,
      'jabatan': _jabatanController.text,
      'lokasi': _lokasiController.text,
      'tingkat': _selectedTingkat,
      'rincian': _rincianController.text,
      'kronologi': _kronologiController.text,
      'penyebab': _penyebabController.text,
      'bagian_tubuh_terluka': _bagianTubuhController.text,
      'penanganan': _penangananController.text,
      'dirujuk_ke': _dirujukKeController.text,
      'hari_kerja_hilang': _hkhController.text.isNotEmpty ? _hkhController.text : null,
      'biaya_pengobatan': _biayaController.text.isNotEmpty ? _biayaController.text : null,
      'tindakan_pencegahan': _tindakanController.text,
    };

    Map<String, dynamic> res;
    if (widget.initialData != null) {
      res = await _service.updateDataKecelakaan(widget.initialData['id'], data, filePath: _selectedFilePath);
    } else {
      res = await _service.storeDataKecelakaan(data, filePath: _selectedFilePath);
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
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      widget.initialData != null ? 'Edit Data Kecelakaan' : 'Tambah Data Kecelakaan',
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
                        child: _buildTextField('Jam Kejadian', _jamController, readOnly: true, onTap: () => _selectTime()),
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
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField('Lokasi', _lokasiController, required: true, hint: 'Lokasi kejadian...'),
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
                      Text('Otomatis mengisi Nama & Jabatan (bisa diedit manual jika tidak ada)', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: 'Tingkat',
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
                            value: _selectedTingkat,
                            isExpanded: true,
                            hint: Text('Pilih Tingkat', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade400)),
                            items: const [
                              DropdownMenuItem(value: 'Ringan', child: Text('Ringan')),
                              DropdownMenuItem(value: 'Sedang', child: Text('Sedang')),
                              DropdownMenuItem(value: 'Berat', child: Text('Berat')),
                              DropdownMenuItem(value: 'Fatal', child: Text('Fatal')),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedTingkat = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  _buildTextField('Kronologi', _kronologiController, required: true, maxLines: 3, hint: 'Ceritakan kronologi singkat kejadian...'),
                  const SizedBox(height: 16),
                  _buildTextField('Rincian Tambahan', _rincianController, maxLines: 2, hint: 'Rincian lainnya yang diperlukan...'),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField('Penyebab', _penyebabController, hint: 'Penyebab kejadian...'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField('Bagian Tubuh Terluka', _bagianTubuhController, hint: 'Contoh: Tangan kanan, Kaki kiri...'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  _buildTextField('Penanganan', _penangananController, maxLines: 2, hint: 'Pertolongan pertama atau penanganan yang dilakukan...'),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildTextField('Dirujuk Ke', _dirujukKeController, hint: 'Rumah Sakit / Klinik'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: _buildTextField('Hari Kerja Hilang', _hkhController, hint: '0', keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _buildTextField('Biaya Pengobatan', _biayaController, hint: 'Rp 0', keyboardType: TextInputType.number),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  _buildTextField('Tindakan Pencegahan', _tindakanController, maxLines: 2, hint: 'Langkah pencegahan agar tidak terulang...'),
                  
                  const SizedBox(height: 16),
                  Text('Foto Kejadian', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
                  Text('Format: JPG, PNG (Max. 5MB)', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500)),
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

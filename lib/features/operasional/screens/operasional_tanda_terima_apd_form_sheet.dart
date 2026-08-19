import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/api/api_client.dart';
import '../services/operasional_tanda_terima_apd_service.dart';

class OperasionalTandaTerimaApdFormSheet extends StatefulWidget {
  final dynamic initialData;
  final List<dynamic> cabangList;
  final VoidCallback onSave;

  const OperasionalTandaTerimaApdFormSheet({
    super.key,
    this.initialData,
    required this.cabangList,
    required this.onSave,
  });

  @override
  State<OperasionalTandaTerimaApdFormSheet> createState() => _OperasionalTandaTerimaApdFormSheetState();
}

class _OperasionalTandaTerimaApdFormSheetState extends State<OperasionalTandaTerimaApdFormSheet> {
  final _service = OperasionalTandaTerimaApdService();
  
  bool _isLoading = false;
  
  // Controllers
  final _tanggalController = TextEditingController();
  final _namaKaryawanController = TextEditingController();
  final _jabatanController = TextEditingController();
  final _namaBarangController = TextEditingController();
  final _jumlahController = TextEditingController(text: '1');
  final _satuanController = TextEditingController();
  final _ukuranController = TextEditingController();
  final _masaPakaiController = TextEditingController();
  final _diserahkanOlehController = TextEditingController();
  final _keteranganController = TextEditingController();
  
  String? _selectedCabangId;
  String? _selectedJenisApd;
  String? _selectedFilePath;
  String? _existingFilePath;

  List<dynamic> _karyawanList = [];
  String? _selectedKaryawanId;

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
      _selectedCabangId = data['cabang_id']?.toString();
      _namaKaryawanController.text = data['nama_karyawan'] ?? '';
      _jabatanController.text = data['jabatan'] ?? '';
      _selectedJenisApd = data['jenis_apd'];
      _namaBarangController.text = data['nama_barang'] ?? '';
      _jumlahController.text = data['jumlah']?.toString() ?? '1';
      _satuanController.text = data['satuan'] ?? '';
      _ukuranController.text = data['ukuran'] ?? '';
      _masaPakaiController.text = data['masa_pakai'] ?? '';
      _diserahkanOlehController.text = data['diserahkan_oleh'] ?? '';
      _keteranganController.text = data['keterangan'] ?? '';
      _existingFilePath = data['tanda_terima'];
      
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
    _namaBarangController.dispose();
    _jumlahController.dispose();
    _satuanController.dispose();
    _ukuranController.dispose();
    _masaPakaiController.dispose();
    _diserahkanOlehController.dispose();
    _keteranganController.dispose();
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
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
      });
    }
  }

  Future<void> _save() async {
    if (_tanggalController.text.isEmpty || _selectedCabangId == null || _namaKaryawanController.text.isEmpty || 
        _selectedJenisApd == null || _namaBarangController.text.isEmpty || _jumlahController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi field yang wajib (*)'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'tanggal': _tanggalController.text,
      'cabang_id': _selectedCabangId,
      'nama_karyawan': _namaKaryawanController.text,
      'jabatan': _jabatanController.text,
      'jenis_apd': _selectedJenisApd,
      'nama_barang': _namaBarangController.text,
      'jumlah': _jumlahController.text,
      'satuan': _satuanController.text,
      'ukuran': _ukuranController.text,
      'masa_pakai': _masaPakaiController.text,
      'diserahkan_oleh': _diserahkanOlehController.text,
      'keterangan': _keteranganController.text,
    };

    Map<String, dynamic> res;
    if (widget.initialData != null) {
      res = await _service.updateTandaTerimaApd(widget.initialData['id'], data, filePath: _selectedFilePath);
    } else {
      res = await _service.storeTandaTerimaApd(data, filePath: _selectedFilePath);
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
                    Icon(Icons.inventory_2_outlined, color: _indigoColor),
                    const SizedBox(width: 8),
                    Text(
                      widget.initialData != null ? 'Edit Tanda Terima APD' : 'Tambah Tanda Terima APD/Suplemen',
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
                  // Section: Informasi Serah Terima
                  Row(
                    children: [
                      const Icon(Icons.date_range_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('Informasi Serah Terima', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
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
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField('Nama Penerima', _namaKaryawanController, required: true, hint: 'Nama Karyawan...'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField('Jabatan', _jabatanController, hint: 'Jabatan...'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  // Section: Detail Barang
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _indigoColor.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _indigoColor.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.widgets_outlined, size: 16, color: _indigoColor),
                            const SizedBox(width: 8),
                            Text('Detail Barang', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _indigoColor)),
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
                                      text: 'Jenis APD/Barang',
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
                                        value: _selectedJenisApd,
                                        isExpanded: true,
                                        hint: Text('Pilih Jenis', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade400)),
                                        items: const [
                                          DropdownMenuItem(value: 'Seragam', child: Text('Seragam')),
                                          DropdownMenuItem(value: 'Sepatu', child: Text('Sepatu')),
                                          DropdownMenuItem(value: 'Helm/Topi', child: Text('Helm/Topi')),
                                          DropdownMenuItem(value: 'Masker/Sarung Tangan', child: Text('Masker/Sarung Tangan')),
                                          DropdownMenuItem(value: 'Suplemen/Vitamin', child: Text('Suplemen/Vitamin')),
                                          DropdownMenuItem(value: 'Lainnya', child: Text('Lainnya')),
                                        ],
                                        onChanged: (val) {
                                          setState(() => _selectedJenisApd = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField('Nama Barang Spesifik', _namaBarangController, required: true, hint: 'Mis: Kaos...'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: _buildTextField('Jumlah', _jumlahController, required: true, keyboardType: TextInputType.number),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: _buildTextField('Satuan', _satuanController, hint: 'Pcs, Pasang...'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildTextField('Ukuran (Jika ada)', _ukuranController, hint: 'S, M, L...'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField('Masa Pakai', _masaPakaiController, hint: 'Mis: 6 bulan...'),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField('Diserahkan Oleh', _diserahkanOlehController, hint: 'Nama petugas...'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        _buildTextField('Keterangan Tambahan', _keteranganController, maxLines: 2, hint: 'Kondisi barang, alasan penggantian...'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  Text('Tanda Terima (Foto/Scan)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  Text('Unggah dokumen atau foto tanda terima yang sudah ditandatangani penerima.', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
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
                            child: Text('Choose File', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _indigoColor)),
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
                  Text('Format: Gambar/PDF (Max. 5MB)', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500)),
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/operasional_layanan_kesehatan_service.dart';

class OperasionalLayananKesehatanFormSheet extends StatefulWidget {
  final dynamic initialData;
  final List<dynamic> cabangList;
  final VoidCallback onSave;

  const OperasionalLayananKesehatanFormSheet({
    super.key,
    this.initialData,
    required this.cabangList,
    required this.onSave,
  });

  @override
  State<OperasionalLayananKesehatanFormSheet> createState() => _OperasionalLayananKesehatanFormSheetState();
}

class _OperasionalLayananKesehatanFormSheetState extends State<OperasionalLayananKesehatanFormSheet> {
  final _service = OperasionalLayananKesehatanService();
  
  bool _isLoading = false;
  
  // Controllers
  final _namaFaskesController = TextEditingController();
  final _alamatController = TextEditingController();
  final _noTeleponController = TextEditingController();
  final _jarakController = TextEditingController();
  final _linkMapsController = TextEditingController();
  final _keteranganController = TextEditingController();
  
  String? _selectedCabangId;
  String? _selectedJenis;
  String _buka24Jam = 'Tidak';
  String _kerjaSamaBpjs = 'Tidak';

  final Color _blueColor = const Color(0xFF02659B);

  @override
  void initState() {
    super.initState();
    _initData();
  }
  
  void _initData() {
    if (widget.initialData != null) {
      final data = widget.initialData;
      _selectedCabangId = data['cabang_id']?.toString();
      _selectedJenis = data['jenis_faskes'];
      _namaFaskesController.text = data['nama_faskes'] ?? '';
      _alamatController.text = data['alamat'] ?? '';
      _noTeleponController.text = data['no_telepon'] ?? '';
      _jarakController.text = data['jarak_km']?.toString() ?? '';
      _buka24Jam = data['buka_24_jam'] ?? 'Tidak';
      _kerjaSamaBpjs = data['kerja_sama_bpjs'] ?? 'Tidak';
      _linkMapsController.text = data['link_maps'] ?? '';
      _keteranganController.text = data['keterangan'] ?? '';
    }
  }

  @override
  void dispose() {
    _namaFaskesController.dispose();
    _alamatController.dispose();
    _noTeleponController.dispose();
    _jarakController.dispose();
    _linkMapsController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedCabangId == null || _selectedJenis == null || _namaFaskesController.text.isEmpty || _alamatController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi field yang wajib (*)'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'cabang_id': _selectedCabangId,
      'nama_faskes': _namaFaskesController.text,
      'jenis_faskes': _selectedJenis,
      'alamat': _alamatController.text,
      'no_telepon': _noTeleponController.text,
      'jarak_km': _jarakController.text.isNotEmpty ? _jarakController.text : null,
      'buka_24_jam': _buka24Jam,
      'kerja_sama_bpjs': _kerjaSamaBpjs,
      'link_maps': _linkMapsController.text,
      'keterangan': _keteranganController.text,
    };

    Map<String, dynamic> res;
    if (widget.initialData != null) {
      res = await _service.updateLayananKesehatan(widget.initialData['id'], data);
    } else {
      res = await _service.storeLayananKesehatan(data);
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

  Widget _buildTextField(String label, TextEditingController controller, {bool required = false, int maxLines = 1, String? hint, TextInputType? keyboardType}) {
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: controller,
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
                    Icon(Icons.local_hospital_outlined, color: _blueColor),
                    const SizedBox(width: 8),
                    Text(
                      widget.initialData != null ? 'Edit Fasilitas Kesehatan' : 'Tambah Fasilitas Kesehatan',
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
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                text: 'Jenis Fasilitas',
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
                                  value: _selectedJenis,
                                  isExpanded: true,
                                  hint: Text('Pilih Jenis', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade400)),
                                  items: const [
                                    DropdownMenuItem(value: 'Rumah Sakit', child: Text('Rumah Sakit')),
                                    DropdownMenuItem(value: 'RSUD', child: Text('RSUD')),
                                    DropdownMenuItem(value: 'Puskesmas', child: Text('Puskesmas')),
                                    DropdownMenuItem(value: 'Klinik', child: Text('Klinik')),
                                    DropdownMenuItem(value: 'Apotek', child: Text('Apotek')),
                                    DropdownMenuItem(value: 'Lainnya', child: Text('Lainnya')),
                                  ],
                                  onChanged: (val) {
                                    setState(() => _selectedJenis = val);
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
                  _buildTextField('Nama Faskes', _namaFaskesController, required: true, hint: 'Contoh: RSUD Kota / Klinik Sehat...'),
                  
                  const SizedBox(height: 16),
                  _buildTextField('Alamat Lengkap', _alamatController, required: true, maxLines: 2, hint: 'Alamat lengkap fasilitas kesehatan...'),
                  
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField('Nomor Telepon', _noTeleponController, keyboardType: TextInputType.phone, hint: 'Nomor darurat / telepon...'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField('Jarak dari Kantor (km)', _jarakController, keyboardType: const TextInputType.numberWithOptions(decimal: true), hint: 'Misal: 1.5'),
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
                            Text('Buka 24 Jam?', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
                                  value: _buka24Jam,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 'Ya', child: Text('Ya')),
                                    DropdownMenuItem(value: 'Tidak', child: Text('Tidak')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _buka24Jam = val);
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
                            Text('Kerja Sama BPJS?', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
                                  value: _kerjaSamaBpjs,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 'Ya', child: Text('Ya')),
                                    DropdownMenuItem(value: 'Tidak', child: Text('Tidak')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _kerjaSamaBpjs = val);
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
                  _buildTextField('Link Google Maps', _linkMapsController, keyboardType: TextInputType.url, hint: 'https://maps.google.com/...'),
                  
                  const SizedBox(height: 16),
                  _buildTextField('Keterangan Tambahan', _keteranganController, maxLines: 2, hint: 'Informasi spesialisasi, rute, dll...'),
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
                    backgroundColor: _blueColor,
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

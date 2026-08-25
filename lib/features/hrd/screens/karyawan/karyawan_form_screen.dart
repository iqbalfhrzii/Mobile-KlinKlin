import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'package:dio/dio.dart';

class KaryawanFormScreen extends StatefulWidget {
  final KaryawanModel? karyawan;
  const KaryawanFormScreen({super.key, this.karyawan});

  @override
  State<KaryawanFormScreen> createState() => _KaryawanFormScreenState();
}

class _KaryawanFormScreenState extends State<KaryawanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final HrdService _hrdService = HrdService();
  
  late TextEditingController _namaCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _noWaCtrl;
  late TextEditingController _namaBankCtrl;
  late TextEditingController _noRekeningCtrl;
  
  int? _selectedCabang;
  int? _selectedJabatan;
  String _status = 'aktif';
  String _statusKaryawan = 'tetap';
  
  List<CabangModel> _cabangs = [];
  List<JabatanModel> _jabatans = [];
  
  bool _isLoading = false;
  bool _isLoadingRef = true;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController(text: widget.karyawan?.nama);
    _emailCtrl = TextEditingController(text: widget.karyawan?.email);
    _noWaCtrl = TextEditingController(text: widget.karyawan?.noWa);
    _namaBankCtrl = TextEditingController(text: widget.karyawan?.namaBank);
    _noRekeningCtrl = TextEditingController(text: widget.karyawan?.noRekening);
    
    _selectedCabang = widget.karyawan?.cabangId;
    _selectedJabatan = widget.karyawan?.jabatanId;
    if (widget.karyawan != null) {
      String statusVal = widget.karyawan!.status.toLowerCase();
      _status = ['aktif', 'nonaktif'].contains(statusVal) ? statusVal : 'aktif';
      
      if (widget.karyawan!.statusKaryawan != null && widget.karyawan!.statusKaryawan!.isNotEmpty) {
        String statusKar = widget.karyawan!.statusKaryawan!;
        final validStatuses = ['Tetap', 'Tetap Koor', 'Kontrak', 'Training'];
        final matched = validStatuses.firstWhere(
          (s) => s.toLowerCase() == statusKar.toLowerCase() || (statusKar.toLowerCase().contains('koor') && s == 'Tetap Koor'),
          orElse: () => 'Tetap',
        );
        _statusKaryawan = matched;
      } else {
        _statusKaryawan = 'Tetap';
      }
    } else {
      _statusKaryawan = 'Tetap';
    }
    _fetchRefs();
  }

  Future<void> _fetchRefs() async {
    try {
      final cabangs = await _hrdService.fetchCabang();
      final jabatans = await _hrdService.fetchJabatan();
      if (mounted) {
        setState(() {
          _cabangs = cabangs;
          _jabatans = jabatans;
          if (_selectedCabang == null && _cabangs.isNotEmpty) _selectedCabang = _cabangs.first.id;
          if (_selectedJabatan == null && _jabatans.isNotEmpty) _selectedJabatan = _jabatans.first.id;
          _isLoadingRef = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRef = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat referensi: $e')));
      }
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _noWaCtrl.dispose();
    _namaBankCtrl.dispose();
    _noRekeningCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCabang == null || _selectedJabatan == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih cabang dan jabatan terlebih dahulu')));
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final data = {
        'nama': _namaCtrl.text,
        'email': _emailCtrl.text,
        'no_wa': _noWaCtrl.text,
        'cabang_id': _selectedCabang,
        'jabatan_id': _selectedJabatan,
        'status': _status,
        'status_karyawan': _statusKaryawan,
        'nama_bank': _namaBankCtrl.text.isEmpty ? null : _namaBankCtrl.text,
        'no_rekening': _noRekeningCtrl.text.isEmpty ? null : _noRekeningCtrl.text,
      };

      if (widget.karyawan == null) {
        data['pin'] = '123456'; // Default PIN required by API
        await _hrdService.createKaryawan(data);
      } else {
        await _hrdService.updateKaryawan(widget.karyawan!.id, data);
      }
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString();
        if (e is DioException && e.response?.data != null) {
          final data = e.response!.data;
          if (data is Map) {
            if (data['errors'] != null && data['errors'] is Map) {
              final errors = data['errors'] as Map;
              if (errors.isNotEmpty) {
                errMsg = errors.values.first.first.toString();
              }
            } else if (data['message'] != null) {
              errMsg = data['message'].toString();
            } else {
              errMsg = data.toString();
            }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg)));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter jabatan by selected cabang
    final availableJabatans = _jabatans.where((j) => j.cabangId == _selectedCabang).toList();
    // Validate if current selected jabatan is still in the filtered list
    if (availableJabatans.isNotEmpty && !availableJabatans.any((j) => j.id == _selectedJabatan)) {
      _selectedJabatan = availableJabatans.first.id;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Text(
                  widget.karyawan == null ? 'Tambah Karyawan' : 'Edit Karyawan',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingRef
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildField(
                            label: 'Nama Lengkap',
                            controller: _namaCtrl,
                            hint: 'Masukkan nama',
                            validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            label: 'Email',
                            controller: _emailCtrl,
                            hint: 'email@klinklin.com',
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) => val == null || val.isEmpty || !val.contains('@') ? 'Email tidak valid' : null,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            label: 'No. WhatsApp',
                            controller: _noWaCtrl,
                            hint: '0812xxxx',
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          Text('Cabang', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedCabang,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: _cabangs.map((c) => DropdownMenuItem(value: c.id, child: Text(c.namaCabang))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCabang = val);
                            },
                          ),
                          const SizedBox(height: 16),
                          Text('Jabatan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedJabatan,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: availableJabatans.map((j) => DropdownMenuItem(value: j.id, child: Text(j.namaJabatan))).toList(),
                            onChanged: availableJabatans.isEmpty ? null : (val) {
                              if (val != null) setState(() => _selectedJabatan = val);
                            },
                            hint: availableJabatans.isEmpty ? const Text('Tidak ada jabatan di cabang ini') : null,
                          ),
                          const SizedBox(height: 16),
                          Text('Status', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _status,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'aktif', child: Text('Aktif')),
                              DropdownMenuItem(value: 'nonaktif', child: Text('Nonaktif')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _status = val);
                            },
                          ),
                          const SizedBox(height: 16),
                          Text('Status Pegawai', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _statusKaryawan,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Tetap', child: Text('Tetap')),
                              DropdownMenuItem(value: 'Tetap Koor', child: Text('Tetap Koor (Cleaner Koor)')),
                              DropdownMenuItem(value: 'Kontrak', child: Text('Kontrak')),
                              DropdownMenuItem(value: 'Training', child: Text('Training')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _statusKaryawan = val);
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            label: 'Nama Bank (Opsional)',
                            controller: _namaBankCtrl,
                            hint: 'BCA / BNI / Mandiri / dll',
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            label: 'No. Rekening (Opsional)',
                            controller: _noRekeningCtrl,
                            hint: 'Masukkan nomor rekening',
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                                  : Text('Simpan', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}

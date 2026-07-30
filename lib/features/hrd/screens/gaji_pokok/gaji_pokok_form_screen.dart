import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';

class GajiPokokFormScreen extends StatefulWidget {
  final GajiPokokModel? gajiPokok;
  const GajiPokokFormScreen({super.key, this.gajiPokok});

  @override
  State<GajiPokokFormScreen> createState() => _GajiPokokFormScreenState();
}

class _GajiPokokFormScreenState extends State<GajiPokokFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final HrdService _hrdService = HrdService();
  
  late TextEditingController _gajiPokokCtrl;
  late TextEditingController _bonusBulananCtrl;
  late TextEditingController _tunjanganKosCtrl;
  late TextEditingController _tunjanganKerjaCtrl;
  late TextEditingController _gajiPokokHarianCtrl;
  
  int? _selectedCabang;
  int? _selectedJabatan;
  String _status = 'TETAP';
  
  List<CabangModel> _cabangs = [];
  List<JabatanModel> _jabatans = [];
  
  bool _isLoading = false;
  bool _isLoadingRef = true;
  bool _isBpjsAktif = false;

  @override
  void initState() {
    super.initState();
    _gajiPokokCtrl = TextEditingController(text: widget.gajiPokok?.gajiPokok.toString() ?? '');
    _bonusBulananCtrl = TextEditingController(text: widget.gajiPokok?.bonusBulanan.toString() ?? '');
    _tunjanganKosCtrl = TextEditingController(text: widget.gajiPokok?.tunjanganKos.toString() ?? '');
    _tunjanganKerjaCtrl = TextEditingController(text: widget.gajiPokok?.tunjanganKerja.toString() ?? '');
    _gajiPokokHarianCtrl = TextEditingController(text: widget.gajiPokok?.gajiPokokHarian.toString() ?? '');
    
    _isBpjsAktif = (widget.gajiPokok?.premiBpjs ?? 0) > 0;
    
    _selectedCabang = widget.gajiPokok?.cabangId;
    _selectedJabatan = widget.gajiPokok?.jabatanId;
    
    if (widget.gajiPokok != null) {
      String statusVal = widget.gajiPokok!.statusKaryawan.toUpperCase();
      _status = ['TETAP', 'KONTRAK', 'TRAINING', 'FREELANCE', 'TETAP KOOR'].contains(statusVal) ? statusVal : 'TETAP';
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
    _gajiPokokCtrl.dispose();
    _bonusBulananCtrl.dispose();
    _tunjanganKosCtrl.dispose();
    _tunjanganKerjaCtrl.dispose();
    _gajiPokokHarianCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCabang == null || _selectedJabatan == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih Cabang dan Jabatan terlebih dahulu')));
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final data = {
        'cabang_id': _selectedCabang,
        'jabatan_id': _selectedJabatan,
        'status_karyawan': _status,
        'gaji_pokok': int.tryParse(_gajiPokokCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        'bonus_bulanan': int.tryParse(_bonusBulananCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        'tunjangan_kos': int.tryParse(_tunjanganKosCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        'tunjangan_kerja': int.tryParse(_tunjanganKerjaCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        'gaji_pokok_harian': int.tryParse(_gajiPokokHarianCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        'premi_bpjs': _isBpjsAktif ? 35000 : 0,
      };

      if (widget.gajiPokok == null) {
        await _hrdService.createGajiPokok(data);
      } else {
        await _hrdService.updateGajiPokok(widget.gajiPokok!.id, data);
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
            }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg)));
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildNumericField({
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint ?? '0',
            prefixText: 'Rp ',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  widget.gajiPokok == null ? 'Tambah Gaji Pokok' : 'Edit Gaji Pokok',
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
                          Text('Cabang *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: _selectedCabang,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: _cabangs.map((c) => DropdownMenuItem(value: c.id, child: Text(c.namaCabang))).toList(),
                            onChanged: (val) => setState(() => _selectedCabang = val),
                            validator: (val) => val == null ? 'Wajib pilih' : null,
                          ),
                          const SizedBox(height: 16),
                          
                          Text('Jabatan *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: _selectedJabatan,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: _jabatans.map((j) => DropdownMenuItem(value: j.id, child: Text(j.namaJabatan))).toList(),
                            onChanged: (val) => setState(() => _selectedJabatan = val),
                            validator: (val) => val == null ? 'Wajib pilih' : null,
                          ),
                          const SizedBox(height: 16),
                          
                          Text('Status Karyawan *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _status,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'TETAP', child: Text('TETAP')),
                              DropdownMenuItem(value: 'KONTRAK', child: Text('KONTRAK')),
                              DropdownMenuItem(value: 'TRAINING', child: Text('TRAINING')),
                              DropdownMenuItem(value: 'FREELANCE', child: Text('FREELANCE')),
                              DropdownMenuItem(value: 'TETAP KOOR', child: Text('TETAP KOOR')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _status = val);
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          _buildNumericField(label: 'Gaji Pokok', controller: _gajiPokokCtrl),
                          const SizedBox(height: 16),
                          _buildNumericField(label: 'Bonus Bulanan', controller: _bonusBulananCtrl),
                          const SizedBox(height: 16),
                          _buildNumericField(label: 'Tunjangan Kos', controller: _tunjanganKosCtrl),
                          const SizedBox(height: 16),
                          _buildNumericField(label: 'Tunjangan Kerja', controller: _tunjanganKerjaCtrl),
                          const SizedBox(height: 16),
                          _buildNumericField(label: 'Gaji Pokok Harian', controller: _gajiPokokHarianCtrl),
                          const SizedBox(height: 24),
                          
                          Text('Premi BPJS Aktif', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => setState(() => _isBpjsAktif = !_isBpjsAktif),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: _isBpjsAktif ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _isBpjsAktif ? AppColors.primary : Colors.transparent),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _isBpjsAktif,
                                      onChanged: (val) => setState(() => _isBpjsAktif = val ?? false),
                                      activeColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '+ Rp 35.000',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                  ),
                                ],
                              ),
                            ),
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
}

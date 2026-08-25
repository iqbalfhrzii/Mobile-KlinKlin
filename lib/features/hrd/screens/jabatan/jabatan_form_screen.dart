import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';

class JabatanFormScreen extends StatefulWidget {
  final JabatanModel? jabatan;
  const JabatanFormScreen({super.key, this.jabatan});

  @override
  State<JabatanFormScreen> createState() => _JabatanFormScreenState();
}

class _JabatanFormScreenState extends State<JabatanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final HrdService _hrdService = HrdService();
  
  late TextEditingController _namaCtrl;
  int? _selectedCabang;
  List<CabangModel> _cabangs = [];
  bool _isLoading = false;
  bool _isLoadingCabang = true;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController(text: widget.jabatan?.namaJabatan);
    _selectedCabang = widget.jabatan?.cabangId;
    _fetchCabang();
  }

  Future<void> _fetchCabang() async {
    try {
      final res = await _hrdService.fetchCabang();
      if (mounted) {
        setState(() {
          _cabangs = res;
          if (_selectedCabang == null && _cabangs.isNotEmpty) {
            _selectedCabang = _cabangs.first.id;
          }
          _isLoadingCabang = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCabang = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat cabang: $e')));
      }
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCabang == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih cabang terlebih dahulu')));
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final data = {
        'nama_jabatan': _namaCtrl.text,
        'cabang_id': _selectedCabang,
      };

      if (widget.jabatan == null) {
        await _hrdService.createJabatan(data);
      } else {
        await _hrdService.updateJabatan(widget.jabatan!.id, data);
      }
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _isLoading = false);
      }
    }
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
                  widget.jabatan == null ? 'Tambah Jabatan' : 'Edit Jabatan',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingCabang
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          _buildField(
                            label: 'Nama Jabatan',
                            controller: _namaCtrl,
                            hint: 'Contoh: Cleaner Part Time',
                            validator: (val) => val == null || val.isEmpty ? 'Nama jabatan wajib diisi' : null,
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
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
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

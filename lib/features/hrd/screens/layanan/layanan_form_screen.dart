import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'package:dio/dio.dart';

class LayananFormScreen extends StatefulWidget {
  final LayananModel? layanan;
  const LayananFormScreen({super.key, this.layanan});

  @override
  State<LayananFormScreen> createState() => _LayananFormScreenState();
}

class _LayananFormScreenState extends State<LayananFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final HrdService _hrdService = HrdService();
  
  late TextEditingController _namaCtrl;
  
  int? _selectedCabang;
  String _status = 'aktif';
  List<CabangModel> _cabangs = [];
  bool _isLoadingRef = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController(text: widget.layanan?.namaLayanan);
    _selectedCabang = widget.layanan?.cabangId;
    if (widget.layanan != null) {
      _status = widget.layanan!.status;
    }
    _fetchRefs();
  }

  Future<void> _fetchRefs() async {
    try {
      final cabangs = await _hrdService.fetchCabang();
      if (mounted) {
        setState(() {
          _cabangs = cabangs;
          if (_selectedCabang == null && _cabangs.isNotEmpty) _selectedCabang = _cabangs.first.id;
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
        'nama_layanan': _namaCtrl.text,
        'cabang_id': _selectedCabang,
        'status': _status,
      };

      if (widget.layanan == null) {
        await _hrdService.createLayanan(data);
      } else {
        await _hrdService.updateLayanan(widget.layanan!.id, data);
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
                  widget.layanan == null ? 'Tambah Layanan' : 'Edit Layanan',
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
                      label: 'Nama Layanan',
                      controller: _namaCtrl,
                      hint: 'Contoh: Cuci Kasur King',
                      validator: (val) => val == null || val.isEmpty ? 'Nama layanan wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    Text('Cabang', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _selectedCabang,
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
                    Text('Status', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _status,
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
    int maxLines = 1,
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
          maxLines: maxLines,
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

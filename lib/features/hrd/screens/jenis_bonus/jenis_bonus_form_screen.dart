import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'package:dio/dio.dart';

class JenisBonusFormScreen extends StatefulWidget {
  final JenisBonusModel? jenisBonus;
  const JenisBonusFormScreen({super.key, this.jenisBonus});

  @override
  State<JenisBonusFormScreen> createState() => _JenisBonusFormScreenState();
}

class _JenisBonusFormScreenState extends State<JenisBonusFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final HrdService _hrdService = HrdService();
  
  late TextEditingController _namaCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController(text: widget.jenisBonus?.namaBonus);
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final data = {
        'nama_bonus': _namaCtrl.text,
      };

      if (widget.jenisBonus == null) {
        await _hrdService.createJenisBonus(data);
      } else {
        await _hrdService.updateJenisBonus(widget.jenisBonus!.id, data);
      }
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString();
        if (e is DioException) {
          if (e.response?.statusCode == 404) {
            errMsg = 'Fitur ini belum tersedia di server (404).';
          } else if (e.response?.data != null) {
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
                  widget.jenisBonus == null ? 'Tambah Kategori Bonus' : 'Edit Kategori Bonus',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField(
                      label: 'Nama Kategori Bonus',
                      controller: _namaCtrl,
                      hint: 'Contoh: Bonus Kerajinan, Bonus Absensi',
                      validator: (val) => val == null || val.isEmpty ? 'Nama kategori bonus wajib diisi' : null,
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

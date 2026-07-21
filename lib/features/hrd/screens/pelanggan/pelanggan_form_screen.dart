import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';

class PelangganFormScreen extends StatefulWidget {
  final PelangganHrdModel? pelanggan;
  const PelangganFormScreen({super.key, this.pelanggan});

  @override
  State<PelangganFormScreen> createState() => _PelangganFormScreenState();
}

class _PelangganFormScreenState extends State<PelangganFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final HrdService _hrdService = HrdService();
  
  late TextEditingController _namaCtrl;
  late TextEditingController _noWaCtrl;
  late TextEditingController _alamatCtrl;
  late TextEditingController _catatanCtrl;
  
  int? _selectedCabang;
  String _status = 'aktif';
  
  List<CabangModel> _cabangs = [];
  
  bool _isLoading = false;
  bool _isLoadingRef = true;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController(text: widget.pelanggan?.namaPelanggan);
    _noWaCtrl = TextEditingController(text: widget.pelanggan?.noWa);
    _alamatCtrl = TextEditingController(text: widget.pelanggan?.alamat);
    _catatanCtrl = TextEditingController(text: widget.pelanggan?.catatan);
    
    _selectedCabang = widget.pelanggan?.cabangId;
    if (widget.pelanggan != null) {
      String statusVal = widget.pelanggan!.status.toLowerCase();
      _status = ['aktif', 'nonaktif'].contains(statusVal) ? statusVal : 'aktif';
    }
    _fetchRefs();
  }

  Future<void> _fetchRefs() async {
    try {
      final cabangs = await _hrdService.fetchCabang();
      if (mounted) {
        setState(() {
          _cabangs = cabangs;
          if (_selectedCabang == null && _cabangs.isNotEmpty) {
            _selectedCabang = _cabangs.first.id;
          }
          _isLoadingRef = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRef = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat cabang: $e')));
      }
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _noWaCtrl.dispose();
    _alamatCtrl.dispose();
    _catatanCtrl.dispose();
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
        'nama_pelanggan': _namaCtrl.text,
        'no_wa': _noWaCtrl.text.isEmpty ? null : _noWaCtrl.text,
        'alamat': _alamatCtrl.text.isEmpty ? null : _alamatCtrl.text,
        'catatan': _catatanCtrl.text.isEmpty ? null : _catatanCtrl.text,
        'cabang_id': _selectedCabang,
        'status': _status,
      };

      if (widget.pelanggan == null) {
        await _hrdService.createPelanggan(data);
      } else {
        await _hrdService.updatePelanggan(widget.pelanggan!.id, data);
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
          decoration: InputDecoration(
            hintText: hint,
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
                  widget.pelanggan == null ? 'Tambah Pelanggan' : 'Edit Pelanggan',
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
                            label: 'Nama Pelanggan',
                            controller: _namaCtrl,
                            hint: 'Masukkan nama pelanggan',
                            validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            label: 'No. WhatsApp',
                            controller: _noWaCtrl,
                            hint: '0812xxxx',
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            label: 'Alamat (Opsional)',
                            controller: _alamatCtrl,
                            hint: 'Masukkan alamat pelanggan',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            label: 'Catatan (Opsional)',
                            controller: _catatanCtrl,
                            hint: 'Tambahkan catatan khusus...',
                            maxLines: 3,
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
}

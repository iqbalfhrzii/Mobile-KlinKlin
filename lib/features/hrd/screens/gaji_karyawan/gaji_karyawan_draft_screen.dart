import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'gaji_karyawan_form_screen.dart';
import 'package:intl/intl.dart';

class GajiKaryawanDraftScreen extends StatefulWidget {
  const GajiKaryawanDraftScreen({super.key});

  @override
  State<GajiKaryawanDraftScreen> createState() => _GajiKaryawanDraftScreenState();
}

class _GajiKaryawanDraftScreenState extends State<GajiKaryawanDraftScreen> {
  final HrdService _hrdService = HrdService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isGenerating = false;

  List<CabangModel> _cabangs = [];
  List<KaryawanModel> _karyawans = [];
  List<KaryawanModel> _filteredKaryawans = [];

  int? _selectedCabangId;
  int? _selectedKaryawanId;
  String _jenisGaji = 'bulanan';

  int _periodeBulan = DateTime.now().month;
  int _periodeTahun = DateTime.now().year;

  final TextEditingController _jumlahHariKerjaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMasterData();
  }

  @override
  void dispose() {
    _jumlahHariKerjaCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMasterData() async {
    try {
      final cabangs = await _hrdService.fetchCabang();
      final karyawans = await _hrdService.fetchKaryawan();
      if (mounted) {
        setState(() {
          _cabangs = cabangs;
          _karyawans = karyawans;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data master: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _onCabangChanged(int? cabangId) {
    setState(() {
      _selectedCabangId = cabangId;
      _selectedKaryawanId = null;
      if (cabangId != null) {
        _filteredKaryawans = _karyawans.where((k) => k.cabangId == cabangId).toList();
      } else {
        _filteredKaryawans = [];
      }
    });
  }

  Future<void> _generateDraft() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isGenerating = true);
    
    try {
      final params = {
        'karyawan_id': _selectedKaryawanId,
        'periode_bulan': _periodeBulan,
        'periode_tahun': _periodeTahun,
        'jenis_gaji': _jenisGaji,
      };

      if (_jenisGaji == 'harian') {
        params['jumlah_hari_kerja'] = int.tryParse(_jumlahHariKerjaCtrl.text) ?? 1;
      }

      final draft = await _hrdService.generateDraftGajiKaryawan(params);
      
      if (mounted) {
        setState(() => _isGenerating = false);
        final res = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GajiKaryawanFormScreen(gajiToEdit: draft),
          ),
        );
        if (res == true) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuat draft: $e')));
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
                  'Buat Draft Gaji',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Jenis Gaji *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<String>(
                                  value: 'bulanan',
                                  groupValue: _jenisGaji,
                                  title: const Text('Bulanan', style: TextStyle(fontSize: 14)),
                                  onChanged: (val) => setState(() => _jenisGaji = val!),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<String>(
                                  value: 'harian',
                                  groupValue: _jenisGaji,
                                  title: const Text('Harian', style: TextStyle(fontSize: 14)),
                                  onChanged: (val) => setState(() => _jenisGaji = val!),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Text('Cabang Karyawan *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: _selectedCabangId,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: _cabangs.map((c) => DropdownMenuItem(value: c.id, child: Text(c.namaCabang))).toList(),
                            onChanged: _onCabangChanged,
                            validator: (val) => val == null ? 'Wajib pilih cabang' : null,
                          ),
                          const SizedBox(height: 16),

                          Text('Nama Karyawan *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: _selectedKaryawanId,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: _filteredKaryawans.map((k) => DropdownMenuItem(value: k.id, child: Text(k.nama))).toList(),
                            onChanged: _selectedCabangId == null ? null : (val) => setState(() => _selectedKaryawanId = val),
                            validator: (val) => val == null ? 'Wajib pilih karyawan' : null,
                            hint: Text(_selectedCabangId == null ? 'Pilih cabang dulu' : 'Pilih karyawan'),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Bulan *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<int>(
                                      value: _periodeBulan,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: AppColors.surface,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      ),
                                      items: List.generate(12, (index) {
                                        return DropdownMenuItem(value: index + 1, child: Text('${index + 1}'));
                                      }),
                                      onChanged: (val) => setState(() => _periodeBulan = val!),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Tahun *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<int>(
                                      value: _periodeTahun,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: AppColors.surface,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      ),
                                      items: [DateTime.now().year - 1, DateTime.now().year, DateTime.now().year + 1].map((y) {
                                        return DropdownMenuItem(value: y, child: Text(y.toString()));
                                      }).toList(),
                                      onChanged: (val) => setState(() => _periodeTahun = val!),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          if (_jenisGaji == 'harian') ...[
                            const SizedBox(height: 16),
                            Text('Jumlah Hari Kerja *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _jumlahHariKerjaCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                suffixText: 'Hari',
                                filled: true,
                                fillColor: AppColors.surface,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                              validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
                            ),
                          ],

                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isGenerating ? null : _generateDraft,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isGenerating
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text('Lanjut Edit Draft', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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

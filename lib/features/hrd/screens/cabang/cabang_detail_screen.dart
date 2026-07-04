import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'package:dio/dio.dart';

class CabangDetailScreen extends StatefulWidget {
  final CabangModel cabang;
  const CabangDetailScreen({super.key, required this.cabang});

  @override
  State<CabangDetailScreen> createState() => _CabangDetailScreenState();
}

class _CabangDetailScreenState extends State<CabangDetailScreen> {
  final HrdService _hrdService = HrdService();
  bool _isLoading = true;
  String _error = '';
  
  List<JenisBonusModel> _jenisBonusList = [];
  List<TarifBonusCabangModel> _tarifBonusList = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final jenisBonus = await _hrdService.fetchJenisBonus();
      final tarifBonus = await _hrdService.fetchTarifBonus(widget.cabang.id);
      if (mounted) {
        setState(() {
          _jenisBonusList = jenisBonus;
          _tarifBonusList = tarifBonus;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is DioException && e.response?.statusCode == 404) {
            _error = 'Fitur ini belum tersedia di server (404).';
          } else {
            _error = e.toString().replaceFirst('Exception: ', '');
          }
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateTarif(JenisBonusModel jenisBonus, int existingId, int existingNominal) async {
    final ctrl = TextEditingController(text: existingNominal > 0 ? existingNominal.toString() : '');
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Atur ${jenisBonus.namaBonus}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Nominal (Rp)',
            prefixText: 'Rp ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final nominal = int.tryParse(ctrl.text) ?? 0;
      try {
        await _hrdService.setTarifBonus(existingId, widget.cabang.id, jenisBonus.id, nominal);
        _fetchData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
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
                  onTap: () => Navigator.pop(context, true),
                  child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Detail Cabang', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                    Text(widget.cabang.namaCabang, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error, style: const TextStyle(color: AppColors.error)))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text('Pengaturan Tarif Bonus Karyawan', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                          const SizedBox(height: 4),
                          Text('Atur nominal bonus per jenis kategori khusus cabang ini.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                          const SizedBox(height: 16),
                          ..._jenisBonusList.map((jb) {
                            final tarif = _tarifBonusList.firstWhere(
                              (t) => t.jenisBonusId == jb.id,
                              orElse: () => TarifBonusCabangModel(id: 0, cabangId: widget.cabang.id, jenisBonusId: jb.id, nominal: 0),
                            );
                            return _buildBonusItem(jb, tarif.id, tarif.nominal);
                          }),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBonusItem(JenisBonusModel jenisBonus, int id, int nominal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        title: Text(jenisBonus.namaBonus, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        subtitle: Text('Rp $nominal', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold)),
        trailing: ElevatedButton(
          onPressed: () => _updateTarif(jenisBonus, id, nominal),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            foregroundColor: AppColors.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Atur'),
        ),
      ),
    );
  }
}

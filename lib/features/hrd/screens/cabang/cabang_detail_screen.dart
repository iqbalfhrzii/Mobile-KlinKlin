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

  Future<bool> _updateTarif(JenisBonusModel jenisBonus, int existingId, int existingNominal) async {
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
        await _fetchData();
        return true;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
    return false;
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
                    Text('Detail Cabang', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
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
                          _buildBranchInfo(),
                          const SizedBox(height: 16),
                          _buildLocationSection(),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _showBonusBottomSheet,
                              icon: const Icon(Icons.card_giftcard_rounded),
                              label: Text('Kelola Bonus Karyawan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple.shade50,
                                foregroundColor: Colors.purple.shade700,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.purple.shade200),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Lokasi Absensi', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.cabang.latitude != null && widget.cabang.longitude != null) ...[
            Text('Latitude: ${widget.cabang.latitude}', style: GoogleFonts.inter(fontSize: 14)),
            const SizedBox(height: 4),
            Text('Longitude: ${widget.cabang.longitude}', style: GoogleFonts.inter(fontSize: 14)),
            const SizedBox(height: 4),
            Text('Radius: ${widget.cabang.radiusAbsensiMeter ?? 100} meter', style: GoogleFonts.inter(fontSize: 14)),
          ] else
            Text('Lokasi absensi belum dikonfigurasi.', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildBranchInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Informasi Cabang', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.cabang.status == 'aktif' ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.cabang.status.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: widget.cabang.status == 'aktif' ? Colors.green.shade700 : Colors.red.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.map_outlined, 'Alamat Lengkap', widget.cabang.alamat ?? '-'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInfoRow(Icons.login_rounded, 'Jam Masuk', widget.cabang.jamMasuk ?? '-')),
              Expanded(child: _buildInfoRow(Icons.logout_rounded, 'Jam Pulang', widget.cabang.jamPulang ?? '-')),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.timer_outlined, 'Toleransi Telat', '${widget.cabang.toleransiTelatMenit ?? 0} menit'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
              Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            ],
          ),
        ),
      ],
    );
  }

  void _showBonusBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.card_giftcard_rounded, color: Colors.purple),
                      const SizedBox(width: 8),
                      Text('Kelola Tarif Bonus', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Atur nominal bonus per jenis kategori khusus cabang ini.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    children: _jenisBonusList.map((jb) {
                      final tarif = _tarifBonusList.firstWhere(
                        (t) => t.jenisBonusId == jb.id,
                        orElse: () => TarifBonusCabangModel(id: 0, cabangId: widget.cabang.id, jenisBonusId: jb.id, nominal: 0),
                      );
                      return _buildModalBonusItem(jb, tarif.id, tarif.nominal, setModalState);
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildModalBonusItem(JenisBonusModel jenisBonus, int id, int nominal, StateSetter setModalState) {
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
          onPressed: () async {
            final changed = await _updateTarif(jenisBonus, id, nominal);
            if (changed) setModalState(() {});
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
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

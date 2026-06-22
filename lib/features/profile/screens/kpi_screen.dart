import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/data/kpi_model.dart';
import '../../../core/data/mock_kpi_data.dart';

class KpiScreen extends StatefulWidget {
  const KpiScreen({super.key});

  @override
  State<KpiScreen> createState() => _KpiScreenState();
}

class _KpiScreenState extends State<KpiScreen> {
  final List<TargetKpi> _kpiList = mockTargetKpi;

  String _formatRupiah(double n) =>
      'Rp ${n.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    // Calculate total score
    double totalBobot = 0;
    double totalScore = 0;
    
    for (var kpi in _kpiList) {
      totalBobot += kpi.bobot;
      double capaian = kpi.capaian?.nilaiCapaian ?? 0;
      double percentage = (capaian / kpi.target).clamp(0.0, 1.0);
      totalScore += (percentage * kpi.bobot);
    }
    
    double finalScorePercentage = totalBobot > 0 ? (totalScore / totalBobot) : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(finalScorePercentage),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ..._kpiList.map((kpi) => _buildKpiCard(kpi)),
                _buildStrategiPencapaian(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double scorePercentage) {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HeaderBackButton(onTap: () => Navigator.pop(context)),
              const SizedBox(width: 12),
              Text('KPI Karyawan', style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
              )),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Periode', style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white.withOpacity(0.8),
                  )),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(mockPeriodeKpi.namaPeriode, style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white,
                        )),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Skor Keseluruhan', style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white.withOpacity(0.8),
                  )),
                  Text('${(scorePercentage * 100).toStringAsFixed(1)}%', style: GoogleFonts.inter(
                    fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white,
                  )),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(TargetKpi kpi) {
    double capaian = kpi.capaian?.nilaiCapaian ?? 0;
    double percentage = (capaian / kpi.target).clamp(0.0, 1.0);
    bool isRupiah = kpi.indikator.satuan.toLowerCase() == 'rupiah';
    bool isPercent = kpi.indikator.satuan == '%';
    
    String targetStr = isRupiah ? _formatRupiah(kpi.target) : '${kpi.target.toInt()}${isPercent ? '%' : ' ' + kpi.indikator.satuan}';
    String capaianStr = isRupiah ? _formatRupiah(capaian) : '${capaian.toInt()}${isPercent ? '%' : ' ' + kpi.indikator.satuan}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kpi.indikator.namaIndikator, style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark,
                    )),
                    if (kpi.keterangan.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(kpi.keterangan, style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textMuted,
                      )),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Bobot: ${kpi.bobot.toInt()}%', style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary,
                )),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Capaian: $capaianStr', style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary,
              )),
              Text('Target: $targetStr', style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textMuted,
              )),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: AppColors.surfaceBlue,
              valueColor: AlwaysStoppedAnimation<Color>(
                percentage >= 1.0 ? AppColors.statusDone : 
                percentage >= 0.7 ? AppColors.primary : 
                AppColors.statusPending
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(kpi.capaian?.catatan ?? '-', style: GoogleFonts.inter(
                fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted,
              )),
              Text('Prosentase: ${(percentage * kpi.bobot).toInt()}%', style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.bold, color: percentage >= 1.0 ? AppColors.statusDone : AppColors.textDark,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrategiPencapaian() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Center(
              child: Text('Strategi Pencapaian', style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark,
              )),
            ),
          ),
          Row(
            children: [
              _buildStrategiItem('Tgl 7 (25%)', 3750000, true),
              _buildStrategiItem('Tgl 14 (50%)', 7500000, true),
              _buildStrategiItem('Tgl 21 (75%)', 11250000, true),
              _buildStrategiItem('Tgl 28 (100%)', 15000000, false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrategiItem(String label, double target, bool withBorder) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: withBorder ? const Border(right: BorderSide(color: AppColors.border)) : null,
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: Colors.yellowAccent.shade100,
              child: Center(
                child: Text(label, style: GoogleFonts.inter(
                  fontSize: 10, color: AppColors.textDark,
                )),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.white,
              child: Center(
                child: Text(_formatRupiah(target), style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textDark,
                ), textAlign: TextAlign.center,),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

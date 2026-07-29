import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/data/kpi_model.dart';
import '../../../core/data/mock_kpi_data.dart';
import '../services/kpi_service.dart';

class KpiScreen extends StatefulWidget {
  const KpiScreen({super.key});

  @override
  State<KpiScreen> createState() => _KpiScreenState();
}

class _KpiScreenState extends State<KpiScreen> {
  List<TargetKpi> _kpiList = [];
  bool _isLoading = true;
  String _namaPeriode = 'Memuat...';

  double _apiTotalNilaiKpi = -1;
  double _targetTgl7 = 3750000;
  double _targetTgl14 = 7500000;
  double _targetTgl21 = 11250000;
  double _targetTgl28 = 15000000;
  String _stratTgl7 = '';
  String _stratTgl14 = '';
  String _stratTgl21 = '';
  String _stratTgl28 = '';

  @override
  void initState() {
    super.initState();
    _loadKpi();
  }

  Future<void> _loadKpi() async {
    try {
      final now = DateTime.now();
      final service = KpiService();
      final kpiData = await service.getKpiCs(bulan: now.month, tahun: now.year);
      
      if (mounted) {
        setState(() {
          _namaPeriode = '${_getMonthName(now.month)} ${now.year}';
          
          if (kpiData['total_nilai_kpi'] != null) {
            _apiTotalNilaiKpi = (kpiData['total_nilai_kpi'] as num).toDouble();
          }
          _targetTgl7 = (kpiData['target_tgl_7'] ?? 3750000).toDouble();
          _targetTgl14 = (kpiData['target_tgl_14'] ?? 7500000).toDouble();
          _targetTgl21 = (kpiData['target_tgl_21'] ?? 11250000).toDouble();
          _targetTgl28 = (kpiData['target_tgl_28'] ?? 15000000).toDouble();
          _stratTgl7 = kpiData['strategi_tgl_7']?.toString() ?? '';
          _stratTgl14 = kpiData['strategi_tgl_14']?.toString() ?? '';
          _stratTgl21 = kpiData['strategi_tgl_21']?.toString() ?? '';
          _stratTgl28 = kpiData['strategi_tgl_28']?.toString() ?? '';

          final p = PeriodeKpi(id: 1, bulan: now.month.toString(), tahun: now.year, namaPeriode: _namaPeriode);
          
          _kpiList = [
            TargetKpi(
              id: 1, karyawanId: 'CS', periode: p, indikator: mockIndikatorKpi[0],
              target: (kpiData['target_omzet'] ?? 0).toDouble(),
              bobot: (kpiData['bobot_omzet'] ?? 0).toDouble(),
              keterangan: 'Target pencapaian omzet bulanan cabang',
              capaian: CapaianKpi(id: 1, targetKpiId: 1, nilaiCapaian: (kpiData['capaian_omzet'] ?? kpiData['realisasi_omzet'] ?? 0).toDouble(), catatan: ''),
            ),
            TargetKpi(
              id: 2, karyawanId: 'CS', periode: p, indikator: mockIndikatorKpi[1],
              target: (kpiData['target_closing_rate'] ?? 0).toDouble(),
              bobot: (kpiData['bobot_closing_rate'] ?? 0).toDouble(),
              keterangan: 'Rasio closing pesanan dari total chat masuk',
              capaian: CapaianKpi(id: 2, targetKpiId: 2, nilaiCapaian: (kpiData['capaian_closing_rate'] ?? kpiData['real_closing_rate'] ?? 0).toDouble(), catatan: ''),
            ),
            TargetKpi(
              id: 3, karyawanId: 'CS', periode: p, indikator: mockIndikatorKpi[2],
              target: (kpiData['target_closing_chat'] ?? 0).toDouble(),
              bobot: (kpiData['bobot_closing_chat'] ?? 0).toDouble(),
              keterangan: 'Rata-rata closing chat per hari kerja aktif',
              capaian: CapaianKpi(id: 3, targetKpiId: 3, nilaiCapaian: (kpiData['capaian_closing_chat'] ?? kpiData['real_closing_chat'] ?? 0).toDouble(), catatan: ''),
            ),
            TargetKpi(
              id: 4, karyawanId: 'CS', periode: p, indikator: mockIndikatorKpi[3],
              target: (kpiData['target_stock_opname'] ?? 0).toDouble(),
              bobot: (kpiData['bobot_stock_opname'] ?? 0).toDouble(),
              keterangan: 'Kedisiplinan pelaporan stock opname rutin',
              capaian: CapaianKpi(id: 4, targetKpiId: 4, nilaiCapaian: (kpiData['nilai_stock_opname'] ?? 0).toDouble(), catatan: ''),
            ),
            TargetKpi(
              id: 5, karyawanId: 'CS', periode: p, indikator: mockIndikatorKpi[4],
              target: (kpiData['target_review_maps'] ?? 0).toDouble(),
              bobot: (kpiData['bobot_review_maps'] ?? 0).toDouble(),
              keterangan: 'Perolehan ulasan bintang 5 dari pelanggan',
              capaian: CapaianKpi(id: 5, targetKpiId: 5, nilaiCapaian: (kpiData['nilai_review_maps'] ?? 0).toDouble(), catatan: ''),
            ),
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _kpiList = mockTargetKpi;
          _namaPeriode = mockPeriodeKpi.namaPeriode;
          _isLoading = false;
        });
      }
    }
  }

  String _getMonthName(int m) {
    const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return months[m - 1];
  }

  String _formatRupiah(double n) =>
      'Rp ${n.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    double totalBobot = 0;
    double totalScore = 0;
    
    for (var kpi in _kpiList) {
      totalBobot += kpi.bobot;
      double capaian = kpi.capaian?.nilaiCapaian ?? 0;
      double percentage = (capaian / (kpi.target > 0 ? kpi.target : 1)).clamp(0.0, 1.0);
      totalScore += (percentage * kpi.bobot);
    }
    
    double finalScorePercentage = _apiTotalNilaiKpi >= 0
        ? (_apiTotalNilaiKpi / 100.0).clamp(0.0, 1.0)
        : (totalBobot > 0 ? (totalScore / totalBobot) : 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(finalScorePercentage),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadKpi,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    children: [
                      Text(
                        'INDIKATOR PENILAIAN KPI',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._kpiList.map((kpi) => _buildKpiCard(kpi)),
                      const SizedBox(height: 12),
                      _buildStrategiPencapaian(),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double scorePercentage) {
    final bool isAchieved = scorePercentage >= 1.0;
    final bool isGood = scorePercentage >= 0.8;
    final Color scoreColor = isAchieved
        ? const Color(0xFF10B981)
        : isGood
            ? const Color(0xFF3B82F6)
            : const Color(0xFFF59E0B);

    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HeaderBackButton(onTap: () => Navigator.pop(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KPI Customer Service ✨',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Pantau performa & target mingguanmu',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _namaPeriode,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL SKOR KESELURUHAN',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withValues(alpha: 0.75),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            (scorePercentage * 100).toStringAsFixed(1),
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '%',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAchieved
                            ? 'Luar biasa! Target bulan ini tercapai 🎉'
                            : isGood
                                ? 'Performa bagus, sedikit lagi capai 100% 💪'
                                : 'Ayo tingkatkan performa minggu ini! 🚀',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: scoreColor, width: 2),
                  ),
                  child: Icon(
                    isAchieved
                        ? Icons.emoji_events_rounded
                        : isGood
                            ? Icons.trending_up_rounded
                            : Icons.bolt_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(TargetKpi kpi) {
    double capaian = kpi.capaian?.nilaiCapaian ?? 0;
    double percentage = (capaian / (kpi.target > 0 ? kpi.target : 1)).clamp(0.0, 1.0);
    bool isRupiah = kpi.indikator.satuan.toLowerCase() == 'rupiah';
    bool isPercent = kpi.indikator.satuan == '%';
    
    String targetStr = isRupiah ? _formatRupiah(kpi.target) : '${kpi.target.toInt()}${isPercent ? '%' : ' ' + kpi.indikator.satuan}';
    String capaianStr = isRupiah ? _formatRupiah(capaian) : '${capaian.toInt()}${isPercent ? '%' : ' ' + kpi.indikator.satuan}';

    final bool isDone = percentage >= 1.0;
    final bool isProgress = percentage >= 0.7;
    final Color badgeBg = isDone
        ? const Color(0xFFD1FAE5)
        : isProgress
            ? const Color(0xFFDBEAFE)
            : const Color(0xFFFEF3C7);
    final Color badgeText = isDone
        ? const Color(0xFF065F46)
        : isProgress
            ? const Color(0xFF1E40AF)
            : const Color(0xFF92400E);
    final String badgeLabel = isDone
        ? 'Tercapai 🎯'
        : isProgress
            ? 'Progres 📈'
            : 'Belum Capai ⚡';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDone ? const Color(0xFF10B981).withValues(alpha: 0.4) : AppColors.border, width: isDone ? 1.5 : 1),
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
                    Text(
                      kpi.indikator.namaIndikator,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (kpi.keterangan.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        kpi.keterangan,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badgeLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bobot: ${kpi.bobot.toInt()}%',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Capaian Saat Ini', style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textMuted,
                    )),
                    const SizedBox(height: 2),
                    Text(capaianStr, style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.bold, color: isDone ? const Color(0xFF10B981) : AppColors.primary,
                    )),
                  ],
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: AppColors.border,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Target Bulanan', style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textMuted,
                    )),
                    const SizedBox(height: 2),
                    Text(targetStr, style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark,
                    )),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: AppColors.surfaceBlue,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDone ? const Color(0xFF10B981) : 
                isProgress ? const Color(0xFF3B82F6) : 
                const Color(0xFFF59E0B)
              ),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rasio Pencapaian: ${(percentage * 100).toInt()}%',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                'Poin Akhir: ${(percentage * kpi.bobot).toStringAsFixed(1)} / ${kpi.bobot.toInt()}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDone ? const Color(0xFF10B981) : AppColors.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrategiPencapaian() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Strategi & Target Mingguan 🚀',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'Milestone pencapaian omzet tgl 7, 14, 21, & 28',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildMilestoneCard('Milestone 1 — Tgl 7 (25%)', _targetTgl7, _stratTgl7, const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
          const SizedBox(height: 12),
          _buildMilestoneCard('Milestone 2 — Tgl 14 (50%)', _targetTgl14, _stratTgl14, const Color(0xFFF5F3FF), const Color(0xFF7C3AED)),
          const SizedBox(height: 12),
          _buildMilestoneCard('Milestone 3 — Tgl 21 (75%)', _targetTgl21, _stratTgl21, const Color(0xFFFFF7ED), const Color(0xFFEA580C)),
          const SizedBox(height: 12),
          _buildMilestoneCard('Milestone 4 — Tgl 28 (100%)', _targetTgl28, _stratTgl28, const Color(0xFFECFDF5), const Color(0xFF059669)),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard(String title, double target, String strategi, Color bg, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              Text(
                _formatRupiah(target),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          if (strategi.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strategi,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textDark,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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

  int _selectedBulan = DateTime.now().month;
  int _selectedTahun = DateTime.now().year;

  double _apiTotalNilaiKpi = -1;
  double _realOmzet = 0;
  double _targetTgl7 = 30000000;
  double _targetTgl14 = 60000000;
  double _targetTgl21 = 90000000;
  double _targetTgl28 = 120000000;

  @override
  void initState() {
    super.initState();
    _selectedBulan = DateTime.now().month;
    _selectedTahun = DateTime.now().year.clamp(2025, 2030);
    _loadKpi();
  }

  Future<void> _loadKpi() async {
    setState(() => _isLoading = true);
    try {
      final service = KpiService();
      final kpiData = await service.getKpiCs(bulan: _selectedBulan, tahun: _selectedTahun);
      
      if (mounted) {
        setState(() {
          _namaPeriode = '${_getMonthName(_selectedBulan)} $_selectedTahun';
          
          if (kpiData['total_nilai_kpi'] != null) {
            _apiTotalNilaiKpi = (kpiData['total_nilai_kpi'] as num).toDouble();
          } else {
            _apiTotalNilaiKpi = -1;
          }
          
          _realOmzet = (kpiData['real_omzet'] ?? kpiData['realisasi_omzet'] ?? 0).toDouble();
          _targetTgl7 = (kpiData['target_tgl_7'] ?? 30000000).toDouble();
          _targetTgl14 = (kpiData['target_tgl_14'] ?? 60000000).toDouble();
          _targetTgl21 = (kpiData['target_tgl_21'] ?? 90000000).toDouble();
          _targetTgl28 = (kpiData['target_tgl_28'] ?? 120000000).toDouble();

          final p = PeriodeKpi(id: 1, bulan: _selectedBulan.toString(), tahun: _selectedTahun, namaPeriode: _namaPeriode);
          
          _kpiList = [
            TargetKpi(
              id: 1, karyawanId: 'CS', periode: p, indikator: mockIndikatorKpi[0],
              target: (kpiData['target_omzet'] ?? 0).toDouble(),
              bobot: (kpiData['bobot_omzet'] ?? 40).toDouble(),
              keterangan: 'Target pencapaian omzet bulanan cabang',
              capaian: CapaianKpi(id: 1, targetKpiId: 1, nilaiCapaian: _realOmzet, catatan: ''),
            ),
            TargetKpi(
              id: 2, karyawanId: 'CS', periode: p, indikator: mockIndikatorKpi[1],
              target: (kpiData['target_closing_rate'] ?? 0).toDouble(),
              bobot: (kpiData['bobot_closing_rate'] ?? 20).toDouble(),
              keterangan: 'Rasio closing pesanan dari total chat masuk',
              capaian: CapaianKpi(id: 2, targetKpiId: 2, nilaiCapaian: (kpiData['real_closing_rate'] ?? 0).toDouble(), catatan: ''),
            ),
            TargetKpi(
              id: 3, karyawanId: 'CS', periode: p, indikator: mockIndikatorKpi[2],
              target: (kpiData['target_closing_chat'] ?? 0).toDouble(),
              bobot: (kpiData['bobot_closing_chat'] ?? 20).toDouble(),
              keterangan: 'Rata-rata closing chat per hari kerja aktif',
              capaian: CapaianKpi(id: 3, targetKpiId: 3, nilaiCapaian: (kpiData['real_closing_chat'] ?? 0).toDouble(), catatan: ''),
            ),
            TargetKpi(
              id: 4, karyawanId: 'CS', periode: p, indikator: mockIndikatorKpi[3],
              target: (kpiData['target_stock_opname'] ?? 0).toDouble(),
              bobot: (kpiData['bobot_stock_opname'] ?? 10).toDouble(),
              keterangan: 'Kedisiplinan pelaporan stock opname rutin',
              capaian: CapaianKpi(id: 4, targetKpiId: 4, nilaiCapaian: (kpiData['nilai_stock_opname'] ?? 0).toDouble(), catatan: ''),
            ),
            TargetKpi(
              id: 5, karyawanId: 'CS', periode: p, indikator: mockIndikatorKpi[4],
              target: (kpiData['target_review_maps'] ?? 0).toDouble(),
              bobot: (kpiData['bobot_review_maps'] ?? 10).toDouble(),
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
          _namaPeriode = '${_getMonthName(_selectedBulan)} $_selectedTahun';
          _isLoading = false;
        });
      }
    }
  }

  void _showPeriodPicker() {
    int tempMonth = _selectedBulan;
    int tempYear = _selectedTahun;

    final List<int> years = [2025, 2026, 2027, 2028, 2029, 2030];
    final List<String> monthShortNames = [
      'Januari', 'Februari', 'Maret', 'April',
      'Mei', 'Juni', 'Juli', 'Agustus',
      'September', 'Oktober', 'November', 'Desember'
    ];

    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pull Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pilih Periode KPI',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Section 1: Tahun (2025 - 2030)
                  Text(
                    'TAHUN (2025 - 2030)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: years.map((y) {
                        final isSelected = tempYear == y;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                tempYear = y;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                y.toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Section 2: Bulan (Jan - Des)
                  Text(
                    'BULAN',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 2.4,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final monthNum = index + 1;
                      final isSelected = tempMonth == monthNum;
                      return InkWell(
                        onTap: () {
                          setModalState(() {
                            tempMonth = monthNum;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            monthShortNames[index],
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textMuted,
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedBulan = tempMonth;
                              _selectedTahun = tempYear;
                            });
                            _loadKpi();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Terapkan Periode',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Text(
                        'RINCIAN INDIKATOR KPI',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._kpiList.map((kpi) => _buildKpiCard(kpi)),
                      const SizedBox(height: 8),
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
      padding: EdgeInsets.fromLTRB(20, 52, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 22 : 26),
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
                      'KPI Customer Service',
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
              InkWell(
                onTap: _showPeriodPicker,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        _namaPeriode,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 16),
                    ],
                  ),
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
                            ? 'Luar biasa! Target bulan ini tercapai'
                            : isGood
                                ? 'Performa bagus, sedikit lagi capai 100%'
                                : 'Ayo tingkatkan performa minggu ini!',
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
    
    String targetStr = isRupiah
        ? _formatRupiah(kpi.target)
        : '${kpi.target.toStringAsFixed(kpi.target % 1 == 0 ? 0 : 1)}${isPercent ? '%' : ' ${kpi.indikator.satuan}'}';
    String capaianStr = isRupiah
        ? _formatRupiah(capaian)
        : '${capaian.toStringAsFixed(capaian % 1 == 0 ? 0 : 1)}${isPercent ? '%' : ' ${kpi.indikator.satuan}'}';

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
        ? 'Tercapai'
        : isProgress
            ? 'Progres'
            : 'Belum Capai';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
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
                      const SizedBox(height: 3),
                      Text(
                        kpi.keterangan,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
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
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
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
                    Text('Nilai / Realisasi', style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textMuted,
                    )),
                    const SizedBox(height: 2),
                    Text(capaianStr, style: GoogleFonts.inter(
                      fontSize: 14.5, fontWeight: FontWeight.bold, color: isDone ? const Color(0xFF10B981) : AppColors.primary,
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
                      fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textDark,
                    )),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rasio Capaian: ${(percentage * 100).toInt()}%',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                'Poin: ${(percentage * kpi.bobot).toStringAsFixed(1)} / ${kpi.bobot.toInt()}%',
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
      margin: const EdgeInsets.only(top: 6, bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
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
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.track_changes_rounded, color: Color(0xFF0284C7), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Strategi Pencapaian Omzet',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'Tahapan target omzet kumulatif mingguan',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMilestoneCard('TGL 7', '25%', _targetTgl7, _realOmzet, const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
          const SizedBox(height: 10),
          _buildMilestoneCard('TGL 14', '50%', _targetTgl14, _realOmzet, const Color(0xFFF5F3FF), const Color(0xFF7C3AED)),
          const SizedBox(height: 10),
          _buildMilestoneCard('TGL 21', '75%', _targetTgl21, _realOmzet, const Color(0xFFFFF7ED), const Color(0xFFEA580C)),
          const SizedBox(height: 10),
          _buildMilestoneCard('TGL 28', '100%', _targetTgl28, _realOmzet, const Color(0xFFECFDF5), const Color(0xFF059669)),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard(String label, String percentBadge, double target, double omzetAktual, Color bg, Color accent) {
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
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  percentBadge,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatRupiah(target),
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Omzet Aktual:',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatRupiah(omzetAktual),
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

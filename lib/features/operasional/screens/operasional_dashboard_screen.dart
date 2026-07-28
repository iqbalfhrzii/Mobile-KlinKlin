import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../services/operasional_service.dart';
import '../../../core/widgets/gradient_header.dart';
import 'operasional_pengaturan_screen.dart';
class OperasionalDashboardScreen extends StatefulWidget {
  const OperasionalDashboardScreen({super.key});

  @override
  State<OperasionalDashboardScreen> createState() =>
      _OperasionalDashboardScreenState();
}

class _OperasionalDashboardScreenState extends State<OperasionalDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _service = OperasionalService();
  late TabController _tabController;

  bool _isLoading = true;
  String _error = '';

  // API Data
  Map<String, dynamic>? _data;

  // Filters
  String _selectedFilter = 'Bulan Ini';
  final List<String> _filters = [
    'Bulan Ini',
    'Kemarin',
    'Hari Ini',
    'Kustom Tanggal',
  ];

  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      String? start;
      String? end;

      final now = DateTime.now();

      if (_selectedFilter == 'Bulan Ini') {
        start = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime(now.year, now.month, 1));
        end = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime(now.year, now.month + 1, 0));
      } else if (_selectedFilter == 'Hari Ini') {
        start = DateFormat('yyyy-MM-dd').format(now);
        end = DateFormat('yyyy-MM-dd').format(now);
      } else if (_selectedFilter == 'Kemarin') {
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateFormat('yyyy-MM-dd').format(yesterday);
        end = DateFormat('yyyy-MM-dd').format(yesterday);
      } else if (_selectedFilter == 'Kustom Tanggal') {
        if (_customStartDate != null && _customEndDate != null) {
          start = DateFormat('yyyy-MM-dd').format(_customStartDate!);
          end = DateFormat('yyyy-MM-dd').format(_customEndDate!);
        } else {
          // fallback to this month
          start = DateFormat(
            'yyyy-MM-dd',
          ).format(DateTime(now.year, now.month, 1));
          end = DateFormat(
            'yyyy-MM-dd',
          ).format(DateTime(now.year, now.month + 1, 0));
        }
      }

      final res = await _service.getLaporanOmzet(
        startDate: start,
        endDate: end,
      );
      if (res['status'] == true) {
        setState(() {
          _data = res['data'];
        });
      } else {
        setState(() => _error = res['message'] ?? 'Unknown error');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onFilterChanged(String filter) async {
    if (filter == 'Kustom Tanggal') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      if (picked != null) {
        setState(() {
          _selectedFilter = filter;
          _customStartDate = picked.start;
          _customEndDate = picked.end;
        });
        _fetchData();
      }
    } else {
      setState(() => _selectedFilter = filter);
      _fetchData();
    }
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          GradientHeader(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Laporan Omzet',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kinerja pendapatan & penjualan',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OperasionalPengaturanScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings_rounded, color: Colors.white),
                    tooltip: 'Pengaturan',
                  ),
                ),
              ],
            ),
          ),

          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: _filters.map((f) {
                final isSelected = _selectedFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _onFilterChanged(f),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        f == 'Kustom Tanggal' &&
                                _customStartDate != null &&
                                isSelected
                            ? '${DateFormat('dd MMM').format(_customStartDate!)} - ${DateFormat('dd MMM').format(_customEndDate!)}'
                            : f,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error.isNotEmpty)
            Expanded(
              child: Center(
                child: Text(_error, style: const TextStyle(color: Colors.red)),
              ),
            )
          else if (_data != null)
            Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final global = _data!['global'];
    final growth = (global['growth'] as num).toDouble();
    final isGrowthPos = growth >= 0;

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Summary Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'OMZET PERIODE INI',
                          _formatCurrency(global['omzet_periode_ini']),
                          null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          'OMZET PERIODE LALU',
                          _formatCurrency(global['omzet_periode_lalu']),
                          null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'GROWTH VS LALU',
                          _formatCurrency(
                            global['omzet_periode_ini'] -
                                global['omzet_periode_lalu'],
                          ),
                          isGrowthPos
                              ? '+${growth.toStringAsFixed(1)}%'
                              : '${growth.toStringAsFixed(1)}%',
                          valueColor: isGrowthPos ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          'JUMLAH CANCEL',
                          '${global['jumlah_cancel']} Order',
                          null,
                          valueColor: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Fast Buttons Grid (2 atas, 2 bawah - compact)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildFastButton(
                              0,
                              'Omzet Cabang',
                              Icons.storefront_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFastButton(
                              1,
                              'Ringkasan Layanan',
                              Icons.design_services_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFastButton(
                              2,
                              'Detail Layanan',
                              Icons.list_alt_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFastButton(
                              3,
                              'Ranking & Visual',
                              Icons.insights_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabOmzetCabang(),
          _buildTabRingkasanLayanan(),
          _buildTabDetailLayanan(),
          _buildTabRankingVisualisasi(),
        ],
      ),
    );
  }

  Widget _buildFastButton(int index, String label, IconData icon) {
    final isSelected = _tabController.index == index;
    return InkWell(
      onTap: () {
        setState(() {
          _tabController.animateTo(index);
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String? subValue, {
    Color valueColor = AppColors.textDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (subValue != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: valueColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subValue,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: valueColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabOmzetCabang() {
    final list = _data!['omzet_per_cabang'] as List;
    if (list.isEmpty) return const Center(child: Text('Tidak ada data'));

    double totalIni = 0;
    double totalLalu = 0;
    double totalAds = 0;
    double totalOrganik = 0;
    double totalLama = 0;

    for (var item in list) {
      totalIni += (item['periode_ini'] as num? ?? 0).toDouble();
      totalLalu += (item['periode_lalu'] as num? ?? 0).toDouble();
      totalAds += (item['ads'] as num? ?? 0).toDouble();
      totalOrganik += (item['organik'] as num? ?? 0).toDouble();
      totalLama += (item['lama'] as num? ?? 0).toDouble();
    }
    double totalGrowth = totalLalu > 0
        ? ((totalIni - totalLalu) / totalLalu) * 100
        : 0;
    final isTotalPos = totalGrowth >= 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 🎯 GRAND TOTAL BANNER CARD
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL OMZET GABUNGAN',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isTotalPos
                          ? Colors.green.shade400.withOpacity(0.3)
                          : Colors.red.shade400.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isTotalPos
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isTotalPos
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${totalGrowth.toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatCurrency(totalIni),
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Periode Lalu: ${_formatCurrency(totalLalu)}',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMiniStatWhite('ADS', _formatCurrency(totalAds)),
                    Container(width: 1, height: 28, color: Colors.white24),
                    _buildMiniStatWhite(
                      'ORGANIK',
                      _formatCurrency(totalOrganik),
                    ),
                    Container(width: 1, height: 28, color: Colors.white24),
                    _buildMiniStatWhite('LAMA', _formatCurrency(totalLama)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'PERFORMA CABANG',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),

        // 🏢 CABANG CARDS
        ...list.map((item) {
          final pIni = (item['periode_ini'] as num? ?? 0).toDouble();
          final pLalu = (item['periode_lalu'] as num? ?? 0).toDouble();
          final growth = (item['growth'] as num? ?? 0).toDouble();
          final isPos = growth >= 0;
          final ads = (item['ads'] as num? ?? 0).toDouble();
          final organik = (item['organik'] as num? ?? 0).toDouble();
          final lama = (item['lama'] as num? ?? 0).toDouble();

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.storefront_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          item['nama_cabang']?.toString().toUpperCase() ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPos
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPos ? Icons.trending_up : Icons.trending_down,
                            size: 14,
                            color: isPos
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${isPos ? '+' : ''}${growth.toStringAsFixed(1)}%',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isPos
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Omzet Periode Ini',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatCurrency(pIni),
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Periode Lalu',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatCurrency(pLalu),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: Colors.grey.shade100, height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSourceChip(
                      'Ads',
                      _formatCurrency(ads),
                      Colors.blue.shade700,
                    ),
                    _buildSourceChip(
                      'Organik',
                      _formatCurrency(organik),
                      Colors.green.shade700,
                    ),
                    _buildSourceChip(
                      'Lama',
                      _formatCurrency(lama),
                      Colors.orange.shade700,
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMiniStatWhite(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSourceChip(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTabRingkasanLayanan() {
    final list = _data!['ringkasan_layanan'] as List;
    if (list.isEmpty) return const Center(child: Text('Tidak ada data'));

    Map<String, dynamic>? overallHighest;
    Map<String, dynamic>? overallLowest;
    Map<String, dynamic>? overallMost;
    Map<String, dynamic>? overallLeast;

    for (var item in list) {
      final h = item['omzet_tertinggi'];
      if (h != null &&
          (overallHighest == null ||
              (h['total'] as num? ?? 0) >
                  (overallHighest['total'] as num? ?? 0))) {
        overallHighest = h;
      }
      final l = item['omzet_terendah'];
      if (l != null &&
          (overallLowest == null ||
              (l['total'] as num? ?? 0) <
                  (overallLowest['total'] as num? ?? 0))) {
        overallLowest = l;
      }
      final m = item['trx_terbanyak'];
      if (m != null &&
          (overallMost == null ||
              (m['trx'] as num? ?? 0) > (overallMost['trx'] as num? ?? 0))) {
        overallMost = m;
      }
      final le = item['trx_tersedikit'];
      if (le != null &&
          (overallLeast == null ||
              (le['trx'] as num? ?? 0) < (overallLeast['trx'] as num? ?? 0))) {
        overallLeast = le;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 🏆 REKOR TOTAL NASIONAL CARD
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.amber.shade700, Colors.orange.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'REKOR TOTAL NASIONAL',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildRekorItem(
                      'Omzet Tertinggi',
                      overallHighest,
                      isTrx: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRekorItem(
                      'Trx Terbanyak',
                      overallMost,
                      isTrx: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildRekorItem(
                      'Omzet Terendah',
                      overallLowest,
                      isTrx: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRekorItem(
                      'Trx Tersedikit',
                      overallLeast,
                      isTrx: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'RINGKASAN PER CABANG',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),

        // 🏢 BRANCH SUMMARY CARDS
        ...list.map((item) {
          final highest = item['omzet_tertinggi'];
          final lowest = item['omzet_terendah'];
          final most = item['trx_terbanyak'];
          final least = item['trx_tersedikit'];

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.insights_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item['nama_cabang']?.toString().toUpperCase() ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: Colors.grey.shade100, height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryBox(
                        'Omzet Tertinggi',
                        highest,
                        Colors.green,
                        isTrx: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSummaryBox(
                        'Trx Terbanyak',
                        most,
                        Colors.orange,
                        isTrx: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryBox(
                        'Omzet Terendah',
                        lowest,
                        Colors.grey,
                        isTrx: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSummaryBox(
                        'Trx Tersedikit',
                        least,
                        Colors.blueGrey,
                        isTrx: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRekorItem(String label, dynamic data, {required bool isTrx}) {
    if (data == null) return Container();
    final name = data['nama_layanan']?.toString() ?? '-';
    final val = isTrx ? '${data['trx']} trx' : _formatCurrency(data['total']);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            val,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox(
    String label,
    dynamic data,
    MaterialColor color, {
    required bool isTrx,
  }) {
    if (data == null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '-',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
        ),
      );
    }
    final name = data['nama_layanan']?.toString() ?? '-';
    final val = isTrx ? '${data['trx']} trx' : _formatCurrency(data['total']);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: color.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            val,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabDetailLayanan() {
    final list = _data!['detail_layanan'] as List;
    if (list.isEmpty) return const Center(child: Text('Tidak ada data'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final namaCabang = item['nama_cabang'].toString();
        final layananMap = item['layanan'] as Map;

        // Collect active services (> 0 omzet or > 0 trx)
        final activeServices = <Map<String, dynamic>>[];
        double totalOmzet = 0.0;
        int totalTrx = 0;

        layananMap.forEach((key, val) {
          final omzet = _getLayananOmzet(val);
          final trx = _getLayananTrx(val);
          if (omzet > 0 || trx > 0) {
            activeServices.add({
              'name': key.toString(),
              'omzet': omzet,
              'trx': trx,
            });
            totalOmzet += omzet;
            totalTrx += trx;
          }
        });

        // Sort active services descending by omzet
        activeServices.sort(
          (a, b) => (b['omzet'] as double).compareTo(a['omzet'] as double),
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.store_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            namaCabang.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${activeServices.length} Layanan Aktif • $totalTrx Trx',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatCurrency(totalOmzet),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // Active Services List
              if (activeServices.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Belum ada transaksi di cabang ini',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: activeServices.length,
                  separatorBuilder: (context, i) =>
                      Divider(color: Colors.grey.shade100, height: 20),
                  itemBuilder: (context, i) {
                    final s = activeServices[i];
                    return Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s['name'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${s['trx']} trx',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 110,
                          child: Text(
                            _formatCurrency(s['omzet'] as num),
                            textAlign: TextAlign.right,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabRankingVisualisasi() {
    final listCabang = List<Map<String, dynamic>>.from(
      _data!['omzet_per_cabang'] as List,
    );
    listCabang.sort(
      (a, b) => (b['periode_ini'] as num).compareTo(a['periode_ini'] as num),
    );
    final maxCabang = listCabang.isEmpty
        ? 1.0
        : (listCabang.first['periode_ini'] as num).toDouble();

    final mapLayananTotal = <String, double>{};
    for (var item in (_data!['detail_layanan'] as List)) {
      final lMap = item['layanan'] as Map;
      lMap.forEach((k, v) {
        mapLayananTotal[k.toString()] =
            (mapLayananTotal[k.toString()] ?? 0) + _getLayananOmzet(v);
      });
    }
    final sortedLayanan = mapLayananTotal.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxLayanan = sortedLayanan.isEmpty ? 1.0 : sortedLayanan.first.value;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRankingSectionTitle(
            '🏆 Top Cabang Tertinggi (Omzet)',
            AppColors.primary,
          ),
          const SizedBox(height: 12),
          ...listCabang.take(5).toList().asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final item = entry.value;
            final val = (item['periode_ini'] as num).toDouble();
            final pct = maxCabang > 0 ? val / maxCabang : 0.0;
            return _buildRankingCard(
              idx,
              item['nama_cabang'],
              _formatCurrency(val),
              pct,
              AppColors.primary,
            );
          }),
          const SizedBox(height: 24),
          _buildRankingSectionTitle(
            '⚡ Top Layanan Terlaris (Omzet)',
            Colors.green.shade700,
          ),
          const SizedBox(height: 12),
          ...sortedLayanan.take(5).toList().asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final item = entry.value;
            final val = item.value;
            final pct = maxLayanan > 0 ? val / maxLayanan : 0.0;
            return _buildRankingCard(
              idx,
              item.key,
              _formatCurrency(val),
              pct,
              Colors.green.shade700,
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRankingSectionTitle(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildRankingCard(
    int rank,
    String title,
    String value,
    double progress,
    Color color,
  ) {
    Color badgeColor;
    if (rank == 1)
      badgeColor = const Color(0xFFEAA100); // Gold
    else if (rank == 2)
      badgeColor = const Color(0xFF9E9E9E); // Silver
    else if (rank == 3)
      badgeColor = const Color(0xFFCD7F32); // Bronze
    else
      badgeColor = Colors.grey.shade300;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '#$rank',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: rank <= 3 ? Colors.white : AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  double _getLayananOmzet(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is Map) return (val['omzet'] as num? ?? 0).toDouble();
    return 0.0;
  }

  int _getLayananTrx(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val > 0 ? 1 : 0;
    if (val is Map) return (val['trx'] as num? ?? 0).toInt();
    return 0;
  }
}

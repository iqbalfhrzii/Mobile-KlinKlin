import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import 'operasional_report_kpi_screen.dart';
import 'operasional_kpi_cs_screen.dart';

class OperasionalKpiMainScreen extends StatefulWidget {
  final int initialIndex;
  const OperasionalKpiMainScreen({super.key, this.initialIndex = 0});

  @override
  State<OperasionalKpiMainScreen> createState() => _OperasionalKpiMainScreenState();
}

class _OperasionalKpiMainScreenState extends State<OperasionalKpiMainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          GradientHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Key Performance Indicator',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Laporan pencapaian target cabang, cleaner & CS',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.white.withValues(alpha: 0.8),
                    labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                    unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.all(4),
                    tabs: const [
                      Tab(text: 'Report CS'),
                      Tab(text: 'KPI CS'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                OperasionalReportKpiScreen(
                  hideHeader: true,
                  onSwitchToKpiCs: () => _tabController.animateTo(1),
                ),
                OperasionalKpiCsScreen(
                  hideHeader: true,
                  onSwitchToReportCs: () => _tabController.animateTo(0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

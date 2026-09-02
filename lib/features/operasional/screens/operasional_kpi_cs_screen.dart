import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/operasional_service.dart';
import 'operasional_kpi_cs_edit_sheet.dart';

import 'operasional_kpi_main_screen.dart';

class OperasionalKpiCsScreen extends StatefulWidget {
  final bool hideHeader;
  final VoidCallback? onSwitchToReportCs;
  const OperasionalKpiCsScreen({super.key, this.hideHeader = false, this.onSwitchToReportCs});

  @override
  State<OperasionalKpiCsScreen> createState() => _OperasionalKpiCsScreenState();
}

class _OperasionalKpiCsScreenState extends State<OperasionalKpiCsScreen> {
  final _service = OperasionalService();
  bool _isLoading = true;
  String _error = '';
  List<dynamic> _data = [];

  int _selectedBulan = DateTime.now().month;
  int _selectedTahun = DateTime.now().year;

  final List<String> _bulanNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

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
      final res = await _service.getKpiCs(bulan: _selectedBulan, tahun: _selectedTahun);
      if (res['status'] == true) {
        setState(() {
          _data = res['data']['kpi_per_cabang'] ?? [];
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

  Future<void> _handleSaveKpi(Map<String, dynamic> data, int cabangId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      
      final payload = {
        'cabang_id': cabangId,
        'bulan': _selectedBulan,
        'tahun': _selectedTahun,
        ...data,
      };

      final res = await _service.updateKpiCs(payload);
      
      if (mounted) Navigator.pop(context); // close dialog
      
      if (res['status'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('KPI Cabang berhasil diperbarui', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
          );
        }
        _fetchData();
      } else {
        throw Exception(res['message'] ?? 'Gagal memperbarui KPI');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // close dialog if error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''), style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          if (!widget.hideHeader)
            GradientHeader(
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KPI Cabang',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Lacak capaian performa bulanan setiap cabang',
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
            ),
          
          // Sleek Month & Year Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                if (!widget.hideHeader) ...[
                  InkWell(
                    onTap: () {
                      if (widget.onSwitchToReportCs != null) {
                        widget.onSwitchToReportCs!();
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const OperasionalKpiMainScreen(initialIndex: 0)));
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.analytics_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Report CS',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Month Dropdown
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedBulan,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                              items: List.generate(12, (index) {
                                return DropdownMenuItem<int>(
                                  value: index + 1,
                                  child: Text(_bulanNames[index]),
                                );
                              }),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedBulan = val);
                                  _fetchData();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Year Dropdown
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedTahun,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                              items: List.generate(7, (index) {
                                final year = 2024 + index;
                                return DropdownMenuItem<int>(
                                  value: year,
                                  child: Text(year.toString()),
                                );
                              }),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedTahun = val);
                                  _fetchData();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error.isNotEmpty
                    ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
                child: const Icon(Icons.leaderboard_rounded, size: 36, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text(
                'Tidak Ada Data KPI Cabang',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _buildSummaryTable(),
        const SizedBox(height: 12),
        ..._data.map((item) => _buildDetailedCard(item)),
      ],
    );
  }

  Widget _buildSummaryTable() {
    if (_data.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ringkasan KPI Cabang',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(color: Color(0xFFE11D48), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Merah: < 100%',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFBE123C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ..._data.map((item) {
          final totalNilai = (item['total_nilai_kpi'] as num).toDouble();
          final isAman = totalNilai >= 100.0;
          
          Color statusColor = isAman ? const Color(0xFF059669) : const Color(0xFFE11D48);
          Color statusBgColor = statusColor.withValues(alpha: 0.1);
          IconData statusIcon = isAman ? Icons.trending_up_rounded : Icons.trending_down_rounded;

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Cabang & KPI Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Icon(statusIcon, color: statusColor, size: 14),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item['nama_cabang'].toString().toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${totalNilai.toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 6),
                  // Row 2: Realisasi Omzet vs Target KPI
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Realisasi: ',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            _formatCurrency(item['realisasi_omzet']),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'Target: ',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            item['target_nilai_kpi'].toString(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (totalNilai / 100).clamp(0.0, 1.0),
                      backgroundColor: statusColor.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDBEAFE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nilai Omzet, Closing Rate, Closing Chat dihitung otomatis. Metrik manual diisi lewat tombol "Atur" di bawah.',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF1D4ED8), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedCard(dynamic item) {
    final totalNilai = (item['total_nilai_kpi'] as num).toDouble();
    final isAman = totalNilai >= 100.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['nama_cabang'].toString().toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bulan: ${_bulanNames[_selectedBulan - 1]} $_selectedTahun',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        showModalBottomSheet(
      useSafeArea: true,
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => Padding(
                            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.85,
                              child: EditKpiCsBottomSheet(
                                initialData: item,
                                onSave: (data) => _handleSaveKpi(data, item['cabang_id']),
                              ),
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_note_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Atur',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAman ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Total ${totalNilai.toStringAsFixed(1)}%',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Target ${item['target_nilai_kpi']}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Metrics List
          Column(
            children: [
              _buildMetricItem('Omzet', true, _formatCurrency(item['target_omzet']), '${item['bobot_omzet']}%', _formatCurrency(item['realisasi_omzet']), item['capaian_omzet']),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              _buildMetricItem('Closing Rate', true, '${item['target_closing_rate']}%', '${item['bobot_closing_rate']}%', '${item['realisasi_closing_rate']}%', item['capaian_closing_rate']),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              _buildMetricItem('Closing Chat (Rata-rata/Hari)', true, '${item['target_closing_chat']}', '${item['bobot_closing_chat']}%', '${item['realisasi_closing_chat']} dari ${item['total_hari_chat']} hr', item['capaian_closing_chat']),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              _buildMetricItem('Stock Opname', false, '${item['target_stock_opname']}', '${item['bobot_stock_opname']}%', '${item['nilai_stock_opname']}', item['capaian_stock_opname']),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              _buildMetricItem('Review Maps', false, '${item['target_review_maps']}', '${item['bobot_review_maps']}%', '${item['nilai_review_maps']}', item['capaian_review_maps']),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              
              // Total Row
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL KPI', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    Row(
                      children: [
                        Text('Target: ${item['target_nilai_kpi']}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAman ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isAman ? Colors.green.shade200 : Colors.red.shade200),
                          ),
                          child: Text('${totalNilai.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: isAman ? Colors.green.shade700 : Colors.red.shade700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          
          // Strategi Pencapaian
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up_rounded, size: 16, color: Colors.grey.shade400),
                    const SizedBox(width: 8),
                    Text(
                      'STRATEGI PENCAPAIAN (NOMINAL TARGET)',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStrategiBox('Tgl 7 (25%)', item['target_tgl_7'], Colors.red),
                    const SizedBox(width: 8),
                    _buildStrategiBox('Tgl 14 (50%)', item['target_tgl_14'], Colors.orange),
                    const SizedBox(width: 8),
                    _buildStrategiBox('Tgl 21 (75%)', item['target_tgl_21'], Colors.green),
                    const SizedBox(width: 8),
                    _buildStrategiBox('Tgl 28 (100%)', item['target_tgl_28'], Colors.blue),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String name, bool isAuto, String target, String bobot, String realisasi, dynamic capaian) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark))),
                    if (isAuto) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text('AUTO', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text('Target: $target', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                    Text('Bobot: $bobot', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Realisasi', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(realisasi, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark), textAlign: TextAlign.right),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 55,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('CAPAI', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text('${(capaian as num).toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategiBox(String label, dynamic value, MaterialColor color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            top: BorderSide(color: color, width: 3),
            bottom: BorderSide(color: Colors.grey.shade200),
            left: BorderSide(color: Colors.grey.shade200),
            right: BorderSide(color: Colors.grey.shade200),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _formatCurrency(value),
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: color.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

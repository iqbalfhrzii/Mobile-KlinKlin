import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/operasional_service.dart';
import 'operasional_kpi_cs_edit_sheet.dart';

class OperasionalKpiCsScreen extends StatefulWidget {
  final bool hideHeader;
  const OperasionalKpiCsScreen({super.key, this.hideHeader = false});

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
            const SnackBar(content: Text('KPI CS berhasil diperbarui', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
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
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          if (!widget.hideHeader)
            GradientHeader(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KPI CS',
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
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // Filter section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildDropdown(
                  items: List.generate(12, (index) => index + 1),
                  value: _selectedBulan,
                  labelBuilder: (val) => _bulanNames[val - 1],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedBulan = val);
                      _fetchData();
                    }
                  },
                  prefix: 'BULAN',
                ),
                const SizedBox(width: 12),
                _buildDropdown(
                  items: List.generate(10, (index) => 2020 + index),
                  value: _selectedTahun,
                  labelBuilder: (val) => val.toString(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedTahun = val);
                      _fetchData();
                    }
                  },
                  prefix: 'TAHUN',
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required List<T> items,
    required T value,
    required String Function(T) labelBuilder,
    required ValueChanged<T?> onChanged,
    required String prefix,
  }) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            prefix,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              icon: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.keyboard_arrow_down, size: 16),
              ),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(labelBuilder(e)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_data.isEmpty) return const Center(child: Text('Tidak ada data'));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      children: [
        _buildSummaryTable(),
        const SizedBox(height: 24),
        ..._data.map((item) => _buildDetailedCard(item)).toList(),
      ],
    );
  }

  Widget _buildSummaryTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Ringkasan Nilai KPI per Cabang',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    'Merah = Belum Capai Target',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _data.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
            itemBuilder: (context, index) {
              final item = _data[index];
              final totalNilai = (item['total_nilai_kpi'] as num).toDouble();
              final isAman = totalNilai >= 100.0;
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['nama_cabang'].toString(),
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Realisasi Omzet', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                                    const SizedBox(height: 2),
                                    Text(_formatCurrency(item['realisasi_omzet']), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Target KPI', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                                    const SizedBox(height: 2),
                                    Text(item['target_nilai_kpi'].toString(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isAman ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isAman ? Colors.green.shade200 : Colors.red.shade200),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('TOTAL', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: isAman ? Colors.green.shade700 : Colors.red.shade700)),
                          const SizedBox(height: 2),
                          Text('${totalNilai.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: isAman ? Colors.green.shade700 : Colors.red.shade700)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nilai Omzet, Closing Rate, Closing Chat dihitung otomatis. Metrik manual diisi lewat tombol "Atur".',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.blue.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
            color: Colors.black.withOpacity(0.04),
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
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        showModalBottomSheet(
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
                        color: Colors.white.withOpacity(0.2),
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
              color: Colors.black.withOpacity(0.02),
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

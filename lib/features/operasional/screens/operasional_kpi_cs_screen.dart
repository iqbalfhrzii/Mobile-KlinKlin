import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/operasional_service.dart';

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
          
          // Banner & Cards Section
          if (_data.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Merah ',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.red.shade700, fontSize: 12),
                          ),
                          TextSpan(
                            text: '— Belum Capai Minimal Target KPI (100%)',
                            style: GoogleFonts.inter(color: Colors.red.shade900, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                    : _buildTable(),
          ),
          const SizedBox(height: 16),
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

  Widget _buildTable() {
    if (_data.isEmpty) return const Center(child: Text('Tidak ada data'));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: _data.length,
      itemBuilder: (context, index) {
        final item = _data[index];
        final totalNilai = (item['total_nilai_kpi'] as num).toDouble();
        final isAman = totalNilai >= 100.0;
        final realisasi = _formatCurrency(item['realisasi_omzet']);
        final targetNilai = item['target_nilai_kpi'].toString();
        final progress = (totalNilai / 100.0).clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isAman ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isAman ? Colors.green : Colors.red).withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Cabang & Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isAman ? Colors.green : Colors.red).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isAman ? Icons.verified_rounded : Icons.warning_amber_rounded,
                          color: isAman ? Colors.green : Colors.red,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        item['nama_cabang'].toString().toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isAman ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${totalNilai.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 14),
              // Body Grid: Realisasi Omzet & Target Nilai KPI
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REALISASI OMZET',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          realisasi,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TARGET NILAI KPI',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          targetNilai,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: (isAman ? Colors.green : Colors.red).withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(isAman ? Colors.green : Colors.red),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/operasional_service.dart';

class OperasionalDataChatScreen extends StatefulWidget {
  final bool hideHeader;
  const OperasionalDataChatScreen({super.key, this.hideHeader = false});

  @override
  State<OperasionalDataChatScreen> createState() => _OperasionalDataChatScreenState();
}

class _OperasionalDataChatScreenState extends State<OperasionalDataChatScreen> {
  final _service = OperasionalService();
  bool _isLoading = true;
  String _error = '';
  Map<String, dynamic>? _data;

  String _selectedFilter = 'Semua';
  final List<String> _filters = ['Semua', 'Kemarin', 'Hari Ini', 'Besok', 'Kustom Tanggal'];
  DateTime? _customStartDate;
  DateTime? _customEndDate;

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
      String? start;
      String? end;
      final now = DateTime.now();

      if (_selectedFilter == 'Semua') {
        start = null;
        end = null;
      } else if (_selectedFilter == 'Hari Ini') {
        start = DateFormat('yyyy-MM-dd').format(now);
        end = DateFormat('yyyy-MM-dd').format(now);
      } else if (_selectedFilter == 'Kemarin') {
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateFormat('yyyy-MM-dd').format(yesterday);
        end = DateFormat('yyyy-MM-dd').format(yesterday);
      } else if (_selectedFilter == 'Besok') {
        final tomorrow = now.add(const Duration(days: 1));
        start = DateFormat('yyyy-MM-dd').format(tomorrow);
        end = DateFormat('yyyy-MM-dd').format(tomorrow);
      } else if (_selectedFilter == 'Kustom Tanggal') {
        if (_customStartDate != null && _customEndDate != null) {
          start = DateFormat('yyyy-MM-dd').format(_customStartDate!);
          end = DateFormat('yyyy-MM-dd').format(_customEndDate!);
        } else {
          start = null;
          end = null;
        }
      }

      final res = await _service.getDataChat(startDate: start, endDate: end);
      if (res['status'] == true) {
        setState(() => _data = res['data']);
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
      setState(() {
        _selectedFilter = filter;
      });
      _fetchData();
    }
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
                        'Data Chat',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '0 laporan',
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
                      ),
                      child: Text(
                        f == 'Kustom Tanggal' && _customStartDate != null && isSelected
                            ? '${DateFormat('dd MMM').format(_customStartDate!)} - ${DateFormat('dd MMM').format(_customEndDate!)}'
                            : f,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
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

  Widget _buildContent() {
    final summary = _data!['global'];
    final list = _data!['per_cabang'] as List;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                'Sumber: laporan Chat Harian yang diinput CS. Angka mengikuti filter cabang & tanggal di atas.\nClosing rate dihitung dari customer baru saja (organik + iklan). Order dari pelanggan lama tidak ikut karena mereka memesan lagi tanpa chat baru - ditampilkan terpisah sebagai jumlah order.',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),

            // Summary Cards
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMainCard(summary),
                  const SizedBox(width: 12),
                  _buildSubCard('Iklan', summary['rate_iklan'], summary['chat_iklan'], summary['closing_iklan'], '% dari chat baru'),
                  const SizedBox(width: 12),
                  _buildSubCard('Organik', summary['rate_organik'], summary['chat_organik'], summary['closing_organik'], '% dari chat baru'),
                  const SizedBox(width: 12),
                  _buildCustLamaCard(summary),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Cards Section
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    'Closing Rate per Cabang',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '— rincian agregasi harian',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            _buildTable(list),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCard(Map<String, dynamic> summary) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F), // Dark blue like the screenshot
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CLOSING RATE — CUSTOMER BARU',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${summary['rate_baru']}',
                style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                '%',
                style: GoogleFonts.inter(fontSize: 24, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${summary['closing_baru']} closing dari ${summary['chat_baru']} chat customer baru • ${summary['hari_lapor']} hari lapor',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.8)),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chat Baru', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.8))),
                  Text('${summary['chat_baru']}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Closing Baru', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.8))),
                  Text('${summary['closing_baru']}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubCard(String title, num rate, int chat, int closing, String desc) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${rate}%',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'CLOSING RATE',
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$chat', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  Text('chat', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$closing', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  Text('closing', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${rate}% dari chat baru • ${rate}% dari closing baru',
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
          )
        ],
      ),
    );
  }

  Widget _buildCustLamaCard(Map<String, dynamic> summary) {
    final rateLama = (summary['total_orderan'] ?? 0) > 0 
        ? ((summary['order_lama'] ?? 0) / summary['total_orderan'] * 100).toStringAsFixed(1)
        : '0.0';
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cust Lama',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '0',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'ORDER PELANGGAN LAMA',
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${summary['chat_lama']}', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  Text('chat', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${summary['order_lama']}', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  Text('order', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$rateLama% dari total orderan',
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
          )
        ],
      ),
    );
  }

  Widget _buildTable(List<dynamic> list) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text('Belum ada data chat yang diinput oleh CS', style: GoogleFonts.inter(color: AppColors.textMuted)),
        ),
      );
    }

    return Column(
      children: list.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Cabang Name & Total Orderan Badge
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
                        child: Icon(Icons.storefront_rounded, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        item['nama_cabang'].toString().toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${item['total_orderan']} Total Order',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 14),

              // Section 1: Customer Baru
              Text(
                'CUSTOMER BARU (ORGANIK + IKLAN)',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem('Chat Baru', '${item['chat_baru']}', Icons.chat_bubble_outline_rounded, Colors.blue),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricItem('Closing', '${item['closing_baru']}', Icons.check_circle_outline_rounded, Colors.green),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricItem('Rate Baru', '${item['rate_baru']}%', Icons.analytics_outlined, Colors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Section 2: Rate Per Sumber & Cust Lama
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rate Iklan: ${item['rate_iklan']}%',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Rate Organik: ${item['rate_organik']}%',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Cust Lama: ${item['order_lama']}',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${item['hari_lapor']} hari lapor',
                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMetricItem(String label, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/chat_service.dart';
import '../../../core/theme/app_colors.dart';

class ClosingRateDashboard extends StatefulWidget {
  const ClosingRateDashboard({super.key});

  @override
  State<ClosingRateDashboard> createState() => _ClosingRateDashboardState();
}

class _ClosingRateDashboardState extends State<ClosingRateDashboard> {
  final ChatService _service = ChatService();
  bool _isLoading = true;
  String _errorMessage = '';

  int _iklanChat = 0;
  int _iklanClosing = 0;
  int _organikChat = 0;
  int _organikClosing = 0;
  int _chatLama = 0;
  int _orderLama = 0;
  int _totalOrderanAll = 0;
  int _daysReported = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final data = await _service.getChatHarian(limit: 7);
      
      int iklanCh = 0, iklanCl = 0;
      int orgCh = 0, orgCl = 0;
      int cLama = 0, oLama = 0, totalOrderan = 0;

      for (var item in data) {
        iklanCh += (item['cust_baru_iklan'] as int? ?? 0);
        iklanCl += (item['closing_cust_baru_iklan'] as int? ?? 0);
        orgCh += (item['cust_baru_organik'] as int? ?? 0);
        orgCl += (item['closing_cust_baru_organik'] as int? ?? 0);
        cLama += (item['cust_lama'] as int? ?? 0);
        oLama += (item['closing_cust_lama'] as int? ?? 0);
        totalOrderan += (item['jumlah_orderan'] as int? ?? 0);
      }

      if (mounted) {
        setState(() {
          _iklanChat = iklanCh;
          _iklanClosing = iklanCl;
          _organikChat = orgCh;
          _organikClosing = orgCl;
          _chatLama = cLama;
          _orderLama = oLama;
          _totalOrderanAll = totalOrderan;
          _daysReported = data.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: CircularProgressIndicator(),
      ));
    }

    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)));
    }

    if (_daysReported == 0) {
      return const SizedBox.shrink();
    }

    final totalChatBaru = _iklanChat + _organikChat;
    final totalClosingBaru = _iklanClosing + _organikClosing;
    final closingRateTotal = totalChatBaru > 0 ? (totalClosingBaru / totalChatBaru * 100).round() : 0;
    
    // Calculate percentages for UI
    final pctIklanChatBaru = totalChatBaru > 0 ? (_iklanChat / totalChatBaru * 100).round() : 0;
    final pctIklanClosingBaru = totalClosingBaru > 0 ? (_iklanClosing / totalClosingBaru * 100).round() : 0;
    
    final pctOrganikChatBaru = totalChatBaru > 0 ? (_organikChat / totalChatBaru * 100).round() : 0;
    final pctOrganikClosingBaru = totalClosingBaru > 0 ? (_organikClosing / totalClosingBaru * 100).round() : 0;
    
    final pctOrderLamaTotalOrderan = _totalOrderanAll > 0 ? (_orderLama / _totalOrderanAll * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMainCard(
          rate: closingRateTotal,
          closingBaru: totalClosingBaru,
          chatBaru: totalChatBaru,
          orderLama: _orderLama,
          totalOrderan: _totalOrderanAll,
          days: _daysReported,
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildDetailCard(
                title: 'Iklan',
                badgeText: 'CLOSING RATE',
                badgeValue: _iklanChat > 0 ? '${(_iklanClosing / _iklanChat * 100).round()}%' : '0%',
                badgeColor: const Color(0xFFDC2626),
                val1Title: 'chat',
                val1Value: _iklanChat.toString(),
                val2Title: 'closing',
                val2Value: _iklanClosing.toString(),
                footer1: '$pctIklanChatBaru% dari chat baru',
                footer2: '$pctIklanClosingBaru% dari closing baru',
              ),
              const SizedBox(width: 12),
              _buildDetailCard(
                title: 'Organik',
                badgeText: 'CLOSING RATE',
                badgeValue: _organikChat > 0 ? '${(_organikClosing / _organikChat * 100).round()}%' : '0%',
                badgeColor: const Color(0xFFDC2626),
                val1Title: 'chat',
                val1Value: _organikChat.toString(),
                val2Title: 'closing',
                val2Value: _organikClosing.toString(),
                footer1: '$pctOrganikChatBaru% dari chat baru',
                footer2: '$pctOrganikClosingBaru% dari closing baru',
              ),
              const SizedBox(width: 12),
              _buildDetailCard(
                title: 'Cust Lama',
                badgeText: 'ORDER PELANGGAN LAMA',
                badgeValue: _orderLama.toString(),
                badgeColor: const Color(0xFF64748B),
                val1Title: 'chat',
                val1Value: _chatLama.toString(),
                val2Title: 'order',
                val2Value: _orderLama.toString(),
                footer1: '$pctOrderLamaTotalOrderan% dari total orderan',
                footer2: 'tanpa rate',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainCard({
    required int rate,
    required int closingBaru,
    required int chatBaru,
    required int orderLama,
    required int totalOrderan,
    required int days,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryLight, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLOSING RATE — CUSTOMER BARU',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1.1),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$rate', style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, height: 1)),
                    Text('%', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$closingBaru closing dari $chatBaru chat customer baru • $days hari lapor',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(22), bottomRight: Radius.circular(22)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildStatRow('Chat Baru', chatBaru.toString()),
                      const SizedBox(height: 12),
                      _buildStatRow('Order Lama', orderLama.toString()),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 16)),
                Expanded(
                  child: Column(
                    children: [
                      _buildStatRow('Closing Baru', closingBaru.toString()),
                      const SizedBox(height: 12),
                      _buildStatRow('Total Orderan', totalOrderan.toString(), isHighlight: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
        Text(value, style: GoogleFonts.inter(fontSize: isHighlight ? 16 : 14, fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600, color: Colors.white)),
      ],
    );
  }

  Widget _buildDetailCard({
    required String title,
    required String badgeText,
    required String badgeValue,
    required Color badgeColor,
    required String val1Title,
    required String val1Value,
    required String val2Title,
    required String val2Value,
    required String footer1,
    required String footer2,
  }) {
    return Container(
      width: 240,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(12)),
                child: Text(badgeValue, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(badgeText, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8), letterSpacing: 0.5)),
          const SizedBox(height: 20),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(val1Value, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                  Text(val1Title, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                ],
              ),
              const SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(val2Value, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                  Text(val2Title, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('$footer1 • $footer2', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}

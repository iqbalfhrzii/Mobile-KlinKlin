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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
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
    
    // Percentages
    final pctIklanChatBaru = totalChatBaru > 0 ? (_iklanChat / totalChatBaru * 100).round() : 0;
    final pctIklanClosingBaru = totalClosingBaru > 0 ? (_iklanClosing / totalClosingBaru * 100).round() : 0;
    
    final pctOrganikChatBaru = totalChatBaru > 0 ? (_organikChat / totalChatBaru * 100).round() : 0;
    final pctOrganikClosingBaru = totalClosingBaru > 0 ? (_organikClosing / totalClosingBaru * 100).round() : 0;
    
    final pctOrderLamaTotalOrderan = _totalOrderanAll > 0 ? (_orderLama / _totalOrderanAll * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Hero Card (Closing Rate Customer Baru)
        _buildMainCard(
          rate: closingRateTotal,
          closingBaru: totalClosingBaru,
          chatBaru: totalChatBaru,
          orderLama: _orderLama,
          totalOrderan: _totalOrderanAll,
          days: _daysReported,
        ),
        const SizedBox(height: 12),

        // Stacked Vertically 1 by 1
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // 1. Iklan Card
              _buildFullWidthBreakdownCard(
                title: 'Iklan (Ads)',
                icon: Icons.campaign_rounded,
                themeColor: const Color(0xFFF43F5E),
                badgeText: _iklanChat > 0 ? '${(_iklanClosing / _iklanChat * 100).round()}% Closing' : '0% Closing',
                chatCount: _iklanChat,
                closingCount: _iklanClosing,
                footer: '$pctIklanChatBaru% dari total chat baru • $pctIklanClosingBaru% dari closing baru',
              ),
              const SizedBox(height: 12),

              // 2. Organik Card
              _buildFullWidthBreakdownCard(
                title: 'Organik',
                icon: Icons.eco_rounded,
                themeColor: const Color(0xFF059669),
                badgeText: _organikChat > 0 ? '${(_organikClosing / _organikChat * 100).round()}% Closing' : '0% Closing',
                chatCount: _organikChat,
                closingCount: _organikClosing,
                footer: '$pctOrganikChatBaru% dari total chat baru • $pctOrganikClosingBaru% dari closing baru',
              ),
              const SizedBox(height: 12),

              // 3. Pelanggan Lama Card
              _buildFullWidthBreakdownCard(
                title: 'Pelanggan Lama',
                icon: Icons.repeat_rounded,
                themeColor: const Color(0xFF6366F1),
                badgeText: '$_orderLama Repeat Order',
                chatCount: _chatLama,
                closingCount: _orderLama,
                chatLabel: 'Chat Lama',
                closingLabel: 'Repeat Order',
                footer: '$pctOrderLamaTotalOrderan% dari seluruh total orderan • Loyal Customer',
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0284C7),
            Color(0xFF0369A1),
            Color(0xFF075985),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.insights_rounded, size: 15, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CLOSING RATE — CUSTOMER BARU',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$rate',
                      style: GoogleFonts.inter(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, height: 1),
                    ),
                    Text(
                      '%',
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.date_range_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '$days hari lapor',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$closingBaru closing dari $chatBaru chat customer baru',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildStatRow('Chat Baru', chatBaru.toString()),
                      const SizedBox(height: 6),
                      _buildStatRow('Order Lama', orderLama.toString()),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 14)),
                Expanded(
                  child: Column(
                    children: [
                      _buildStatRow('Closing Baru', closingBaru.toString()),
                      const SizedBox(height: 6),
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
        Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white70)),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isHighlight ? 14.5 : 13,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            color: isHighlight ? const Color(0xFFFDE047) : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildFullWidthBreakdownCard({
    required String title,
    required IconData icon,
    required Color themeColor,
    required String badgeText,
    required int chatCount,
    required int closingCount,
    String chatLabel = 'Chat Masuk',
    String closingLabel = 'Closing Deal',
    required String footer,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: themeColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: themeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Stat Tile Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$chatCount',
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                          ),
                          Text(
                            chatLabel,
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_circle_rounded, size: 16, color: themeColor),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$closingCount',
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: themeColor),
                          ),
                          Text(
                            closingLabel,
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Footer Text
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  footer,
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

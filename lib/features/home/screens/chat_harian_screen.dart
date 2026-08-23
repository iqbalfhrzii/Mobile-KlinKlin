import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../services/chat_service.dart';

class ChatHarianScreen extends StatefulWidget {
  const ChatHarianScreen({super.key});

  @override
  State<ChatHarianScreen> createState() => _ChatHarianScreenState();
}

class _ChatHarianScreenState extends State<ChatHarianScreen> {
  final ChatService _service = ChatService();

  String _periode = 'semua';
  bool _isLoading = true;
  List<dynamic> _history = [];
  String _userName = 'CS';
  String _userBranch = 'Cabang';

  // Calculated Stats
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
    _loadUserInfo();
    _fetchData();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userName = prefs.getString('user_name') ?? 'CS';
        _userBranch = prefs.getString('user_branch') ?? 'Cabang';
      });
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getChatHarian(
        periode: _periode == 'semua' ? null : _periode,
      );

      int iklanCh = 0, iklanCl = 0;
      int orgCh = 0, orgCl = 0;
      int cLama = 0, oLama = 0, totalOrderan = 0;

      for (var item in data) {
        iklanCh += int.tryParse(item['cust_baru_iklan']?.toString() ?? '0') ?? 0;
        iklanCl += int.tryParse(item['closing_cust_baru_iklan']?.toString() ?? '0') ?? 0;
        orgCh += int.tryParse(item['cust_baru_organik']?.toString() ?? '0') ?? 0;
        orgCl += int.tryParse(item['closing_cust_baru_organik']?.toString() ?? '0') ?? 0;
        cLama += int.tryParse(item['cust_lama']?.toString() ?? '0') ?? 0;
        oLama += int.tryParse(item['closing_cust_lama']?.toString() ?? '0') ?? 0;
        totalOrderan += int.tryParse(item['jumlah_orderan']?.toString() ?? '0') ?? 0;
      }

      if (mounted) {
        setState(() {
          _history = data;
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
        setState(() => _isLoading = false);
        SnackbarUtils.showError(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _onFilterChanged(String newPeriode) {
    if (_periode == newPeriode) return;
    setState(() {
      _periode = newPeriode;
    });
    _fetchData();
  }

  Future<void> _deleteItem(int id, String tanggal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Text(
              'Hapus Laporan?',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus data chat harian tanggal $tanggal?',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteChatHarian(id);
        if (mounted) {
          SnackbarUtils.showSuccess(context, 'Data chat harian berhasil dihapus');
          _fetchData();
        }
      } catch (e) {
        if (mounted) {
          SnackbarUtils.showError(context, e.toString().replaceFirst('Exception: ', ''));
        }
      }
    }
  }

  void _openFormModal({Map<String, dynamic>? editItem}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChatHarianFormSheet(
        editItem: editItem,
        userName: _userName,
        userBranch: _userBranch,
        onSaved: () {
          _fetchData();
        },
      ),
    );
  }

  String _formatDisplayDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '-';
    try {
      final dt = DateTime.parse(rawDate);
      const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      final dayName = days[dt.weekday - 1];
      final monthName = months[dt.month - 1];
      return '$dayName, ${dt.day} $monthName ${dt.year}';
    } catch (_) {
      return rawDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalChatBaru = _iklanChat + _organikChat;
    final totalClosingBaru = _iklanClosing + _organikClosing;
    final closingRateTotal = totalChatBaru > 0 ? (totalClosingBaru / totalChatBaru * 100).round() : 0;

    final pctIklanChatBaru = totalChatBaru > 0 ? (_iklanChat / totalChatBaru * 100).round() : 0;
    final pctIklanClosingBaru = totalClosingBaru > 0 ? (_iklanClosing / totalClosingBaru * 100).round() : 0;

    final pctOrganikChatBaru = totalChatBaru > 0 ? (_organikChat / totalChatBaru * 100).round() : 0;
    final pctOrganikClosingBaru = totalClosingBaru > 0 ? (_organikClosing / totalClosingBaru * 100).round() : 0;

    final pctOrderLamaTotalOrderan = _totalOrderanAll > 0 ? (_orderLama / _totalOrderanAll * 100).round() : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Gradient Header
          GradientHeader(
            child: Row(
              children: [
                HeaderBackButton(onTap: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Chat Harian CS',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_history.length} data',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pencatatan & konversi closing harian',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _fetchData,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                  tooltip: 'Segarkan',
                ),
              ],
            ),
          ),

          // Main Scrollable Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filter Chips Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Semua', 'semua'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Kemarin', 'kemarin'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Hari ini', 'hari_ini'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Besok', 'besok'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    if (_isLoading)
                      Container(
                        height: 200,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(color: AppColors.primary),
                      )
                    else ...[
                      // 1. Hero Card (Matching Dashboard exactly!)
                      _buildMainCard(
                        rate: closingRateTotal,
                        closingBaru: totalClosingBaru,
                        chatBaru: totalChatBaru,
                        orderLama: _orderLama,
                        totalOrderan: _totalOrderanAll,
                        days: _daysReported,
                      ),

                      const SizedBox(height: 12),

                      // 2. Three Breakdown Cards (Matching Dashboard exactly!)
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

                      const SizedBox(height: 16),

                      // 3. Riwayat Laporan Section
                      Text(
                        'Riwayat Laporan (${_history.length})',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),

                      const SizedBox(height: 6),

                      if (_history.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppColors.textMuted.withValues(alpha: 0.4)),
                                const SizedBox(height: 10),
                                Text(
                                  'Belum ada data chat harian pada periode ini.',
                                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._history.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _buildHistoryCard(item as Map<String, dynamic>),
                          );
                        }),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom > 0
              ? MediaQuery.of(context).padding.bottom + 8
              : 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: () => _openFormModal(),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
          label: Text(
            'Tambah Laporan Chat Harian',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _periode == value;
    return GestureDetector(
      onTap: () => _onFilterChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : AppColors.border,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: themeColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: themeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Split Counter
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
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
                          borderRadius: BorderRadius.circular(8),
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
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                          ),
                          Text(chatLabel, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
                const SizedBox(width: 14),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.check_circle_rounded, size: 16, color: themeColor),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$closingCount',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: themeColor),
                          ),
                          Text(closingLabel, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Footer
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFF94A3B8)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  footer,
                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final id = item['id'] is int ? item['id'] as int : int.tryParse(item['id']?.toString() ?? '0') ?? 0;
    final rawTanggal = item['tanggal']?.toString() ?? '';
    final formattedDate = _formatDisplayDate(rawTanggal);

    final cbOrg = int.tryParse(item['cust_baru_organik']?.toString() ?? '0') ?? 0;
    final cbIklan = int.tryParse(item['cust_baru_iklan']?.toString() ?? '0') ?? 0;
    final cLama = int.tryParse(item['cust_lama']?.toString() ?? '0') ?? 0;

    final clOrg = int.tryParse(item['closing_cust_baru_organik']?.toString() ?? '0') ?? 0;
    final clIklan = int.tryParse(item['closing_cust_baru_iklan']?.toString() ?? '0') ?? 0;
    final clLama = int.tryParse(item['closing_cust_lama']?.toString() ?? '0') ?? 0;

    final jmlOrderan = int.tryParse(item['jumlah_orderan']?.toString() ?? '0') ?? 0;
    final telp = int.tryParse(item['telp']?.toString() ?? '0') ?? 0;

    final totalChatBaru = cbOrg + cbIklan;
    final totalClosingBaru = clOrg + clIklan;
    final rate = totalChatBaru > 0 ? ((totalClosingBaru / totalChatBaru) * 100).round() : 0;

    final karyawanNama = item['karyawan']?['nama'] ?? item['karyawan']?['nama_karyawan'] ?? _userName;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Tanggal & Closing Rate Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF0284C7)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formattedDate,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.2)),
                ),
                child: Text(
                  '$rate% Closing',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Details Grid Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customer Baru', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('$totalChatBaru chat • $totalClosingBaru closing', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                          Text('($cbOrg org, $cbIklan ads)', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customer Lama', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('$cLama chat • $clLama repeat', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Orderan & Telp', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('$jmlOrderan order • $telp telp', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SDM / CS', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(karyawanNama, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Mobile-friendly Large Action Buttons Row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  onPressed: () => _openFormModal(editItem: item),
                  icon: const Icon(Icons.edit_rounded, size: 15),
                  label: Text(
                    'Edit Laporan',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    backgroundColor: const Color(0xFFF0F9FF),
                    side: const BorderSide(color: Color(0xFFBAE6FD), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () => _deleteItem(id, formattedDate),
                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                  label: Text(
                    'Hapus',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    backgroundColor: const Color(0xFFFEF2F2),
                    side: const BorderSide(color: Color(0xFFFECACA), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Modal Sheet Form (Tambah / Edit Laporan) ─────────────────────────────────
class _ChatHarianFormSheet extends StatefulWidget {
  const _ChatHarianFormSheet({
    this.editItem,
    required this.userName,
    required this.userBranch,
    required this.onSaved,
  });

  final Map<String, dynamic>? editItem;
  final String userName;
  final String userBranch;
  final VoidCallback onSaved;

  @override
  State<_ChatHarianFormSheet> createState() => _ChatHarianFormSheetState();
}

class _ChatHarianFormSheetState extends State<_ChatHarianFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate;
  late final TextEditingController _cbOrganikCtrl;
  late final TextEditingController _cbIklanCtrl;
  late final TextEditingController _cLamaCtrl;
  late final TextEditingController _closingCbOrganikCtrl;
  late final TextEditingController _closingCbIklanCtrl;
  late final TextEditingController _closingCLamaCtrl;
  late final TextEditingController _jmlOrderanCtrl;
  late final TextEditingController _telpCtrl;

  bool _isSaving = false;
  final ChatService _service = ChatService();

  @override
  void initState() {
    super.initState();
    final item = widget.editItem;
    if (item != null && item['tanggal'] != null) {
      _selectedDate = DateTime.tryParse(item['tanggal'].toString()) ?? DateTime.now();
    } else {
      _selectedDate = DateTime.now();
    }

    _cbOrganikCtrl = TextEditingController(text: item?['cust_baru_organik']?.toString() ?? '0');
    _cbIklanCtrl = TextEditingController(text: item?['cust_baru_iklan']?.toString() ?? '0');
    _cLamaCtrl = TextEditingController(text: item?['cust_lama']?.toString() ?? '0');

    _closingCbOrganikCtrl = TextEditingController(text: item?['closing_cust_baru_organik']?.toString() ?? '0');
    _closingCbIklanCtrl = TextEditingController(text: item?['closing_cust_baru_iklan']?.toString() ?? '0');
    _closingCLamaCtrl = TextEditingController(text: item?['closing_cust_lama']?.toString() ?? '0');

    _jmlOrderanCtrl = TextEditingController(text: item?['jumlah_orderan']?.toString() ?? '0');
    _telpCtrl = TextEditingController(text: item?['telp']?.toString() ?? '0');
  }

  @override
  void dispose() {
    _cbOrganikCtrl.dispose();
    _cbIklanCtrl.dispose();
    _cLamaCtrl.dispose();
    _closingCbOrganikCtrl.dispose();
    _closingCbIklanCtrl.dispose();
    _closingCLamaCtrl.dispose();
    _jmlOrderanCtrl.dispose();
    _telpCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final editId = widget.editItem?['id'] is int ? widget.editItem!['id'] as int : int.tryParse(widget.editItem?['id']?.toString() ?? '');

      if (editId != null && editId > 0) {
        await _service.updateChatHarian(
          editId,
          date: _selectedDate,
          custBaruOrganik: int.tryParse(_cbOrganikCtrl.text) ?? 0,
          custBaruIklan: int.tryParse(_cbIklanCtrl.text) ?? 0,
          custLama: int.tryParse(_cLamaCtrl.text) ?? 0,
          closingOrganik: int.tryParse(_closingCbOrganikCtrl.text) ?? 0,
          closingIklan: int.tryParse(_closingCbIklanCtrl.text) ?? 0,
          closingLama: int.tryParse(_closingCLamaCtrl.text) ?? 0,
          jumlahOrderan: int.tryParse(_jmlOrderanCtrl.text) ?? 0,
          telp: int.tryParse(_telpCtrl.text) ?? 0,
        );
      } else {
        await _service.submitChatHarian(
          date: _selectedDate,
          custBaruOrganik: int.tryParse(_cbOrganikCtrl.text) ?? 0,
          custBaruIklan: int.tryParse(_cbIklanCtrl.text) ?? 0,
          custLama: int.tryParse(_cLamaCtrl.text) ?? 0,
          closingOrganik: int.tryParse(_closingCbOrganikCtrl.text) ?? 0,
          closingIklan: int.tryParse(_closingCbIklanCtrl.text) ?? 0,
          closingLama: int.tryParse(_closingCLamaCtrl.text) ?? 0,
          jumlahOrderan: int.tryParse(_jmlOrderanCtrl.text) ?? 0,
          telp: int.tryParse(_telpCtrl.text) ?? 0,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      SnackbarUtils.showSuccess(context, 'Data chat harian berhasil disimpan!');
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        SnackbarUtils.showError(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.editItem != null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Form(
          key: _formKey,
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

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit Chat Harian' : 'Tambah Chat Harian',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Form Body
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date & Cabang Picker Row
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('dd/MM/yyyy').format(_selectedDate),
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                widget.userBranch,
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Section 1: Customer Baru & Lama
                      _buildSectionTitle('Customer Baru & Lama (Chat Masuk)'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildNumberInput('Cust Baru Organik', _cbOrganikCtrl)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildNumberInput('Cust Baru Iklan', _cbIklanCtrl)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildNumberInput('Cust Lama', _cLamaCtrl)),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Section 2: Closing
                      _buildSectionTitle('Closing'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildNumberInput('Closing Organik', _closingCbOrganikCtrl)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildNumberInput('Closing Iklan', _closingCbIklanCtrl)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildNumberInput('Closing Lama', _closingCLamaCtrl)),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Section 3: Lainnya & SDM
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle('Lainnya'),
                                const SizedBox(height: 8),
                                _buildNumberInput('Jumlah Orderan', _jmlOrderanCtrl),
                                const SizedBox(height: 8),
                                _buildNumberInput('Telp', _telpCtrl),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle('SDM'),
                                const SizedBox(height: 8),
                                Text(
                                  'Nama SDM/CS yang melaporkan',
                                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    widget.userName,
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Simpan Chat',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _buildNumberInput(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/leave_service.dart';

class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({super.key});

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  final LeaveService _service = LeaveService();
  
  bool _isLoading = true;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final res = await _service.getLeaveHistory();
      if (mounted) {
        setState(() {
          _history = res['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'diterima': return Colors.green;
      case 'ditolak': return Colors.red;
      case 'pending': return Colors.orange;
      default: return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HeaderBackButton(onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 12),
                    Text('Riwayat Pengajuan', style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
                    )),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Daftar pengajuan cuti dan izin Anda', style: GoogleFonts.inter(
                  fontSize: 14, color: Colors.white.withValues(alpha: 0.8),
                )),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_rounded, size: 64, color: AppColors.border),
                            const SizedBox(height: 16),
                            Text('Belum ada riwayat pengajuan', style: GoogleFonts.inter(color: AppColors.textMuted)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          final startDate = DateTime.parse(item['tanggal_mulai']);
                          final endDate = DateTime.parse(item['tanggal_selesai']);
                          final isSameDay = startDate.year == endDate.year && startDate.month == endDate.month && startDate.day == endDate.day;
                          
                          final dateStr = isSameDay 
                              ? DateFormat('dd MMM yyyy').format(startDate)
                              : '${DateFormat('dd MMM').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';
                              
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [AppColors.cardShadow],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceBlue,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        (item['jenis'] ?? '').toString().toUpperCase(),
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(item['status']).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        (item['status'] ?? 'Pending').toString().toUpperCase(),
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _getStatusColor(item['status'])),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(dateStr, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                const SizedBox(height: 6),
                                Text(item['alasan'] ?? '-', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

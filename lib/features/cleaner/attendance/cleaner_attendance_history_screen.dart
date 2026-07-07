import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../attendance/data/attendance_model.dart';
import '../../attendance/services/attendance_service.dart';

class CleanerAttendanceHistoryScreen extends StatefulWidget {
  const CleanerAttendanceHistoryScreen({super.key});

  @override
  State<CleanerAttendanceHistoryScreen> createState() => _CleanerAttendanceHistoryScreenState();
}

class _CleanerAttendanceHistoryScreenState extends State<CleanerAttendanceHistoryScreen> {
  final AttendanceService _service = AttendanceService();
  bool _isLoading = true;
  List<AttendanceHistoryItem> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _service.getHistory(); // Optionally pass month/date filters
      setState(() => _history = history);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Riwayat Absensi', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: AppColors.textDark,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: _history.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(child: Text('Belum ada riwayat absensi.')),
                        )
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final item = _history[index];
                        final isCheckIn = item.type == 'check_in';
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: isCheckIn ? Colors.green.shade100 : Colors.orange.shade100,
                              child: Icon(
                                isCheckIn ? Icons.login : Icons.logout,
                                color: isCheckIn ? Colors.green : Colors.orange,
                              ),
                            ),
                            title: Text(
                              isCheckIn ? 'Check-In' : 'Check-Out',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(item.time, style: GoogleFonts.inter(color: AppColors.textMuted)),
                                Text('Jarak: ${item.distanceMeter.toStringAsFixed(1)}m', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            trailing: _buildStatusBadge(item.status),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'valid':
        color = Colors.green;
        break;
      case 'invalid':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

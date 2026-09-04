import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../attendance/data/attendance_model.dart';
import '../../attendance/services/attendance_service.dart';
import '../../../../core/widgets/gradient_header.dart';
import 'selfie_viewer_screen.dart';
import '../../../../core/utils/timezone_helper.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final AttendanceService _service = AttendanceService();
  bool _isLoading = true;
  List<AttendanceHistoryItem> _history = [];
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final monthStr = "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}";
      final history = await _service.getHistory(month: monthStr);
      if (mounted) setState(() => _history = history);
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

  String _monthShort(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return months[month - 1];
  }

  void _stepMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    });
    _loadHistory();
  }

  String _parseTimeOnly(String? raw, {String fallback = '--:--'}) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final str = raw.trim();

    // 1. If it contains 'T' (e.g. "2026-08-23T08:00:00.000000Z"), extract time part after 'T'
    if (str.contains('T')) {
      final timePart = str.split('T')[1];
      final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(timePart);
      if (match != null) {
        final h = match.group(1)!.padLeft(2, '0');
        final m = match.group(2)!;
        return '$h:$m';
      }
    }

    // 2. If it contains date and space (e.g. "2026-08-23 08:00:00"), extract time part after space
    if (str.contains(' ')) {
      final parts = str.split(' ');
      if (parts.length >= 2) {
        final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(parts[1]);
        if (match != null) {
          final h = match.group(1)!.padLeft(2, '0');
          final m = match.group(2)!;
          return '$h:$m';
        }
      }
    }

    // 3. Simple time format (e.g. "08:00:00" or "08:00")
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(str);
    if (match != null) {
      final h = match.group(1)!.padLeft(2, '0');
      final m = match.group(2)!;
      return '$h:$m';
    }

    return str.length >= 5 ? str.substring(0, 5) : str;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                HeaderBackButton(onTap: () => Navigator.pop(context)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Riwayat Absensi',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Daftar catatan check-in & check-out',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                // Month Step Controls
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _stepMonth(-1),
                        icon: const Icon(Icons.chevron_left_rounded, size: 18, color: Colors.white),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      ),
                      Text(
                        '${_monthShort(_selectedMonth.month)} ${_selectedMonth.year}',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _stepMonth(1),
                        icon: const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadHistory,
                    color: AppColors.primary,
                    child: _history.isEmpty
                        ? ListView(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey.shade300),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Belum ada riwayat absensi pada periode ini.',
                                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _history.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = _history[index];
                              final typeStr = item.type.toLowerCase();
                              final isCheckIn = typeStr == 'check_in' || typeStr == 'masuk';
                              final color = isCheckIn ? const Color(0xFF059669) : const Color(0xFFD97706);
                              final bgColor = isCheckIn ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB);
                              final timeStr = _parseTimeOnly(item.time);

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppColors.border),
                                  boxShadow: [AppColors.cardShadow],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                                        color: color,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                isCheckIn ? 'Check-In' : 'Check-Out',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textDark,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _buildStatusBadge(item.status),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Waktu: $timeStr ${TimezoneHelper.getTimezoneLabel(item.cabangName)} \u2022 ${item.tanggal ?? ""}',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Jarak: ${item.distanceMeter.toStringAsFixed(1)} m ke kantor',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (item.selfieViewUrl != null && item.id > 0)
                                      IconButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => SelfieViewerScreen(
                                                attendanceId: item.id,
                                                initialUrl: item.selfieViewUrl!,
                                                title: isCheckIn ? 'Foto Selfie Masuk' : 'Foto Selfie Pulang',
                                                item: item,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.photo_camera_rounded, size: 20, color: Color(0xFF2563EB)),
                                        tooltip: 'Lihat Foto Selfie',
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    Color bgColor;
    final s = status.toLowerCase();
    if (s == 'valid' || s == 'diterima') {
      color = const Color(0xFF059669);
      bgColor = const Color(0xFFECFDF5);
    } else if (s == 'invalid' || s == 'ditolak') {
      color = const Color(0xFFDC2626);
      bgColor = const Color(0xFFFEF2F2);
    } else {
      color = const Color(0xFF2563EB);
      bgColor = const Color(0xFFEFF6FF);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 9.5, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

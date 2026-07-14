import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../data/attendance_model.dart';
import 'selfie_viewer_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminAttendanceDetailScreen extends StatefulWidget {
  final GroupedAttendanceItem item;
  final bool showPhoto;

  const AdminAttendanceDetailScreen({super.key, required this.item, this.showPhoto = true});

  @override
  State<AdminAttendanceDetailScreen> createState() => _AdminAttendanceDetailScreenState();
}

class _AdminAttendanceDetailScreenState extends State<AdminAttendanceDetailScreen> {
  String? _token;
  bool _isTokenLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _token = prefs.getString('auth_token');
        _isTokenLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            child: Row(
              children: [
                HeaderBackButton(onTap: () => Navigator.pop(context)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Detail Absensi', style: GoogleFonts.inter(
                        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white,
                      )),
                      const SizedBox(height: 4),
                      Text(widget.item.namaCleaner, style: GoogleFonts.inter(
                        fontSize: 13, color: Colors.white.withOpacity(0.8),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tanggal: ${widget.item.tanggal}',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        if (widget.item.checkIn != null) ...[
                          _buildDetailItem(context, 'Check-In', widget.item.checkIn!),
                          const Divider(height: 32),
                        ],
                        if (widget.item.checkOut != null) ...[
                          _buildDetailItem(context, 'Check-Out', widget.item.checkOut!),
                        ],
                        if (widget.item.checkIn == null && widget.item.checkOut == null)
                          const Center(child: Text('Data tidak ditemukan.')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, String title, AttendanceHistoryItem data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
            _buildStatusBadge(data.status),
          ],
        ),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.access_time_rounded, 'Waktu', data.time),
        const SizedBox(height: 8),
        _buildInfoRow(Icons.location_on_outlined, 'Jarak dari Kantor', '${data.distanceMeter.toStringAsFixed(1)} meter'),
        const SizedBox(height: 16),
        if (widget.showPhoto && data.selfieViewUrl != null && data.selfieViewUrl!.isNotEmpty)
          _isTokenLoaded
              ? GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SelfieViewerScreen(attendanceId: data.id, initialUrl: data.selfieViewUrl!),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        data.selfieViewUrl!,
                        headers: _token != null ? {'Authorization': 'Bearer $_token'} : null,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 48),
                        ),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                  : null,
                              color: AppColors.primary,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                )
              : const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text('$label: ', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
        Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'valid':
      case 'diterima':
        color = Colors.green;
        break;
      case 'invalid':
      case 'ditolak':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

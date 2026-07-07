import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../services/attendance_service.dart';
import '../data/attendance_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelfieViewerScreen extends StatefulWidget {
  final int attendanceId;
  final String initialUrl;

  const SelfieViewerScreen({
    super.key,
    required this.attendanceId,
    required this.initialUrl,
  });

  @override
  State<SelfieViewerScreen> createState() => _SelfieViewerScreenState();
}

class _SelfieViewerScreenState extends State<SelfieViewerScreen> {
  final AttendanceService _service = AttendanceService();
  
  late String _currentUrl;
  bool _isRefreshingUrl = false;
  bool _hasFailedTwice = false;
  AttendanceHistoryItem? _detailData;
  String? _token;
  bool _isTokenLoaded = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _fetchDetailBackground();
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

  Future<void> _fetchDetailBackground() async {
    try {
      final detail = await _service.getDetailAbsensi(widget.attendanceId);
      if (mounted) {
        setState(() {
          _detailData = detail;
        });
      }
    } catch (_) {
      // Background fetch failed, ignore for now
    }
  }

  Future<void> _refreshUrl() async {
    if (_isRefreshingUrl) return;

    setState(() {
      _isRefreshingUrl = true;
    });

    try {
      final detail = await _service.getDetailAbsensi(widget.attendanceId);
      if (mounted) {
        setState(() {
          _detailData = detail;
          if (detail.selfieViewUrl != null && detail.selfieViewUrl!.isNotEmpty) {
            _currentUrl = detail.selfieViewUrl!;
            _hasFailedTwice = false;
          } else {
            _hasFailedTwice = true;
          }
          _isRefreshingUrl = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasFailedTwice = true;
          _isRefreshingUrl = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat ulang foto: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Detail Selfie Absensi', style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: _hasFailedTwice
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                        const SizedBox(height: 16),
                        Text('Foto selfie tidak dapat dimuat.\nSilakan coba lagi.', 
                            textAlign: TextAlign.center, 
                            style: GoogleFonts.inter(color: Colors.white)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _refreshUrl,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Muat Ulang'),
                        ),
                      ],
                    ),
                  )
                : InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Center(
                      child: !_isTokenLoaded 
                        ? const CircularProgressIndicator(color: AppColors.primary)
                        : Image.network(
                            _currentUrl,
                            headers: _token != null ? {'Authorization': 'Bearer $_token'} : null,
                            key: ValueKey(_currentUrl),
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                                      : null,
                                  color: AppColors.primary,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              // URL expired or invalid. Let's trigger refresh.
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!_hasFailedTwice && !_isRefreshingUrl) {
                                  _refreshUrl();
                                }
                              });

                              return _isRefreshingUrl 
                                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                                : const SizedBox.shrink(); // Will be replaced by _hasFailedTwice UI soon
                            },
                          ),
                    ),
                  ),
          ),
          if (_detailData != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _detailData!.namaCleaner ?? 'Cleaner',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoColumn('Tipe', _detailData!.type == 'check_in' || _detailData!.type == 'masuk' ? 'Masuk' : 'Pulang'),
                        _buildInfoColumn('Waktu', _detailData!.time),
                        _buildInfoColumn('Jarak', '${_detailData!.distanceMeter.toStringAsFixed(1)}m'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Status: ', style: GoogleFonts.inter(color: AppColors.textMuted)),
                        _buildStatusBadge(_detailData!.status),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 12, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

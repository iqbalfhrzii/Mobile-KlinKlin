import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../data/attendance_model.dart';
import '../services/attendance_service.dart';

class SelfieViewerScreen extends StatefulWidget {
  final int attendanceId;
  final String initialUrl;
  final String? title;
  final AttendanceHistoryItem? item;
  final Uint8List? imageBytes;

  const SelfieViewerScreen({
    super.key,
    required this.attendanceId,
    required this.initialUrl,
    this.title,
    this.item,
    this.imageBytes,
  });

  @override
  State<SelfieViewerScreen> createState() => _SelfieViewerScreenState();
}

class _SelfieViewerScreenState extends State<SelfieViewerScreen> {
  final AttendanceService _service = AttendanceService();
  final Dio _dio = DioClient.instance.dio;

  Uint8List? _imageBytes;
  bool _isLoadingImage = true;
  String? _errorMessage;
  AttendanceHistoryItem? _detailData;

  @override
  void initState() {
    super.initState();
    _detailData = widget.item;
    if (widget.imageBytes != null && widget.imageBytes!.isNotEmpty) {
      _imageBytes = widget.imageBytes;
      _isLoadingImage = false;
    } else {
      _loadImage();
    }
    if (_detailData == null && widget.attendanceId > 0) {
      _fetchDetailBackground();
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
      // Ignore background fetch error
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoadingImage = true;
      _errorMessage = null;
    });

    try {
      // 1. Try fetching directly via Dio bytes
      String targetUrl = widget.initialUrl;
      
      // If targetUrl contains full API url, make it relative if using configured Dio baseURL
      if (targetUrl.contains('/api/absensi/')) {
        final path = targetUrl.substring(targetUrl.indexOf('/api/absensi/') + 4); // /absensi/...
        targetUrl = path;
      } else if (!targetUrl.startsWith('http') && !targetUrl.startsWith('/')) {
        targetUrl = '/absensi/${widget.attendanceId}/selfie';
      }

      final response = await _dio.get<List<int>>(
        targetUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
        if (mounted) {
          setState(() {
            _imageBytes = Uint8List.fromList(response.data!);
            _isLoadingImage = false;
          });
        }
        return;
      }

      if (response.statusCode == 403) {
        throw Exception('Akses ditolak (403): Role akun Anda belum diizinkan melihat foto selfie ini.');
      } else if (response.statusCode == 404) {
        throw Exception('Foto selfie tidak ditemukan di server atau belum diunggah.');
      } else {
        throw Exception('Server mengembalikan status ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingImage = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String pageTitle = widget.title ?? 'Detail Selfie Absensi';
    if (widget.title == null && _detailData != null) {
      pageTitle = _detailData!.isCheckIn ? 'Foto Selfie Masuk (Check-In)' : 'Foto Selfie Pulang (Check-Out)';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(pageTitle, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildImageContent(),
          ),
          if (_detailData != null) _buildDetailSheet(),
        ],
      ),
    );
  }

  Widget _buildImageContent() {
    if (_isLoadingImage) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Memuat foto selfie...',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null || _imageBytes == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.no_photography_rounded, color: Colors.white54, size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Foto selfie tidak tersedia.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('Coba Lagi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ),
      );
    }

    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 4.0,
      child: Center(
        child: Image.memory(
          _imageBytes!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              'Gagal merender format gambar.',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSheet() {
    final isCheckIn = _detailData!.isCheckIn;
    final sessionColor = isCheckIn ? const Color(0xFF059669) : const Color(0xFF2563EB);
    final sessionBg = isCheckIn ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _detailData!.namaCleaner ?? 'Karyawan',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      if (_detailData!.cabangName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _detailData!.cabangName!,
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sessionBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCheckIn ? 'Absen Masuk' : 'Absen Pulang',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: sessionColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn('Waktu', _detailData!.time),
                _buildInfoColumn('Jarak ke Kantor', '${_detailData!.distanceMeter.toStringAsFixed(1)} m'),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Status', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(height: 3),
                    _buildStatusBadge(_detailData!.status),
                  ],
                ),
              ],
            ),
            if (_detailData!.deviceInfo != null && _detailData!.deviceInfo!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.phone_android_rounded, size: 13, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Perangkat: ${_detailData!.deviceInfo}',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 12, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

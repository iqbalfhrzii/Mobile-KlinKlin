import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/dio_client.dart';
import '../data/attendance_model.dart';
import '../screens/selfie_viewer_screen.dart';

class AttendanceSelfieThumbnail extends StatefulWidget {
  final int attendanceId;
  final String selfieUrl;
  final String? title;
  final AttendanceHistoryItem? item;
  final double width;
  final double height;
  final Color? accentColor;
  final String? badgeLabel;

  const AttendanceSelfieThumbnail({
    super.key,
    required this.attendanceId,
    required this.selfieUrl,
    this.title,
    this.item,
    this.width = 92,
    this.height = 110,
    this.accentColor,
    this.badgeLabel,
  });

  // Shared in-memory cache across thumbnail instances
  static final Map<int, Uint8List> imageCache = {};

  @override
  State<AttendanceSelfieThumbnail> createState() => _AttendanceSelfieThumbnailState();
}

class _AttendanceSelfieThumbnailState extends State<AttendanceSelfieThumbnail> {
  final Dio _dio = DioClient.instance.dio;
  Uint8List? _bytes;
  bool _isLoading = false;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant AttendanceSelfieThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attendanceId != widget.attendanceId) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.attendanceId <= 0) {
      setState(() => _isError = true);
      return;
    }

    if (AttendanceSelfieThumbnail.imageCache.containsKey(widget.attendanceId)) {
      setState(() {
        _bytes = AttendanceSelfieThumbnail.imageCache[widget.attendanceId];
        _isLoading = false;
        _isError = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isError = false;
    });

    try {
      String path = '/absensi/${widget.attendanceId}/selfie';
      if (widget.selfieUrl.contains('/api/absensi/')) {
        path = widget.selfieUrl.substring(widget.selfieUrl.indexOf('/api/absensi/') + 4);
      }

      final response = await _dio.get<List<int>>(
        path,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
        final b = Uint8List.fromList(response.data!);
        AttendanceSelfieThumbnail.imageCache[widget.attendanceId] = b;
        if (mounted) {
          setState(() {
            _bytes = b;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isError = true;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _openViewer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelfieViewerScreen(
          attendanceId: widget.attendanceId,
          initialUrl: widget.selfieUrl,
          title: widget.title,
          item: widget.item,
          imageBytes: _bytes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.accentColor ?? const Color(0xFFCBD5E1);

    return GestureDetector(
      onTap: _openViewer,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isLoading)
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                ),
              )
            else if (_isError || _bytes == null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_rounded, size: 24, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 4),
                    Text(
                      'Tidak ada foto',
                      style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else ...[
              Image.memory(
                _bytes!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_rounded, size: 24, color: Color(0xFF94A3B8)),
                ),
              ),

              // Bottom gradient shade with zoom hint
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],

            // Optional Top Badge (e.g. "Masuk" / "Pulang")
            if (widget.badgeLabel != null && widget.badgeLabel!.isNotEmpty)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: (widget.accentColor ?? Colors.black).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.badgeLabel!,
                    style: GoogleFonts.inter(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

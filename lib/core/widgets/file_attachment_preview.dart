import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:video_player/video_player.dart';
import '../api/api_client.dart';
import '../theme/app_colors.dart';

class FileAttachmentPreview {
  static String getFullUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    
    final baseUrl = ApiClient.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    if (cleanPath.startsWith('storage/')) {
      return '$baseUrl/$cleanPath';
    }
    return '$baseUrl/storage/$cleanPath';
  }

  static bool isImageFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp');
  }

  static bool isPdfFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.pdf');
  }

  static bool isVideoFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.3gp') ||
        lower.endsWith('.flv');
  }

  /// Unduh dan simpan berkas langsung ke penyimpanan perangkat tanpa membuka browser web ERP.
  static Future<void> downloadAndSaveFile({
    required BuildContext context,
    required String fileUrl,
    required String fileName,
    String? title,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Mengunduh berkas ke perangkat...'),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final dio = Dio();
      final res = await dio.get<List<int>>(
        fileUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (res.data == null || res.data!.isEmpty) {
        throw Exception('Berkas kosong atau tidak dapat diunduh');
      }

      final bytes = Uint8List.fromList(res.data!);
      final rawExt = fileName.contains('.') ? fileName.split('.').last.toLowerCase().split('?').first : 'jpg';
      final ext = rawExt.isEmpty ? 'jpg' : rawExt;
      final cleanTitle = (title ?? fileName).replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final finalFileName = cleanTitle.toLowerCase().endsWith('.$ext')
          ? cleanTitle
          : '$cleanTitle.$ext';

      bool savedDirectly = false;
      String savedPath = '';

      // 1. Coba simpan langsung ke folder Download publik Android (/storage/emulated/0/Download)
      try {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (downloadDir.existsSync()) {
          final targetFile = File('${downloadDir.path}/$finalFileName');
          await targetFile.writeAsBytes(bytes);
          savedDirectly = true;
          savedPath = targetFile.path;
        }
      } catch (_) {
        savedDirectly = false;
      }

      // 2. Jika tidak bisa simpan langsung (Scoped Storage), gunakan FilePicker save dialog
      if (!savedDirectly) {
        try {
          final savedFilePath = await FilePicker.platform.saveFile(
            dialogTitle: 'Pilih lokasi simpan berkas:',
            fileName: finalFileName,
            bytes: bytes,
          );
          if (savedFilePath != null) {
            savedDirectly = true;
            savedPath = savedFilePath;
          }
        } catch (_) {
          savedDirectly = false;
        }
      }

      // 3. Fallback jika kedua cara di atas belum menghasilkan path, gunakan Printing.sharePdf
      if (!savedDirectly) {
        await Printing.sharePdf(bytes: bytes, filename: finalFileName);
        if (context.mounted) {
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Berkas siap disimpan / dibagikan'),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Berhasil disimpan ke $savedPath',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Gagal mengunduh berkas: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  static void showPreview(BuildContext context, {required String filePath, String? title}) {
    final fullUrl = getFullUrl(filePath);
    final isImg = isImageFile(filePath);
    final isPdf = isPdfFile(filePath);
    final isVid = isVideoFile(filePath);
    final displayTitle = title ?? (isImg ? 'Pratinjau Foto' : (isPdf ? 'Dokumen PDF' : (isVid ? 'Putar Video' : 'Berkas Lampiran')));

    if (isVid) {
      // Open dedicated Full-Screen In-App Video Player
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => _VideoPlayerScreen(
            videoUrl: fullUrl,
            title: displayTitle,
          ),
        ),
      );
      return;
    }

    if (isPdf) {
      // Open dedicated Full-Screen HD PDF Viewer with Multi-touch Zoom (Pinch-to-zoom)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => _PdfViewerScreen(
            pdfUrl: fullUrl,
            title: displayTitle,
          ),
        ),
      );
      return;
    }

    if (!isImg) {
      // For other document types (Word, Excel, ZIP), open via external browser / app directly
      _openExternal(context, fullUrl, displayTitle);
      return;
    }

    // Image Modal Preview with Pinch to zoom & Download support
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.image_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      displayTitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
                    tooltip: 'Unduh Gambar',
                    onPressed: () => downloadAndSaveFile(
                      context: context,
                      fileUrl: fullUrl,
                      fileName: filePath,
                      title: displayTitle,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                    tooltip: 'Bagikan Gambar',
                    onPressed: () async {
                      try {
                        final dio = Dio();
                        final res = await dio.get<List<int>>(
                          fullUrl,
                          options: Options(responseType: ResponseType.bytes),
                        );
                        if (res.data != null) {
                          final bytes = Uint8List.fromList(res.data!);
                          final ext = filePath.split('.').last.toLowerCase();
                          final cleanTitle = displayTitle.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
                          await Printing.sharePdf(bytes: bytes, filename: '$cleanTitle.$ext');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal membagikan gambar: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 20),
                    tooltip: 'Buka di Browser',
                    onPressed: () => launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),

            // Image Viewer
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                ),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 6.0,
                  child: Center(
                    child: Image.network(
                      fullUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                : null,
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder: (_, error, ___) => Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.broken_image_rounded, size: 48, color: Colors.redAccent),
                            const SizedBox(height: 12),
                            Text(
                              'Gagal memuat gambar',
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Berkas mungkin belum tersedia di server',
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => downloadAndSaveFile(
                        context: context,
                        fileUrl: fullUrl,
                        fileName: filePath,
                        title: displayTitle,
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
                      label: Text(
                        'Unduh / Simpan Gambar',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final dio = Dio();
                        final res = await dio.get<List<int>>(
                          fullUrl,
                          options: Options(responseType: ResponseType.bytes),
                        );
                        if (res.data != null) {
                          final bytes = Uint8List.fromList(res.data!);
                          final ext = filePath.split('.').last.toLowerCase();
                          final cleanTitle = displayTitle.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
                          await Printing.sharePdf(bytes: bytes, filename: '$cleanTitle.$ext');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal membagikan: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
                    label: Text(
                      'Bagikan',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _openExternal(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.file_present_rounded, color: AppColors.primaryMid),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(
          'Berkas ini akan dibuka melalui browser atau aplikasi pembuka berkas eksternal Anda.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white),
            label: const Text('Buka Berkas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMid,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a modern, interactive attachment card widget for use in detail modal sheets.
  static Widget buildAttachmentCard(
    BuildContext context, {
    required String? filePath,
    String label = 'File Lampiran / Foto',
  }) {
    if (filePath == null || filePath.trim().isEmpty) return const SizedBox.shrink();

    final isImg = isImageFile(filePath);
    final isPdf = isPdfFile(filePath);
    final fullUrl = getFullUrl(filePath);

    Color badgeBg = isImg ? Colors.blue.shade50 : (isPdf ? Colors.red.shade50 : Colors.amber.shade50);
    Color badgeBorder = isImg ? Colors.blue.shade200 : (isPdf ? Colors.red.shade200 : Colors.amber.shade200);
    Color iconColor = isImg ? Colors.blue.shade700 : (isPdf ? Colors.red.shade700 : Colors.amber.shade800);
    IconData icon = isImg ? Icons.image_rounded : (isPdf ? Icons.picture_as_pdf_rounded : Icons.attach_file_rounded);

    String subtitle = isImg
        ? 'Foto terlampir (Ketuk untuk pratinjau)'
        : (isPdf ? 'Dokumen PDF (Ketuk untuk baca & zoom)' : 'Berkas terlampir (Ketuk untuk unduh)');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showPreview(context, filePath: filePath, title: label),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Thumbnail or Icon Container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: badgeBorder),
                  ),
                  child: isImg
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.network(
                            fullUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(Icons.image_outlined, color: iconColor, size: 24),
                          ),
                        )
                      : Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),

                // Text Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Clickable Preview Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMid.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryMid.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.visibility_rounded, size: 14, color: AppColors.primaryMid),
                      const SizedBox(width: 4),
                      Text(
                        'Buka',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryMid,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full interactive in-app HD PDF Viewer with smooth pinch-to-zoom up to 600%
class _PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const _PdfViewerScreen({
    required this.pdfUrl,
    required this.title,
  });

  @override
  State<_PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<_PdfViewerScreen> {
  Uint8List? _pdfBytes;
  List<Uint8List> _renderedPages = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final TransformationController _transformationController = TransformationController();
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadAndRasterPdf();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadAndRasterPdf() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _renderedPages = [];
    });

    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        widget.pdfUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data != null) {
        final bytes = Uint8List.fromList(response.data!);
        _pdfBytes = bytes;

        // Convert PDF pages to HD images for smooth pinch-to-zoom (220 DPI)
        final List<Uint8List> pages = [];
        await for (final page in Printing.raster(bytes, dpi: 220)) {
          final png = await page.toPng();
          pages.add(png);
        }

        if (mounted) {
          setState(() {
            _renderedPages = pages;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Gagal mengunduh isi berkas PDF';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat PDF: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _zoomIn() {
    setState(() {
      _currentScale = (_currentScale * 1.3).clamp(0.8, 6.0);
      _transformationController.value = Matrix4.diagonal3Values(_currentScale, _currentScale, 1.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentScale = (_currentScale / 1.3).clamp(0.8, 6.0);
      _transformationController.value = Matrix4.diagonal3Values(_currentScale, _currentScale, 1.0);
    });
  }

  void _resetZoom() {
    setState(() {
      _currentScale = 1.0;
      _transformationController.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
            if (_renderedPages.isNotEmpty)
              Text(
                '${_renderedPages.length} Halaman • Cubit (Pinch) untuk Zoom',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
          ],
        ),
        actions: [
          if (_pdfBytes != null) ...[
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
              tooltip: 'Unduh PDF',
              onPressed: () => FileAttachmentPreview.downloadAndSaveFile(
                context: context,
                fileUrl: widget.pdfUrl,
                fileName: '${widget.title}.pdf',
                title: widget.title,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
              tooltip: 'Bagikan PDF',
              onPressed: () => Printing.sharePdf(bytes: _pdfBytes!, filename: '${widget.title}.pdf'),
            ),
            IconButton(
              icon: const Icon(Icons.print_rounded, color: Colors.white, size: 20),
              tooltip: 'Cetak / Print',
              onPressed: () => Printing.layoutPdf(onLayout: (format) => _pdfBytes!, name: widget.title),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
            tooltip: 'Buka di Browser Eksternal',
            onPressed: () => launchUrl(Uri.parse(widget.pdfUrl), mode: LaunchMode.externalApplication),
          ),
        ],
      ),
      floatingActionButton: _renderedPages.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white24),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.zoom_out_rounded, color: Colors.white, size: 20),
                    tooltip: 'Zoom Out',
                    onPressed: _zoomOut,
                  ),
                  IconButton(
                    icon: const Icon(Icons.restart_alt_rounded, color: Colors.amberAccent, size: 18),
                    tooltip: 'Reset Zoom (100%)',
                    onPressed: _resetZoom,
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 20),
                    tooltip: 'Zoom In',
                    onPressed: _zoomIn,
                  ),
                ],
              ),
            )
          : null,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Memproses & Memuat Halaman PDF...',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 14),
                        Text(
                          _errorMessage,
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: () => launchUrl(Uri.parse(widget.pdfUrl), mode: LaunchMode.externalApplication),
                          icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white),
                          label: const Text('Buka di Browser Langsung', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.8,
                  maxScale: 6.0,
                  panEnabled: true,
                  scaleEnabled: true,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
                    itemCount: _renderedPages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            _renderedPages[index],
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ================= IN-APP FULL SCREEN VIDEO PLAYER =================
class _VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const _VideoPlayerScreen({
    required this.videoUrl,
    required this.title,
  });

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  Timer? _hideTimer;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await _controller.initialize();
      _controller.addListener(_videoListener);
      await _controller.play();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _startHideControlsTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Gagal memutar video: $e';
        });
      }
    }
  }

  void _videoListener() {
    if (mounted) setState(() {});
  }

  void _startHideControlsTimer() {
    _hideTimer?.cancel();
    if (_controller.value.isPlaying) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _controller.value.isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  void _togglePlayPause() {
    if (_controller.value.isCompleted) {
      _controller.seekTo(Duration.zero);
      _controller.play();
    } else if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() {});
    _startHideControlsTimer();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. VIDEO SURFACE
            if (_isLoading)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Memuat video...',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              )
            else if (_hasError)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 44),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Pemutar Video Memerlukan Restart Aplikasi',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      if (_errorMessage.isNotEmpty) ...[
                        Text(
                          _errorMessage,
                          style: GoogleFonts.inter(color: Colors.redAccent.shade100, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        'Plugin video native baru saja ditambahkan ke proyek. Harap restart aplikasi (hentikan lalu jalankan "flutter run" kembali) agar modul native video terkompilasi ke dalam APK.',
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => launchUrl(Uri.parse(widget.videoUrl), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white, size: 18),
                        label: const Text('Buka di Pemutar Eksternal Sementara', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _initializePlayer,
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 16),
                        label: const Text('Coba Lagi', style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: _toggleControls,
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio > 0
                        ? _controller.value.aspectRatio
                        : 16 / 9,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),

            // 2. CONTROLS OVERLAY
            if (!_isLoading && !_hasError)
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black87,
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black87,
                        ],
                        stops: [0.0, 0.25, 0.75, 1.0],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top Header Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                  color: Colors.white,
                                ),
                                tooltip: _isMuted ? 'Suara Hidup' : 'Senyap',
                                onPressed: _toggleMute,
                              ),
                              IconButton(
                                icon: const Icon(Icons.download_rounded, color: Colors.white),
                                tooltip: 'Unduh Video',
                                onPressed: () => FileAttachmentPreview.downloadAndSaveFile(
                                  context: context,
                                  fileUrl: widget.videoUrl,
                                  fileName: widget.videoUrl,
                                  title: widget.title,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.share_rounded, color: Colors.white),
                                tooltip: 'Bagikan Video',
                                onPressed: () async {
                                  try {
                                    final dio = Dio();
                                    final res = await dio.get<List<int>>(
                                      widget.videoUrl,
                                      options: Options(responseType: ResponseType.bytes),
                                    );
                                    if (res.data != null) {
                                      final bytes = Uint8List.fromList(res.data!);
                                      final cleanTitle = widget.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
                                      await Printing.sharePdf(bytes: bytes, filename: '$cleanTitle.mp4');
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Gagal membagikan: $e'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
                                tooltip: 'Buka di Player Eksternal',
                                onPressed: () => launchUrl(Uri.parse(widget.videoUrl), mode: LaunchMode.externalApplication),
                              ),
                            ],
                          ),
                        ),

                        // Center Play / Pause Button
                        Center(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _togglePlayPause,
                              borderRadius: BorderRadius.circular(40),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white38, width: 1.5),
                                ),
                                child: Icon(
                                  _controller.value.isCompleted
                                      ? Icons.replay_rounded
                                      : (_controller.value.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded),
                                  color: Colors.white,
                                  size: 44,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Bottom Control Bar (Seek bar + Duration)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Slider
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: const Color(0xFF2563EB),
                                  inactiveTrackColor: Colors.white30,
                                  thumbColor: Colors.white,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                  trackHeight: 3,
                                ),
                                child: Slider(
                                  min: 0.0,
                                  max: _controller.value.duration.inMilliseconds > 0
                                      ? _controller.value.duration.inMilliseconds.toDouble()
                                      : 1.0,
                                  value: _controller.value.position.inMilliseconds.toDouble().clamp(
                                        0.0,
                                        _controller.value.duration.inMilliseconds > 0
                                            ? _controller.value.duration.inMilliseconds.toDouble()
                                            : 1.0,
                                      ),
                                  onChanged: (val) {
                                    _controller.seekTo(Duration(milliseconds: val.toInt()));
                                  },
                                ),
                              ),

                              // Time row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(_controller.value.position),
                                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                                  ),
                                  Text(
                                    _formatDuration(_controller.value.duration),
                                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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


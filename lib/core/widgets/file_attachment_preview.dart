import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        lower.endsWith('.bmp') ||
        !lower.contains('.'); // default treat as image if uploaded from image picker without explicit ext
  }

  static void showPreview(BuildContext context, {required String filePath, String? title}) {
    final fullUrl = getFullUrl(filePath);
    final isImg = isImageFile(filePath);
    final displayTitle = title ?? (isImg ? 'Pratinjau Foto' : 'Pratinjau Dokumen');

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
                  Icon(
                    isImg ? Icons.photo_library_rounded : Icons.description_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
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
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),

            // Content Area
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.72,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: isImg
                    ? InteractiveViewer(
                        panEnabled: true,
                        minScale: 0.8,
                        maxScale: 4.0,
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
                      )
                    : Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.file_present_rounded, size: 48, color: Colors.amberAccent),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              displayTitle,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Dokumen berkas terlampir',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
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

  /// Builds a modern, interactive attachment card widget for use in detail modal sheets.
  static Widget buildAttachmentCard(
    BuildContext context, {
    required String? filePath,
    String label = 'File Lampiran / Foto',
  }) {
    if (filePath == null || filePath.trim().isEmpty) return const SizedBox.shrink();

    final isImg = isImageFile(filePath);
    final fullUrl = getFullUrl(filePath);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showPreview(context, filePath: filePath, title: label),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Thumbnail or Icon Container
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isImg ? Colors.blue.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isImg ? Colors.blue.shade200 : Colors.amber.shade200,
                    ),
                  ),
                  child: isImg
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Image.network(
                            fullUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, color: AppColors.primaryMid, size: 22),
                          ),
                        )
                      : Icon(Icons.attach_file_rounded, color: Colors.amber.shade800, size: 22),
                ),
                const SizedBox(width: 12),

                // Text Info (Private & Friendly, No Hash File Path)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isImg ? 'Foto terlampir (Ketuk untuk melihat)' : 'Dokumen berkas terlampir',
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
                        'Lihat',
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

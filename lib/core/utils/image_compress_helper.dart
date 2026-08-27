import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageCompressHelper {
  /// Batas ukuran berkas 2 MB (2,097,152 bytes)
  static const int maxFileSizeBytes = 2 * 1024 * 1024;

  /// Memeriksa ukuran berkas gambar.
  /// - Jika ukuran file <= 2MB: Berkas asli dikembalikan langsung TANPA kompresi.
  /// - Jika ukuran file > 2MB: Otomatis dikompres sehingga ukurannya di bawah 2MB.
  static Future<File> compressIfNeeded(File file, {int targetQuality = 80}) async {
    try {
      if (!await file.exists()) return file;

      final int originalSize = await file.length();

      // Aturan: Jika di bawah atau sama dengan 2MB, jangan di-compress
      if (originalSize <= maxFileSizeBytes) {
        debugPrint(
          '[ImageCompressHelper] Berkas ${(originalSize / 1024).toStringAsFixed(1)} KB <= 2 MB. Melewati kompresi.',
        );
        return file;
      }

      debugPrint(
        '[ImageCompressHelper] Berkas ${(originalSize / (1024 * 1024)).toStringAsFixed(2)} MB > 2 MB. Memulai auto-compress...',
      );

      final tempPath = Directory.systemTemp.path;
      final targetPath =
          '$tempPath/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Kompresi Pass 1 (Quality 80, max 1920px)
      XFile? compressed = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: targetQuality,
        minWidth: 1920,
        minHeight: 1920,
      );

      if (compressed != null) {
        File compressedFile = File(compressed.path);
        int compressedSize = await compressedFile.length();

        // Jika masih di atas 2MB (misal foto sangat besar/kompleks), lakukan Pass 2 dengan quality 65
        if (compressedSize > maxFileSizeBytes) {
          final targetPath2 =
              '$tempPath/compressed2_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final XFile? compressed2 = await FlutterImageCompress.compressAndGetFile(
            compressedFile.path,
            targetPath2,
            quality: 65,
            minWidth: 1600,
            minHeight: 1600,
          );
          if (compressed2 != null) {
            compressedFile = File(compressed2.path);
            compressedSize = await compressedFile.length();
          }
        }

        debugPrint(
          '[ImageCompressHelper] Selesai: ${(originalSize / (1024 * 1024)).toStringAsFixed(2)} MB -> ${(compressedSize / 1024).toStringAsFixed(1)} KB.',
        );
        return compressedFile;
      }

      return file;
    } catch (e) {
      debugPrint('[ImageCompressHelper] Gagal kompres: $e');
      return file;
    }
  }

  /// Helper untuk memproses hasil dari ImagePicker (XFile?)
  /// Jika null, return null. Jika ada, compressIfNeeded.
  static Future<File?> compressXFileIfNeeded(XFile? pickedFile, {int targetQuality = 80}) async {
    if (pickedFile == null) return null;
    final file = File(pickedFile.path);
    return compressIfNeeded(file, targetQuality: targetQuality);
  }
}

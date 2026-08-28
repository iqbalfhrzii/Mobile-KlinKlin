import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api/api_client.dart';
import '../theme/app_colors.dart';

/// Komponen Avatar serbaguna yang mampu merender foto profil karyawan / customer
/// dari berbagai format data:
/// 1. Data URI Base64 (`data:image/...;base64,...` atau `data:application/octet-stream;base64,...`)
/// 2. Raw Base64 string
/// 3. URL HTTP / HTTPS lengkap
/// 4. Path penyimpanan relatif (`karyawan/xyz.jpg` / `storage/karyawan/xyz.jpg`)
/// 5. File lokal perangkat
/// 6. Fallback inisial nama jika foto tidak tersedia atau gagal dimuat
class AppAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double size;
  final BoxShape shape;
  final BorderRadius? borderRadius;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final double borderWidth;
  final BoxFit fit;

  const AppAvatar({
    super.key,
    this.photoUrl,
    required this.name,
    this.size = 44,
    this.shape = BoxShape.circle,
    this.borderRadius,
    this.backgroundColor = AppColors.surfaceBlue,
    this.textColor = AppColors.primary,
    this.borderColor,
    this.borderWidth = 1.5,
    this.fit = BoxFit.cover,
  });

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final first = parts[0].isNotEmpty ? parts[0][0] : '';
      final second = parts[1].isNotEmpty ? parts[1][0] : '';
      return '$first$second'.toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : (borderRadius ?? BorderRadius.circular(size * 0.25)),
        border: borderColor != null ? Border.all(color: borderColor!, width: borderWidth) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: GoogleFonts.inter(
          fontSize: size * 0.36,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final raw = photoUrl?.trim();
    if (raw == null || raw.isEmpty || raw == 'null') {
      return _buildFallback();
    }

    Widget content;

    // 1. Cek jika data URI Base64 (data:...;base64,...)
    if (raw.startsWith('data:') || raw.contains(';base64,')) {
      try {
        final commaIdx = raw.indexOf(',');
        final base64Payload = commaIdx != -1 ? raw.substring(commaIdx + 1).trim() : raw;
        final bytes = base64Decode(base64Payload);
        content = Image.memory(
          bytes,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } catch (_) {
        return _buildFallback();
      }
    }
    // 2. Cek jika accidental URL wrapping base64 (e.g. /storage/data:...)
    else if (raw.contains('/storage/data:') || raw.contains('data:image')) {
      try {
        final startIdx = raw.indexOf('data:');
        final sub = raw.substring(startIdx);
        final commaIdx = sub.indexOf(',');
        final base64Payload = commaIdx != -1 ? sub.substring(commaIdx + 1).trim() : sub;
        final bytes = base64Decode(base64Payload);
        content = Image.memory(
          bytes,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } catch (_) {
        return _buildFallback();
      }
    }
    // 3. Cek jika raw base64 tanpa prefix data: (panjang > 80 karakter dan tidak ada slash/http)
    else if (raw.length > 80 && !raw.startsWith('http') && !raw.contains('/') && !raw.contains('\\')) {
      try {
        final bytes = base64Decode(raw);
        content = Image.memory(
          bytes,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } catch (_) {
        return _buildFallback();
      }
    }
    // 4. Cek jika file lokal
    else if ((raw.startsWith('/') || raw.contains(':\\')) && !raw.startsWith('http')) {
      try {
        final file = File(raw);
        if (file.existsSync()) {
          content = Image.file(
            file,
            width: size,
            height: size,
            fit: fit,
            errorBuilder: (_, __, ___) => _buildFallback(),
          );
        } else {
          return _buildFallback();
        }
      } catch (_) {
        return _buildFallback();
      }
    }
    // 5. Cek jika HTTP / HTTPS
    else if (raw.startsWith('http://') || raw.startsWith('https://')) {
      content = Image.network(
        Uri.encodeFull(raw),
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    }
    // 6. Path relatif di storage backend
    else {
      final cleanPath = raw.replaceAll('\\', '/').replaceFirst(RegExp(r'^/?(storage/|public/)?'), '');
      final baseDomain = ApiClient.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
      final fullUrl = '$baseDomain/storage/$cleanPath';
      content = Image.network(
        Uri.encodeFull(fullUrl),
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    }

    // Bungkus dengan Container + Clip
    final clipRadius = shape == BoxShape.circle ? null : (borderRadius ?? BorderRadius.circular(size * 0.25));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: shape,
        borderRadius: clipRadius,
        border: borderColor != null ? Border.all(color: borderColor!, width: borderWidth) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

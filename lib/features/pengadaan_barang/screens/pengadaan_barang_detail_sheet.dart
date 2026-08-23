import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/api/api_client.dart';

class PengadaanBarangDetailSheet extends StatelessWidget {
  final dynamic item;

  const PengadaanBarangDetailSheet({
    super.key,
    required this.item,
  });

  String _getUrgensiLabel(String? urgensi) {
    final u = (urgensi ?? 'low').toLowerCase();
    if (u.contains('darurat') || u.contains('high') || u.contains('tinggi')) {
      return 'Tinggi';
    } else if (u.contains('medium') || u.contains('sedang')) {
      return 'Sedang';
    } else {
      return 'Rendah';
    }
  }

  Color _getUrgensiColor(String? urgensi) {
    final u = (urgensi ?? 'low').toLowerCase();
    if (u.contains('darurat') || u.contains('high') || u.contains('tinggi')) {
      return const Color(0xFFDC2626); // Red
    } else if (u.contains('medium') || u.contains('sedang')) {
      return const Color(0xFFD97706); // Amber
    } else {
      return const Color(0xFF16A34A); // Green
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final dt = DateTime.parse(date.toString());
      return DateFormat('dd MMMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      try {
        final dt = DateTime.parse(date.toString());
        return DateFormat('dd MMM yyyy').format(dt);
      } catch (_) {
        return date.toString();
      }
    }
  }

  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final baseUrl = ApiClient.baseUrl.replaceAll('/api', '');
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    if (cleanPath.startsWith('storage/')) {
      return '$baseUrl/$cleanPath';
    }
    return '$baseUrl/storage/$cleanPath';
  }

  IconData _getJenisIcon(String? jenis) {
    final j = (jenis ?? '').toLowerCase();
    if (j == 'chemical') {
      return Icons.science_outlined;
    } else if (j == 'bhp') {
      return Icons.cleaning_services_outlined;
    }
    return Icons.build_outlined;
  }

  void _showFullScreenImage(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                        const SizedBox(height: 10),
                        Text('Gagal memuat gambar', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: InkWell(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = (item['status_pengajuan'] ?? 'pending').toString().toLowerCase();
    final isPending = status == 'pending';
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';

    final pemohonName = item['pemohon']?['nama_lengkap'] ?? item['pemohon']?['nama'] ?? item['pemohon']?['name'] ?? 'Bagus';
    final cabangName = item['cabang']?['nama_cabang'] ?? item['cabang']?['nama'] ?? 'Surabaya';
    final tglPengajuan = _formatDate(item['tanggal_pengajuan']);
    
    final namaBarang = item['nama_barang'] ?? '-';
    final merkSpek = item['merk_spesifikasi'] ?? '-';
    final jenis = item['jenis_pembelian'] ?? 'Alat';
    final jumlah = item['jumlah'] ?? 1;
    final satuan = item['satuan'] == 'Other' ? (item['satuan_lainnya'] ?? 'Pcs') : (item['satuan'] ?? 'Pcs');
    final urgensi = item['tingkat_urgensi'] ?? 'Low';
    final alasan = item['alasan_pengajuan'] ?? '-';

    // Photos list
    final List<String> photoUrls = [];
    for (int i = 1; i <= 5; i++) {
      final p = item['foto_$i'];
      if (p != null && p.toString().isNotEmpty) {
        photoUrls.add(_getImageUrl(p.toString()));
      }
    }

    final urgensiColor = _getUrgensiColor(urgensi);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMid.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryMid, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Pengajuan',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      Text(
                        'Pengadaan Alat & Chemical',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Body (Scrollable)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Status Banner Card
                  _buildStatusBanner(isPending, isApproved, isRejected, jumlah, satuan),

                  const SizedBox(height: 14),

                  // 2. Main Item Card (Hero)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Jenis & Tanggal Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryMid.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_getJenisIcon(jenis), size: 14, color: AppColors.primaryMid),
                                  const SizedBox(width: 5),
                                  Text(
                                    jenis,
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryMid),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  tglPengajuan,
                                  style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Nama Barang
                        Text(
                          namaBarang,
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('Merk / Spesifikasi: ', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                            Expanded(
                              child: Text(
                                merkSpek,
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 14),

                        // Quick Metric Strip
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('JUMLAH DIMINTA', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$jumlah $satuan',
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: urgensiColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: urgensiColor.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('TINGKAT URGENSI', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: urgensiColor)),
                                    const SizedBox(height: 2),
                                    Text(
                                      _getUrgensiLabel(urgensi),
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: urgensiColor),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3. Pemohon & Cabang Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primaryMid.withValues(alpha: 0.12),
                          child: Text(
                            pemohonName.isNotEmpty ? pemohonName[0].toUpperCase() : 'U',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryMid),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pemohonName,
                                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textDark),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                                  const SizedBox(width: 3),
                                  Text(
                                    cabangName,
                                    style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Pemohon',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 4. Alasan Pengajuan Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.format_quote_rounded, size: 18, color: AppColors.primaryMid),
                            const SizedBox(width: 6),
                            Text(
                              'Alasan Pengajuan',
                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: const Border(left: BorderSide(color: AppColors.primaryMid, width: 3)),
                          ),
                          child: Text(
                            alasan.isNotEmpty ? alasan : 'Tidak ada alasan pengajuan yang dicantumkan.',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF334155),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 5. Foto Bukti Barang Lama / Rusak
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.photo_library_outlined, size: 18, color: AppColors.primaryMid),
                                const SizedBox(width: 6),
                                Text(
                                  'Foto Bukti Fisik',
                                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${photoUrls.length} Foto',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (photoUrls.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.image_not_supported_outlined, size: 36, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'Tidak ada foto bukti yang dilampirkan',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: photoUrls.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final url = entry.value;

                                return Padding(
                                  padding: EdgeInsets.only(right: idx == photoUrls.length - 1 ? 0 : 10),
                                  child: InkWell(
                                    onTap: () => _showFullScreenImage(context, url, 'Foto ${idx + 1}'),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(11),
                                            child: Image.network(
                                              url,
                                              fit: BoxFit.cover,
                                              loadingBuilder: (_, child, progress) {
                                                if (progress == null) return child;
                                                return const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
                                              },
                                              errorBuilder: (_, __, ___) => Center(
                                                child: Icon(Icons.broken_image, size: 28, color: Colors.grey.shade400),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 6,
                                          right: 6,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.6),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Footer Action
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMid,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text('Tutup', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(bool isPending, bool isApproved, bool isRejected, dynamic jumlah, String satuan) {
    if (isPending) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.access_time_filled, size: 20, color: Color(0xFFD97706)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Menunggu Persetujuan',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pengajuan ini sedang menunggu keputusan persetujuan dari pihak Operasional.',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFB45309)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (isApproved) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, size: 20, color: Color(0xFF16A34A)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pengajuan Telah Disetujui (${item['jumlah_disetujui'] ?? jumlah} $satuan)',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF065F46)),
                  ),
                  if (item['disetujui_oleh'] != null || item['disetujuiOleh'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Disetujui oleh ${item['disetujuiOleh']?['nama'] ?? item['disetujuiOleh']?['name'] ?? 'Operasional'} pada ${_formatDate(item['tanggal_persetujuan'])}',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF047857)),
                    ),
                  ],
                  if (item['catatan_persetujuan'] != null && item['catatan_persetujuan'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Catatan: "${item['catatan_persetujuan']}"',
                      style: GoogleFonts.inter(fontSize: 11.5, fontStyle: FontStyle.italic, color: const Color(0xFF065F46)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    } else if (isRejected) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cancel, size: 20, color: Color(0xFFDC2626)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pengajuan Ditolak',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF991B1B)),
                  ),
                  if (item['catatan_persetujuan'] != null && item['catatan_persetujuan'].toString().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Alasan: "${item['catatan_persetujuan']}"',
                      style: GoogleFonts.inter(fontSize: 11.5, fontStyle: FontStyle.italic, color: const Color(0xFF7F1D1D)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

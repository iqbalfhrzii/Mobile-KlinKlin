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
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return date.toString();
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
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.white,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('Gagal memuat gambar', style: GoogleFonts.inter(fontSize: 12)),
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
                  padding: const EdgeInsets.all(6),
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
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMid.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryMid, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Pengajuan Barang',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      Text(
                        'Informasi permohonan alat & chemical cabang',
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
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner
                  if (isPending)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_filled, size: 18, color: Color(0xFFD97706)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Pengajuan ini sedang menunggu keputusan persetujuan.',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (isApproved)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle, size: 18, color: Color(0xFF16A34A)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pengajuan Disetujui (${item['jumlah_disetujui'] ?? jumlah} $satuan)',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF065F46)),
                                ),
                                if (item['disetujui_oleh'] != null || item['disetujuiOleh'] != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Diperiksa oleh ${item['disetujuiOleh']?['nama'] ?? item['disetujuiOleh']?['name'] ?? 'Operasional'} pada ${_formatDate(item['tanggal_persetujuan'])}',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF047857)),
                                  ),
                                ],
                                if (item['catatan_persetujuan'] != null && item['catatan_persetujuan'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Catatan: "${item['catatan_persetujuan']}"',
                                    style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF065F46)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (isRejected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.cancel, size: 18, color: Color(0xFFDC2626)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pengajuan Ditolak',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF991B1B)),
                                ),
                                if (item['catatan_persetujuan'] != null && item['catatan_persetujuan'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Alasan: "${item['catatan_persetujuan']}"',
                                    style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF7F1D1D)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // 2-Column Info Grid
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kolom Kiri: Informasi Pemohon
                      Expanded(
                        child: _buildInfoCard(
                          title: 'INFORMASI PEMOHON',
                          children: [
                            Text(pemohonName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                            const SizedBox(height: 2),
                            Text('$cabangName • $tglPengajuan', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Kolom Kanan: Kuantitas & Urgensi
                      Expanded(
                        child: _buildInfoCard(
                          title: 'KUANTITAS & URGENSI',
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    '$jumlah $satuan',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: urgensiColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'URGENSI: ${_getUrgensiLabel(urgensi).toUpperCase()}',
                                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: urgensiColor),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Row: Informasi Barang & Alasan Pengajuan
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Informasi Barang
                      Expanded(
                        child: _buildInfoCard(
                          title: 'INFORMASI BARANG',
                          children: [
                            Text(namaBarang, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                            const SizedBox(height: 2),
                            Text('Merk/Spek: $merkSpek', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryMid.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Jenis: $jenis',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryMid),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Alasan Pengajuan
                      Expanded(
                        child: _buildInfoCard(
                          title: 'ALASAN PENGAJUAN',
                          children: [
                            Text(
                              alasan,
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Foto Bukti Barang Lama / Rusak
                  Text(
                    'FOTO BUKTI BARANG LAMA / RUSAK',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),

                  if (photoUrls.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Center(
                        child: Text('Tidak ada foto bukti yang diunggah', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: photoUrls.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final url = entry.value;

                        return InkWell(
                          onTap: () => _showFullScreenImage(context, url, 'Foto ${idx + 1}'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                loadingBuilder: (_, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
                                },
                                errorBuilder: (_, __, ___) => Center(
                                  child: Icon(Icons.broken_image, size: 24, color: Colors.grey.shade400),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
                child: Text('Tutup', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

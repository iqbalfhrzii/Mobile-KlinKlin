import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/data/hrd_models.dart';
import 'karyawan_form_sheet.dart';

class KaryawanDetailSheet extends StatelessWidget {
  final KaryawanModel karyawan;
  final List<CabangModel>? cabangs;
  final List<JabatanModel>? jabatans;
  final VoidCallback? onEdit;

  const KaryawanDetailSheet({
    super.key,
    required this.karyawan,
    this.cabangs,
    this.jabatans,
    this.onEdit,
  });

  static Future<bool?> show(
    BuildContext context, {
    required KaryawanModel karyawan,
    List<CabangModel>? cabangs,
    List<JabatanModel>? jabatans,
    VoidCallback? onEdit,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => KaryawanDetailSheet(
        karyawan: karyawan,
        cabangs: cabangs,
        jabatans: jabatans,
        onEdit: onEdit,
      ),
    );
  }

  Future<void> _openWhatsApp(BuildContext context, String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) return;
    final formattedPhone = cleanPhone.startsWith('0') ? '62${cleanPhone.substring(1)}' : cleanPhone;
    final uri = Uri.parse('https://wa.me/$formattedPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka WhatsApp: $e')),
        );
      }
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label berhasil disalin'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusStr = karyawan.status.toLowerCase();
    final isAktif = statusStr == 'aktif';
    final isPending = statusStr == 'pending';
    final isKoor = (karyawan.statusKaryawan ?? '').toLowerCase().contains('koor');

    final namaCabang = karyawan.cabang?.namaCabang ?? '-';
    final namaJabatan = karyawan.jabatan?.namaJabatan ?? '-';
    final hasWa = karyawan.noWa != null && karyawan.noWa!.trim().isNotEmpty && karyawan.noWa != '-';
    final hasRekening = (karyawan.noRekening != null && karyawan.noRekening!.trim().isNotEmpty && karyawan.noRekening != '-') ||
        (karyawan.namaBank != null && karyawan.namaBank!.trim().isNotEmpty && karyawan.namaBank != '-');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF2563EB),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Detail Karyawan',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Profile Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar
                        _buildAvatar(karyawan, size: 60),
                        const SizedBox(width: 14),

                        // Name & Status
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                karyawan.nama,
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                karyawan.email,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isAktif
                                      ? const Color(0xFFDCFCE7)
                                      : isPending
                                          ? const Color(0xFFFEF3C7)
                                          : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isAktif
                                        ? const Color(0xFF86EFAC)
                                        : isPending
                                            ? const Color(0xFFFDE68A)
                                            : const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Text(
                                  'Status: ${karyawan.status.toUpperCase()}',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: isAktif
                                        ? const Color(0xFF15803D)
                                        : isPending
                                            ? const Color(0xFFB45309)
                                            : const Color(0xFFB91C1C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Information List
                  Text(
                    'Informasi Pekerjaan & Kontak',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Info Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        // Jabatan
                        _buildItemRow(
                          icon: Icons.work_outline_rounded,
                          iconColor: const Color(0xFF2563EB),
                          iconBg: const Color(0xFFEFF6FF),
                          label: 'Jabatan',
                          value: namaJabatan,
                        ),
                        const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),

                        // Cabang
                        _buildItemRow(
                          icon: Icons.storefront_rounded,
                          iconColor: const Color(0xFFEA580C),
                          iconBg: const Color(0xFFFFF7ED),
                          label: 'Cabang Penempatan',
                          value: namaCabang,
                        ),
                        const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),

                        // Status Pegawai
                        _buildItemRow(
                          icon: isKoor ? Icons.star_rounded : Icons.badge_outlined,
                          iconColor: isKoor ? const Color(0xFFD97706) : const Color(0xFF475569),
                          iconBg: isKoor ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                          label: 'Status Pegawai',
                          value: karyawan.statusKaryawan ?? 'Tetap',
                          isHighlight: isKoor,
                        ),
                        const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),

                        // No. WhatsApp
                        _buildItemRow(
                          icon: Icons.phone_outlined,
                          iconColor: const Color(0xFF16A34A),
                          iconBg: const Color(0xFFDCFCE7),
                          label: 'No. WhatsApp / Telepon',
                          value: hasWa ? karyawan.noWa! : '-',
                          trailing: hasWa
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () => _copyToClipboard(context, karyawan.noWa!, 'Nomor WhatsApp'),
                                      borderRadius: BorderRadius.circular(6),
                                      child: const Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Icon(Icons.copy_rounded, size: 16, color: Color(0xFF64748B)),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _openWhatsApp(context, karyawan.noWa!),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF22C55E),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.chat_rounded, size: 12, color: Colors.white),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Chat WA',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                        const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),

                        // Rekening Bank
                        _buildItemRow(
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: const Color(0xFF6366F1),
                          iconBg: const Color(0xFFEEF2FF),
                          label: 'Rekening Bank',
                          value: hasRekening
                              ? '${karyawan.namaBank ?? '-'} • ${karyawan.noRekening ?? '-'}'
                              : '-',
                          trailing: (karyawan.noRekening != null && karyawan.noRekening!.isNotEmpty && karyawan.noRekening != '-')
                              ? InkWell(
                                  onTap: () => _copyToClipboard(context, karyawan.noRekening!, 'Nomor Rekening'),
                                  borderRadius: BorderRadius.circular(6),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(Icons.copy_rounded, size: 16, color: Color(0xFF64748B)),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Tutup',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(context); // Close detail sheet
                      if (onEdit != null) {
                        onEdit!();
                      } else {
                        final updated = await KaryawanFormSheet.show(
                          context,
                          karyawan: karyawan,
                          cabangs: cabangs,
                          jabatans: jabatans,
                        );
                        if (updated == true && context.mounted) {
                          // Signal update
                        }
                      }
                    },
                    icon: const Icon(Icons.edit_outlined, size: 17, color: Colors.white),
                    label: Text(
                      'Edit Karyawan',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    Widget? trailing,
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isHighlight ? const Color(0xFFD97706) : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildAvatar(KaryawanModel karyawan, {double size = 60}) {
    final photoUrl = karyawan.fullFotoUrl;
    final initial = karyawan.nama.isNotEmpty ? karyawan.nama.substring(0, 1).toUpperCase() : 'K';

    Widget fallback() {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFFDBEAFE),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: GoogleFonts.inter(
            color: const Color(0xFF1D4ED8),
            fontWeight: FontWeight.bold,
            fontSize: size * 0.38,
          ),
        ),
      );
    }

    if (photoUrl == null || photoUrl.isEmpty) {
      return fallback();
    }

    if (photoUrl.startsWith('data:image')) {
      try {
        final base64Str = photoUrl.split(',').last;
        return ClipOval(
          child: Image.memory(
            base64Decode(base64Str),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback(),
          ),
        );
      } catch (_) {
        return fallback();
      }
    }

    return ClipOval(
      child: Image.network(
        photoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }
}

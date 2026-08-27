import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import 'karyawan_form_sheet.dart';

class KaryawanDetailScreen extends StatefulWidget {
  final KaryawanModel karyawan;
  const KaryawanDetailScreen({super.key, required this.karyawan});

  @override
  State<KaryawanDetailScreen> createState() => _KaryawanDetailScreenState();
}

class _KaryawanDetailScreenState extends State<KaryawanDetailScreen> {
  late KaryawanModel _karyawan;

  @override
  void initState() {
    super.initState();
    _karyawan = widget.karyawan;
  }

  Future<void> _editKaryawan() async {
    final updated = await KaryawanFormSheet.show(
      context,
      karyawan: _karyawan,
    );
    if (updated == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusStr = _karyawan.status.toLowerCase();
    final isAktif = statusStr == 'aktif';
    final isPending = statusStr == 'pending';
    final isKoor = (_karyawan.statusKaryawan ?? '').toLowerCase().contains('koor');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Karyawan',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _karyawan.nama,
                        style: GoogleFonts.inter(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _editKaryawan,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Profile Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildAvatar(_karyawan, size: 60),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _karyawan.nama,
                                  style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _karyawan.email,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isAktif
                                  ? const Color(0xFFDCFCE7)
                                  : isPending
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _karyawan.status.toUpperCase(),
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

                      const SizedBox(height: 20),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 16),

                      _buildInfoRow(
                        Icons.work_outline_rounded,
                        'Jabatan',
                        _karyawan.jabatan?.namaJabatan ?? '-',
                        iconColor: const Color(0xFF2563EB),
                      ),
                      const SizedBox(height: 14),
                      _buildInfoRow(
                        Icons.storefront_rounded,
                        'Cabang',
                        _karyawan.cabang?.namaCabang ?? '-',
                        iconColor: const Color(0xFFEA580C),
                      ),
                      const SizedBox(height: 14),
                      _buildInfoRow(
                        isKoor ? Icons.star_rounded : Icons.badge_outlined,
                        'Status Pegawai',
                        _karyawan.statusKaryawan ?? '-',
                        iconColor: isKoor ? const Color(0xFFD97706) : const Color(0xFF475569),
                        isHighlight: isKoor,
                      ),
                      const SizedBox(height: 14),
                      _buildInfoRow(
                        Icons.phone_outlined,
                        'No. WhatsApp',
                        _karyawan.noWa ?? '-',
                        iconColor: const Color(0xFF16A34A),
                      ),
                      const SizedBox(height: 14),
                      _buildInfoRow(
                        Icons.account_balance_wallet_outlined,
                        'Rekening Bank',
                        '${_karyawan.namaBank ?? '-'} • ${_karyawan.noRekening ?? '-'}',
                        iconColor: const Color(0xFF6366F1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
          color: Color(0xFFEFF6FF),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: GoogleFonts.inter(
            color: const Color(0xFF2563EB),
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

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color iconColor = const Color(0xFF64748B),
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
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
      ],
    );
  }
}

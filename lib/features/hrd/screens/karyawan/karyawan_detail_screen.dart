import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';

class KaryawanDetailScreen extends StatelessWidget {
  final KaryawanModel karyawan;
  const KaryawanDetailScreen({super.key, required this.karyawan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Detail Karyawan', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                    Text(karyawan.nama, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildInfoCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: karyawan.fotoProfil != null ? NetworkImage(karyawan.fotoProfil!) : null,
                child: karyawan.fotoProfil == null ? Text(karyawan.nama.substring(0, 1).toUpperCase(), style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.bold)) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(karyawan.nama, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(karyawan.email, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: karyawan.status == 'aktif' ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  karyawan.status.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: karyawan.status == 'aktif' ? Colors.green.shade700 : Colors.red.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow(Icons.work_outline_rounded, 'Jabatan', karyawan.jabatan?.namaJabatan ?? '-'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.storefront_rounded, 'Cabang', karyawan.cabang?.namaCabang ?? '-'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.badge_outlined, 'Status Pegawai', karyawan.statusKaryawan ?? '-'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.phone_outlined, 'No. WhatsApp', karyawan.noWa ?? '-'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.account_balance_wallet_outlined, 'Rekening Bank', '${karyawan.namaBank ?? '-'} - ${karyawan.noRekening ?? '-'}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            ],
          ),
        ),
      ],
    );
  }
}

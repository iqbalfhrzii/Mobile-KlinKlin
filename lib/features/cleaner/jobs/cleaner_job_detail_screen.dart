import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/cleaner_job_service.dart';

class CleanerJobDetailScreen extends StatefulWidget {
  const CleanerJobDetailScreen({super.key, required this.job});
  final Map<String, dynamic> job;

  @override
  State<CleanerJobDetailScreen> createState() => _CleanerJobDetailScreenState();
}

class _CleanerJobDetailScreenState extends State<CleanerJobDetailScreen> {
  final CleanerJobService _service = CleanerJobService();
  late Map<String, dynamic> _job;
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _refreshDetail();
  }

  Future<void> _refreshDetail() async {
    setState(() => _isLoading = true);
    try {
      final detail = await _service.fetchJobDetail(_job['id']);
      setState(() {
        _job = detail;
        _isLoading = false;
      });
    } catch (e) {
      // If fetching detail fails, just use the partial job data passed from list
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String action) async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      if (action == 'start') {
        await _service.startJob(_job['id']);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pekerjaan dimulai!'), backgroundColor: AppColors.statusProgress));
      } else if (action == 'finish') {
        await _service.finishJob(_job['id']);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pekerjaan selesai!'), backgroundColor: AppColors.statusDone));
      }
      await _refreshDetail();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error), backgroundColor: AppColors.error));
    }
  }

  String _formatRupiah(int n) =>
      'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  Future<void> _launchWA(String noWa) async {
    String phone = noWa.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) {
      phone = '62${phone.substring(1)}';
    }
    final url = Uri.parse('https://wa.me/$phone');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka WhatsApp')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _job['status_pengerjaan'];
    final pesanan = _job['pesanan'] ?? {};
    final pelanggan = pesanan['pelanggan'] ?? {};
    final details = pesanan['details'] as List? ?? [];
    
    final bonusList = _job['bonuses'] as List? ?? [];
    final totalBonus = int.tryParse(_job['total_bonus']?.toString() ?? '0') ?? 0;

    final isStartable = status == 'assigned' || status == 'notified';
    final isFinishable = status == 'in_progress';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context, pesanan['id']?.toString() ?? '-'),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusHeader(status),
                        const SizedBox(height: 24),
                        
                        // Detail Pelanggan & Alamat
                        Text('Informasi Pelanggan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white, 
                            borderRadius: BorderRadius.circular(16), 
                            border: Border.all(color: AppColors.border),
                            boxShadow: [AppColors.cardShadow],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person, color: AppColors.primary, size: 20),
                                  const SizedBox(width: 8),
                                  Text(pelanggan['nama_pelanggan'] ?? '-', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on, color: AppColors.error, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(pelanggan['alamat_pelanggan'] ?? pelanggan['alamat'] ?? 'Alamat tidak tersedia', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark)),
                                        if (pelanggan['patokan_alamat'] != null) ...[
                                          const SizedBox(height: 4),
                                          Text('Patokan: ${pelanggan['patokan_alamat']}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                        ]
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (pelanggan['no_wa'] != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.phone, color: AppColors.statusDone, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(pelanggan['no_wa'], style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark))),
                                    InkWell(
                                      onTap: () => _launchWA(pelanggan['no_wa']),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF25D366).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Image.network(
                                              'https://www.edigitalagency.com.au/wp-content/uploads/WhatsApp-logo-webp-green-small-size.webp',
                                              height: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Text('Chat Pelanggan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1DA851))),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ]
                            ],
                          ),
                        ),
                  const SizedBox(height: 24),

                  // Detail Layanan
                  Text('Layanan Dipesan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 12),
                  ...details.map((d) {
                    final l = d['layanan'] ?? {};
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white, 
                        borderRadius: BorderRadius.circular(16), 
                        border: Border.all(color: AppColors.border),
                        boxShadow: [AppColors.cardShadow],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l['nama_layanan'] ?? '-', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                          const SizedBox(height: 4),
                          Text('Qty: ${d['qty'] ?? '-'}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          Text('Tanggal: ${d['tanggal_pengerjaan'] ?? '-'} | Waktu: ${d['waktu_pengerjaan'] ?? '-'}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),

                  // Bonus
                  if (bonusList.isNotEmpty || totalBonus > 0) ...[
                    Text('Bonus Anda', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFFFFBE6), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFFE58F))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...bonusList.map((b) {
                            String namaBonus = b['keterangan'] ?? 'Bonus';
                            if (b['tarif_bonus_cabang'] != null && b['tarif_bonus_cabang']['jenis_bonus'] != null) {
                              namaBonus = b['tarif_bonus_cabang']['jenis_bonus']['nama_bonus'] ?? namaBonus;
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(namaBonus, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFAD6800)))),
                                  Text(_formatRupiah(int.tryParse(b['nominal']?.toString() ?? '0') ?? 0), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFD48806))),
                                ],
                              ),
                            );
                          }),
                          if (bonusList.isNotEmpty) const Divider(color: Color(0xFFFFE58F)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Bonus', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFAD6800))),
                              Text(_formatRupiah(totalBonus), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFFD48806))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isStartable || isFinishable

          ? Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _updateStatus(isStartable ? 'start' : 'finish'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isStartable ? AppColors.primary : AppColors.statusDone,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      isStartable ? 'Mulai Pekerjaan' : 'Selesaikan Pekerjaan',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildHeader(BuildContext context, String orderId) {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HeaderBackButton(onTap: () => Navigator.pop(context)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detail Tugas', style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
                  )),
                  Text('#$orderId', style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.white.withOpacity(0.6),
                  )),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(String? status) {
    Color bg = AppColors.border;
    Color fg = AppColors.textMuted;
    String text = 'Tugas Baru';
    IconData icon = Icons.info_outline;

    switch (status) {
      case 'assigned':
      case 'notified':
        bg = AppColors.statusPending.withOpacity(0.1);
        fg = AppColors.statusPending;
        text = 'Siap Dikerjakan';
        icon = Icons.play_circle_outline;
        break;
      case 'in_progress':
        bg = AppColors.statusProgress.withOpacity(0.1);
        fg = AppColors.statusProgress;
        text = 'Sedang Dikerjakan';
        icon = Icons.timelapse;
        break;
      case 'finished':
        bg = AppColors.statusDone.withOpacity(0.1);
        fg = AppColors.statusDone;
        text = 'Selesai';
        icon = Icons.check_circle_outline;
        break;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 28),
          const SizedBox(width: 12),
          Text(text, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: fg)),
        ],
      ),
    );
  }
}

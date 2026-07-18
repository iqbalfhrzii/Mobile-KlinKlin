import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/whatsapp_icon.dart';
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
  bool _hasChanged = false;
  String _error = '';

  Timer? _durationTimer;
  String _durationDisplay = '00:00:00';
  DateTime? _workStartTime;

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _refreshDetail();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshDetail() async {
    setState(() => _isLoading = true);
    try {
      final detail = await _service.fetchJobDetail(_job['id']);
      setState(() {
        _job = detail;
        _isLoading = false;
      });
      if (_job['status_pengerjaan'] == 'in_progress') {
        _startDurationTimer();
      } else {
        _durationTimer?.cancel();
      }
    } catch (e) {
      // If fetching detail fails, just use the partial job data passed from list
      setState(() {
        _isLoading = false;
      });
      if (_job['status_pengerjaan'] == 'in_progress') {
        _startDurationTimer();
      }
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    
    DateTime? startTime;
    if (_job['started_at'] != null) {
      startTime = DateTime.tryParse(_job['started_at'].toString())?.toLocal();
    }
    if (startTime == null && _job['waktu_mulai'] != null) {
      startTime = DateTime.tryParse(_job['waktu_mulai'].toString())?.toLocal();
    }
    if (startTime == null && _job['updated_at'] != null) {
      startTime = DateTime.tryParse(_job['updated_at'].toString())?.toLocal();
    }
    _workStartTime = startTime;
    
    if (_workStartTime == null) {
      _loadLocalStartTime();
      return;
    }
    
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final now = DateTime.now();
      final diff = now.difference(_workStartTime!);
      if (diff.isNegative) {
        setState(() {
          _durationDisplay = '00:00:00';
        });
        return;
      }
      final hours = diff.inHours.toString().padLeft(2, '0');
      final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
      setState(() {
        _durationDisplay = '$hours:$minutes:$seconds';
      });
    });
  }

  Future<void> _loadLocalStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    final localTimeStr = prefs.getString('job_start_time_${_job['id']}');
    if (localTimeStr != null) {
      _workStartTime = DateTime.tryParse(localTimeStr);
    }
    if (_workStartTime == null) {
      _workStartTime = DateTime.now();
      prefs.setString('job_start_time_${_job['id']}', _workStartTime!.toIso8601String());
    }
    _startDurationTimer();
  }

  Future<void> _saveLocalStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    _workStartTime = now;
    await prefs.setString('job_start_time_${_job['id']}', now.toIso8601String());
  }

  Future<void> _clearLocalStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('job_start_time_${_job['id']}');
  }

  Future<void> _updateStatus(String action) async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      if (action == 'start') {
        await _service.startJob(_job['id']);
        await _saveLocalStartTime();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pekerjaan dimulai!'), backgroundColor: AppColors.statusProgress));
      } else if (action == 'finish') {
        await _service.finishJob(_job['id']);
        await _clearLocalStartTime();
        _durationTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pekerjaan selesai!'), backgroundColor: AppColors.statusDone));
      }
      _hasChanged = true;
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

  String _formatDateWithDay(String? dateStr) {
    if (dateStr == null || dateStr == '-') return '-';
    try {
      final dt = DateTime.parse(dateStr);
      final weekdayNames = {
        1: 'Senin',
        2: 'Selasa',
        3: 'Rabu',
        4: 'Kamis',
        5: 'Jumat',
        6: 'Sabtu',
        7: 'Minggu',
      };
      final months = {
        1: 'Januari',
        2: 'Februari',
        3: 'Maret',
        4: 'April',
        5: 'Mei',
        6: 'Juni',
        7: 'Juli',
        8: 'Agustus',
        9: 'September',
        10: 'Oktober',
        11: 'November',
        12: 'Desember',
      };
      final dayName = weekdayNames[dt.weekday] ?? '';
      final monthName = months[dt.month] ?? '';
      return '$dayName, ${dt.day} $monthName ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _getFinishedDurationString() {
    DateTime? start;
    if (_job['started_at'] != null) {
      start = DateTime.tryParse(_job['started_at'].toString())?.toLocal();
    }
    if (start == null && _job['waktu_mulai'] != null) {
      start = DateTime.tryParse(_job['waktu_mulai'].toString())?.toLocal();
    }
    
    DateTime? end;
    if (_job['finished_at'] != null) {
      end = DateTime.tryParse(_job['finished_at'].toString())?.toLocal();
    }
    if (end == null && _job['waktu_selesai'] != null) {
      end = DateTime.tryParse(_job['waktu_selesai'].toString())?.toLocal();
    }
    if (end == null && _job['updated_at'] != null) {
      end = DateTime.tryParse(_job['updated_at'].toString())?.toLocal();
    }
    
    if (start == null || end == null) return 'Selesai';
    final diff = end.difference(start);
    if (diff.isNegative) return 'Selesai';
    
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;
    
    List<String> parts = [];
    if (hours > 0) parts.add('$hours jam');
    if (minutes > 0) parts.add('$minutes menit');
    if (hours == 0 && minutes == 0) parts.add('$seconds detik');
    
    return parts.join(' ');
  }

  Widget _buildFuturisticScheduleOrTimerCard(String? status, String globalTgl, String globalWaktu) {
    if (status == 'in_progress') {
      return _buildFuturisticTimerCard(globalTgl, globalWaktu);
    } else if (status == 'finished') {
      return _buildFuturisticFinishedCard(globalTgl, globalWaktu);
    } else {
      return _buildFuturisticScheduledCard(globalTgl, globalWaktu);
    }
  }

  Widget _buildFuturisticTimerCard(String globalTgl, String globalWaktu) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Waktu Pengerjaan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.statusProgress.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.statusProgress,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Aktif',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.statusProgress),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.statusProgress.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.timer_outlined, color: AppColors.statusProgress, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _durationDisplay,
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.statusProgress,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Durasi pengerjaan berjalan',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month, color: AppColors.textMuted, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    globalTgl,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.access_time_outlined, color: AppColors.textMuted, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Mulai: $globalWaktu',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFuturisticFinishedCard(String globalTgl, String globalWaktu) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: AppColors.statusDone.withOpacity(0.3)),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Durasi Pengerjaan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.statusDone.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Selesai',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.statusDone),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.statusDone.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.statusDone, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getFinishedDurationString(),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pekerjaan diselesaikan',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month, color: AppColors.textMuted, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    globalTgl,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.access_time_outlined, color: AppColors.textMuted, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    globalWaktu,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFuturisticScheduledCard(String globalTgl, String globalWaktu) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Jadwal Pengerjaan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.statusPending.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Mendatang',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.statusPending),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.calendar_month, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(globalTgl, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time_outlined, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(globalWaktu, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _job['status_pengerjaan'];
    final pesanan = _job['pesanan'] ?? {};
    final pelanggan = pesanan['pelanggan'] ?? {};
    final details = pesanan['details'] as List? ?? [];
    
    String globalTgl = '-';
    String globalWaktu = '-';
    if (details.isNotEmpty) {
      globalTgl = _formatDateWithDay(details.first['tanggal_pengerjaan']);
      globalWaktu = details.first['waktu_pengerjaan'] ?? '-';
    }
    
    final bonusList = _job['bonuses'] as List? ?? [];
    final num totalBonus = _job['total_bonus'] is num ? _job['total_bonus'] : (num.tryParse(_job['total_bonus']?.toString() ?? '0') ?? 0);

    final isStartable = status == 'assigned' || status == 'notified';
    final isFinishable = status == 'in_progress';

    final List<Widget> bonusWidgets = [];
    
    for (var b in bonusList) {
      String namaBonus = b['keterangan'] ?? 'Bonus';
      String? catatan;
      
      if (b['tarif_bonus_cabang'] != null && b['tarif_bonus_cabang']['jenis_bonus'] != null) {
        namaBonus = b['tarif_bonus_cabang']['jenis_bonus']['nama_bonus'] ?? namaBonus;
        if (b['keterangan'] != null && b['keterangan'].toString().trim().isNotEmpty) {
           String raw = b['keterangan'].toString().trim();
           if (!raw.startsWith('[BONUS_LAYANAN]') && raw != namaBonus) {
              catatan = raw;
           }
        }
      }
      
      // If it's a service bonus, extract the real name and note
      if (b['keterangan'] != null && b['keterangan'].toString().startsWith('[BONUS_LAYANAN]')) {
        final parts = b['keterangan'].toString().split('|');
        if (parts.length > 1) {
          namaBonus = parts[1].trim(); 
        }
        if (parts.length > 2 && parts[2].trim().isNotEmpty) {
          catatan = parts[2].trim();
        }
      }
      
      final num nominal = b['nominal'] is num ? b['nominal'] : (num.tryParse(b['nominal']?.toString() ?? '0') ?? 0);
      
      bonusWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(namaBonus, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFAD6800))),
                    if (catatan != null) ...[
                      const SizedBox(height: 2),
                      Text('Catatan: $catatan', style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFFAD6800).withOpacity(0.8))),
                    ]
                  ],
                ),
              ),
              Text(_formatRupiah(nominal.toInt()), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFD48806))),
            ],
          ),
        )
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _hasChanged);
      },
      child: Scaffold(
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
                        _buildFuturisticScheduleOrTimerCard(status, globalTgl, globalWaktu),
                        const SizedBox(height: 20),
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
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: AppColors.primary.withOpacity(0.1),
                                    child: Text(
                                      (pelanggan['nama_pelanggan'] ?? 'P').toString().substring(0, 1).toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pelanggan['nama_pelanggan'] ?? '-',
                                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                        ),
                                        if (pelanggan['no_wa'] != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            pelanggan['no_wa'],
                                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (pelanggan['no_wa'] != null && (_job['show_wa'] == true || _job['show_wa'] == 1 || _job['show_wa'] == '1'))
                                    InkWell(
                                      onTap: () => _launchWA(pelanggan['no_wa']),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF25D366),
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF25D366).withOpacity(0.15),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const WhatsAppIcon(size: 18, color: Colors.white),
                                            const SizedBox(width: 6),
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
                              ),
                              const SizedBox(height: 14),
                              const Divider(color: AppColors.border, height: 1),
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on_rounded, color: AppColors.error, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Alamat Pengerjaan',
                                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          pelanggan['alamat_pelanggan'] ?? pelanggan['alamat'] ?? 'Alamat tidak tersedia',
                                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, height: 1.4),
                                        ),
                                        if (pelanggan['patokan_alamat'] != null && pelanggan['patokan_alamat'].toString().trim().isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceBlue,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Icon(Icons.flag_rounded, size: 14, color: AppColors.primary),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    'Patokan: ${pelanggan['patokan_alamat']}',
                                                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (pelanggan['catatan'] != null && pelanggan['catatan'].toString().trim().isNotEmpty && pelanggan['catatan'].toString().trim() != 'null') ...[
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9F9F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.note_alt_rounded, color: AppColors.primary, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Catatan Pelanggan',
                                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              pelanggan['catatan'].toString(),
                                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (pesanan['keterangan_order'] != null && pesanan['keterangan_order'].toString().trim().isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.notes_rounded, color: Colors.grey.shade600, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Catatan Pesanan',
                                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              pesanan['keterangan_order'].toString(),
                                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, fontStyle: FontStyle.italic),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),const SizedBox(height: 8),

                  // Detail Layanan
                  Text('Layanan Dipesan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 12),
                  ...details.map((d) {
                    final l = d['layanan'] ?? {};
                    return Container(
                      width: double.infinity,
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
                          Text(l['nama_layanan'] ?? '-', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBE6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFFE58F)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline, size: 18, color: Color(0xFFD48806)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Qty/Catatan: ${d['qty'] ?? '-'}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFAD6800))),
                                ),
                              ],
                            ),
                          ),
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
                          ...bonusWidgets,
                          if (bonusWidgets.isNotEmpty) const Divider(color: Color(0xFFFFE58F)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Bonus', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFAD6800))),
                              Text(_formatRupiah(totalBonus.toInt()), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFFD48806))),
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
      ),
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
              HeaderBackButton(onTap: () => Navigator.pop(context, _hasChanged)),
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

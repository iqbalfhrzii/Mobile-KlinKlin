import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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

  DateTime? _parseServerTime(dynamic val) {
    if (val == null) return null;
    String str = val.toString();
    if (!str.endsWith('Z')) str += 'Z';
    return DateTime.tryParse(str)?.toLocal();
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();

    DateTime? startTime = _parseServerTime(_job['started_at']) ?? 
                          _parseServerTime(_job['waktu_mulai']) ?? 
                          _parseServerTime(_job['updated_at']);
    
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
      prefs.setString(
        'job_start_time_${_job['id']}',
        _workStartTime!.toIso8601String(),
      );
    }
    _startDurationTimer();
  }

  Future<void> _saveLocalStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    _workStartTime = now;
    await prefs.setString(
      'job_start_time_${_job['id']}',
      now.toIso8601String(),
    );
  }

  Future<void> _clearLocalStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('job_start_time_${_job['id']}');
  }

  Future<void> _updateStatus(String action, List<File> photos) async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      if (action == 'start') {
        await _service.startJob(_job['id'], photos);
        await _saveLocalStartTime();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pekerjaan dimulai!'),
            backgroundColor: AppColors.statusProgress,
          ),
        );
      } else if (action == 'finish') {
        await _service.finishJob(_job['id'], photos);
        await _clearLocalStartTime();
        _durationTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pekerjaan selesai!'),
            backgroundColor: AppColors.statusDone,
          ),
        );
      }
      _hasChanged = true;
      await _refreshDetail();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error), backgroundColor: AppColors.error),
      );
    }
  }

  void _showPhotoPickerSheet(String action) {
    final ImagePicker picker = ImagePicker();
    List<File> selectedPhotos = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickPhoto(ImageSource source) async {
              if (selectedPhotos.length >= 3) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Maksimal 3 foto')),
                );
                return;
              }

              if (source == ImageSource.gallery) {
                final List<XFile>? files = await picker.pickMultiImage(
                  imageQuality: 60,
                  maxWidth: 1024,
                  maxHeight: 1024,
                );
                if (files != null && files.isNotEmpty) {
                  setModalState(() {
                    for (var file in files) {
                      if (selectedPhotos.length < 3) {
                        selectedPhotos.add(File(file.path));
                      }
                    }
                  });
                }
              } else {
                final XFile? file = await picker.pickImage(
                  source: source,
                  imageQuality: 60,
                  maxWidth: 1024,
                  maxHeight: 1024,
                );
                if (file != null) {
                  setModalState(() {
                    selectedPhotos.add(File(file.path));
                  });
                }
              }
            }

            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            action == 'start'
                                ? 'Mulai Pekerjaan'
                                : 'Selesaikan Pekerjaan',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Upload 2 - 3 foto bukti.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      ...selectedPhotos.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final f = entry.value;
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 14),
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                image: DecorationImage(
                                  image: FileImage(f),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: -4,
                              right: 6,
                              child: GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    selectedPhotos.removeAt(idx);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      if (selectedPhotos.length < 3)
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (_) => Container(
                                margin: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                      title: Text(
                                        'Ambil Foto Kamera',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        pickPhoto(ImageSource.camera);
                                      },
                                    ),
                                    const Divider(
                                      height: 1,
                                      color: Color(0xFFF1F5F9),
                                    ),
                                    ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5F3FF),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.photo_library_rounded,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                      ),
                                      title: Text(
                                        'Pilih dari Galeri',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Bisa pilih lebih dari 1 foto',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        pickPhoto(ImageSource.gallery);
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1.5,
                                style: BorderStyle.none,
                              ),
                            ),
                            child: CustomPaint(
                              painter: _DottedBorderPainter(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.add_photo_alternate_rounded,
                                    color: Color(0xFF94A3B8),
                                    size: 28,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tambah',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedPhotos.isEmpty
                          ? null
                          : () {
                              Navigator.pop(context);
                              _updateStatus(action, selectedPhotos);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: action == 'start'
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF10B981),
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: selectedPhotos.isEmpty ? 0 : 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        action == 'start'
                            ? 'Upload & Mulai'
                            : 'Upload & Selesai',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: selectedPhotos.isEmpty
                              ? const Color(0xFF94A3B8)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
        );
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

  Future<void> _openMap(String address) async {
    final query = Uri.encodeComponent(address);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka Maps')),
        );
      }
    }
  }

  String _getFinishedDurationString() {
    DateTime? start = _parseServerTime(_job['started_at']) ?? 
                      _parseServerTime(_job['waktu_mulai']);
    
    DateTime? end = _parseServerTime(_job['finished_at']) ?? 
                    _parseServerTime(_job['waktu_selesai']) ?? 
                    _parseServerTime(_job['updated_at']);

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

  Widget _buildFuturisticScheduleOrTimerCard(
    String? status,
    String globalTgl,
    String globalWaktu,
  ) {
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
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Waktu Pengerjaan',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.statusProgress.withValues(alpha: 0.1),
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
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.statusProgress,
                      ),
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
                  color: AppColors.statusProgress.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  color: AppColors.statusProgress,
                  size: 26,
                ),
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
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
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
                  const Icon(
                    Icons.calendar_month,
                    color: AppColors.textMuted,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    globalTgl,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_outlined,
                    color: AppColors.textMuted,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Mulai: $globalWaktu',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w500,
                    ),
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
        border: Border.all(color: AppColors.statusDone.withValues(alpha: 0.3)),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Durasi Pengerjaan',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.statusDone.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Selesai',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.statusDone,
                  ),
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
                  color: AppColors.statusDone.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.statusDone,
                  size: 26,
                ),
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
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
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
                  const Icon(
                    Icons.calendar_month,
                    color: AppColors.textMuted,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    globalTgl,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_outlined,
                    color: AppColors.textMuted,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    globalWaktu,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textDark,
                    ),
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
              Text(
                'Jadwal Pengerjaan',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.statusPending.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Mendatang',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.statusPending,
                  ),
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
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      globalTgl,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          globalWaktu,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
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
    final num totalBonus = _job['total_bonus'] is num
        ? _job['total_bonus']
        : (num.tryParse(_job['total_bonus']?.toString() ?? '0') ?? 0);

    final isStartable = status == 'assigned' || status == 'notified';
    final isFinishable = status == 'in_progress';

    final List<Widget> bonusWidgets = [];

    for (var b in bonusList) {
      String namaBonus = b['keterangan'] ?? 'Bonus';
      String? catatan;

      if (b['tarif_bonus_cabang'] != null &&
          b['tarif_bonus_cabang']['jenis_bonus'] != null) {
        namaBonus =
            b['tarif_bonus_cabang']['jenis_bonus']['nama_bonus'] ?? namaBonus;
        if (b['keterangan'] != null &&
            b['keterangan'].toString().trim().isNotEmpty) {
          String raw = b['keterangan'].toString().trim();
          if (!raw.startsWith('[BONUS_LAYANAN]') && raw != namaBonus) {
            catatan = raw;
          }
        }
      }

      // If it's a service bonus, extract the real name and note
      if (b['keterangan'] != null &&
          b['keterangan'].toString().startsWith('[BONUS_LAYANAN]')) {
        final parts = b['keterangan'].toString().split('|');
        if (parts.length > 1) {
          namaBonus = parts[1].trim();
        }
        if (parts.length > 2 && parts[2].trim().isNotEmpty) {
          catatan = parts[2].trim();
        }
      }

      final num nominal = b['nominal'] is num
          ? b['nominal']
          : (num.tryParse(b['nominal']?.toString() ?? '0') ?? 0);

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
                    Text(
                      namaBonus,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFFAD6800),
                      ),
                    ),
                    if (catatan != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Catatan: $catatan',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFFAD6800).withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                _formatRupiah(nominal.toInt()),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD48806),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _hasChanged);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC), // Modern soft background
        body: Column(
          children: [
            _buildHeader(context, pesanan['nomor_pesanan']?.toString() ?? pesanan['id']?.toString() ?? '-'),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusHeader(status),
                          const SizedBox(height: 16),
                          _buildFuturisticScheduleOrTimerCard(
                            status,
                            globalTgl,
                            globalWaktu,
                          ),
                          const SizedBox(height: 24),

                          // Customer Info Pro Max
                          Text(
                            'Informasi Pelanggan',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF0F172A,
                                  ).withValues(alpha: 0.04),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF3B82F6),
                                              Color(0xFF2563EB),
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF2563EB,
                                              ).withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            (pelanggan['nama_pelanggan'] ?? 'P')
                                                .toString()
                                                .substring(0, 1)
                                                .toUpperCase(),
                                            style: GoogleFonts.inter(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              pelanggan['nama_pelanggan'] ??
                                                  '-',
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                            if (pelanggan['no_wa'] != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                pelanggan['no_wa'],
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  color: const Color(
                                                    0xFF64748B,
                                                  ),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (pelanggan['no_wa'] != null &&
                                          (_job['show_wa'] == true ||
                                              _job['show_wa'] == 1 ||
                                              _job['show_wa'] == '1'))
                                        GestureDetector(
                                          onTap: () =>
                                              _launchWA(pelanggan['no_wa']),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF25D366,
                                              ).withValues(alpha: 0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const WhatsAppIcon(
                                              size: 20,
                                              color: Color(0xFF25D366),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Divider(
                                  color: Color(0xFFF1F5F9),
                                  height: 1,
                                  thickness: 1,
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.location_on_rounded,
                                          color: Color(0xFFDC2626),
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Alamat Pengerjaan',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              pelanggan['alamat_pelanggan'] ??
                                                  pelanggan['alamat'] ??
                                                  'Alamat tidak tersedia',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                color: const Color(0xFF1E293B),
                                                height: 1.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (pelanggan['patokan_alamat'] !=
                                                    null &&
                                                pelanggan['patokan_alamat']
                                                    .toString()
                                                    .trim()
                                                    .isNotEmpty) ...[
                                              const SizedBox(height: 10),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFEFF6FF,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFDBEAFE,
                                                    ),
                                                  ),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Icon(
                                                      Icons.flag_rounded,
                                                      size: 14,
                                                      color: Color(0xFF2563EB),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        'Patokan: ${pelanggan['patokan_alamat']}',
                                                        style:
                                                            GoogleFonts.inter(
                                                              fontSize: 12,
                                                              color:
                                                                  const Color(
                                                                    0xFF1D4ED8,
                                                                  ),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 12),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  final address = pelanggan['alamat_pelanggan'] ??
                                                      pelanggan['alamat'] ??
                                                      '';
                                                  if (address.toString().trim().isNotEmpty) {
                                                    _openMap(address.toString());
                                                  }
                                                },
                                                icon: const Icon(Icons.map_rounded, size: 18),
                                                label: Text('Buka di Maps', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFFEFF6FF),
                                                  foregroundColor: const Color(0xFF2563EB),
                                                  elevation: 0,
                                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if ((pelanggan['catatan'] != null &&
                                        pelanggan['catatan']
                                            .toString()
                                            .trim()
                                            .isNotEmpty &&
                                        pelanggan['catatan']
                                                .toString()
                                                .trim() !=
                                            'null') ||
                                    (pesanan['keterangan_order'] != null &&
                                        pesanan['keterangan_order']
                                            .toString()
                                            .trim()
                                            .isNotEmpty)) ...[
                                  const Divider(
                                    color: Color(0xFFF1F5F9),
                                    height: 1,
                                    thickness: 1,
                                  ),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(20),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (pelanggan['catatan'] != null &&
                                            pelanggan['catatan']
                                                .toString()
                                                .trim()
                                                .isNotEmpty &&
                                            pelanggan['catatan']
                                                    .toString()
                                                    .trim() !=
                                                'null') ...[
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.note_alt_rounded,
                                                color: Color(0xFFF59E0B),
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Catatan Pelanggan',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color(
                                                          0xFFD97706,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      pelanggan['catatan']
                                                          .toString(),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        color: const Color(
                                                          0xFF475569,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (pesanan['keterangan_order'] !=
                                                  null &&
                                              pesanan['keterangan_order']
                                                  .toString()
                                                  .trim()
                                                  .isNotEmpty)
                                            const SizedBox(height: 12),
                                        ],
                                        if (pesanan['keterangan_order'] !=
                                                null &&
                                            pesanan['keterangan_order']
                                                .toString()
                                                .trim()
                                                .isNotEmpty) ...[
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.notes_rounded,
                                                color: Color(0xFF64748B),
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Catatan Pesanan',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: const Color(
                                                          0xFF64748B,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      pesanan['keterangan_order']
                                                          .toString(),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        color: const Color(
                                                          0xFF475569,
                                                        ),
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Tim Cleaner
                          Builder(
                            builder: (context) {
                              final cleanersData = pesanan['cleaners'] as List<dynamic>?;
                              if (cleanersData == null || cleanersData.isEmpty) {
                                return const SizedBox();
                              }

                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.people_alt_rounded,
                                            color: AppColors.primary,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Tim Cleaner (Rekan Kerja)',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    ...cleanersData.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final c = entry.value;
                                      
                                      final cleanerInfo = c['cleaner'] ?? {};
                                      final status = c['status_pengerjaan'] ?? 'assigned';
                                      
                                      Color statusColor = AppColors.statusPending;
                                      String statusText = status.toString().toUpperCase();
                                      
                                      if (status == 'finished') {
                                        statusColor = AppColors.statusDone;
                                        statusText = 'SELESAI';
                                      } else if (status == 'started') {
                                        statusColor = AppColors.statusProgress;
                                        statusText = 'DIPROSES';
                                      } else if (status == 'notified') {
                                        statusColor = AppColors.statusPending;
                                        statusText = 'DIBERITAHU';
                                      } else if (status == 'assigned') {
                                        statusColor = AppColors.statusPending;
                                        statusText = 'MENUNGGU';
                                      }

                                      final bool isMe = c['cleaner_id'] == _job['cleaner_id'];
                                      final String nama = (cleanerInfo['nama'] ?? '-').toString().trim();
                                      final String initial = nama.isNotEmpty ? nama[0].toUpperCase() : '?';

                                      return Column(
                                        children: [
                                          Row(
                                            children: [
                                              // Avatar with gradient
                                              Container(
                                                width: 42,
                                                height: 42,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: isMe
                                                        ? [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)]
                                                        : [const Color(0xFF64748B), const Color(0xFF94A3B8)],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: (isMe ? AppColors.primary : Colors.black).withValues(alpha: 0.15),
                                                      blurRadius: 6,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    initial,
                                                    style: GoogleFonts.inter(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            nama,
                                                            style: GoogleFonts.inter(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppColors.textDark,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        if (isMe)
                                                          Container(
                                                            margin: const EdgeInsets.only(left: 6),
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: AppColors.primary.withValues(alpha: 0.1),
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text(
                                                              'ANDA',
                                                              style: GoogleFonts.inter(
                                                                fontSize: 9,
                                                                fontWeight: FontWeight.w900,
                                                                color: AppColors.primary,
                                                                letterSpacing: 0.5,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.phone_android_rounded,
                                                          size: 12,
                                                          color: AppColors.textMuted,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          cleanerInfo['no_wa'] ?? '-',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 12,
                                                            color: AppColors.textMuted,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: statusColor.withValues(alpha: 0.2),
                                                  ),
                                                ),
                                                child: Text(
                                                  statusText,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: statusColor,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (index < cleanersData.length - 1)
                                            Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              child: Divider(
                                                height: 1,
                                                color: AppColors.border.withValues(alpha: 0.5),
                                              ),
                                            ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              );
                            },
                          ),

                          // Detail Layanan
                          Text(
                            'Layanan Dipesan',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
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
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF0F172A,
                                    ).withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.cleaning_services_rounded,
                                      color: Color(0xFF3B82F6),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l['nama_layanan'] ?? '-',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF1E293B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFFBEB),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            'Qty: ${d['qty'] ?? '-'}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFFD97706),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 12),

                          // Bonus Pro Max
                          if (bonusList.isNotEmpty || totalBonus > 0) ...[
                            Text(
                              'Bonus Anda',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFEF3C7),
                                    Color(0xFFFDE68A),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFFCD34D),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...bonusWidgets,
                                  if (bonusWidgets.isNotEmpty)
                                    const Divider(
                                      color: Color(0xFFF59E0B),
                                      height: 24,
                                    ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Total Bonus',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFB45309),
                                        ),
                                      ),
                                      Text(
                                        _formatRupiah(totalBonus.toInt()),
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF92400E),
                                        ),
                                      ),
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
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: isStartable || isFinishable
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                width: double.infinity,
                child: FloatingActionButton.extended(
                  onPressed: _isLoading
                      ? null
                      : () => _showPhotoPickerSheet(
                          isStartable ? 'start' : 'finish',
                        ),
                  backgroundColor: isStartable
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF10B981),
                  elevation: 6,
                  icon: Icon(
                    isStartable
                        ? Icons.play_arrow_rounded
                        : Icons.check_circle_rounded,
                    color: Colors.white,
                  ),
                  label: Text(
                    isStartable ? 'Mulai Pekerjaan' : 'Selesaikan Pekerjaan',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
              HeaderBackButton(
                onTap: () => Navigator.pop(context, _hasChanged),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detail Tugas',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    orderId,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
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
        bg = AppColors.statusPending.withValues(alpha: 0.1);
        fg = AppColors.statusPending;
        text = 'Siap Dikerjakan';
        icon = Icons.play_circle_outline;
        break;
      case 'in_progress':
        bg = AppColors.statusProgress.withValues(alpha: 0.1);
        fg = AppColors.statusProgress;
        text = 'Sedang Dikerjakan';
        icon = Icons.timelapse;
        break;
      case 'finished':
        bg = AppColors.statusDone.withValues(alpha: 0.1);
        fg = AppColors.statusDone;
        text = 'Selesai';
        icon = Icons.check_circle_outline;
        break;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 28),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const dashWidth = 6.0;
    const dashSpace = 4.0;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(16),
        ),
      );

    final dashPath = Path();
    for (var metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

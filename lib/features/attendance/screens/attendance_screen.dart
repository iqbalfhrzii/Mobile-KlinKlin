import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../attendance/services/attendance_service.dart';
import 'attendance_history_screen.dart';
import '../../attendance/screens/admin_attendance_detail_screen.dart';
import 'camera_screen.dart';
import '../services/mock_location_service.dart';
import '../data/attendance_model.dart';
import '../../profile/screens/leave_request_screen.dart';
import '../../profile/screens/leave_history_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AttendanceService _service = AttendanceService();
  
  bool _isLoading = true;
  bool _isProcessing = false;
  AttendanceStatus? _status;

  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();
  
  Position? _currentPosition;
  bool _isLocating = false;
  
  DateTime _selectedMonth = DateTime.now();
  List<GroupedAttendanceItem> _history = [];

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
    _loadStatus();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    try {
      final status = await _service.getTodayStatus();
      if (mounted) setState(() => _status = status);
      await _fetchLocation();
      await _fetchHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLocation() async {
    setState(() => _isLocating = true);
    try {
      final hasPerms = await _checkPermissions();
      if (!hasPerms) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) setState(() => _currentPosition = position);
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final monthStr = "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}";
      final historyList = await _service.getHistory(month: monthStr);
      
      final grouped = <String, GroupedAttendanceItem>{};
      for (var item in historyList) {
        if (item.tanggal == null) continue;
        final key = item.tanggal!;
        
        if (!grouped.containsKey(key)) {
          grouped[key] = GroupedAttendanceItem(
            tanggal: item.tanggal!,
            karyawanId: item.karyawanId ?? 0,
            namaCleaner: item.namaCleaner ?? 'Anda',
          );
        }
        
        if (item.type == 'check_in' || item.type == 'masuk') {
          grouped[key] = GroupedAttendanceItem(
            tanggal: grouped[key]!.tanggal,
            karyawanId: grouped[key]!.karyawanId,
            namaCleaner: grouped[key]!.namaCleaner,
            checkIn: item,
            checkOut: grouped[key]!.checkOut,
          );
        } else if (item.type == 'check_out' || item.type == 'pulang') {
          grouped[key] = GroupedAttendanceItem(
            tanggal: grouped[key]!.tanggal,
            karyawanId: grouped[key]!.karyawanId,
            namaCleaner: grouped[key]!.namaCleaner,
            checkIn: grouped[key]!.checkIn,
            checkOut: item,
          );
        }
      }
      
      final result = grouped.values.toList();
      result.sort((a, b) => b.tanggal.compareTo(a.tanggal));
      
      if (mounted) setState(() => _history = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Riwayat error: $e')));
      }
    }
  }

  Future<bool> _checkPermissions() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      _showError('Izin kamera ditolak. Silakan izinkan melalui pengaturan.');
      return false;
    }

    final locationStatus = await Permission.location.request();
    if (!locationStatus.isGranted) {
      _showError('Izin lokasi ditolak. Silakan izinkan melalui pengaturan.');
      return false;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      _showError('GPS mati. Silakan nyalakan GPS Anda.');
      return false;
    }

    return true;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _handleAbsensi(bool isCheckIn) async {
    if (_isProcessing) return;

    final hasPerms = await _checkPermissions();
    if (!hasPerms) return;

    setState(() => _isProcessing = true);

    try {
      // Get High Accuracy Location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 10),
      );
      
      if (mounted) setState(() => _currentPosition = position);

      // Check Accuracy
      if (position.accuracy > 100.0) {
        throw Exception('Akurasi GPS terlalu rendah (${position.accuracy.toStringAsFixed(1)}m). Cari area dengan sinyal lebih baik.');
      }

      // Check Mock Location (Fake GPS)
      final isMock = await MockLocationService.isMockLocation(position);
      if (isMock) {
        throw Exception('Lokasi palsu terdeteksi. Matikan aplikasi Fake GPS sebelum melakukan absensi.');
      }

      // Distance checking if branch coordinates exist
      if (_status?.branchLat != null && _status?.branchLng != null) {
        final distance = Geolocator.distanceBetween(
          position.latitude, position.longitude, 
          _status!.branchLat!, _status!.branchLng!
        );
        final maxRadius = _status?.maxRadiusMeter ?? 50.0;
        if (distance > maxRadius) {
          throw Exception('Anda berada di luar radius kantor (${distance.toStringAsFixed(1)}m / ${maxRadius}m).');
        }
      }

      // Open Camera Screen
      final File? photoFile = await Navigator.push<File>(
        context,
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );

      if (photoFile == null) {
        setState(() => _isProcessing = false);
        return; // User cancelled
      }

      // Show confirming dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isCheckIn ? 'Konfirmasi Check-In' : 'Konfirmasi Check-Out'),
          content: const Text('Kirim data absensi sekarang?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false), 
              child: const Text('Batal')
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true), 
              child: const Text('Kirim')
            ),
          ],
        )
      );

      if (confirm != true) {
        setState(() => _isProcessing = false);
        return;
      }

      // Submit API
      await _service.submitAttendance(
        isCheckIn: isCheckIn,
        photoFile: photoFile,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        isMockLocation: isMock,
      );

      _showSuccess(isCheckIn ? 'Check-in berhasil!' : 'Check-out berhasil!');
      await _loadStatus(); // Reload

    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _dayName(int weekday) {
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return days[weekday - 1];
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return months[month - 1];
  }

  Future<void> _selectMonth() async {
    int tempMonth = _selectedMonth.month;
    int tempYear = _selectedMonth.year;
    
    final List<String> monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Pilih Periode', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDark)),
              content: Row(
                children: [
                  Expanded(
                    child: DropdownButton<int>(
                      value: tempMonth,
                      isExpanded: true,
                      items: List.generate(12, (index) {
                        return DropdownMenuItem(
                          value: index + 1,
                          child: Text(monthNames[index], style: GoogleFonts.inter(fontSize: 14)),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) setStateDialog(() => tempMonth = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButton<int>(
                      value: tempYear,
                      isExpanded: true,
                      items: List.generate(5, (index) {
                        int year = DateTime.now().year - 2 + index;
                        return DropdownMenuItem(
                          value: year,
                          child: Text(year.toString(), style: GoogleFonts.inter(fontSize: 14)),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) setStateDialog(() => tempYear = val);
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Batal', style: GoogleFonts.inter(color: Colors.grey.shade600)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (tempMonth != _selectedMonth.month || tempYear != _selectedMonth.year) {
                      setState(() => _selectedMonth = DateTime(tempYear, tempMonth, 1));
                      _fetchHistory();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Terapkan', style: GoogleFonts.inter(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildClockHeader(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadStatus,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildActionButtons(),
                        const SizedBox(height: 16),
                        _buildScheduleCard(),
                        const SizedBox(height: 16),
                        _buildLeaveMenu(),
                        const SizedBox(height: 24),
                        _buildHistoryList(),
                      ],
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveMenu() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveRequestScreen()));
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.event_available_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pengajuan Cuti / Izin', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const SizedBox(height: 4),
                      Text('Ajukan libur atau izin dengan mudah', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClockHeader() {
    final timeStr = "${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}:${_currentTime.second.toString().padLeft(2, '0')}";
    final dateStr = "${_dayName(_currentTime.weekday)}, ${_currentTime.day} ${_monthName(_currentTime.month)} ${_currentTime.year}";
    
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: HeaderBackButton(onTap: () => Navigator.pop(context)),
          ),
          Center(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(timeStr, style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                const SizedBox(height: 4),
                Text(dateStr, style: GoogleFonts.inter(fontSize: 16, color: Colors.white.withValues(alpha: 0.9))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
    String formatTime(String time) {
      if (time.length >= 5) return time.substring(0, 5);
      return time;
    }

    final rawJamMasuk = _status?.jamMasuk ?? '08:00';
    final rawJamPulang = _status?.jamPulang ?? '17:00';
    final toleransiMenit = _status?.toleransiTelatMenit ?? 15;

    final jamMasuk = formatTime(rawJamMasuk);
    final jamPulang = formatTime(rawJamPulang);
    
    String jamTelat = '-';
    try {
      final parts = rawJamMasuk.split(':');
      if (parts.length >= 2) {
        final dt = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
        final telatDt = dt.add(Duration(minutes: toleransiMenit));
        jamTelat = '> ${telatDt.hour.toString().padLeft(2, '0')}:${telatDt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5)
          )
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
                  borderRadius: BorderRadius.circular(12)
                ),
                child: const Icon(Icons.access_time_filled_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Text('Jadwal Absensi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
              const Spacer(),
              _buildRadiusBadge(),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildScheduleItem('Jam Masuk', jamMasuk, Colors.green.shade700, Icons.login_rounded),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(
                child: _buildScheduleItem('Toleransi', jamTelat, Colors.red.shade700, Icons.warning_amber_rounded),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(
                child: _buildScheduleItem('Jam Pulang', jamPulang, Colors.orange.shade700, Icons.logout_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(String label, String time, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
          ]
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12)
          ),
          child: Text(time, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        )
      ],
    );
  }

  Widget _buildRadiusBadge() {
    if (_isLocating) {
      return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_currentPosition == null || _status?.branchLat == null || _status?.branchLng == null) {
      return InkWell(
        onTap: _fetchLocation,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.refresh, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('Cek Lokasi', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
            ]
          )
        )
      );
    }

    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude, _currentPosition!.longitude,
      _status!.branchLat!, _status!.branchLng!
    );
    final isInside = distance <= (_status?.maxRadiusMeter ?? 50.0);

    return InkWell(
      onTap: _fetchLocation,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isInside ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1), 
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isInside ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3))
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isInside ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isInside ? Colors.green : Colors.red,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              isInside ? 'Di Dalam Radius' : 'Di Luar Radius', 
              style: GoogleFonts.inter(color: isInside ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 10)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final bool canCheckIn = _status != null && !_status!.hasCheckedIn;
    final bool canCheckOut = _status != null && _status!.hasCheckedIn && !_status!.hasCheckedOut;

    return Row(
      children: [
        Expanded(
          child: _buildAbsenButton(
            label: 'Check-In',
            time: _status?.checkInTime,
            isEnabled: canCheckIn && !_isProcessing,
            isCheckIn: true,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildAbsenButton(
            label: 'Check-Out',
            time: _status?.checkOutTime,
            isEnabled: canCheckOut && !_isProcessing,
            isCheckIn: false,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildAbsenButton({
    required String label,
    required String? time,
    required bool isEnabled,
    required bool isCheckIn,
    required Color color,
  }) {
    final formattedTime = _formatTime(time ?? '--:--');
    
    final gradient = isEnabled 
      ? LinearGradient(
          colors: isCheckIn 
            ? [const Color(0xFF10B981), const Color(0xFF059669)] 
            : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : LinearGradient(
          colors: [Colors.grey.shade200, Colors.grey.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

    final textColor = isEnabled ? Colors.white : Colors.grey.shade500;
    
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isEnabled ? [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        ] : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? () => _handleAbsensi(isCheckIn) : null,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Icon(
                  isCheckIn ? Icons.login_rounded : Icons.logout_rounded, 
                  color: isEnabled ? Colors.white : Colors.grey.shade400, 
                  size: 32
                ),
                const SizedBox(height: 12),
                Text(
                  label, 
                  style: GoogleFonts.inter(fontSize: 16, color: textColor, fontWeight: FontWeight.w800)
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: isEnabled ? Colors.white.withValues(alpha: 0.25) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    formattedTime, 
                    style: GoogleFonts.inter(
                      fontSize: 13, 
                      fontWeight: FontWeight.w700, 
                      color: isEnabled ? Colors.white : Colors.grey.shade400
                    )
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(String timeStr) {
    if (timeStr == '--:--') return timeStr;
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      if (timeStr.length > 16) return timeStr.substring(11, 16);
      return timeStr;
    }
  }

  String _formatTanggal(String rawDate) {
    try {
      final dt = DateTime.parse(rawDate);
      return '${_dayName(dt.weekday)}, ${dt.day} ${_monthName(dt.month)} ${dt.year}';
    } catch (_) {
      return rawDate;
    }
  }

  Widget _buildHistoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
              Text('Riwayat Aktivitas', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              TextButton.icon(
                 onPressed: _selectMonth,
                 icon: const Icon(Icons.calendar_month, size: 16),
                 label: Text('${_monthName(_selectedMonth.month)} ${_selectedMonth.year}', style: GoogleFonts.inter(fontWeight: FontWeight.w600))
              )
           ]
        ),
        const SizedBox(height: 4),
        Row(
           children: [
             Expanded(
               child: OutlinedButton.icon(
                 onPressed: () {},
                 icon: const Icon(Icons.check_circle_outline, size: 16),
                 label: const Text('Absensi'),
                 style: OutlinedButton.styleFrom(
                   foregroundColor: AppColors.primary,
                   side: const BorderSide(color: AppColors.primary),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                 ),
               ),
             ),
             const SizedBox(width: 8),
             Expanded(
               child: OutlinedButton.icon(
                 onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveHistoryScreen()));
                 },
                 icon: const Icon(Icons.history_rounded, size: 16),
                 label: const Text('Cuti & Izin'),
                 style: OutlinedButton.styleFrom(
                   foregroundColor: Colors.purple,
                   side: const BorderSide(color: Colors.purple),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                 ),
               ),
             ),
           ]
        ),
        const SizedBox(height: 12),
        if (_history.isEmpty)
           Center(
             child: Padding(
               padding: const EdgeInsets.all(32), 
               child: Text('Belum ada riwayat', style: GoogleFonts.inter(color: AppColors.textMuted))
             )
           )
        else
           ..._history.map((group) {
             return Card(
               margin: const EdgeInsets.only(bottom: 12),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               child: InkWell(
                 borderRadius: BorderRadius.circular(12),
                 onTap: () {
                   Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const AttendanceHistoryScreen(),
                  ));
                 },
                 child: Padding(
                   padding: const EdgeInsets.all(16),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text(
                             _formatTanggal(group.tanggal),
                             style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                           ),
                           Icon(Icons.chevron_right, color: Colors.grey.shade400),
                         ],
                       ),
                       const SizedBox(height: 12),
                       Row(
                         children: [
                           Expanded(
                             child: _buildTimeRow(
                               icon: Icons.login_rounded, 
                               color: Colors.green, 
                               label: 'Masuk', 
                               time: group.checkIn?.time ?? '--:--'
                             ),
                           ),
                           Expanded(
                             child: _buildTimeRow(
                               icon: Icons.logout_rounded, 
                               color: Colors.orange, 
                               label: 'Pulang', 
                               time: group.checkOut?.time ?? '--:--'
                             ),
                           ),
                         ],
                       ),
                     ],
                   ),
                 ),
               ),
             );
           }),
      ],
    );
  }

  Widget _buildTimeRow({required IconData icon, required Color color, required String label, required String time}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text('$label: ', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
        Text(time, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

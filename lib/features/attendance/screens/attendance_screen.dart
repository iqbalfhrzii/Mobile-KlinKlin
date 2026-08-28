import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../attendance/services/attendance_service.dart';
import 'camera_screen.dart';
import '../services/mock_location_service.dart';
import '../data/attendance_model.dart';
import '../widgets/attendance_day_detail_sheet.dart';
import '../../profile/screens/leave_request_screen.dart';
import '../../profile/screens/leave_history_screen.dart';
import '../../cleaner/tukar_libur/screens/tukar_libur_screen.dart';

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
  String _activeFilter = 'semua'; // 'semua', 'hadir', 'keluar', 'telat', 'tidak_absen', 'libur_cuti'

  String _userRole = 'Cleaner';

  // Monthly stats matching web ERP
  int _statAbsenMasuk = 0;
  int _statAbsenKeluar = 0;
  int _statTelat = 0;
  int _statTidakAbsen = 0;
  int _statIzinCutiLibur = 0;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
    _loadUserRole();
    _loadStatus();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userRole = prefs.getString('user_role') ?? 'Cleaner';
      });
    }
  }

  bool get _isCleaner => _userRole.toLowerCase().contains('cleaner');

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    try {
      final status = await _service.getTodayStatus();
      if (mounted) setState(() => _status = status);
      await _fetchLocation();
      await _fetchHistory();
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = AttendanceStatus(
            hasCheckedIn: false,
            hasCheckedOut: false,
            branchName: 'Kantor Cabang',
            branchLat: -6.200000,
            branchLng: 106.816666,
            maxRadiusMeter: 50.0,
            jamMasuk: '08:00',
            jamPulang: '17:00',
            toleransiTelatMenit: 15,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLocation() async {
    setState(() => _isLocating = true);
    try {
      final hasPerms = await _checkLocationPermissionOnly();
      if (!hasPerms) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) setState(() => _currentPosition = position);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<bool> _checkLocationPermissionOnly() async {
    final status = await Permission.location.status;
    if (!status.isGranted) {
      final req = await Permission.location.request();
      if (!req.isGranted) return false;
    }
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<void> _fetchHistory() async {
    try {
      final monthStr = "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}";
      
      // Fetch attendance history, approved leaves, and scheduled days off in parallel
      final results = await Future.wait([
        _service.getHistory(month: monthStr),
        _service.getMyLeaves(),
        _service.getMyJadwalLiburs(),
      ]);

      final List<AttendanceHistoryItem> historyList = results[0] as List<AttendanceHistoryItem>;
      final List<Map<String, dynamic>> myLeaves = results[1] as List<Map<String, dynamic>>;
      final List<String> myLiburs = results[2] as List<String>;
      
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
        
        final type = item.type.toLowerCase();
        if (type == 'check_in' || type == 'masuk') {
          grouped[key] = GroupedAttendanceItem(
            tanggal: grouped[key]!.tanggal,
            karyawanId: grouped[key]!.karyawanId,
            namaCleaner: grouped[key]!.namaCleaner,
            checkIn: item,
            checkOut: grouped[key]!.checkOut,
          );
        } else if (type == 'check_out' || type == 'pulang') {
          grouped[key] = GroupedAttendanceItem(
            tanggal: grouped[key]!.tanggal,
            karyawanId: grouped[key]!.karyawanId,
            namaCleaner: grouped[key]!.namaCleaner,
            checkIn: grouped[key]!.checkIn,
            checkOut: item,
          );
        }
      }
      
      // Calculate day-by-day history and stats matching Laravel business logic
      final now = DateTime.now();
      final isCurrentMonth = _selectedMonth.year == now.year && _selectedMonth.month == now.month;
      final int lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
      final int maxDayToEvaluate = isCurrentMonth ? now.day : lastDayOfMonth;

      int masuk = 0;
      int keluar = 0;
      int telat = 0;
      int tidakAbsen = 0;
      int izinCutiLibur = 0;

      final shiftMasuk = _parseTimeOnly(_status?.jamMasuk, fallback: '08:00');
      final toleransi = _status?.toleransiTelatMenit ?? 15;
      final lateBoundary = _calculateLateBoundary(shiftMasuk, toleransi);

      final List<GroupedAttendanceItem> fullList = [];

      for (int day = maxDayToEvaluate; day >= 1; day--) {
        final dStr = "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
        final existing = grouped[dStr];
        final dt = DateTime(_selectedMonth.year, _selectedMonth.month, day);

        if (existing != null && (existing.checkIn != null || existing.checkOut != null)) {
          // --- 1. Karyawan Hadir (Ada Check-in atau Check-out) ---
          String itemStatus = 'Tepat Waktu';
          if (existing.checkIn != null) {
            masuk++;
            final inTime = _parseTimeOnly(existing.checkIn!.time);
            if (_isTimeAfter(inTime, lateBoundary)) {
              telat++;
              itemStatus = 'Telat';
            } else if (existing.checkOut != null) {
              itemStatus = 'Lengkap';
            }
          } else {
            itemStatus = 'Pulang Cepat';
          }

          if (existing.checkOut != null) {
            keluar++;
          }

          fullList.add(GroupedAttendanceItem(
            tanggal: dStr,
            karyawanId: existing.karyawanId,
            namaCleaner: existing.namaCleaner,
            checkIn: existing.checkIn,
            checkOut: existing.checkOut,
            status: itemStatus,
          ));
        } else {
          // --- 2. Karyawan Tidak Melakukan Absensi pada Tanggal Ini ---
          // Periksa apakah ada Cuti / Izin yang disetujui
          Map<String, dynamic>? matchingLeave;
          for (var l in myLeaves) {
            final status = (l['status'] ?? '').toString().toLowerCase();
            final start = (l['tanggal_mulai'] ?? '').toString();
            final end = (l['tanggal_selesai'] ?? '').toString();
            if ((status == 'disetujui' || status == 'approved' || status == 'diterima') &&
                start.isNotEmpty && end.isNotEmpty &&
                dStr.compareTo(start) >= 0 && dStr.compareTo(end) <= 0) {
              matchingLeave = l;
              break;
            }
          }

          if (matchingLeave != null) {
            // Memiliki izin/cuti resmi -> TIDAK dihitung sebagai "Tidak Absen"!
            izinCutiLibur++;
            final jenis = (matchingLeave['jenis_pengajuan'] ?? matchingLeave['jenis'] ?? 'Cuti').toString();
            final jenisCapital = jenis.isNotEmpty 
                ? (jenis[0].toUpperCase() + jenis.substring(1).toLowerCase()) 
                : 'Cuti';
            fullList.add(GroupedAttendanceItem(
              tanggal: dStr,
              karyawanId: 0,
              namaCleaner: 'Anda',
              status: jenisCapital,
            ));
          } else if (myLiburs.contains(dStr)) {
            // Memiliki jadwal libur resmi (JadwalLibur) -> TIDAK dihitung sebagai "Tidak Absen"!
            izinCutiLibur++;
            fullList.add(GroupedAttendanceItem(
              tanggal: dStr,
              karyawanId: 0,
              namaCleaner: 'Anda',
              status: 'Libur',
            ));
          } else if (dt.weekday == DateTime.sunday) {
            // Hari Minggu (Libur Mingguan) -> TIDAK dihitung sebagai "Tidak Absen"!
            izinCutiLibur++;
            fullList.add(GroupedAttendanceItem(
              tanggal: dStr,
              karyawanId: 0,
              namaCleaner: 'Anda',
              status: 'Libur Mingguan',
            ));
          } else {
            // Hari kerja aktif yang terlewat tanpa izin/libur -> DIHITUNG SEBAGAI TIDAK ABSEN!
            tidakAbsen++;
            fullList.add(GroupedAttendanceItem(
              tanggal: dStr,
              karyawanId: 0,
              namaCleaner: 'Anda',
              status: 'Tidak Absen',
            ));
          }
        }
      }

      if (mounted) {
        setState(() {
          _history = fullList;
          _statAbsenMasuk = masuk;
          _statAbsenKeluar = keluar;
          _statTelat = telat;
          _statTidakAbsen = tidakAbsen;
          _statIzinCutiLibur = izinCutiLibur;
        });
      }
    } catch (_) {
      // Keep state resilient
    }
  }

  bool _isTimeAfter(String timeA, String timeB) {
    try {
      final pA = timeA.split(':');
      final pB = timeB.split(':');
      if (pA.length >= 2 && pB.length >= 2) {
        final minA = (int.tryParse(pA[0]) ?? 0) * 60 + (int.tryParse(pA[1]) ?? 0);
        final minB = (int.tryParse(pB[0]) ?? 0) * 60 + (int.tryParse(pB[1]) ?? 0);
        return minA > minB;
      }
    } catch (_) {}
    return false;
  }

  String _parseTimeOnly(String? raw, {String fallback = '--:--'}) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final str = raw.trim();

    // 1. If it contains 'T' (e.g. "2026-08-23T08:00:00.000000Z"), extract time part after 'T'
    if (str.contains('T')) {
      final timePart = str.split('T')[1];
      final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(timePart);
      if (match != null) {
        final h = match.group(1)!.padLeft(2, '0');
        final m = match.group(2)!;
        return '$h:$m';
      }
    }

    // 2. If it contains date and space (e.g. "2026-08-23 08:00:00"), extract time part after space
    if (str.contains(' ')) {
      final parts = str.split(' ');
      if (parts.length >= 2) {
        final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(parts[1]);
        if (match != null) {
          final h = match.group(1)!.padLeft(2, '0');
          final m = match.group(2)!;
          return '$h:$m';
        }
      }
    }

    // 3. Simple time format (e.g. "08:00:00" or "08:00")
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(str);
    if (match != null) {
      final h = match.group(1)!.padLeft(2, '0');
      final m = match.group(2)!;
      return '$h:$m';
    }

    return str.length >= 5 ? str.substring(0, 5) : str;
  }

  String _calculateLateBoundary(String rawJamMasuk, int toleransiMenit) {
    final parsed = _parseTimeOnly(rawJamMasuk, fallback: '08:00');
    final parts = parsed.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 8;
      final m = int.tryParse(parts[1]) ?? 0;
      final dt = DateTime(2000, 1, 1, h, m).add(Duration(minutes: toleransiMenit));
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '08:15';
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
    SnackbarUtils.showError(context, message);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    SnackbarUtils.showSuccess(context, message);
  }

  Future<void> _handleAbsensi(bool isCheckIn) async {
    if (_isProcessing) return;

    final hasPerms = await _checkPermissions();
    if (!hasPerms) return;

    setState(() => _isProcessing = true);

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 10),
      );
      
      if (mounted) setState(() => _currentPosition = position);

      if (position.accuracy > 100.0) {
        throw Exception('Akurasi GPS terlalu rendah (${position.accuracy.toStringAsFixed(1)}m). Cari area dengan sinyal lebih baik.');
      }

      final isMock = await MockLocationService.isMockLocation(position);
      if (isMock) {
        throw Exception('Lokasi palsu terdeteksi. Matikan aplikasi Fake GPS sebelum melakukan absensi.');
      }

      if (_status?.branchLat != null && _status?.branchLng != null) {
        final distance = Geolocator.distanceBetween(
          position.latitude, position.longitude, 
          _status!.branchLat!, _status!.branchLng!
        );
        final maxRadius = _status?.maxRadiusMeter ?? 50.0;
        if (distance > maxRadius) {
          throw Exception('Anda berada di luar radius kantor (${distance.toStringAsFixed(1)}m / ${maxRadius.toStringAsFixed(0)}m).');
        }
      }

      final File? photoFile = await Navigator.push<File>(
        context,
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );

      if (photoFile == null) {
        setState(() => _isProcessing = false);
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isCheckIn ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                  color: isCheckIn ? const Color(0xFF059669) : const Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isCheckIn ? 'Konfirmasi Masuk' : 'Konfirmasi Pulang',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin mengirim data ${isCheckIn ? "Check-In" : "Check-Out"} sekarang?',
            style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textDark),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false), 
              child: Text('Batal', style: GoogleFonts.inter(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCheckIn ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text('Kirim Absen', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirm != true) {
        setState(() => _isProcessing = false);
        return;
      }

      await _service.submitAttendance(
        isCheckIn: isCheckIn,
        photoFile: photoFile,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        isMockLocation: isMock,
      );

      _showSuccess(isCheckIn ? 'Check-in berhasil disimpan!' : 'Check-out berhasil disimpan!');
      await _loadStatus();

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

  String _dayShort(int weekday) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return days[weekday - 1];
  }

  String _monthName(int month) {
    const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return months[month - 1];
  }

  String _monthShort(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return months[month - 1];
  }

  Future<void> _selectMonth() async {
    int tempMonth = _selectedMonth.month;
    int tempYear = _selectedMonth.year;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Pilih Periode', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
              content: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: tempMonth,
                      decoration: InputDecoration(
                        labelText: 'Bulan',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: List.generate(12, (index) {
                        return DropdownMenuItem(
                          value: index + 1,
                          child: Text(_monthShort(index + 1), style: GoogleFonts.inter(fontSize: 13)),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) setStateDialog(() => tempMonth = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: tempYear,
                      decoration: InputDecoration(
                        labelText: 'Tahun',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: List.generate(5, (index) {
                        int year = DateTime.now().year - 2 + index;
                        return DropdownMenuItem(
                          value: year,
                          child: Text(year.toString(), style: GoogleFonts.inter(fontSize: 13)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text('Terapkan', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _stepMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    });
    _fetchHistory();
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
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildActionCards(),
                        const SizedBox(height: 14),
                        _buildScheduleAndLocationCard(),
                        const SizedBox(height: 14),
                        _buildMenuPintasan(),
                        const SizedBox(height: 18),
                        _buildRiwayatSection(),
                      ],
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  // --- 1. HEADER DIGITAL CLOCK ---
  Widget _buildClockHeader() {
    final timeStr = "${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}:${_currentTime.second.toString().padLeft(2, '0')}";
    final dateStr = "${_dayName(_currentTime.weekday)}, ${_currentTime.day} ${_monthName(_currentTime.month)} ${_currentTime.year}";
    final branchName = _status?.branchName ?? 'Kantor Cabang';

    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Stack(
        children: [
          if (Navigator.canPop(context))
            Align(
              alignment: Alignment.topLeft,
              child: HeaderBackButton(onTap: () => Navigator.pop(context)),
            ),
          Center(
            child: Column(
              children: [
                const SizedBox(height: 4),
                // Branch pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, color: Colors.white, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        branchName,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Clock
                Text(
                  timeStr,
                  style: GoogleFonts.inter(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 4),
                // Date
                Text(
                  dateStr,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. CHECK-IN / CHECK-OUT ACTION CARDS ---
  Widget _buildActionCards() {
    final bool hasCheckedIn = _status?.hasCheckedIn == true;
    final bool hasCheckedOut = _status?.hasCheckedOut == true;
    final bool canCheckIn = !hasCheckedIn;
    final bool canCheckOut = hasCheckedIn && !hasCheckedOut;

    final inTimeFormatted = _parseTimeOnly(_status?.checkInTime);
    final outTimeFormatted = _parseTimeOnly(_status?.checkOutTime);

    return Row(
      children: [
        // Check-In Card
        Expanded(
          child: _buildSingleActionCard(
            label: hasCheckedIn ? 'Sudah Check-In' : 'Check-In',
            sublabel: hasCheckedIn ? '$inTimeFormatted WIB' : 'Absen Masuk',
            timePill: hasCheckedIn ? inTimeFormatted : null,
            icon: hasCheckedIn ? Icons.check_circle_rounded : Icons.login_rounded,
            isCompleted: hasCheckedIn,
            isActive: canCheckIn && !_isProcessing,
            primaryColor: const Color(0xFF10B981),
            activeGradient: const [Color(0xFF10B981), Color(0xFF059669)],
            onTap: (canCheckIn && !_isProcessing) ? () => _handleAbsensi(true) : null,
          ),
        ),
        const SizedBox(width: 12),
        // Check-Out Card
        Expanded(
          child: _buildSingleActionCard(
            label: hasCheckedOut ? 'Sudah Check-Out' : 'Check-Out',
            sublabel: hasCheckedOut
                ? '$outTimeFormatted WIB'
                : (hasCheckedIn ? 'Absen Pulang' : 'Belum Masuk'),
            timePill: hasCheckedOut ? outTimeFormatted : null,
            icon: hasCheckedOut ? Icons.check_circle_rounded : Icons.logout_rounded,
            isCompleted: hasCheckedOut,
            isActive: canCheckOut && !_isProcessing,
            primaryColor: const Color(0xFFF59E0B),
            activeGradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
            onTap: (canCheckOut && !_isProcessing) ? () => _handleAbsensi(false) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSingleActionCard({
    required String label,
    required String sublabel,
    required String? timePill,
    required IconData icon,
    required bool isCompleted,
    required bool isActive,
    required Color primaryColor,
    required List<Color> activeGradient,
    VoidCallback? onTap,
  }) {
    Decoration decoration;
    Color textColor;
    Color iconColor;

    if (isActive) {
      decoration = BoxDecoration(
        gradient: LinearGradient(
          colors: activeGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.32),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      );
      textColor = Colors.white;
      iconColor = Colors.white;
    } else if (isCompleted) {
      decoration = BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: primaryColor.withValues(alpha: 0.35), width: 1.5),
      );
      textColor = primaryColor;
      iconColor = primaryColor;
    } else {
      decoration = BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      );
      textColor = const Color(0xFF94A3B8);
      iconColor = const Color(0xFFCBD5E1);
    }

    return Container(
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isActive 
                        ? Colors.white.withValues(alpha: 0.2) 
                        : (isCompleted ? primaryColor.withValues(alpha: 0.12) : const Color(0xFFE2E8F0)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (timePill != null)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$timePill WIB',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  )
                else
                  Text(
                    sublabel,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isActive ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 3. JADWAL & LOKASI CARD ---
  Widget _buildScheduleAndLocationCard() {
    final rawJamMasuk = _status?.jamMasuk;
    final rawJamPulang = _status?.jamPulang;
    final toleransiMenit = _status?.toleransiTelatMenit ?? 15;

    final jamMasuk = _parseTimeOnly(rawJamMasuk, fallback: '08:00');
    final jamPulang = _parseTimeOnly(rawJamPulang, fallback: '17:00');
    final batasTelat = _calculateLateBoundary(jamMasuk, toleransiMenit);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.access_time_filled_rounded, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Jadwal Absensi',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
              _buildRadiusBadge(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSchedulePillar(
                  label: 'Jam Masuk',
                  time: '$jamMasuk WIB',
                  icon: Icons.login_rounded,
                  color: const Color(0xFF059669),
                  bgColor: const Color(0xFFECFDF5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSchedulePillar(
                  label: 'Toleransi',
                  time: '< $batasTelat',
                  icon: Icons.timer_outlined,
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFFFBEB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSchedulePillar(
                  label: 'Jam Pulang',
                  time: '$jamPulang WIB',
                  icon: Icons.logout_rounded,
                  color: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEF2F2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulePillar({
    required String label,
    required String time,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusBadge() {
    if (_isLocating) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 6),
            Text('GPS...', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted)),
          ],
        ),
      );
    }

    if (_currentPosition == null || _status?.branchLat == null || _status?.branchLng == null) {
      return InkWell(
        onTap: _fetchLocation,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh_rounded, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('Cek Lokasi', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude, _currentPosition!.longitude,
      _status!.branchLat!, _status!.branchLng!
    );
    final maxRadius = _status?.maxRadiusMeter ?? 50.0;
    final isInside = distance <= maxRadius;

    return InkWell(
      onTap: _fetchLocation,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isInside ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isInside ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isInside ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isInside ? const Color(0xFF059669) : const Color(0xFFDC2626),
              size: 13,
            ),
            const SizedBox(width: 4),
            Text(
              isInside ? 'Dalam Radius (${distance.toStringAsFixed(0)}m)' : 'Luar Radius (${distance.toStringAsFixed(0)}m)',
              style: GoogleFonts.inter(
                color: isInside ? const Color(0xFF059669) : const Color(0xFFDC2626),
                fontWeight: FontWeight.bold,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. MENU PINTASAN ---
  Widget _buildMenuPintasan() {
    return Column(
      children: [
        _buildMenuCard(
          title: 'Pengajuan Cuti / Izin',
          subtitle: 'Ajukan permohonan libur atau izin kerja',
          icon: Icons.event_available_rounded,
          iconColor: const Color(0xFF2563EB),
          bgColor: const Color(0xFFEFF6FF),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveRequestScreen())),
        ),
        const SizedBox(height: 10),
        if (_isCleaner)
          _buildMenuCard(
            title: 'Tukar Libur',
            subtitle: 'Tukar jadwal hari libur dengan sesama cleaner',
            icon: Icons.event_repeat_rounded,
            iconColor: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF5F3FF),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TukarLiburScreen())),
          )
        else
          _buildMenuCard(
            title: 'Riwayat Cuti & Izin',
            subtitle: 'Lihat status persetujuan cuti dan izin Anda',
            icon: Icons.history_edu_rounded,
            iconColor: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF5F3FF),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveHistoryScreen())),
          ),
      ],
    );
  }

  Widget _buildMenuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 5. 5 STAT CARDS (FITTED & INTERACTIVE AS FILTERS) ---
  Widget _buildSummaryCards() {
    return Column(
      children: [
        // Baris 1: 3 Kartu (Absen Masuk, Absen Keluar, Telat)
        Row(
          children: [
            Expanded(
              child: _buildStatCardItem(
                filterKey: 'hadir',
                label: 'Absen Masuk',
                value: '$_statAbsenMasuk',
                icon: Icons.login_rounded,
                iconColor: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
                valueColor: AppColors.textDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCardItem(
                filterKey: 'keluar',
                label: 'Absen Keluar',
                value: '$_statAbsenKeluar',
                icon: Icons.logout_rounded,
                iconColor: const Color(0xFF0284C7),
                bgColor: const Color(0xFFE0F2FE),
                valueColor: AppColors.textDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCardItem(
                filterKey: 'telat',
                label: 'Telat',
                value: '$_statTelat',
                icon: Icons.access_time_rounded,
                iconColor: const Color(0xFFEA580C),
                bgColor: const Color(0xFFFFF7ED),
                valueColor: const Color(0xFFEA580C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Baris 2: 2 Kartu (Tidak Absen, Izin/Cuti/Libur)
        Row(
          children: [
            Expanded(
              child: _buildStatCardItem(
                filterKey: 'tidak_absen',
                label: 'Tidak Absen',
                value: '$_statTidakAbsen',
                icon: Icons.cancel_outlined,
                iconColor: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEF2F2),
                valueColor: const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCardItem(
                filterKey: 'libur_cuti',
                label: 'Izin/Cuti/Libur',
                value: '$_statIzinCutiLibur',
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFF5F3FF),
                valueColor: const Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCardItem({
    required String filterKey,
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color valueColor,
  }) {
    final isSelected = _activeFilter == filterKey;

    return InkWell(
      onTap: () {
        setState(() {
          _activeFilter = isSelected ? 'semua' : filterKey;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? bgColor.withValues(alpha: 0.85) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? iconColor : AppColors.border,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [AppColors.cardShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? iconColor : AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 12, color: iconColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: valueColor,
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Aktif',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- 6. RIWAYAT SECTION ---
  Widget _buildRiwayatSection() {
    // Apply Filter
    final filteredHistory = _history.where((group) {
      final s = (group.status ?? '').toLowerCase();
      if (_activeFilter == 'hadir') {
        return group.checkIn != null;
      } else if (_activeFilter == 'keluar') {
        return group.checkOut != null;
      } else if (_activeFilter == 'telat') {
        return s == 'telat';
      } else if (_activeFilter == 'tidak_absen') {
        return s == 'tidak absen';
      } else if (_activeFilter == 'libur_cuti') {
        return s.contains('libur') || s.contains('cuti') || s.contains('izin');
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Month Navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Riwayat Kehadiran',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _stepMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    color: AppColors.textDark,
                  ),
                  InkWell(
                    onTap: _selectMonth,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        '${_monthShort(_selectedMonth.month)} ${_selectedMonth.year}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _stepMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    color: AppColors.textDark,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // The 5 Stat Cards (Fitted directly without scrolling)
        _buildSummaryCards(),
        const SizedBox(height: 14),

        // Filter Header with Dropdown & Active Indicator
        _buildFilterHeaderRow(),
        const SizedBox(height: 8),

        // History List
        if (filteredHistory.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 36, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text(
                    'Belum ada data untuk filter ini.',
                    style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredHistory.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final group = filteredHistory[index];
              return _buildHistoryCard(group);
            },
          ),
      ],
    );
  }

  Widget _buildFilterHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'Daftar Riwayat',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            if (_activeFilter != 'semua') ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _activeFilter = 'semua'),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.close_rounded, size: 12, color: Color(0xFFDC2626)),
                      const SizedBox(width: 3),
                      Text(
                        'Reset Filter',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        // Filter Dropdown Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: _activeFilter != 'semua' ? const Color(0xFFEFF6FF) : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _activeFilter != 'semua' ? const Color(0xFF2563EB) : AppColors.border,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _activeFilter,
              isDense: true,
              icon: Icon(
                Icons.filter_list_rounded,
                size: 16,
                color: _activeFilter != 'semua' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _activeFilter != 'semua' ? const Color(0xFF2563EB) : AppColors.textDark,
              ),
              items: [
                DropdownMenuItem(value: 'semua', child: Text('Semua (${_history.length})')),
                DropdownMenuItem(value: 'hadir', child: Text('Absen Masuk ($_statAbsenMasuk)')),
                DropdownMenuItem(value: 'keluar', child: Text('Absen Keluar ($_statAbsenKeluar)')),
                DropdownMenuItem(value: 'telat', child: Text('Telat ($_statTelat)')),
                DropdownMenuItem(value: 'tidak_absen', child: Text('Tidak Absen ($_statTidakAbsen)')),
                DropdownMenuItem(value: 'libur_cuti', child: Text('Izin/Cuti/Libur ($_statIzinCutiLibur)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _activeFilter = val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(GroupedAttendanceItem group) {
    DateTime? dt;
    try {
      dt = DateTime.parse(group.tanggal);
    } catch (_) {}

    final dayNum = dt != null ? '${dt.day}' : '--';
    final dayStr = dt != null ? _dayShort(dt.weekday) : '';
    final fullDate = dt != null ? '${_dayName(dt.weekday)}, ${dt.day} ${_monthName(dt.month)} ${dt.year}' : group.tanggal;

    final inTime = _parseTimeOnly(group.checkIn?.time);
    final outTime = _parseTimeOnly(group.checkOut?.time);

    final status = group.status ?? 'Tepat Waktu';
    final bool isAbsent = status == 'Tidak Absen';
    final bool isHolidayOrLeave = status.contains('Libur') || status.contains('Cuti') || status.contains('Izin');

    Color dateBgColor = const Color(0xFFF1F5F9);
    Color dateTextColor = AppColors.textDark;
    Border? customBorder;

    if (isAbsent) {
      dateBgColor = const Color(0xFFFEF2F2);
      dateTextColor = const Color(0xFFDC2626);
      customBorder = Border.all(color: const Color(0xFFFCA5A5), width: 1.2);
    } else if (isHolidayOrLeave) {
      dateBgColor = const Color(0xFFF5F3FF);
      dateTextColor = const Color(0xFF7C3AED);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: customBorder ?? Border.all(color: AppColors.border),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetailBottomSheet(group),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Date pill
                Container(
                  width: 44,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: dateBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        dayNum,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: dateTextColor,
                        ),
                      ),
                      Text(
                        dayStr,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isAbsent ? const Color(0xFFDC2626) : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Content / Times
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullDate,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (isAbsent)
                        Text(
                          'Tidak ada catatan kehadiran',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFFDC2626),
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else if (isHolidayOrLeave)
                        Text(
                          status.contains('Libur') ? 'Jadwal hari libur kerja' : 'Izin / Cuti disetujui',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF7C3AED),
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        Row(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.login_rounded, size: 13, color: Color(0xFF059669)),
                                const SizedBox(width: 3),
                                Text(
                                  inTime != '--:--' ? '$inTime WIB' : '--:--',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: inTime != '--:--' ? const Color(0xFF059669) : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                const Icon(Icons.logout_rounded, size: 13, color: Color(0xFFD97706)),
                                const SizedBox(width: 3),
                                Text(
                                  outTime != '--:--' ? '$outTime WIB' : '--:--',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: outTime != '--:--' ? const Color(0xFFD97706) : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Status Badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _renderStatusPill(status),
                    const SizedBox(height: 4),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _renderStatusPill(String status) {
    if (status == 'Tidak Absen') {
      return _buildStatusPill('Tidak Absen', const Color(0xFFDC2626), const Color(0xFFFEF2F2));
    } else if (status.contains('Libur')) {
      return _buildStatusPill(status, const Color(0xFF2563EB), const Color(0xFFEFF6FF));
    } else if (status.contains('Cuti') || status.contains('Izin')) {
      return _buildStatusPill(status, const Color(0xFF7C3AED), const Color(0xFFF5F3FF));
    } else if (status == 'Telat') {
      return _buildStatusPill('Telat', const Color(0xFFEA580C), const Color(0xFFFFF7ED));
    } else if (status == 'Lengkap') {
      return _buildStatusPill('Lengkap', const Color(0xFF059669), const Color(0xFFECFDF5));
    }
    return _buildStatusPill('Tepat Waktu', const Color(0xFF059669), const Color(0xFFECFDF5));
  }

  Widget _buildStatusPill(String label, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // --- DETAIL BOTTOM SHEET ---
  void _showDetailBottomSheet(GroupedAttendanceItem group) {
    DateTime? dt;
    try {
      dt = DateTime.parse(group.tanggal);
    } catch (_) {}

    AttendanceDayDetailSheet.show(
      context,
      employeeName: group.namaCleaner.isNotEmpty && group.namaCleaner != 'Anda' ? group.namaCleaner : 'Saya',
      jabatanName: _userRole,
      cabangName: _status?.branchName,
      date: dt,
      dateStr: group.tanggal,
      status: group.status ?? 'Tepat Waktu',
      checkIn: group.checkIn,
      checkOut: group.checkOut,
    );
  }
}

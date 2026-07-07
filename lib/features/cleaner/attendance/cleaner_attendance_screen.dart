import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../attendance/data/attendance_model.dart';
import '../../attendance/services/attendance_service.dart';
import '../../attendance/services/mock_location_service.dart';
import 'camera_screen.dart';

class CleanerAttendanceScreen extends StatefulWidget {
  const CleanerAttendanceScreen({super.key});

  @override
  State<CleanerAttendanceScreen> createState() => _CleanerAttendanceScreenState();
}

class _CleanerAttendanceScreenState extends State<CleanerAttendanceScreen> {
  final AttendanceService _service = AttendanceService();
  
  bool _isLoading = true;
  bool _isProcessing = false;
  AttendanceStatus? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    try {
      final status = await _service.getTodayStatus();
      setState(() => _status = status);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
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

      // Check Accuracy
      if (position.accuracy > 30.0) {
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Absensi', style: GoogleFonts.inter(
                        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white,
                      )),
                      const SizedBox(height: 4),
                      Text('Catat kehadiran harianmu', style: GoogleFonts.inter(
                        fontSize: 13, color: Colors.white.withOpacity(0.8),
                      )),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 24),
                ),
              ],
            ),
          ),
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
                        _buildStatusCard(),
                        const SizedBox(height: 24),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Cabang: ${_status?.branchName ?? '-'}',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTimeColumn('Check-In', _formatTime(_status?.checkInTime ?? '--:--')),
              _buildTimeColumn('Check-Out', _formatTime(_status?.checkOutTime ?? '--:--')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeColumn(String label, String time) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(color: AppColors.textMuted)),
        const SizedBox(height: 8),
        Text(time, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
      ],
    );
  }

  String _formatTime(String timeStr) {
    if (timeStr == '--:--') return timeStr;
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      // Fallback: Just get the HH:mm from raw string if parsing fails
      if (timeStr.length > 16) {
        return timeStr.substring(11, 16);
      }
      return timeStr;
    }
  }

  Widget _buildActionButtons() {
    final bool canCheckIn = _status != null && !_status!.hasCheckedIn;
    final bool canCheckOut = _status != null && _status!.hasCheckedIn && !_status!.hasCheckedOut;

    return Column(
      children: [
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: CircularProgressIndicator(),
          ),
        ElevatedButton(
          onPressed: (canCheckIn && !_isProcessing) ? () => _handleAbsensi(true) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            disabledBackgroundColor: Colors.grey.shade300,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: const Size(double.infinity, 50),
          ),
          child: Text('Check-In', style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: (canCheckOut && !_isProcessing) ? () => _handleAbsensi(false) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            disabledBackgroundColor: Colors.grey.shade300,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: const Size(double.infinity, 50),
          ),
          child: Text('Check-Out', style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

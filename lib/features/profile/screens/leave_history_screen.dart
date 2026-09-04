import 'package:flutter/material.dart';
import 'leave_request_screen.dart';

/// Screen wrapper untuk kompatibilitas riwayat cuti.
/// Sekarang pengajuan cuti dan riwayat cuti telah digabungkan menjadi satu halaman
/// dengan filter tab kanan-kiri. Halaman ini langsung mengarahkan ke tab Riwayat (index 1).
class LeaveHistoryScreen extends StatelessWidget {
  const LeaveHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LeaveRequestScreen(initialTabIndex: 1);
  }
}

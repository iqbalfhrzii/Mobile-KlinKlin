import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../../core/theme/app_colors.dart';
import '../data/attendance_model.dart';
import '../services/attendance_service.dart';
import 'admin_attendance_detail_screen.dart';

class AdminAttendanceListScreen extends StatefulWidget {
  const AdminAttendanceListScreen({super.key});

  @override
  State<AdminAttendanceListScreen> createState() => _AdminAttendanceListScreenState();
}

class _AdminAttendanceListScreenState extends State<AdminAttendanceListScreen> {
  final AttendanceService _service = AttendanceService();
  bool _isLoading = true;
  List<GroupedAttendanceItem> _groupedItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final items = await _service.getAllAbsensi();
      final grouped = <String, GroupedAttendanceItem>{};
      
      for (var item in items) {
        if (item.karyawanId == null || item.tanggal == null) continue;
        
        final key = '${item.karyawanId}_${item.tanggal}';
        
        if (!grouped.containsKey(key)) {
          grouped[key] = GroupedAttendanceItem(
            tanggal: item.tanggal!,
            karyawanId: item.karyawanId!,
            namaCleaner: item.namaCleaner ?? 'Cleaner Tanpa Nama',
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
      
      final groupedList = grouped.values.toList();
      groupedList.sort((a, b) => b.tanggal.compareTo(a.tanggal));
      
      setState(() => _groupedItems = groupedList);
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
                      Text('Daftar Absensi', style: GoogleFonts.inter(
                        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white,
                      )),
                      const SizedBox(height: 4),
                      Text('Pantau riwayat kehadiran karyawan', style: GoogleFonts.inter(
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
                  child: const Icon(Icons.history_rounded, color: Colors.white, size: 24),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: _groupedItems.isEmpty
                        ? ListView(
                            children: const [
                              Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Center(child: Text('Belum ada data absensi.')),
                              )
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _groupedItems.length,
                            itemBuilder: (context, index) {
                              final group = _groupedItems[index];
                              
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => AdminAttendanceDetailScreen(item: group)),
                                  );
                                },
                                child: Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: AppColors.primaryLight,
                                          radius: 24,
                                          child: Text(
                                            group.namaCleaner.substring(0, 1).toUpperCase(),
                                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primary),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                group.namaCleaner,
                                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                group.tanggal,
                                                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  _buildTimeChip('Masuk', group.checkIn?.time, Colors.green),
                                                  const SizedBox(width: 8),
                                                  _buildTimeChip('Pulang', group.checkOut?.time, Colors.orange),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String label, String? time, Color color) {
    final bool hasData = time != null && time.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasData ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: hasData ? color.withOpacity(0.5) : Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(label == 'Masuk' ? Icons.login : Icons.logout, size: 12, color: hasData ? color : Colors.grey),
          const SizedBox(width: 4),
          Text(
            hasData ? time.split(' ').last : '--:--', 
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: hasData ? color : Colors.grey),
          ),
        ],
      ),
    );
  }
}

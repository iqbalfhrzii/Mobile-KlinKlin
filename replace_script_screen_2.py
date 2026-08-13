import re

path = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\attendance\screens\admin_attendance_detail_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace _monthlyHistory type
content = content.replace('List<AttendanceHistoryItem> _monthlyHistory = [];', 'List<dynamic> _monthlyHistory = [];')

# Replace _loadStats function entirely
new_load_stats = """
  Future<void> _loadStats() async {
    try {
      final date = DateTime.parse(widget.item.tanggal);
      final currentMonth = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      
      final data = await AttendanceService().getDetailBulanan(
        karyawanId: widget.item.karyawanId,
        month: currentMonth,
      );
      
      if (data.isNotEmpty && data['stats'] != null) {
        final stats = data['stats'];
        final riwayatList = data['riwayat'] as List<dynamic>? ?? [];
        
        if (mounted) {
          setState(() {
            _tepatWaktu = stats['tepatWaktu'] ?? 0;
            _telat = stats['telat'] ?? 0;
            _plgCepat = stats['pulangCepat'] ?? 0;
            _tdkAbsen = stats['tidakAbsen'] ?? 0;
            _monthlyHistory = riwayatList;
            _isLoadingStats = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingStats = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }
"""
content = re.sub(r'  Future<void> _loadStats\(\) async \{.*?\n  Widget _buildStatBox', new_load_stats + '\n  Widget _buildStatBox', content, flags=re.DOTALL)

# Replace the history item builder since now it's a map not an object
history_item_builder = """
      itemBuilder: (context, index) {
        final item = _monthlyHistory[index];
        final bool isMasuk = true; // API returns grouped data, we can just display it simply. Wait, the detailBulanan returns per day.
        final jamMasuk = item['jam_masuk'];
        final jamKeluar = item['jam_keluar'];
        final status = item['status'] ?? 'Tidak Absen';
        
        String timeDisplay = 'Tidak absen';
        if (jamMasuk != null && jamKeluar != null) {
            timeDisplay = '$jamMasuk - $jamKeluar';
        } else if (jamMasuk != null) {
            timeDisplay = '$jamMasuk - ?';
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: status == 'Tidak Absen' ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              status == 'Tidak Absen' ? Icons.event_busy_rounded : Icons.calendar_today_rounded,
              size: 18,
              color: status == 'Tidak Absen' ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
            ),
          ),
          title: Text(
            item['tanggal'] != null ? _formatIndonesianDate(item['tanggal']) : 'Tanggal tidak diketahui',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Jam: $timeDisplay',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
          ),
        );
      },
"""
content = re.sub(r'      itemBuilder: \(context, index\) \{.*?\n      \},', history_item_builder, content, flags=re.DOTALL)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated screen to use API")

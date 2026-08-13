import re

path = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\attendance\screens\admin_attendance_detail_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

history_list_widget = """
  Widget _buildMonthlyHistory() {
    if (_isLoadingStats) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(),
      ));
    }
    if (_monthlyHistory.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('Belum ada riwayat bulan ini.', style: GoogleFonts.inter(color: AppColors.textMuted)),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _monthlyHistory.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _monthlyHistory[index];
        final bool isMasuk = item.type == 'check_in' || item.type == 'masuk';
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isMasuk ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isMasuk ? Icons.login_rounded : Icons.logout_rounded,
              size: 18,
              color: isMasuk ? const Color(0xFF2E7D32) : const Color(0xFF1565C0),
            ),
          ),
          title: Text(
            item.tanggal != null ? _formatIndonesianDate(item.tanggal!) : 'Tanggal tidak diketahui',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Jam: ${item.time}',
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
              item.status,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
          ),
        );
      },
    );
  }
"""

if '_buildMonthlyHistory' not in content:
    content = content.replace('  Widget _buildDetailField', history_list_widget + '\n  Widget _buildDetailField')

ui_insertion_2 = """
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        'Riwayat Absen Bulan Ini',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!_isLoadingStats)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                          child: Text('${_monthlyHistory.length} log', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildMonthlyHistory(),
"""

if 'Riwayat Absen Bulan Ini' not in content:
    # We will insert it at the end of the SingleChildScrollView
    # Specifically, after the Absensi Keluar Card
    # Let's find the Absensi Keluar Card
    
    target_pattern = r"emptyMessage: 'Cleaner belum melakukan absen keluar pada tanggal ini\.',\s*\),"
    replacement = "emptyMessage: 'Cleaner belum melakukan absen keluar pada tanggal ini.',\n                  ),\n" + ui_insertion_2
    
    content = re.sub(target_pattern, replacement, content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated history list!")

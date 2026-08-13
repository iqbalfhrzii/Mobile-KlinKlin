import re

path = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\attendance\screens\admin_attendance_detail_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add attendance_service.dart import if not present
if 'attendance_service.dart' not in content:
    content = content.replace("import '../data/attendance_model.dart';", "import '../data/attendance_model.dart';\nimport '../services/attendance_service.dart';")

# Add state variables
state_vars = """
  bool _isLoadingStats = true;
  int _tepatWaktu = 0;
  int _telat = 0;
  int _plgCepat = 0;
  int _tdkAbsen = 0;
  List<AttendanceHistoryItem> _monthlyHistory = [];
"""
if '_isLoadingStats' not in content:
    content = content.replace('bool _isTokenLoaded = false;', 'bool _isTokenLoaded = false;\n' + state_vars)

# Update initState to load stats
if '_loadStats' not in content:
    init_state_new = """
  @override
  void initState() {
    super.initState();
    _loadToken();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final date = DateTime.parse(widget.item.tanggal);
      final currentMonth = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final history = await AttendanceService().getAllAbsensi(
        karyawanId: widget.item.karyawanId,
        month: currentMonth,
      );
      
      // Group by date to calculate Tdk Absen correctly
      final Map<String, List<AttendanceHistoryItem>> grouped = {};
      for (var item in history) {
        if (item.tanggal == null) continue;
        if (!grouped.containsKey(item.tanggal)) grouped[item.tanggal!] = [];
        grouped[item.tanggal!]!.add(item);
      }
      
      int tepat = 0;
      int tlt = 0;
      int plgCepat = 0;
      int tdkAbsn = 0;
      
      // Calculate workdays passed in this month up to the selected date
      int workdaysPassed = 0;
      for (int i = 1; i <= date.day; i++) {
        final d = DateTime(date.year, date.month, i);
        if (d.weekday != DateTime.sunday) {
          workdaysPassed++;
        }
      }

      int presentDays = 0;
      
      grouped.forEach((dateStr, items) {
        final masuk = items.where((i) => i.type == 'check_in' || i.type == 'masuk').firstOrNull;
        final keluar = items.where((i) => i.type == 'check_out' || i.type == 'pulang').firstOrNull;
        
        if (masuk != null) {
          presentDays++;
          bool isLate = false;
          if (masuk.time.contains(' ')) {
            final tParts = masuk.time.split(' ').last.split(':');
            if (tParts.length >= 2) {
              final h = int.tryParse(tParts[0]) ?? 0;
              final m = int.tryParse(tParts[1]) ?? 0;
              if (h > 8 || (h == 8 && m > 15)) isLate = true;
            }
          }
          if (isLate) {
            tlt++;
          } else {
            tepat++;
          }
        }
        
        if (keluar != null) {
          bool isEarly = false;
          if (keluar.time.contains(' ')) {
            final tParts = keluar.time.split(' ').last.split(':');
            if (tParts.length >= 2) {
              final h = int.tryParse(tParts[0]) ?? 0;
              if (h < 17) isEarly = true;
            }
          }
          if (isEarly) plgCepat++;
        }
      });
      
      tdkAbsn = (workdaysPassed - presentDays);
      if (tdkAbsn < 0) tdkAbsn = 0;

      if (mounted) {
        setState(() {
          _tepatWaktu = tepat;
          _telat = tlt;
          _plgCepat = plgCepat;
          _tdkAbsen = tdkAbsn;
          _monthlyHistory = history;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }
"""
    content = content.replace("""
  @override
  void initState() {
    super.initState();
    _loadToken();
  }
""", init_state_new)

# Add stats boxes and history to UI
ui_insertion = """
                  // --- 3. Stats Boxes ---
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatBox('TEPAT WAKTU', _tepatWaktu.toString(), const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatBox('TELAT', _telat.toString(), const Color(0xFFF57F17), const Color(0xFFFFF8E1)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatBox('PLG CEPAT', _plgCepat.toString(), const Color(0xFF1565C0), const Color(0xFFE3F2FD)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatBox('TDK ABSEN', _tdkAbsen.toString(), const Color(0xFFC62828), const Color(0xFFFFEBEE)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

"""

if 'Stats Boxes' not in content:
    content = content.replace("""                  // --- 3. Section Title ---""", ui_insertion + """                  // --- 3. Section Title ---""")


box_widget = """
  Widget _buildStatBox(String label, String value, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          _isLoadingStats 
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color))
              : Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

"""

if '_buildStatBox' not in content:
    content = content.replace('  Widget _buildRuleRow', box_widget + '  Widget _buildRuleRow')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated admin_attendance_detail_screen.dart")

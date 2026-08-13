import re

path = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\attendance\screens\attendance_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

import_statement = "import '../../cleaner/tukar_libur/screens/tukar_libur_screen.dart';"
if 'tukar_libur_screen.dart' not in content:
    content = content.replace("import '../../profile/screens/leave_history_screen.dart';", "import '../../profile/screens/leave_history_screen.dart';\n" + import_statement)

new_menu = """
  Widget _buildLeaveMenu() {
    return Column(
      children: [
        _buildMenuButton(
          title: 'Pengajuan Cuti / Izin',
          subtitle: 'Ajukan libur atau izin dengan mudah',
          icon: Icons.event_available_rounded,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveRequestScreen()));
          },
        ),
        const SizedBox(height: 12),
        _buildMenuButton(
          title: 'Tukar Libur',
          subtitle: 'Tukar jadwal libur dengan sesama Cleaner',
          icon: Icons.event_repeat_rounded,
          iconColor: const Color(0xFF8B5CF6),
          bgColors: const [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TukarLiburScreen()));
          },
        ),
      ],
    );
  }

  Widget _buildMenuButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = AppColors.primary,
    List<Color> bgColors = const [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
  }) {
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: bgColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
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
"""

old_menu_regex = re.compile(r'  Widget _buildLeaveMenu\(\) \{[\s\S]*?    \);\n  \}')
content = old_menu_regex.sub(new_menu, content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated attendance_screen.dart")

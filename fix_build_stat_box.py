import re

path = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\attendance\screens\admin_attendance_detail_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

stat_box_func = """
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
}
"""

if 'Widget _buildStatBox' not in content:
    content = re.sub(r'}\s*$', stat_box_func, content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

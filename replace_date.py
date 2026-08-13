import re

path = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\cleaner\tukar_libur\screens\tukar_libur_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Tambahkan import intl jika belum ada
if 'package:intl/intl.dart' not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:intl/intl.dart';")

# Fungsi formatter
formatter = """
  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      // Gunakan Intl jika tersedia locale id, atau fallback manual
      // Berhubung kita ingin format cepat: Hari, dd Bulan yyyy
      final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      final dayName = days[dt.weekday - 1];
      final monthName = months[dt.month - 1];
      return '$dayName, ${dt.day} $monthName ${dt.year}';
    } catch (_) {
      return dateStr.split('T')[0]; // fallback
    }
  }

  @override"""

content = content.replace('  @override\n  Widget build(BuildContext context) {', formatter + '\n  Widget build(BuildContext context) {')

# Update Dropdown 1 (Libur Saya)
content = re.sub(
    r"child: Text\(libur\['tanggal'\]\),",
    r"child: Text(_formatDate(libur['tanggal'])),",
    content
)

# Update Dropdown 2 (Rekan)
content = re.sub(
    r"child: Text\(libur\['tanggal'\]\)",
    r"child: Text(_formatDate(libur['tanggal']))",
    content
)

# Update Riwayat texts
content = re.sub(
    r"Text\(item\['tanggal_pengaju'\], style: GoogleFonts\.inter\(fontWeight: FontWeight\.w700, fontSize: 13, color: AppColors\.textDark\)\)",
    r"Text(_formatDate(item['tanggal_pengaju']), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark))",
    content
)
content = re.sub(
    r"Text\(item\['tanggal_target'\], style: GoogleFonts\.inter\(fontWeight: FontWeight\.w700, fontSize: 13, color: AppColors\.primary\)\)",
    r"Text(_formatDate(item['tanggal_target']), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary))",
    content
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Date formatter added')

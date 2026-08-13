import re

path = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\profile\screens\profile_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

import_statement = "import '../../cleaner/tukar_libur/screens/tukar_libur_screen.dart';"

if import_statement not in content:
    content = content.replace("import '../../stok_opname/screens/stok_opname_screen.dart';", "import '../../stok_opname/screens/stok_opname_screen.dart';\n" + import_statement)

menu_insertion = """
                    if (_userRole.toLowerCase().contains('cleaner')) ...[
                      _buildMenuSection('Kehadiran', [
                        _MenuItem(Icons.event_repeat_rounded, 'Tukar Libur', onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const TukarLiburScreen()));
                        }),
                      ]),
                      const SizedBox(height: 12),
                    ],
"""

if 'Tukar Libur' not in content:
    content = content.replace("                    _buildMenuSection('Akun', [", menu_insertion + "                    _buildMenuSection('Akun', [")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated profile_screen.dart")

import re

path = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\profile\screens\profile_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Make sure master_barang_screen is imported
if 'master_barang_screen.dart' not in content:
    content = content.replace("import '../../stok_opname/screens/stok_opname_screen.dart';", "import '../../stok_opname/screens/stok_opname_screen.dart';\nimport '../../master_barang/screens/master_barang_screen.dart';")

# Find the Manajemen section
manajemen_section = """                      _buildMenuSection('Manajemen', [
                        _MenuItem(Icons.fact_check_outlined, 'Stok Opname', onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const StokOpnameScreen()));
                        }),
                      ]),
                      const SizedBox(height: 12),"""

new_manajemen = """                      if (_userRole.toLowerCase().contains('cs') || _userRole.toLowerCase().contains('customer service')) ...[
                        _buildMenuSection('Manajemen CS', [
                          _MenuItem(Icons.fact_check_outlined, 'Stok Opname', onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const StokOpnameScreen()));
                          }),
                        ]),
                        const SizedBox(height: 12),
                      ],
                      if (_userRole.toLowerCase().contains('operasional') || _userRole.toLowerCase().contains('admin')) ...[
                        _buildMenuSection('Manajemen Operasional', [
                          _MenuItem(Icons.inventory_2_outlined, 'Master Barang & Aset', onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const MasterBarangScreen()));
                          }),
                        ]),
                        const SizedBox(height: 12),
                      ],"""

content = content.replace(manajemen_section, new_manajemen)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated profile_screen.dart logic')

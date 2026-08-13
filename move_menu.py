import re

# File 1: profile_screen.dart
path1 = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\profile\screens\profile_screen.dart'
with open(path1, 'r', encoding='utf-8') as f:
    content1 = f.read()

# Remove import
content1 = content1.replace("import '../../master_barang/screens/master_barang_screen.dart';\n", '')

# Remove menu item
old_menu = """                      _buildMenuSection('Manajemen', [
                        _MenuItem(Icons.inventory_2_outlined, 'Master Barang & Aset', onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MasterBarangScreen()));
                        }),
                        _MenuItem(Icons.fact_check_outlined, 'Stok Opname', onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const StokOpnameScreen()));
                        }),
                      ]),"""
new_menu = """                      _buildMenuSection('Manajemen', [
                        _MenuItem(Icons.fact_check_outlined, 'Stok Opname', onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const StokOpnameScreen()));
                        }),
                      ]),"""
content1 = content1.replace(old_menu, new_menu)

with open(path1, 'w', encoding='utf-8') as f:
    f.write(content1)

# File 2: operasional_pengaturan_screen.dart
path2 = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\operasional\screens\operasional_pengaturan_screen.dart'
with open(path2, 'r', encoding='utf-8') as f:
    content2 = f.read()

if 'master_barang_screen.dart' not in content2:
    content2 = content2.replace(
        "import '../../profile/screens/profile_screen.dart';",
        "import '../../profile/screens/profile_screen.dart';\nimport '../../master_barang/screens/master_barang_screen.dart';"
    )

new_card = """                _buildMenuCard(
                  context,
                  icon: Icons.inventory_2_outlined,
                  title: 'Master Barang & Aset',
                  subtitle: 'Kelola kategori, barang, dan generate QR code untuk semua cabang.',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MasterBarangScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildMenuCard(
                  context,
                  icon: Icons.business,"""
content2 = content2.replace("                _buildMenuCard(\n                  context,\n                  icon: Icons.business,", new_card)

with open(path2, 'w', encoding='utf-8') as f:
    f.write(content2)

print('Berhasil memindahkan menu')

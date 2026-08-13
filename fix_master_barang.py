import re

# File 1: master_barang_service.dart
path1 = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\master_barang\services\master_barang_service.dart'
with open(path1, 'r', encoding='utf-8') as f:
    content1 = f.read()

# Replace /api/master-barang with /master-barang
content1 = content1.replace('/api/master-barang', '/master-barang')

with open(path1, 'w', encoding='utf-8') as f:
    f.write(content1)

# File 2: master_barang_screen.dart
path2 = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\master_barang\screens\master_barang_screen.dart'
with open(path2, 'r', encoding='utf-8') as f:
    content2 = f.read()

# Add import for GradientHeader if not exists
if 'gradient_header.dart' not in content2:
    content2 = content2.replace("import '../services/master_barang_service.dart';", "import '../services/master_barang_service.dart';\nimport '../../../core/widgets/gradient_header.dart';")

# Replace scaffold appbar with GradientHeader in body
old_build = """  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Master Barang & Aset',
          style: GoogleFonts.inter(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 13),
          tabs: const [
            Tab(text: 'Kategori'),
            Tab(text: 'Data Barang'),
            Tab(text: 'Item Fisik'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildKategoriTab(),
          _buildBarangTab(),
          _buildItemFisikTab(),
        ],
      ),
    );
  }"""

new_build = """  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            child: Row(
              children: [
                HeaderBackButton(onTap: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                Text(
                  'Master Barang & Aset',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 13),
              tabs: const [
                Tab(text: 'Kategori'),
                Tab(text: 'Data Barang'),
                Tab(text: 'Item Fisik'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildKategoriTab(),
                _buildBarangTab(),
                _buildItemFisikTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }"""

content2 = content2.replace(old_build, new_build)

with open(path2, 'w', encoding='utf-8') as f:
    f.write(content2)

print('Updated master barang screen and service')

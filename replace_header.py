import re

path = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\cleaner\tukar_libur\screens\tukar_libur_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add import for GradientHeader
if 'gradient_header.dart' not in content:
    content = content.replace("import '../../../../core/theme/app_colors.dart';", "import '../../../../core/theme/app_colors.dart';\nimport '../../../../core/widgets/gradient_header.dart';")

new_build = """
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HeaderBackButton(onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 12),
                    Text('Tukar Libur', style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
                    )),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Tukar jadwal libur dengan sesama Cleaner', style: GoogleFonts.inter(
                  fontSize: 14, color: Colors.white.withValues(alpha: 0.8),
                )),
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
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Pengajuan Baru'),
                Tab(text: 'Riwayat'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                        const SizedBox(height: 16),
                        Text(_error, style: GoogleFonts.inter(color: AppColors.error), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _fetchData, child: const Text('Coba Lagi')),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildForm(),
                      _buildRiwayat(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
"""

regex = re.compile(r'  @override\n  Widget build\(BuildContext context\) \{[\s\S]*?    \);\n  \}')
content = regex.sub(new_build.strip('\n'), content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated header")

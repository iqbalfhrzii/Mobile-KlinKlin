import re

path = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\cleaner\tukar_libur\screens\tukar_libur_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

new_tab_bar = """
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: const [
                  Tab(text: 'Pengajuan Baru'),
                  Tab(text: 'Riwayat'),
                ],
              ),
            ),
          ),
"""

regex = re.compile(r'          Container\(\n            color: Colors\.white,\n            child: TabBar\([\s\S]*?            \),\n          \),')
content = regex.sub(new_tab_bar.strip('\n'), content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated tab bar")

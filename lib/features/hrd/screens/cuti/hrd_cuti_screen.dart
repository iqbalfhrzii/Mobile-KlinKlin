import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../services/hrd_cuti_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/gradient_header.dart';

class HrdCutiScreen extends StatefulWidget {
  const HrdCutiScreen({super.key});

  @override
  State<HrdCutiScreen> createState() => _HrdCutiScreenState();
}

class _HrdCutiScreenState extends State<HrdCutiScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = HrdCutiService();

  // Data Cuti State
  List<Map<String, dynamic>> _karyawans = [];
  bool _isLoadingKaryawan = true;
  String _searchKaryawan = '';

  // Pengajuan State
  List<Map<String, dynamic>> _pengajuan = [];
  Map<String, dynamic> _pengajuanStats = {'pending': 0, 'disetujui': 0, 'ditolak': 0};
  bool _isLoadingPengajuan = true;
  String _statusFilter = 'pending';

  // Pengaturan State
  int _defaultJatahCuti = 12;
  List<String> _hariKerja = [];
  bool _isLoadingPengaturan = true;
  final List<Map<String, String>> _allDaysMap = [
    {'en': 'Monday', 'id': 'Senin'},
    {'en': 'Tuesday', 'id': 'Selasa'},
    {'en': 'Wednesday', 'id': 'Rabu'},
    {'en': 'Thursday', 'id': 'Kamis'},
    {'en': 'Friday', 'id': 'Jumat'},
    {'en': 'Saturday', 'id': 'Sabtu'},
    {'en': 'Sunday', 'id': 'Minggu'},
  ];

  String? _getFotoUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    String cleanPath = path.replaceFirst(RegExp(r'^/?(storage/)?'), '');
    return 'http://159.223.59.109/storage/$cleanPath';
  }

  Widget _buildAvatar(Map<String, dynamic> k, {double radius = 20}) {
    final fotoUrl = _getFotoUrl(k['foto_profil']);
    final fallbackText = Text(
      k['nama'] != null && k['nama'].toString().isNotEmpty ? k['nama'][0].toUpperCase() : 'K',
      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: radius - 4),
    );

    if (fotoUrl == null) {
      return CircleAvatar(radius: radius, backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: fallbackText);
    }
    return ClipOval(
      child: Image.network(
        fotoUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => CircleAvatar(radius: radius, backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: fallbackText),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        if (_tabController.index == 0) _fetchKaryawans();
        if (_tabController.index == 1) _fetchPengajuan();
        if (_tabController.index == 2) _fetchPengaturan();
      }
    });
    _fetchKaryawans();
  }

  // --- FETCHERS ---
  Future<void> _fetchKaryawans() async {
    setState(() => _isLoadingKaryawan = true);
    try {
      final data = await _service.fetchKaryawans(search: _searchKaryawan);
      setState(() => _karyawans = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingKaryawan = false);
    }
  }

  Future<void> _fetchPengajuan() async {
    setState(() => _isLoadingPengajuan = true);
    try {
      final res = await _service.fetchPengajuan(status: _statusFilter == 'semua' ? '' : _statusFilter);
      setState(() {
        _pengajuan = List<Map<String, dynamic>>.from(res['data']);
        _pengajuanStats = res['stats'];
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingPengajuan = false);
    }
  }

  Future<void> _fetchPengaturan() async {
    setState(() => _isLoadingPengaturan = true);
    try {
      final data = await _service.fetchPengaturan();
      setState(() {
        _defaultJatahCuti = data['default_jatah_cuti'] ?? 12;
        _hariKerja = List<String>.from(data['hari_kerja'] ?? []);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingPengaturan = false);
    }
  }

  // --- ACTIONS ---
  Future<void> _updateJatahCuti(int karyawanId, int jatah, int sisa) async {
    try {
      await _service.updateKaryawanCuti(karyawanId, jatah, sisa);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cuti berhasil diupdate')));
      _fetchKaryawans();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _approve(int id) async {
    try {
      await _service.approvePengajuan(id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengajuan disetujui')));
      _fetchPengajuan();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _reject(int id, String catatan) async {
    try {
      await _service.rejectPengajuan(id, catatan);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengajuan ditolak')));
      _fetchPengajuan();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _savePengaturan() async {
    try {
      await _service.updatePengaturan(_defaultJatahCuti, _hariKerja);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengaturan disimpan')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // --- UI BUILDERS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Cuti & Izin',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Data Cuti'),
                      Tab(text: 'Pengajuan'),
                      Tab(text: 'Pengaturan'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDataCutiTab(),
                _buildPengajuanTab(),
                _buildPengaturanTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCutiTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (val) {
              _searchKaryawan = val;
              _fetchKaryawans();
            },
            decoration: InputDecoration(
              hintText: 'Cari nama atau jabatan...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingKaryawan
              ? ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 5,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        height: 100,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _karyawans.length,
                  itemBuilder: (context, index) {
                    final k = _karyawans[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1D4ED8).withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: _getFotoUrl(k['foto_profil']) != null 
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: Image.network(
                                            _getFotoUrl(k['foto_profil'])!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Center(
                                              child: Text(
                                                k['nama'] != null && k['nama'].toString().isNotEmpty ? k['nama'][0].toUpperCase() : 'K',
                                                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            k['nama'] != null && k['nama'].toString().isNotEmpty ? k['nama'][0].toUpperCase() : 'K',
                                            style: GoogleFonts.inter(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(k['nama'] ?? '-', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark, letterSpacing: -0.2)),
                                      const SizedBox(height: 2),
                                      Text('${k['jabatan']?['nama_jabatan'] ?? '-'} • ${k['cabang']?['nama_cabang'] ?? '-'}', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatItem('Jatah', '${k['jatah_cuti']}', Colors.blue),
                                Container(width: 1, height: 30, color: Colors.grey.withValues(alpha: 0.2)),
                                _buildStatItem('Sisa', '${k['sisa_cuti']}', Colors.green),
                                Container(width: 1, height: 30, color: Colors.grey.withValues(alpha: 0.2)),
                                _buildStatItem('Izin', '${k['total_izin']} Hari', Colors.orange),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      side: const BorderSide(color: AppColors.primary),
                                      foregroundColor: AppColors.primary,
                                    ),
                                    onPressed: () => _showRiwayat(k['id']),
                                    child: Text('Detail', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF0284C7)]),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _showEditCuti(k),
                                      child: Text('Edit', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
        Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildPengajuanTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildStatCard('Pending', _pengajuanStats['pending'].toString(), const Color(0xFFF59E0B), Icons.pending_actions_rounded),
              const SizedBox(width: 8),
              _buildStatCard('Disetujui', _pengajuanStats['disetujui'].toString(), const Color(0xFF10B981), Icons.check_circle_outline_rounded),
              const SizedBox(width: 8),
              _buildStatCard('Ditolak', _pengajuanStats['ditolak'].toString(), const Color(0xFFEF4444), Icons.cancel_outlined),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ['pending', 'disetujui', 'ditolak', 'semua'].map((status) {
              final isSelected = _statusFilter == status;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onSelected: (val) {
                    if (val) {
                      setState(() => _statusFilter = status);
                      _fetchPengajuan();
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoadingPengajuan
              ? const Center(child: CircularProgressIndicator())
              : _pengajuan.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada pengajuan ${_statusFilter == 'semua' ? '' : _statusFilter}.',
                            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _pengajuan.length,
                      itemBuilder: (context, index) {
                        final p = _pengajuan[index];
                        return _buildPengajuanCard(p);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildPengajuanCard(Map<String, dynamic> p) {
    final k = p['karyawan'];
    final tglMulai = DateTime.parse(p['tanggal_mulai']);
    final tglSelesai = DateTime.parse(p['tanggal_selesai']);
    final tglStr = DateFormat('dd MMM yyyy').format(tglMulai) + (tglMulai != tglSelesai ? ' - ${DateFormat('dd MMM yyyy').format(tglSelesai)}' : '');

    final isPending = p['status'] == 'pending';
    final isApproved = p['status'] == 'disetujui';
    final statusColor = isPending ? const Color(0xFFF59E0B) : isApproved ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final statusBg = isPending ? const Color(0xFFFEF3C7) : isApproved ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status & Jenis
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusBg.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: statusColor.withValues(alpha: 0.2))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      p['jenis'] == 'cuti' ? Icons.beach_access_rounded : Icons.sick_rounded,
                      size: 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      p['jenis'].toString().toUpperCase(),
                      style: GoogleFonts.inter(color: statusColor, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    p['status'].toString().toUpperCase(),
                    style: GoogleFonts.inter(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info
                Row(
                  children: [
                    _buildAvatar(k, radius: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k['nama'] ?? '-', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark)),
                          Text('${k['jabatan']?['nama_jabatan'] ?? '-'} • ${k['cabang']?['nama_cabang'] ?? '-'}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text('Tanggal Pelaksanaan', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(tglStr, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.subject_rounded, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Alasan Pengajuan', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                                const SizedBox(height: 4),
                                Text(p['alasan'] ?? '-', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isPending) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            foregroundColor: const Color(0xFFEF4444),
                          ),
                          onPressed: () => _showRejectModal(p['id']),
                          child: Text('Tolak', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF059669)]),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF059669).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _showApproveConfirm(p['id']),
                            child: Text('Setujui', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    onPressed: () => _showDetailPengajuanModal(p),
                    child: Text('Lihat Detail Lengkap', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPengaturanTab() {
    if (_isLoadingPengaturan) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchPengaturan();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Pengaturan Cuti', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Default Jatah Cuti Tahunan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: _defaultJatahCuti.toString(),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.primary),
                            ),
                          ),
                          onChanged: (val) => _defaultJatahCuti = int.tryParse(val) ?? 0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Hari / Tahun', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                      const Spacer(flex: 3),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Akan diterapkan otomatis untuk karyawan yang baru terdaftar.', style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade500)),
                  
                  const SizedBox(height: 24),
                  
                  Text('Hari Kerja (Untuk Perhitungan Cuti)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _allDaysMap.map((dayMap) {
                      final en = dayMap['en']!;
                      final id = dayMap['id']!;
                      final isSelected = _hariKerja.contains(en);
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _hariKerja.remove(en);
                              } else {
                                _hariKerja.add(en);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF10B981) : Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                  color: isSelected ? AppColors.primary : Colors.grey.shade400,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  id,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade500, height: 1.4),
                      children: const [
                        TextSpan(text: 'Hari libur di luar hari kerja yang dipilih '),
                        TextSpan(text: 'tidak akan memotong', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        TextSpan(text: ' jatah cuti karyawan saat mereka mengajukan cuti di tanggal tersebut.'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: _savePengaturan,
                      child: Text('Simpan Pengaturan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }

  // --- MODALS ---
  void _showEditCuti(Map<String, dynamic> k) {
    int jatah = k['jatah_cuti'];
    int sisa = k['sisa_cuti'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Cuti - ${k['nama']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: jatah.toString(),
              decoration: const InputDecoration(labelText: 'Jatah Cuti Keseluruhan'),
              keyboardType: TextInputType.number,
              onChanged: (v) => jatah = int.tryParse(v) ?? jatah,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: sisa.toString(),
              decoration: const InputDecoration(labelText: 'Sisa Cuti Saat Ini'),
              keyboardType: TextInputType.number,
              onChanged: (v) => sisa = int.tryParse(v) ?? sisa,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateJatahCuti(k['id'], jatah, sisa);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showRiwayat(int id) async {
    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final data = await _service.fetchRiwayatKaryawan(id);
      if (mounted) Navigator.pop(context);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Riwayat Izin & Cuti', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _getFotoUrl(data['foto_profil']) != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  _getFotoUrl(data['foto_profil'])!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Center(child: Text(data['nama'] != null && data['nama'].toString().isNotEmpty ? data['nama'][0].toUpperCase() : 'K', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20))),
                                ),
                              )
                            : Center(child: Text(data['nama'] != null && data['nama'].toString().isNotEmpty ? data['nama'][0].toUpperCase() : 'K', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['nama'] ?? '-', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                            const SizedBox(height: 2),
                            Text('${data['jabatan']?['nama_jabatan'] ?? '-'} • ${data['cabang']?['nama_cabang'] ?? '-'}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Seluruh Riwayat Pengajuan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: (data['pengajuan_izin_cutis'] as List).isEmpty
                        ? Center(child: Text('Belum ada riwayat pengajuan.', style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            shrinkWrap: true,
                            itemCount: (data['pengajuan_izin_cutis'] as List).length,
                            separatorBuilder: (context, index) => const Divider(height: 16),
                            itemBuilder: (context, index) {
                              final p = data['pengajuan_izin_cutis'][index];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('TANGGAL', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text('${p['tanggal_mulai']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('JENIS', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text('${p['jenis'].toString().toUpperCase()}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('STATUS', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text('${p['status'].toString().toUpperCase()}', style: GoogleFonts.inter(
                                          fontSize: 12, 
                                          fontWeight: FontWeight.w700, 
                                          color: p['status'] == 'disetujui' ? Colors.green : (p['status'] == 'ditolak' ? Colors.red : Colors.orange)
                                        )),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text('Tutup', style: GoogleFonts.inter(color: Colors.grey.shade700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _showApproveConfirm(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Apakah Anda yakin ingin menyetujui pengajuan ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _approve(id);
            },
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
  }

  void _showRejectModal(int id) {
    String catatan = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Pengajuan'),
        content: TextFormField(
          decoration: const InputDecoration(labelText: 'Alasan penolakan', border: OutlineInputBorder()),
          maxLines: 3,
          onChanged: (v) => catatan = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (catatan.isEmpty) return;
              Navigator.pop(context);
              _reject(id, catatan);
            },
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  void _showDetailPengajuanModal(Map<String, dynamic> p) {
    final k = p['karyawan'];
    final tglMulai = DateTime.parse(p['tanggal_mulai']);
    final tglSelesai = DateTime.parse(p['tanggal_selesai']);
    final durasi = tglSelesai.difference(tglMulai).inDays + 1;
    
    final isPending = p['status'] == 'pending';
    final isApproved = p['status'] == 'disetujui';
    final statusColor = isPending ? const Color(0xFFF59E0B) : isApproved ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final statusBg = isPending ? const Color(0xFFFEF3C7) : isApproved ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2);

    String? lampiranUrl = p['lampiran_path'] ?? p['bukti_foto'] ?? p['bukti'] ?? p['lampiran'];
    if (lampiranUrl != null && !lampiranUrl.startsWith('http')) {
      lampiranUrl = lampiranUrl.replaceFirst(RegExp(r'^/?(storage/)?'), '');
      lampiranUrl = 'http://159.223.59.109/storage/$lampiranUrl';
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Detail Pengajuan ${p['jenis'].toString().toUpperCase()}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildAvatar(k, radius: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k['nama'] ?? '-', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                          Text('${k['jabatan']?['nama_jabatan'] ?? '-'} • ${k['cabang']?['nama_cabang'] ?? '-'}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tanggal Mulai', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                                const SizedBox(height: 4),
                                Text(DateFormat('dd MMM yyyy').format(tglMulai), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tanggal Selesai', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                                const SizedBox(height: 4),
                                Text(DateFormat('dd MMM yyyy').format(tglSelesai), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Durasi', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                                const SizedBox(height: 4),
                                Text('$durasi Hari', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Status', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    p['status'].toString().toUpperCase(),
                                    style: GoogleFonts.inter(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Alasan', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(p['alasan'] ?? '-', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark)),
                ),
                if (lampiranUrl != null) ...[
                  const SizedBox(height: 16),
                  Text('Lampiran / Bukti', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      lampiranUrl,
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 120,
                        width: 120,
                        color: Colors.grey.shade100,
                        child: Icon(Icons.broken_image_rounded, color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('Tutup', style: GoogleFonts.inter(color: Colors.grey.shade700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

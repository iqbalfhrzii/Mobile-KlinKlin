import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../services/hrd_cuti_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

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
  final List<String> _allDays = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Cuti & Izin', style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Data Cuti'),
            Tab(text: 'Pengajuan'),
            Tab(text: 'Pengaturan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDataCutiTab(),
          _buildPengajuanTab(),
          _buildPengaturanTab(),
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
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  backgroundImage: k['foto_profil'] != null ? NetworkImage(k['foto_profil']) : null,
                                  child: k['foto_profil'] == null ? Text(k['nama'][0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)) : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(k['nama'] ?? '-', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text('${k['jabatan']?['nama_jabatan'] ?? '-'} • ${k['cabang']?['nama_cabang'] ?? '-'}', style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatItem('Jatah', '${k['jatah_cuti']}', Colors.blue),
                                _buildStatItem('Sisa', '${k['sisa_cuti']}', Colors.green),
                                _buildStatItem('Izin', '${k['total_izin']} Hari', Colors.orange),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _showRiwayat(k['id']),
                                    child: const Text('Detail'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _showEditCuti(k),
                                    child: const Text('Edit'),
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
              _buildStatCard('Pending', _pengajuanStats['pending'].toString(), Colors.orange),
              const SizedBox(width: 8),
              _buildStatCard('Setuju', _pengajuanStats['disetujui'].toString(), Colors.green),
              const SizedBox(width: 8),
              _buildStatCard('Tolak', _pengajuanStats['ditolak'].toString(), Colors.red),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ['pending', 'disetujui', 'ditolak', 'semua'].map((status) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(status.toUpperCase()),
                  selected: _statusFilter == status,
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

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
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

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(p['jenis'].toString().toUpperCase(), style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                Text(p['status'].toString().toUpperCase(), style: TextStyle(
                  color: p['status'] == 'pending' ? Colors.orange : p['status'] == 'disetujui' ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                )),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: k['foto_profil'] != null ? NetworkImage(k['foto_profil']) : null,
                  child: k['foto_profil'] == null ? const Icon(Icons.person, size: 16) : null,
                ),
                const SizedBox(width: 8),
                Text(k['nama'], style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Tanggal: $tglStr', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            Text('Alasan: ${p['alasan']}', style: GoogleFonts.inter(fontSize: 13)),
            if (p['status'] == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () => _showRejectModal(p['id']),
                      child: const Text('Tolak'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () => _showApproveConfirm(p['id']),
                      child: const Text('Setujui'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPengaturanTab() {
    if (_isLoadingPengaturan) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pengaturan Cuti', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('Default Jatah Cuti Tahunan', style: GoogleFonts.inter(fontSize: 14)),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _defaultJatahCuti.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixText: 'Hari / Tahun',
                ),
                onChanged: (val) => _defaultJatahCuti = int.tryParse(val) ?? 0,
              ),
              const SizedBox(height: 16),
              Text('Hari Kerja (Untuk Perhitungan Cuti)', style: GoogleFonts.inter(fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allDays.map((day) {
                  final isSelected = _hariKerja.contains(day);
                  return FilterChip(
                    label: Text(day),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _hariKerja.add(day);
                        } else {
                          _hariKerja.remove(day);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _savePengaturan,
                  child: const Text('Simpan Pengaturan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          builder: (context) => AlertDialog(
            title: Text('Riwayat - ${data['nama']}'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: (data['pengajuan_izin_cutis'] as List).length,
                itemBuilder: (context, index) {
                  final p = data['pengajuan_izin_cutis'][index];
                  return ListTile(
                    title: Text('${p['jenis'].toString().toUpperCase()} - ${p['status'].toString().toUpperCase()}'),
                    subtitle: Text('${p['tanggal_mulai']} s.d ${p['tanggal_selesai']}'),
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
            ],
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
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/data/hrd_models.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../services/hrd_cuti_service.dart';
import '../../services/hrd_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/whatsapp_icon.dart';

class HrdCutiScreen extends StatefulWidget {
  const HrdCutiScreen({super.key});

  @override
  State<HrdCutiScreen> createState() => _HrdCutiScreenState();
}

class _HrdCutiScreenState extends State<HrdCutiScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = HrdCutiService();
  final _hrdService = HrdService();

  // Data Cuti State
  List<Map<String, dynamic>> _karyawans = [];
  List<CabangModel> _cabangs = [];
  bool _isLoadingKaryawan = true;
  String _searchKaryawan = '';
  String? _selectedJabatan;
  String? _selectedCabangId;

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

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return '-';
    try {
      DateTime dt;
      if (dateVal is DateTime) {
        dt = dateVal;
      } else {
        dt = DateTime.parse(dateVal.toString());
      }
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return dateVal.toString().split('T').first;
    }
  }

  Widget _buildAvatar(Map<String, dynamic>? k, {double size = 48, double radius = 14}) {
    final name = k?['nama']?.toString() ?? '';
    final rawPhoto = (k?['foto_profil'] ?? k?['foto'] ?? k?['foto_url'] ?? k?['profile_photo_url'])?.toString().trim();
    return AppAvatar(
      photoUrl: rawPhoto,
      name: name,
      size: size,
      shape: BoxShape.rectangle,
      borderRadius: BorderRadius.circular(radius),
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
    _fetchCabangs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchCabangs() async {
    try {
      final data = await _hrdService.fetchCabang();
      if (mounted) setState(() => _cabangs = data);
    } catch (_) {}
  }

  // --- FETCHERS ---
  Future<void> _fetchKaryawans() async {
    setState(() => _isLoadingKaryawan = true);
    try {
      final data = await _service.fetchKaryawans(
        search: _searchKaryawan,
        cabangId: _selectedCabangId,
        jabatan: _selectedJabatan,
      );
      if (mounted) setState(() => _karyawans = data);
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
      if (mounted) {
        setState(() {
          _pengajuan = List<Map<String, dynamic>>.from(res['data'] ?? []);
          _pengajuanStats = Map<String, dynamic>.from(res['stats'] ?? {'pending': 0, 'disetujui': 0, 'ditolak': 0});
        });
      }
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
      if (mounted) {
        setState(() {
          _defaultJatahCuti = data['default_jatah_cuti'] ?? 12;
          _hariKerja = List<String>.from(data['hari_kerja'] ?? []);
        });
      }
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data cuti berhasil diperbarui')));
      _fetchKaryawans();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _notifyCsInApp(int pengajuanId) async {
    try {
      await _service.notifyCs(pengajuanId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Notifikasi pengingat cuti/izin berhasil dikirim ke CS'),
              ],
            ),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim notifikasi: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _sendCutiInfoToCSWA(Map<String, dynamic> p, {String? targetPhone}) async {
    final k = p['karyawan'];
    final namaCleaner = k?['nama'] ?? 'Cleaner';
    final namaCabang = k?['cabang']?['nama_cabang'] ?? 'Cabang';
    final jenis = (p['jenis']?.toString().toUpperCase() ?? 'CUTI');
    final tglMulai = _formatDate(p['tanggal_mulai']);
    final tglSelesai = _formatDate(p['tanggal_selesai']);
    final tglStr = tglMulai == tglSelesai ? tglMulai : '$tglMulai s/d $tglSelesai';
    final durasi = p['durasi_hari']?.toString() ?? '1';
    final alasan = (p['alasan'] != null && p['alasan'].toString().isNotEmpty) ? p['alasan'].toString() : '-';

    final message = '''📢 *INFO $jenis CLEANER*
Halo tim CS *$namaCabang*,
Diberitahukan bahwa Cleaner berikut telah *DISETUJUI* $jenis oleh HRD:

👤 *Nama*: *$namaCleaner*
🏢 *Cabang*: *$namaCabang*
🏖️ *Jenis*: *$jenis*
📅 *Tanggal*: *$tglStr* ($durasi Hari)
📝 *Alasan*: $alasan

⚠️ *Catatan untuk CS*:
Mohon tidak mengalokasikan / menjadwalkan pesanan kepada cleaner tersebut pada tanggal di atas. Terima kasih! 🙏''';

    final encodedMsg = Uri.encodeComponent(message);
    Uri url;
    if (targetPhone != null && targetPhone.isNotEmpty) {
      final phone = targetPhone.startsWith('0') ? '62${targetPhone.substring(1)}' : targetPhone;
      url = Uri.parse('https://wa.me/$phone?text=$encodedMsg');
    } else {
      url = Uri.parse('https://wa.me/?text=$encodedMsg');
    }

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _showNotifyCsOptions(Map<String, dynamic> p) {
    final k = p['karyawan'];
    final namaCleaner = k?['nama'] ?? 'Cleaner';
    final jenis = (p['jenis']?.toString().toUpperCase() ?? 'CUTI');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.campaign_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Beritahu CS ($namaCleaner)',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Pemberitahuan persetujuan $jenis cleaner',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),

            // Option 1: WhatsApp
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _sendCutiInfoToCSWA(p);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF25D366),
                        shape: BoxShape.circle,
                      ),
                      child: const WhatsAppIcon(size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kirim Format WhatsApp ke CS',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF14532D),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Buka WhatsApp dengan pesan format info cuti/izin yang rapi',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF166534),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF166534)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Option 2: Push Notification In-App
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _notifyCsInApp(p['id']);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_active_rounded, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kirim Notifikasi Aplikasi ke CS',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kirim notif pengingat ke CS cabang & seluruh CS',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF1D4ED8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF1D4ED8)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(int id) async {
    try {
      await _service.approvePengajuan(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Pengajuan disetujui & CS otomatis dapat notifikasi'),
              ],
            ),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
      _fetchPengajuan();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _reject(int id, String catatan) async {
    try {
      await _service.rejectPengajuan(id, catatan);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengajuan telah ditolak')));
      _fetchPengajuan();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _savePengaturan() async {
    try {
      await _service.updatePengaturan(_defaultJatahCuti, _hariKerja);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengaturan cuti berhasil disimpan')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _getCabangName(String? cabangId) {
    if (cabangId == null || cabangId.isEmpty) return 'Semua Cabang';
    final found = _cabangs.where((c) => c.id.toString() == cabangId);
    if (found.isNotEmpty) return found.first.namaCabang;
    return 'Cabang #$cabangId';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF1D4ED8),
                    unselectedLabelColor: Colors.white.withValues(alpha: 0.85),
                    labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                    unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
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

  // ==========================================
  // TAB 1: DATA CUTI KARYAWAN
  // ==========================================
  Widget _buildDataCutiTab() {
    final bool hasActiveFilter = _selectedJabatan != null || _selectedCabangId != null;

    return Column(
      children: [
        // Search Bar & Filter Button Row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) {
                    _searchKaryawan = val;
                    _fetchKaryawans();
                  },
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau jabatan...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _showFilterModal,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasActiveFilter ? const Color(0xFF2563EB) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasActiveFilter ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: hasActiveFilter
                            ? const Color(0xFF2563EB).withValues(alpha: 0.25)
                            : const Color(0xFF64748B).withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 22,
                        color: hasActiveFilter ? Colors.white : const Color(0xFF334155),
                      ),
                      if (hasActiveFilter)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Active Filter Chips Bar (if any)
        if (hasActiveFilter)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_selectedJabatan != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Jabatan: $_selectedJabatan',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8)),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() => _selectedJabatan = null);
                                _fetchKaryawans();
                              },
                              child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF1D4ED8)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_selectedCabangId != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Cabang: ${_getCabangName(_selectedCabangId)}',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() => _selectedCabangId = null);
                                _fetchKaryawans();
                              },
                              child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF059669)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedJabatan = null;
                        _selectedCabangId = null;
                      });
                      _fetchKaryawans();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        'Reset Filter',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                      ),
                    ),
                  ),
                ],
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
                      baseColor: Colors.grey[200]!,
                      highlightColor: Colors.grey[50]!,
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                )
              : _karyawans.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_search_rounded, size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('Tidak ada data karyawan.', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
                          if (hasActiveFilter) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedJabatan = null;
                                  _selectedCabangId = null;
                                });
                                _fetchKaryawans();
                              },
                              child: const Text('Hapus Filter'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchKaryawans,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _karyawans.length,
                        itemBuilder: (context, index) {
                          final k = _karyawans[index];
                          final namaJabatan = k['jabatan']?['nama_jabatan'] ?? '-';
                          final namaCabang = k['cabang']?['nama_cabang'] ?? '-';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF64748B).withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => _showRiwayat(k['id']),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          _buildAvatar(k, size: 48, radius: 14),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  k['nama'] ?? '-',
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFEFF6FF),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                                      ),
                                                      child: Text(
                                                        namaJabatan,
                                                        style: GoogleFonts.inter(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: const Color(0xFF1D4ED8),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '• $namaCabang',
                                                      style: GoogleFonts.inter(
                                                        color: const Color(0xFF64748B),
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () => _showEditCuti(k),
                                            borderRadius: BorderRadius.circular(10),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: const Color(0xFFBFDBFE)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF1D4ED8)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Edit',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF1D4ED8),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),

                                      // Stats Row
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFF1F5F9)),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: _buildStatItem('Jatah Cuti', '${k['jatah_cuti'] ?? 0}', const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                                            ),
                                            Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                                            Expanded(
                                              child: _buildStatItem('Sisa Cuti', '${k['sisa_cuti'] ?? 0}', const Color(0xFF059669), const Color(0xFFECFDF5)),
                                            ),
                                            Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                                            Expanded(
                                              child: _buildStatItem('Total Izin', '${k['total_izin'] ?? 0} Hari', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Frame Tap Indicator
                                      Row(
                                        children: [
                                          const Icon(Icons.touch_app_outlined, size: 13, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Ketuk kartu untuk riwayat izin & cuti',
                                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                          ),
                                          const Spacer(),
                                          const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color, Color bgColor) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
        const SizedBox(height: 3),
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  // ==========================================
  // MODAL FILTER DATA CUTI
  // ==========================================
  void _showFilterModal() {
    String? tempJabatan = _selectedJabatan;
    String? tempCabangId = _selectedCabangId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Filter Data Cuti',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 16),

                // 1. Filter Jabatan
                Text('Jabatan Karyawan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    {'label': 'Semua Jabatan', 'value': null},
                    {'label': 'Cleaner', 'value': 'Cleaner'},
                    {'label': 'Customer Service (CS)', 'value': 'CS'},
                  ].map((item) {
                    final isSelected = tempJabatan == item['value'];
                    return ChoiceChip(
                      label: Text(
                        item['label'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF2563EB),
                      backgroundColor: const Color(0xFFF8FAFC),
                      side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      showCheckmark: false,
                      onSelected: (val) {
                        setModalState(() {
                          tempJabatan = item['value'];
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // 2. Filter Cabang
                Text('Cabang Karyawan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: tempCabangId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Semua Cabang', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ..._cabangs.map((c) => DropdownMenuItem<String?>(
                          value: c.id.toString(),
                          child: Text(c.namaCabang),
                        )),
                  ],
                  onChanged: (val) {
                    setModalState(() {
                      tempCabangId = val;
                    });
                  },
                ),
                const SizedBox(height: 26),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _selectedJabatan = null;
                            _selectedCabangId = null;
                          });
                          _fetchKaryawans();
                        },
                        child: Text('Reset', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF64748B))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _selectedJabatan = tempJabatan;
                            _selectedCabangId = tempCabangId;
                          });
                          _fetchKaryawans();
                        },
                        child: Text('Terapkan Filter', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 2: PENGAJUAN IZIN & CUTI
  // ==========================================
  Widget _buildPengajuanTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              _buildStatCard('Pending', _pengajuanStats['pending'].toString(), const Color(0xFFD97706), const Color(0xFFFEF3C7), Icons.hourglass_top_rounded),
              const SizedBox(width: 8),
              _buildStatCard('Disetujui', _pengajuanStats['disetujui'].toString(), const Color(0xFF059669), const Color(0xFFD1FAE5), Icons.check_circle_rounded),
              const SizedBox(width: 8),
              _buildStatCard('Ditolak', _pengajuanStats['ditolak'].toString(), const Color(0xFFDC2626), const Color(0xFFFEE2E2), Icons.cancel_rounded),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: ['pending', 'disetujui', 'ditolak', 'semua'].map((status) {
              final isSelected = _statusFilter == status;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  showCheckmark: false,
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
        const SizedBox(height: 4),
        Expanded(
          child: _isLoadingPengajuan
              ? const Center(child: CircularProgressIndicator())
              : _pengajuan.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada pengajuan ${_statusFilter == 'semua' ? '' : _statusFilter}.',
                            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchPengajuan,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                        itemCount: _pengajuan.length,
                        itemBuilder: (context, index) {
                          final p = _pengajuan[index];
                          return _buildPengajuanCard(p);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, Color bg, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF64748B).withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildPengajuanCard(Map<String, dynamic> p) {
    final k = p['karyawan'];
    final tglMulai = _formatDate(p['tanggal_mulai']);
    final tglSelesai = _formatDate(p['tanggal_selesai']);
    final tglStr = tglMulai == tglSelesai ? tglMulai : '$tglMulai s/d $tglSelesai';

    final isPending = p['status'] == 'pending';
    final isApproved = p['status'] == 'disetujui';
    final isRejected = p['status'] == 'ditolak';

    final statusColor = isPending ? const Color(0xFFD97706) : isApproved ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final statusBg = isPending ? const Color(0xFFFFFBEB) : isApproved ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    final statusBorder = isPending ? const Color(0xFFFDE68A) : isApproved ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA);

    final isCuti = (p['jenis']?.toString().toLowerCase() ?? '') == 'cuti';
    final jenisColor = isCuti ? const Color(0xFF7E22CE) : const Color(0xFFD97706);
    final jenisBg = isCuti ? const Color(0xFFFAF5FF) : const Color(0xFFFFFBEB);
    final jenisBorder = isCuti ? const Color(0xFFE9D5FF) : const Color(0xFFFDE68A);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showDetailPengajuanModal(p),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Jenis Badge & Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: jenisBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: jenisBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(isCuti ? Icons.beach_access_rounded : Icons.sick_rounded, size: 14, color: jenisColor),
                          const SizedBox(width: 5),
                          Text(
                            p['jenis'].toString().toUpperCase(),
                            style: GoogleFonts.inter(color: jenisColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusBorder),
                      ),
                      child: Text(
                        isApproved ? 'DISETUJUI' : (isRejected ? 'DITOLAK' : 'PENDING'),
                        style: GoogleFonts.inter(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Karyawan Info
                Row(
                  children: [
                    _buildAvatar(k, size: 44, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k?['nama'] ?? '-', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          Text('${k?['jabatan']?['nama_jabatan'] ?? '-'} • ${k?['cabang']?['nama_cabang'] ?? '-'}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Date & Reason Info Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text('Pelaksanaan:', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              tglStr,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                      if (p['alasan'] != null && p['alasan'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.notes_rounded, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                p['alasan'],
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                if (isPending) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            foregroundColor: const Color(0xFFEF4444),
                          ),
                          onPressed: () => _showRejectModal(p['id']),
                          child: Text('Tolak', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _showApproveConfirm(p['id']),
                          child: Text('Setujui', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ] else if (isApproved) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showNotifyCsOptions(p),
                      icon: const Icon(Icons.campaign_rounded, size: 16),
                      label: Text('Beritahu CS', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.touch_app_outlined, size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      'Ketuk kartu untuk detail pengajuan',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: PENGATURAN CUTI
  // ==========================================
  Widget _buildPengaturanTab() {
    if (_isLoadingPengaturan) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _fetchPengaturan,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF64748B).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
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
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.settings_suggest_rounded, color: Color(0xFF2563EB), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text('Pengaturan Cuti Karyawan', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 16),

                Text('Default Jatah Cuti Tahunan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        initialValue: _defaultJatahCuti.toString(),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                        ),
                        onChanged: (val) => _defaultJatahCuti = int.tryParse(val) ?? 0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Hari / Tahun', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Diterapkan otomatis untuk karyawan baru yang terdaftar.', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8))),

                const SizedBox(height: 22),
                Text('Hari Kerja (Perhitungan Cuti)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allDaysMap.map((dayMap) {
                    final en = dayMap['en']!;
                    final id = dayMap['id']!;
                    final isSelected = _hariKerja.contains(en);
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _hariKerja.remove(en);
                          } else {
                            _hariKerja.add(en);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              id,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Text(
                  'Hari libur di luar hari kerja yang dipilih tidak akan memotong jatah cuti.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _savePengaturan,
                    child: Text('Simpan Pengaturan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MODAL BOTTOM SHEET: RIWAYAT IZIN & CUTI
  // ==========================================
  void _showRiwayat(int id) async {
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      final data = await _service.fetchRiwayatKaryawan(id);
      if (mounted) Navigator.pop(context); // Close loading dialog
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) {
            final pengajuans = List<Map<String, dynamic>>.from(data['pengajuan_izin_cutis'] ?? []);
            final namaJabatan = data['jabatan']?['nama_jabatan'] ?? '-';
            final namaCabang = data['cabang']?['nama_cabang'] ?? '-';

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header Modal
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 14, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.history_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Riwayat Izin & Cuti',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Daftar pengajuan izin & cuti karyawan',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE2E8F0),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Card (Matching Web Design)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF64748B).withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                _buildAvatar(data, size: 64, radius: 16),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['nama'] ?? '-',
                                        style: GoogleFonts.inter(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFBFDBFE)),
                                            ),
                                            child: Text(
                                              namaJabatan,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF1D4ED8),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '• $namaCabang',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: const Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Seluruh Riwayat Pengajuan',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${pengajuans.length} Pengajuan',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (pengajuans.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey.shade300),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Belum ada riwayat pengajuan cuti/izin.',
                                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...pengajuans.map((p) {
                              final tglPengajuan = _formatDate(p['created_at']);
                              final tglMulai = _formatDate(p['tanggal_mulai']);
                              final tglSelesai = _formatDate(p['tanggal_selesai']);
                              
                              int durasi = 1;
                              try {
                                final dMulai = DateTime.parse(p['tanggal_mulai'].toString());
                                final dSelesai = DateTime.parse(p['tanggal_selesai'].toString());
                                durasi = dSelesai.difference(dMulai).inDays + 1;
                              } catch (_) {}

                              final isApproved = (p['status']?.toString().toLowerCase() ?? '') == 'disetujui';
                              final isRejected = (p['status']?.toString().toLowerCase() ?? '') == 'ditolak';

                              final statusColor = isApproved 
                                  ? const Color(0xFF059669) 
                                  : (isRejected ? const Color(0xFFDC2626) : const Color(0xFFD97706));
                              final statusBg = isApproved 
                                  ? const Color(0xFFECFDF5) 
                                  : (isRejected ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB));
                              final statusBorder = isApproved 
                                  ? const Color(0xFFA7F3D0) 
                                  : (isRejected ? const Color(0xFFFECACA) : const Color(0xFFFDE68A));

                              final isCuti = (p['jenis']?.toString().toLowerCase() ?? '') == 'cuti';
                              final jenisColor = isCuti ? const Color(0xFF7E22CE) : const Color(0xFFD97706);
                              final jenisBg = isCuti ? const Color(0xFFFAF5FF) : const Color(0xFFFFFBEB);
                              final jenisBorder = isCuti ? const Color(0xFFE9D5FF) : const Color(0xFFFDE68A);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF64748B).withValues(alpha: 0.04),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: jenisBg,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: jenisBorder),
                                              ),
                                              child: Text(
                                                p['jenis'].toString().toUpperCase(),
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: jenisColor,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              tglPengajuan,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: statusBg,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: statusBorder),
                                          ),
                                          child: Text(
                                            isApproved ? 'Disetujui' : (isRejected ? 'Ditolak' : 'Pending'),
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: statusColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(Icons.date_range_rounded, size: 15, color: Color(0xFF64748B)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            tglMulai == tglSelesai ? tglMulai : '$tglMulai s/d $tglSelesai',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '$durasi Hari',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (p['alasan'] != null && p['alasan'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Alasan: ${p['alasan']}',
                                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Tutup', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF475569))),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat riwayat: $e')));
    }
  }

  // ==========================================
  // MODAL EDIT JATAH & SISA CUTI
  // ==========================================
  void _showEditCuti(Map<String, dynamic> k) {
    int jatah = k['jatah_cuti'] ?? 0;
    int sisa = k['sisa_cuti'] ?? 0;
    final jatahCtrl = TextEditingController(text: jatah.toString());
    final sisaCtrl = TextEditingController(text: sisa.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildAvatar(k, size: 44, radius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Cuti Karyawan', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                        Text(k['nama'] ?? '-', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 18),

              Text('Jatah Cuti Keseluruhan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
              const SizedBox(height: 6),
              TextFormField(
                controller: jatahCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixText: 'Hari',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              Text('Sisa Cuti Saat Ini', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
              const SizedBox(height: 6),
              TextFormField(
                controller: sisaCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixText: 'Hari',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Batal', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF64748B))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final newJatah = int.tryParse(jatahCtrl.text) ?? jatah;
                        final newSisa = int.tryParse(sisaCtrl.text) ?? sisa;
                        Navigator.pop(ctx);
                        _updateJatahCuti(k['id'], newJatah, newSisa);
                      },
                      child: Text('Simpan Perubahan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showApproveConfirm(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AppConfirmationDialog(
        title: 'Setujui Pengajuan Cuti',
        message: 'Apakah Anda yakin ingin menyetujui pengajuan cuti ini?',
        type: ConfirmationDialogType.success,
        confirmText: 'Ya, Setujui',
        cancelText: 'Batal',
        onConfirm: () {
          Navigator.pop(ctx);
          _approve(id);
        },
      ),
    );
  }

  void _showRejectModal(int id) {
    String catatan = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Tolak Pengajuan', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
              const SizedBox(height: 4),
              Text('Masukkan alasan penolakan untuk karyawan', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Tulis alasan penolakan...',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                maxLines: 3,
                onChanged: (v) => catatan = v,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Batal', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF64748B))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (catatan.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wajib mengisi alasan penolakan')));
                          return;
                        }
                        Navigator.pop(ctx);
                        _reject(id, catatan.trim());
                      },
                      child: Text('Tolak Pengajuan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailPengajuanModal(Map<String, dynamic> p) {
    final k = p['karyawan'];
    final tglMulai = _formatDate(p['tanggal_mulai']);
    final tglSelesai = _formatDate(p['tanggal_selesai']);
    final tglPengajuan = _formatDate(p['created_at']);
    final namaJabatan = k?['jabatan']?['nama_jabatan'] ?? '-';
    final namaCabang = k?['cabang']?['nama_cabang'] ?? '-';

    int durasi = 1;
    try {
      final dMulai = DateTime.parse(p['tanggal_mulai'].toString());
      final dSelesai = DateTime.parse(p['tanggal_selesai'].toString());
      durasi = dSelesai.difference(dMulai).inDays + 1;
    } catch (_) {}

    final isPending = (p['status']?.toString().toLowerCase() ?? '') == 'pending';
    final isApproved = (p['status']?.toString().toLowerCase() ?? '') == 'disetujui';
    final isRejected = (p['status']?.toString().toLowerCase() ?? '') == 'ditolak';

    final statusColor = isApproved
        ? const Color(0xFF059669)
        : (isRejected ? const Color(0xFFDC2626) : const Color(0xFFD97706));
    final statusBg = isApproved
        ? const Color(0xFFECFDF5)
        : (isRejected ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB));
    final statusBorder = isApproved
        ? const Color(0xFFA7F3D0)
        : (isRejected ? const Color(0xFFFECACA) : const Color(0xFFFDE68A));

    final isCuti = (p['jenis']?.toString().toLowerCase() ?? '') == 'cuti';
    final jenisColor = isCuti ? const Color(0xFF7E22CE) : const Color(0xFFD97706);
    final jenisBg = isCuti ? const Color(0xFFFAF5FF) : const Color(0xFFFFFBEB);
    final jenisBorder = isCuti ? const Color(0xFFE9D5FF) : const Color(0xFFFDE68A);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header Modal
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        isCuti ? Icons.beach_access_rounded : Icons.sick_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Detail Pengajuan',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: jenisBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: jenisBorder),
                              ),
                              child: Text(
                                p['jenis'].toString().toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: jenisColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Diajukan pada $tglPengajuan',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF64748B).withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _buildAvatar(k, size: 60, radius: 16),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  k?['nama'] ?? '-',
                                  style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: Text(
                                        namaJabatan,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '• $namaCabang',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Detail Information Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF64748B).withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Tanggal Mulai', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 4),
                                    Text(tglMulai, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Tanggal Selesai', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 4),
                                    Text(tglSelesai, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Durasi', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 4),
                                    Text('$durasi Hari', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Status', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusBg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: statusBorder),
                                      ),
                                      child: Text(
                                        isApproved ? 'Disetujui' : (isRejected ? 'Ditolak' : 'Pending'),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 16),

                          Text('Alasan Pengajuan', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              (p['alasan'] != null && p['alasan'].toString().isNotEmpty) ? p['alasan'].toString() : '-',
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155), height: 1.4),
                            ),
                          ),

                          if (p['catatan_hrd'] != null && p['catatan_hrd'].toString().isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text('Catatan HRD', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Text(
                                p['catatan_hrd'].toString(),
                                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF991B1B)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (isPending) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: const BorderSide(color: Color(0xFFEF4444)),
                                foregroundColor: const Color(0xFFEF4444),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showRejectModal(p['id']);
                              },
                              child: Text('Tolak', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showApproveConfirm(p['id']);
                              },
                              child: Text('Setujui Pengajuan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ] else if (isApproved) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showNotifyCsOptions(p);
                          },
                          icon: const Icon(Icons.campaign_rounded, size: 18),
                          label: Text('Beritahu CS (Notif / WhatsApp)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Tutup Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Tutup', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF475569))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

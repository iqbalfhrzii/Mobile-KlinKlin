import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/file_attachment_preview.dart';
import '../services/operasional_pengumuman_service.dart';
import 'operasional_pengumuman_form_sheet.dart';

class OperasionalPengumumanScreen extends StatefulWidget {
  const OperasionalPengumumanScreen({super.key});

  @override
  State<OperasionalPengumumanScreen> createState() => _OperasionalPengumumanScreenState();
}

class _OperasionalPengumumanScreenState extends State<OperasionalPengumumanScreen> with SingleTickerProviderStateMixin {
  final _service = OperasionalPengumumanService();
  final _searchController = TextEditingController();

  late TabController _tabController;
  List<dynamic> _pengumumanList = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Timer? _debounce;
  String _userRole = '';

  bool get _canCreatePengumuman {
    final r = _userRole.toLowerCase().trim();
    if (r.isEmpty) return false;
    if (r.contains('cleaner') || r.contains('customer service') || r == 'cs') {
      return false;
    }
    return true;
  }

  final Color _primaryEmerald = const Color(0xFF059669);
  final Color _lightEmerald = const Color(0xFFECFDF5);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _fetchPengumuman(page: 1);
      }
    });
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userRole = prefs.getString('user_role') ?? '';
      });
      _fetchPengumuman(page: 1);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchPengumuman(page: 1);
    });
  }

  Future<void> _fetchPengumuman({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final currentTab = !_canCreatePengumuman
        ? 'diterima'
        : (_tabController.index == 0 ? 'diterima' : 'dibuat');
    final res = await _service.getPengumuman(
      tab: currentTab,
      search: _searchController.text.trim(),
      page: page,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['status'] == true && res['data'] != null) {
          final data = res['data'];
          if (data is Map && data['data'] != null) {
            _pengumumanList = data['data'];
          } else if (data is List) {
            _pengumumanList = data;
          }
        } else {
          if (res['message'] != null && res['message'].toString().isNotEmpty && res['status'] == false) {
            _errorMessage = res['message'].toString();
          }
        }
      });
    }
  }

  void _openForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: OperasionalPengumumanFormSheet(
            onSave: () {
              Navigator.pop(context);
              _tabController.animateTo(1); // Switch to "Dibuat" tab
              _fetchPengumuman(page: 1);
            },
          ),
        ),
      ),
    );
  }

  void _showDetailModal(dynamic data) {
    final judul = data['judul'] ?? 'Pengumuman';
    final isi = data['isi'] ?? '-';
    final pengirimNama = data['pengirim']?['nama'] ?? 'Kantor Pusat';
    final pengirimJabatan = data['pengirim']?['jabatan']?['nama_jabatan'] ?? 'Manajemen';
    final pengirimCabang = data['pengirim']?['cabang']?['nama_cabang'] ?? '';
    final filePath = (data['file_path'] ?? data['file'] ?? data['lampiran'])?.toString();

    final targetRoles = data['target_roles'];
    final targetCabangs = data['target_cabangs'];

    String formattedDate = '-';
    if (data['created_at'] != null) {
      try {
        formattedDate = DateFormat('EEEE, dd MMMM yyyy • HH:mm', 'id_ID').format(DateTime.parse(data['created_at'].toString()));
      } catch (_) {
        formattedDate = data['created_at'].toString();
      }
    }

    if (data['id'] != null) {
      _service.markAsRead(int.parse(data['id'].toString()));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 6),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Header Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 14, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _lightEmerald,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Icon(Icons.campaign_rounded, color: _primaryEmerald, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detail Pengumuman',
                          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        ),
                        Text(
                          'Informasi dan instruksi operasional',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Title Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFECFDF5),
                            const Color(0xFFF0FDF4),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _primaryEmerald,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'PENGUMUMAN RESMI',
                                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  formattedDate,
                                  textAlign: TextAlign.end,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF065F46)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            judul,
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), height: 1.3),
                          ),
                          const SizedBox(height: 14),

                          // Pengirim Tile
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: _primaryEmerald.withValues(alpha: 0.15),
                                  child: Text(
                                    pengirimNama.isNotEmpty ? pengirimNama[0].toUpperCase() : 'P',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _primaryEmerald),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pengirimNama,
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                      ),
                                      Text(
                                        '$pengirimJabatan ${pengirimCabang.isNotEmpty ? '• $pengirimCabang' : ''}',
                                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Target Audience Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.people_alt_outlined, size: 17, color: Color(0xFF475569)),
                              const SizedBox(width: 8),
                              Text(
                                'Ditujukan Untuk:',
                                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if ((targetRoles == null || (targetRoles is List && targetRoles.isEmpty)) &&
                              (targetCabangs == null || (targetCabangs is List && targetCabangs.isEmpty))) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.public_rounded, size: 15, color: _primaryEmerald),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Semua Karyawan (Seluruh Divisi & Cabang)',
                                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF065F46)),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (targetRoles != null && targetRoles is List && targetRoles.isNotEmpty)
                                  ...targetRoles.map((r) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.blue.shade200),
                                        ),
                                        child: Text(
                                          '👤 Jabatan: $r',
                                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                        ),
                                      )),
                                if (targetCabangs != null && targetCabangs is List && targetCabangs.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.purple.shade200),
                                    ),
                                    child: Text(
                                      '🏢 ${targetCabangs.length} Cabang Ditargetkan',
                                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.purple.shade800),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Message Content Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.notes_rounded, size: 18, color: _primaryEmerald),
                              const SizedBox(width: 8),
                              Text(
                                'Isi Pesan Pengumuman',
                                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isi,
                            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF334155), height: 1.6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // File Attachment if exists
                    if (filePath != null && filePath.isNotEmpty) ...[
                      FileAttachmentPreview.buildAttachmentCard(
                        context,
                        filePath: filePath,
                        label: 'Lampiran Berkas / Dokumen',
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: SafeArea(
                top: false,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Tutup Pengumuman', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: _canCreatePengumuman
          ? FloatingActionButton.extended(
              onPressed: _openForm,
              backgroundColor: _primaryEmerald,
              elevation: 4,
              icon: const Icon(Icons.campaign_rounded, color: Colors.white, size: 22),
              label: Text(
                'Buat Pengumuman',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            )
          : null,
      body: Column(
        children: [
          // Top Gradient Header
          GradientHeader(
            child: Row(
              children: [
                HeaderBackButton(onTap: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pengumuman',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pusat informasi resmi divisi & cabang',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _fetchPengumuman(page: 1),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // Friendly Segmented Tab Bar (Only for roles with creation rights)
          if (_canCreatePengumuman)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Container(
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1)),
                    ],
                  ),
                  labelColor: _primaryEmerald,
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  dividerHeight: 0,
                  labelPadding: EdgeInsets.zero,
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Diterima'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.send_rounded, size: 15),
                          SizedBox(width: 6),
                          Text('Dibuat'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Search Bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16, _canCreatePengumuman ? 0 : 12, 16, 12),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Cari judul atau isi pengumuman...',
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 19, color: Color(0xFF94A3B8)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded, size: 17, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            _searchController.clear();
                            _fetchPengumuman(page: 1);
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Body Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Gagal Memuat Pengumuman',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _errorMessage,
                                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12.5),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _fetchPengumuman(page: 1),
                                icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                                label: const Text('Coba Lagi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryEmerald,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _pengumumanList.isEmpty
                        ? RefreshIndicator(
                            onRefresh: () => _fetchPengumuman(page: 1),
                            child: ListView(
                              children: [
                                const SizedBox(height: 70),
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 32),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(24),
                                          decoration: BoxDecoration(
                                            color: _lightEmerald,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFFA7F3D0)),
                                          ),
                                          child: Icon(Icons.campaign_outlined, size: 54, color: _primaryEmerald),
                                        ),
                                        const SizedBox(height: 18),
                                        Text(
                                          _tabController.index == 0
                                              ? 'Belum Ada Pengumuman Diterima'
                                              : 'Belum Ada Pengumuman Dibuat',
                                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _tabController.index == 0
                                              ? 'Semua pengumuman dan instruksi resmi dari kantor pusat akan muncul di sini.'
                                              : 'Buat pengumuman baru untuk menyampaikan pesan ke cabang atau divisi tertentu.',
                                          style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13, height: 1.4),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 20),
                                        if (_tabController.index == 1) ...[
                                          ElevatedButton.icon(
                                            onPressed: _openForm,
                                            icon: const Icon(Icons.add_rounded, color: Colors.white),
                                            label: const Text('Buat Pengumuman Sekarang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _primaryEmerald,
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _fetchPengumuman(page: 1),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                              itemCount: _pengumumanList.length,
                              itemBuilder: (context, index) {
                                final item = _pengumumanList[index];
                                final judul = item['judul'] ?? 'Pengumuman';
                                final isi = item['isi'] ?? '-';
                                final pengirim = item['pengirim']?['nama'] ?? 'Kantor Pusat';
                                final hasFile = item['file_path'] != null && item['file_path'].toString().isNotEmpty;

                                final bool isUnread = item['pivot']?['is_read'] == false || item['pivot']?['is_read'] == 0;

                                String formattedDate = '-';
                                if (item['created_at'] != null) {
                                  try {
                                    formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(item['created_at'].toString()));
                                  } catch (_) {
                                    formattedDate = item['created_at'].toString();
                                  }
                                }

                                final targetRoles = item['target_roles'];
                                final targetCabangs = item['target_cabangs'];

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isUnread ? _primaryEmerald.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
                                      width: isUnread ? 1.6 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isUnread ? _primaryEmerald.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _showDetailModal(item),
                                      borderRadius: BorderRadius.circular(18),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // Header
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: isUnread ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                              border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: isUnread ? _lightEmerald : const Color(0xFFE2E8F0),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Icon(Icons.campaign_rounded, size: 16, color: isUnread ? _primaryEmerald : const Color(0xFF64748B)),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    formattedDate,
                                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                                                  ),
                                                ),
                                                if (isUnread) ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFD1FAE5),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: const Color(0xFF6EE7B7)),
                                                    ),
                                                    child: Text(
                                                      '✨ Baru',
                                                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF064E3B)),
                                                    ),
                                                  ),
                                                ] else ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                                    ),
                                                    child: Text(
                                                      'Oleh: $pengirim',
                                                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),

                                          // Body
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  judul,
                                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), height: 1.3),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  isi,
                                                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.45),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 12),

                                                // Target pills
                                                if ((targetRoles == null || (targetRoles is List && targetRoles.isEmpty)) &&
                                                    (targetCabangs == null || (targetCabangs is List && targetCabangs.isEmpty))) ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFECFDF5),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: const Color(0xFFA7F3D0)),
                                                    ),
                                                    child: Text(
                                                      '📢 Semua Karyawan',
                                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF065F46)),
                                                    ),
                                                  ),
                                                ] else ...[
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 6,
                                                    children: [
                                                      if (targetRoles != null && targetRoles is List && targetRoles.isNotEmpty)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: Colors.blue.shade50,
                                                            borderRadius: BorderRadius.circular(6),
                                                            border: Border.all(color: Colors.blue.shade200),
                                                          ),
                                                          child: Text(
                                                            '👤 ${targetRoles.length} Divisi',
                                                            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                                          ),
                                                        ),
                                                      if (targetCabangs != null && targetCabangs is List && targetCabangs.isNotEmpty)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: Colors.purple.shade50,
                                                            borderRadius: BorderRadius.circular(6),
                                                            border: Border.all(color: Colors.purple.shade200),
                                                          ),
                                                          child: Text(
                                                            '🏢 ${targetCabangs.length} Cabang',
                                                            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.purple.shade800),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),

                                          const Divider(height: 1, color: Color(0xFFF1F5F9)),

                                          // Footer
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            child: Row(
                                              children: [
                                                if (hasFile) ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.shade50,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.attach_file_rounded, size: 13, color: Colors.blue.shade700),
                                                        const SizedBox(width: 3),
                                                        Text(
                                                          'Berkas Lampiran',
                                                          style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                                const Spacer(),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: _lightEmerald,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        'Lihat Detail',
                                                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: _primaryEmerald),
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Icon(Icons.chevron_right_rounded, size: 16, color: _primaryEmerald),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

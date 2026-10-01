import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_compress_helper.dart';
import '../../../core/widgets/gradient_header.dart';
import '../models/pengajuan_fitur_model.dart';
import '../services/pengajuan_fitur_service.dart';

class PengajuanFiturScreen extends StatefulWidget {
  const PengajuanFiturScreen({super.key});

  @override
  State<PengajuanFiturScreen> createState() => _PengajuanFiturScreenState();
}

class _PengajuanFiturScreenState extends State<PengajuanFiturScreen> with SingleTickerProviderStateMixin {
  final PengajuanFiturService _service = PengajuanFiturService();
  late TabController _tabController;

  bool _isLoading = true;
  bool _isSuperadmin = false;
  int? _currentUserId;
  String _selectedKategori = 'semua'; // 'semua', 'website', 'aplikasi'

  List<PengajuanFiturModel> _antriList = [];
  List<PengajuanFiturModel> _prosesList = [];
  List<PengajuanFiturModel> _selesaiList = [];

  int _countAntri = 0;
  int _countProses = 0;
  int _countSelesai = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final result = await _service.getPengajuanList(kategori: _selectedKategori);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _isSuperadmin = result['is_superadmin'] == true;
          _currentUserId = result['current_user_id'] is int
              ? result['current_user_id'] as int
              : int.tryParse(result['current_user_id']?.toString() ?? '');
          _antriList = result['antri'] as List<PengajuanFiturModel>;
          _prosesList = result['proses'] as List<PengajuanFiturModel>;
          _selesaiList = result['selesai'] as List<PengajuanFiturModel>;

          final counts = result['counts'] as Map<String, dynamic>;
          _countAntri = counts['antri'] ?? _antriList.length;
          _countProses = counts['proses'] ?? _prosesList.length;
          _countSelesai = counts['selesai'] ?? _selesaiList.length;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal memuat data'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      });
    }
  }

  void _onKategoriChanged(String kategori) {
    if (_selectedKategori == kategori) return;
    setState(() {
      _selectedKategori = kategori;
    });
    _loadData();
  }

  Future<void> _updateStatus(PengajuanFiturModel item, String newStatus) async {
    final res = await _service.updateStatus(item.id, newStatus);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Status berhasil diperbarui'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Gagal mengubah status'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _approvePengajuan(PengajuanFiturModel item) async {
    setState(() => _isLoading = true);
    final res = await _service.approve(item.id);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Pengajuan telah Anda setujui.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Gagal menyetujui pengajuan'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _rejectPengajuan(PengajuanFiturModel item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Tolak Hasil Perbaikan?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Pengajuan akan dikembalikan ke status Proses agar tim developer memperbaiki kembali.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Ya, Kembalikan ke Proses',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final res = await _service.reject(item.id);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Pengajuan dikembalikan ke tahap proses.'),
          backgroundColor: const Color(0xFF0284C7),
        ),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Gagal menolak pengajuan'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _openDetailPhoto(String photoUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      padding: const EdgeInsets.all(24),
                      color: Colors.white,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            'Gagal memuat gambar lampiran',
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, color: Colors.white, size: 20),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBuatPengajuanSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BuatPengajuanSheet(
        onSuccess: () {
          _loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          _buildKategoriFilter(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListTab(_antriList, 'antri'),
                      _buildListTab(_prosesList, 'proses'),
                      _buildListTab(_selesaiList, 'selesai'),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openBuatPengajuanSheet,
        backgroundColor: const Color(0xFF059669),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Buat Pengajuan',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return GradientHeader(
      padding: EdgeInsets.fromLTRB(
        16,
        50,
        16,
        MediaQuery.of(context).padding.bottom > 0 ? 16 : 20,
      ),
      child: Row(
        children: [
          HeaderIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pengajuan Fitur & Bug',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Lihat status antrian dan progres pengajuan fitur & bug Anda.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          HeaderIconButton(
            icon: Icons.refresh_rounded,
            onTap: _loadData,
          ),
        ],
      ),
    );
  }

  Widget _buildKategoriFilter() {
    final categories = [
      {'key': 'semua', 'label': 'Semua', 'icon': null},
      {'key': 'website', 'label': 'Website', 'icon': '🌐'},
      {'key': 'aplikasi', 'label': 'Aplikasi Mobile', 'icon': '📱'},
    ];

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedKategori == cat['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _onKategoriChanged(cat['key']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (cat['key'] == 'aplikasi'
                          ? const Color(0xFF7C3AED)
                          : (cat['key'] == 'website'
                              ? const Color(0xFF0284C7)
                              : const Color(0xFF0F172A)))
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (cat['icon'] != null) ...[
                      Text(cat['icon']!, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      cat['label']!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF0F172A),
        unselectedLabelColor: const Color(0xFF64748B),
        indicatorColor: const Color(0xFF0284C7),
        indicatorWeight: 3,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Antri'),
                const SizedBox(width: 6),
                _buildTabBadge(_countAntri, const Color(0xFFF59E0B)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Sedang Diproses'),
                const SizedBox(width: 6),
                _buildTabBadge(_countProses, const Color(0xFF3B82F6)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Selesai (Terbaru)'),
                const SizedBox(width: 6),
                _buildTabBadge(_countSelesai, const Color(0xFF10B981)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildListTab(List<PengajuanFiturModel> items, String status) {
    if (items.isEmpty) {
      String emptyMessage;
      IconData emptyIcon;
      if (status == 'antri') {
        emptyMessage = 'Belum ada pengajuan dalam status antri.';
        emptyIcon = Icons.hourglass_empty_rounded;
      } else if (status == 'proses') {
        emptyMessage = 'Belum ada pengajuan yang sedang diproses.';
        emptyIcon = Icons.pending_actions_rounded;
      } else {
        emptyMessage = 'Belum ada pengajuan yang selesai.';
        emptyIcon = Icons.task_alt_rounded;
      }

      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 60),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(emptyIcon, size: 36, color: const Color(0xFF94A3B8)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildPengajuanCard(item);
        },
      ),
    );
  }

  Widget _buildPengajuanCard(PengajuanFiturModel item) {
    final isFitur = item.isFitur;
    final isAplikasi = item.isAplikasi;
    final bool isMine = (_currentUserId != null && item.karyawanId == _currentUserId);

    final formattedDate = item.createdAt != null
        ? DateFormat('d MMM yyyy, HH:mm').format(item.createdAt!)
        : '-';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetailPengajuanSheet(item),
        child: Container(
          decoration: BoxDecoration(
            color: isMine && item.status == 'selesai' ? const Color(0xFFF8FAFC) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isMine && item.status == 'selesai'
                  ? const Color(0xFFBAE6FD)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Badges & Date
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Badge Jenis
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isFitur
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isFitur
                                    ? const Color(0xFFA7F3D0)
                                    : const Color(0xFFFECDD3),
                              ),
                            ),
                            child: Text(
                              item.jenisLabel,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isFitur
                                    ? const Color(0xFF047857)
                                    : const Color(0xFFBE123C),
                              ),
                            ),
                          ),
                          // Badge Kategori
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isAplikasi
                                  ? const Color(0xFFF5F3FF)
                                  : const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isAplikasi
                                    ? const Color(0xFFDDD6FE)
                                    : const Color(0xFFBAE6FD),
                              ),
                            ),
                            child: Text(
                              isAplikasi ? '📱 Aplikasi' : '🌐 Website',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isAplikasi
                                    ? const Color(0xFF6D28D9)
                                    : const Color(0xFF0369A1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title: Kendala Utama
                Text(
                  item.kendalaUtama,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),

                // Description
                Text(
                  item.deskripsi,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                // Photo Button
                if (item.fotoHalamanUrl != null && item.fotoHalamanUrl!.isNotEmpty) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _openDetailPhoto(item.fotoHalamanUrl!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.attach_file_rounded, size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(
                            'Lihat Lampiran Foto',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Indicator if rejected and in proses
                if (item.status == 'proses' && item.isRejected) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.replay_rounded, color: Color(0xFFE11D48), size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Perlu perbaikan ulang dari hasil review pemohon',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFBE123C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Footer: Submitter info & Action (Superadmin)
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: isMine ? const Color(0xFFDBEAFE) : const Color(0xFFE2E8F0),
                        child: Text(
                          item.namaKaryawan != null && item.namaKaryawan!.isNotEmpty
                              ? item.namaKaryawan![0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isMine ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: item.namaKaryawan ?? 'Pengguna',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  if (isMine)
                                    TextSpan(
                                      text: ' (Anda)',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF2563EB),
                                      ),
                                    ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${item.jabatanKaryawan ?? '-'}${item.cabangKaryawan != null ? ' • ${item.cabangKaryawan}' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Action Button for Superadmin
                      if (_isSuperadmin && item.status == 'antri') ...[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () => _updateStatus(item, 'proses'),
                          child: Text(
                            'Proses >',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ] else if (_isSuperadmin && item.status == 'proses') ...[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () => _updateStatus(item, 'selesai'),
                          child: Text(
                            'Selesai ✓',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // User Approval Section (matching web Livewire design)
                if (item.status == 'selesai') ...[
                  if (isMine) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.isPendingApproval) ...[
                            Text(
                              'Apakah fitur/perbaikan ini sudah sesuai?',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E40AF),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      padding: const EdgeInsets.symmetric(vertical: 9),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    onPressed: () => _approvePengajuan(item),
                                    child: Text(
                                      'Sudah Sesuai',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF43F5E),
                                      padding: const EdgeInsets.symmetric(vertical: 9),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    onPressed: () => _rejectPengajuan(item),
                                    child: Text(
                                      'Belum Sesuai',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (item.isApproved) ...[
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Telah Disetujui',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else if (item.isApproved) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Telah disetujui pemohon',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailPengajuanSheet(PengajuanFiturModel item) {
    final bool isMine = (_currentUserId != null && item.karyawanId == _currentUserId);
    final isFitur = item.isFitur;
    final isAplikasi = item.isAplikasi;

    final formattedDate = item.createdAt != null
        ? DateFormat('d MMMM yyyy, HH:mm').format(item.createdAt!)
        : '-';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Detail Pengajuan',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges Row
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: item.status == 'selesai'
                                  ? const Color(0xFFECFDF5)
                                  : (item.status == 'proses'
                                      ? const Color(0xFFEFF6FF)
                                      : const Color(0xFFFFFBEB)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: item.status == 'selesai'
                                    ? const Color(0xFFA7F3D0)
                                    : (item.status == 'proses'
                                        ? const Color(0xFFBFDBFE)
                                        : const Color(0xFFFDE68A)),
                              ),
                            ),
                            child: Text(
                              item.statusLabel.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: item.status == 'selesai'
                                    ? const Color(0xFF047857)
                                    : (item.status == 'proses'
                                        ? const Color(0xFF1D4ED8)
                                        : const Color(0xFFB45309)),
                              ),
                            ),
                          ),
                          // Jenis Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isFitur ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isFitur ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3),
                              ),
                            ),
                            child: Text(
                              item.jenisLabel,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isFitur ? const Color(0xFF047857) : const Color(0xFFBE123C),
                              ),
                            ),
                          ),
                          // Kategori Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isAplikasi ? const Color(0xFFF5F3FF) : const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isAplikasi ? const Color(0xFFDDD6FE) : const Color(0xFFBAE6FD),
                              ),
                            ),
                            child: Text(
                              isAplikasi ? '📱 Aplikasi Mobile' : '🌐 Website',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isAplikasi ? const Color(0xFF6D28D9) : const Color(0xFF0369A1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Kendala Utama / Judul
                      Text(
                        'Kendala / Usulan Utama',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.kendalaUtama,
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 16),

                      // Deskripsi Detail
                      Text(
                        'Deskripsi Detail',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: SelectableText(
                          item.deskripsi,
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155), height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Info Pengaju
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Diajukan Oleh', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                                Text(
                                  '${item.namaKaryawan ?? 'Pengguna'}${isMine ? ' (Anda)' : ''}',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Jabatan & Cabang', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                                Text(
                                  '${item.jabatanKaryawan ?? '-'}${item.cabangKaryawan != null ? ' • ${item.cabangKaryawan}' : ''}',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Waktu Pengajuan', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                                Text(
                                  formattedDate,
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF334155)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Lampiran Foto
                      if (item.fotoHalamanUrl != null && item.fotoHalamanUrl!.isNotEmpty) ...[
                        Text(
                          'Lampiran Foto',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _openDetailPhoto(item.fotoHalamanUrl!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Image.network(
                                  item.fotoHalamanUrl!,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 120,
                                    color: const Color(0xFFF1F5F9),
                                    child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey)),
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text('Ketuk untuk perbesar', style: GoogleFonts.inter(fontSize: 10, color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Approval Actions inside Bottom Sheet
                      if (item.status == 'selesai' && isMine) ...[
                        if (item.isPendingApproval) ...[
                          Text(
                            'Persetujuan Hasil Perbaikan',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                  label: Text(
                                    'Sudah Sesuai',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _approvePengajuan(item);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF43F5E),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.cancel_rounded, color: Colors.white, size: 18),
                                  label: Text(
                                    'Belum Sesuai',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _rejectPengajuan(item);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ] else if (item.isApproved) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Perbaikan ini telah Anda setujui',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF047857)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],

                      // Superadmin Change Status inside Bottom Sheet
                      if (_isSuperadmin) ...[
                        const SizedBox(height: 12),
                        if (item.status == 'antri')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _updateStatus(item, 'proses');
                              },
                              child: Text(
                                'Pindahkan ke Sedang Diproses >',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                              ),
                            ),
                          )
                        else if (item.status == 'proses')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _updateStatus(item, 'selesai');
                              },
                              child: Text(
                                'Tandai Selesai ✓',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// -------------------------------------------------------------
// Sheet Buat Pengajuan
// -------------------------------------------------------------
class _BuatPengajuanSheet extends StatefulWidget {
  final VoidCallback onSuccess;

  const _BuatPengajuanSheet({required this.onSuccess});

  @override
  State<_BuatPengajuanSheet> createState() => _BuatPengajuanSheetState();
}

class _BuatPengajuanSheetState extends State<_BuatPengajuanSheet> {
  final _formKey = GlobalKey<FormState>();
  final _service = PengajuanFiturService();
  final _picker = ImagePicker();

  String _jenis = 'pengajuan_fitur'; // 'pengajuan_fitur' | 'pelaporan_bug'
  String _kategori = 'aplikasi';      // Default in mobile app is 'aplikasi'
  final _kendalaCtrl = TextEditingController();
  final _deskripsiCtrl = TextEditingController();

  File? _selectedImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _kendalaCtrl.dispose();
    _deskripsiCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        final compressed = await ImageCompressHelper.compressXFileIfNeeded(picked);
        if (compressed != null) {
          setState(() {
            _selectedImage = compressed;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih gambar: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pilih Sumber Foto',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0284C7)),
                title: Text('Kamera', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF059669)),
                title: Text('Galeri', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wajib melampirkan screenshot / foto halaman!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final res = await _service.submitPengajuan(
      jenis: _jenis,
      kategori: _kategori,
      kendalaUtama: _kendalaCtrl.text.trim(),
      deskripsi: _deskripsiCtrl.text.trim(),
      fotoFile: _selectedImage!,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      Navigator.pop(context);
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Pengajuan berhasil dikirim!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Gagal mengirim pengajuan'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Buat Pengajuan',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Form Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kategori Platform
                    Text(
                      'Kategori Platform',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildChoiceButton(
                            label: '📱 Aplikasi Mobile',
                            isSelected: _kategori == 'aplikasi',
                            selectedColor: const Color(0xFF7C3AED),
                            onTap: () => setState(() => _kategori = 'aplikasi'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildChoiceButton(
                            label: '🌐 Website',
                            isSelected: _kategori == 'website',
                            selectedColor: const Color(0xFF0284C7),
                            onTap: () => setState(() => _kategori = 'website'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Jenis Pengajuan
                    Text(
                      'Jenis Pengajuan',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildChoiceButton(
                            label: '✨ Fitur Baru',
                            isSelected: _jenis == 'pengajuan_fitur',
                            selectedColor: const Color(0xFF059669),
                            onTap: () => setState(() => _jenis = 'pengajuan_fitur'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildChoiceButton(
                            label: '🐞 Bug (Error)',
                            isSelected: _jenis == 'pelaporan_bug',
                            selectedColor: const Color(0xFFE11D48),
                            onTap: () => setState(() => _jenis = 'pelaporan_bug'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Kendala Utama
                    Text(
                      'Kendala / Usulan Utama',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _kendalaCtrl,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Tombol simpan tidak berfungsi',
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Kendala utama wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Deskripsi Lengkap
                    Text(
                      'Deskripsi Lengkap',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _deskripsiCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Ceritakan detail kendala atau fitur yang diinginkan...',
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Deskripsi wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Lampiran Foto (Wajib)
                    Text(
                      'Foto Halaman / Screenshot (Wajib)',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedImage == null)
                      InkWell(
                        onTap: _showImageSourcePicker,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFCBD5E1),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate_rounded, size: 36, color: Color(0xFF059669)),
                              const SizedBox(height: 8),
                              Text(
                                'Upload Screenshot Halaman Terkait',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Kamera atau Galeri (Maks 10 MB)',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImage!,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedImage!.path.split(Platform.pathSeparator).last,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1E293B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Foto siap diunggah',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF059669),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48)),
                              onPressed: () => setState(() => _selectedImage = null),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Submit Buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                            child: Text(
                              'Batal',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            onPressed: _isSubmitting ? null : _submit,
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    'Kirim Pengajuan',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceButton({
    required String label,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? selectedColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? selectedColor : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}

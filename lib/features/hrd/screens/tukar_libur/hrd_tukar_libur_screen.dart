import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/data/hrd_models.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../services/hrd_service.dart';
import '../../services/hrd_tukar_libur_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/whatsapp_icon.dart';

class HrdTukarLiburScreen extends StatefulWidget {
  const HrdTukarLiburScreen({super.key});

  @override
  State<HrdTukarLiburScreen> createState() => _HrdTukarLiburScreenState();
}

class _HrdTukarLiburScreenState extends State<HrdTukarLiburScreen> {
  final HrdService _hrdService = HrdService();

  bool _isLoading = true;
  List<dynamic> _allList = [];
  List<dynamic> _pendingList = [];
  List<dynamic> _riwayatList = [];
  List<CabangModel> _cabangList = [];

  Map<String, dynamic> _stats = {
    'total_pending': 0,
    'total_approved': 0,
    'total_rejected': 0,
    'total': 0,
  };

  String _activeTab = 'all'; // 'all', 'pending', 'approved', 'rejected'
  int? _selectedCabangId;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadCabangs();
    _fetchData();
  }

  Future<void> _loadCabangs() async {
    try {
      final cabangs = await _hrdService.fetchCabang();
      if (mounted) {
        setState(() {
          _cabangList = cabangs.where((c) => !c.namaCabang.toLowerCase().contains('kantor pusat')).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final monthStr = DateFormat('yyyy-MM').format(_selectedMonth);
      final res = await HrdTukarLiburService.getPengajuanTukarLibur(
        cabangId: _selectedCabangId,
        bulan: monthStr,
        search: _searchQuery,
      );

      if (mounted) {
        setState(() {
          _pendingList = res['pending'] as List<dynamic>? ?? [];
          _riwayatList = res['riwayat'] as List<dynamic>? ?? [];
          _allList = res['all'] as List<dynamic>? ?? [];
          if (res['stats'] is Map<String, dynamic>) {
            _stats = res['stats'] as Map<String, dynamic>;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data tukar libur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<dynamic> get _filteredList {
    if (_activeTab == 'pending') {
      return _pendingList;
    } else if (_activeTab == 'approved') {
      return _riwayatList.where((item) => item['status'] == 'approved').toList();
    } else if (_activeTab == 'rejected') {
      return _riwayatList.where((item) => item['status'] == 'rejected').toList();
    }
    return _allList;
  }

  bool get _hasActiveFilter =>
      _selectedCabangId != null ||
      _searchQuery.isNotEmpty;

  String _getCabangName(int? cabangId) {
    if (cabangId == null) return 'Semua Cabang';
    final found = _cabangList.where((c) => c.id == cabangId);
    return found.isNotEmpty ? found.first.namaCabang : 'Cabang #$cabangId';
  }

  String _formatDate(String? rawDate, {bool withTime = false}) {
    if (rawDate == null || rawDate.isEmpty) return '-';
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      final monthName = months[dt.month - 1];
      if (withTime) {
        final hour = dt.hour.toString().padLeft(2, '0');
        final min = dt.minute.toString().padLeft(2, '0');
        return '${dt.day} $monthName ${dt.year}, $hour:$min';
      }
      return '${dt.day} $monthName ${dt.year}';
    } catch (_) {
      return rawDate;
    }
  }

  String _monthName(int month) {
    const m = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return m[month - 1];
  }

  void _stepMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    });
    _fetchData();
  }

  Future<void> _handleApprove(dynamic item) async {
    final pengajuNama = item['pengaju']?['nama'] ?? 'Cleaner A';
    final targetNama = item['target']?['nama'] ?? 'Cleaner B';
    final tglA = _formatDate(item['tanggal_pengaju']);
    final tglB = _formatDate(item['tanggal_target']);

    final confirm = await AppConfirmationDialog.show(
      context,
      title: 'Setujui Tukar Libur',
      message: 'Apakah Anda yakin ingin menyetujui pertukaran libur ini?',
      type: ConfirmationDialogType.success,
      confirmText: 'Setujui & Tukar',
      cancelText: 'Batal',
      contentWidget: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 13)),
                Expanded(
                  child: Text(
                    '$pengajuNama akan libur pada $tglB',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 13)),
                Expanded(
                  child: Text(
                    '$targetNama akan libur pada $tglA',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF059669)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Jadwal libur di sistem absensi akan otomatis ditukar.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF047857),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final res = await HrdTukarLiburService.approve(item['id']);
      if (mounted) Navigator.pop(context); // close loading

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(res['message'] ?? 'Pengajuan tukar libur disetujui & CS otomatis diberitahu.')),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        _fetchData();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // close loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyetujui: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _notifyCsInApp(int id) async {
    try {
      final res = await HrdTukarLiburService.notifyCs(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(res['message'] ?? 'Notifikasi tukar libur berhasil dikirim ke CS')),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim notifikasi ke CS: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _sendTukarLiburInfoToCSWA(dynamic item, {String? targetPhone}) async {
    final pengajuNama = item['pengaju']?['nama'] ?? 'Cleaner A';
    final pengajuCabang = item['pengaju']?['cabang']?['nama_cabang'] ?? 'Cabang';
    final targetNama = item['target']?['nama'] ?? 'Cleaner B';
    final tglPengaju = _formatDate(item['tanggal_pengaju']);
    final tglTarget = _formatDate(item['tanggal_target']);
    final alasan = (item['alasan'] != null && item['alasan'].toString().isNotEmpty) ? item['alasan'].toString() : '-';

    final message = '''🔄 *INFO TUKAR LIBUR CLEANER*
Halo tim CS *$pengajuCabang*,
Diberitahukan bahwa pertukaran libur cleaner telah *DISETUJUI* oleh HRD:

👤 *Cleaner A*: *$pengajuNama*
📅 *Jadwal Libur Baru*: *$tglTarget* (Semula $tglPengaju)

👤 *Cleaner B*: *$targetNama*
📅 *Jadwal Libur Baru*: *$tglPengaju* (Semula $tglTarget)

📝 *Alasan*: $alasan

⚠️ *Catatan untuk CS*:
Mohon sesuaikan alokasi & jadwal penugasan pesanan cleaner di cabang terkait. Terima kasih! 🙏''';

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

  void _showNotifyCsOptions(dynamic item) {
    final pengajuNama = item['pengaju']?['nama'] ?? 'Cleaner A';
    final targetNama = item['target']?['nama'] ?? 'Cleaner B';

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
                        'Beritahu CS (Tukar Libur)',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '$pengajuNama ⇄ $targetNama',
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
                _sendTukarLiburInfoToCSWA(item);
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
                            'Buka WhatsApp dengan pesan format info tukar libur yang rapi',
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
                _notifyCsInApp(item['id']);
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
                            'Kirim notif pengingat tukar libur ke CS cabang terkait & seluruh CS',
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

  Future<void> _handleReject(dynamic item) async {
    final confirm = await AppConfirmationDialog.show(
      context,
      title: 'Tolak Tukar Libur',
      message: 'Apakah Anda yakin ingin menolak pengajuan pertukaran libur ini?',
      type: ConfirmationDialogType.danger,
      confirmText: 'Tolak Pengajuan',
      cancelText: 'Batal',
      isDestructive: true,
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final res = await HrdTukarLiburService.reject(item['id']);
      if (mounted) Navigator.pop(context); // close loading

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Pengajuan tukar libur ditolak.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        _fetchData();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // close loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menolak: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final listToShow = _filteredList;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            child: Row(
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
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tukar Libur Cleaner',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kelola pengajuan pertukaran libur antar Cleaner',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _fetchData,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Body Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month Navigator Card
                    _buildMonthNavigator(),
                    const SizedBox(height: 12),

                    // 4 Stat Summary Cards
                    _buildStatSummaryRow(),
                    const SizedBox(height: 14),

                    // Search & Filter Row
                    _buildSearchAndFilterRow(),
                    const SizedBox(height: 12),

                    // Status ChoiceChips
                    _buildStatusChoiceChips(),

                    // Active Filter Tags (if any)
                    if (_hasActiveFilter) ...[
                      const SizedBox(height: 10),
                      _buildActiveFilterChips(),
                    ],
                    const SizedBox(height: 16),

                    // Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _activeTab == 'pending'
                              ? 'Menunggu Persetujuan'
                              : (_activeTab == 'approved'
                                  ? 'Riwayat Disetujui'
                                  : (_activeTab == 'rejected' ? 'Riwayat Ditolak' : 'Semua Pengajuan')),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${listToShow.length} Data',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // List Items
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (listToShow.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.event_repeat_rounded, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'Tidak ada pengajuan tukar libur.',
                                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: listToShow.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = listToShow[index];
                          return _buildTukarLiburCard(item);
                        },
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

  // --- 1. MONTH NAVIGATOR ---
  Widget _buildMonthNavigator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'Periode: ${_monthName(_selectedMonth.month)} ${_selectedMonth.year}',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => _stepMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                color: const Color(0xFF334155),
              ),
              IconButton(
                onPressed: () => _stepMonth(1),
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                color: const Color(0xFF334155),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 2. STAT SUMMARY ROW (4 STATS) ---
  Widget _buildStatSummaryRow() {
    final pending = _stats['total_pending'] ?? 0;
    final approved = _stats['total_approved'] ?? 0;
    final rejected = _stats['total_rejected'] ?? 0;
    final total = _stats['total'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildSingleStat(
            title: 'Menunggu',
            value: '$pending',
            icon: Icons.hourglass_top_rounded,
            color: const Color(0xFFD97706),
            bg: const Color(0xFFFFFBEB),
            tabKey: 'pending',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSingleStat(
            title: 'Disetujui',
            value: '$approved',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF059669),
            bg: const Color(0xFFECFDF5),
            tabKey: 'approved',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSingleStat(
            title: 'Ditolak',
            value: '$rejected',
            icon: Icons.cancel_outlined,
            color: const Color(0xFFDC2626),
            bg: const Color(0xFFFEF2F2),
            tabKey: 'rejected',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSingleStat(
            title: 'Total',
            value: '$total',
            icon: Icons.swap_horiz_rounded,
            color: const Color(0xFF2563EB),
            bg: const Color(0xFFEFF6FF),
            tabKey: 'all',
          ),
        ),
      ],
    );
  }

  Widget _buildSingleStat({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bg,
    required String tabKey,
  }) {
    final isSelected = _activeTab == tabKey;
    return InkWell(
      onTap: () => setState(() => _activeTab = tabKey),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? color.withValues(alpha: 0.12) : const Color(0xFF64748B).withValues(alpha: 0.04),
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
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
                  child: Icon(icon, size: 13, color: color),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: isSelected ? color : const Color(0xFF0F172A),
              ),
            ),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. SEARCH & FILTER ROW (MATCHING PENGAJUAN STYLE) ---
  Widget _buildSearchAndFilterRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _searchQuery.isNotEmpty ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                width: _searchQuery.isNotEmpty ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF64748B).withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _fetchData();
              },
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Cari cleaner, cabang, alasan...',
                hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                          _fetchData();
                        },
                        child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
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
              color: _hasActiveFilter ? const Color(0xFF2563EB) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hasActiveFilter ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: _hasActiveFilter
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
                  color: _hasActiveFilter ? Colors.white : const Color(0xFF334155),
                ),
                if (_hasActiveFilter)
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
    );
  }

  // --- 4. STATUS CHOICECHIPS ROW ---
  Widget _buildStatusChoiceChips() {
    final chips = [
      {'key': 'all', 'label': 'SEMUA', 'count': _allList.length},
      {'key': 'pending', 'label': 'MENUNGGU', 'count': _pendingList.length},
      {'key': 'approved', 'label': 'DISETUJUI', 'count': _riwayatList.where((e) => e['status'] == 'approved').length},
      {'key': 'rejected', 'label': 'DITOLAK', 'count': _riwayatList.where((e) => e['status'] == 'rejected').length},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((c) {
          final isSelected = _activeTab == c['key'];
          final count = c['count'] as int;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${c['label']} ($count)'),
              selected: isSelected,
              onSelected: (val) {
                setState(() => _activeTab = c['key'] as String);
              },
              selectedColor: const Color(0xFF2563EB),
              backgroundColor: Colors.white,
              labelStyle: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- 5. ACTIVE FILTER CHIPS ---
  Widget _buildActiveFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
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
                        _fetchData();
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
                _selectedCabangId = null;
                _searchQuery = '';
                _searchCtrl.clear();
              });
              _fetchData();
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
    );
  }

  // --- 6. TUKAR LIBUR CARD ---
  Widget _buildTukarLiburCard(dynamic item) {
    final status = (item['status'] ?? 'pending').toString().toLowerCase();
    final bool isPending = status == 'pending';
    final bool isApproved = status == 'approved';

    final pengajuNama = item['pengaju']?['nama'] ?? 'Cleaner A';
    final pengajuCabang = item['pengaju']?['cabang']?['nama_cabang'] ?? '-';
    final targetNama = item['target']?['nama'] ?? 'Cleaner B';
    final targetCabang = item['target']?['cabang']?['nama_cabang'] ?? '-';

    final tglA = _formatDate(item['tanggal_pengaju']);
    final tglB = _formatDate(item['tanggal_target']);
    final tglPengajuan = _formatDate(item['created_at'], withTime: true);
    final alasan = item['alasan'] ?? '-';

    final hrdNama = item['hrd']?['nama'] ?? 'HRD';

    Color statusColor = const Color(0xFFD97706);
    Color statusBg = const Color(0xFFFFFBEB);
    Color statusBorder = const Color(0xFFFDE68A);
    String statusLabel = 'Menunggu';

    if (isApproved) {
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFECFDF5);
      statusBorder = const Color(0xFFA7F3D0);
      statusLabel = 'Disetujui';
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEF2F2);
      statusBorder = const Color(0xFFFECACA);
      statusLabel = 'Ditolak';
    }

    final initialA = pengajuNama.trim().isNotEmpty ? pengajuNama.trim()[0].toUpperCase() : 'A';
    final initialB = targetNama.trim().isNotEmpty ? targetNama.trim()[0].toUpperCase() : 'B';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPending ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
          width: isPending ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isPending ? const Color(0xFFD97706).withValues(alpha: 0.08) : const Color(0xFF64748B).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showDetailPengajuanModal(item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Date & Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          tglPengajuan,
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusBorder),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Visual Swap Box (Cleaner A <-> Cleaner B / Self Swap)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      // Cleaner A (Pengaju)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: const Color(0xFFEFF6FF),
                                  child: Text(
                                    initialA,
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    pengajuNama,
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Libur Asal:', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                            Text(
                              tglA,
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626)),
                            ),
                            if (pengajuCabang != '-')
                              Text(pengajuCabang, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                          ],
                        ),
                      ),

                      // Middle Swap Icon
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: (item['pengaju_id'] == item['target_id'] ? const Color(0xFF059669) : const Color(0xFF2563EB)).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item['pengaju_id'] == item['target_id'] ? Icons.arrow_forward_rounded : Icons.swap_horiz_rounded,
                          size: 18,
                          color: item['pengaju_id'] == item['target_id'] ? const Color(0xFF059669) : const Color(0xFF2563EB),
                        ),
                      ),

                      // Cleaner B (Target / Self Swap New Day)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: const Color(0xFFECFDF5),
                                  child: Text(
                                    item['pengaju_id'] == item['target_id'] ? '★' : initialB,
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item['pengaju_id'] == item['target_id'] ? 'Libur Baru (Mandiri)' : targetNama,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: item['pengaju_id'] == item['target_id'] ? const Color(0xFF059669) : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(item['pengaju_id'] == item['target_id'] ? 'Libur Pengganti:' : 'Libur Asal:', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                            Text(
                              tglB,
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFF059669)),
                            ),
                            if (targetCabang != '-')
                              Text(targetCabang, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Alasan Box
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                          children: [
                            const TextSpan(text: 'Alasan: ', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                            TextSpan(text: alasan, style: const TextStyle(fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Processed by info for History
                if (!isPending) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(isApproved ? Icons.verified_user_rounded : Icons.info_outline_rounded, size: 13, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          '$statusLabel oleh $hrdNama',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action Buttons for Pending
                if (isPending) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _handleReject(item),
                          icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                          label: Text(
                            'Tolak',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _handleApprove(item),
                          icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                          label: Text(
                            'Setujui & Tukar',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
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
                      onPressed: () => _showNotifyCsOptions(item),
                      icon: const Icon(Icons.campaign_rounded, size: 16),
                      label: Text('Beritahu CS', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // Bottom Tap Hint
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

  // --- 7. DETAIL BOTTOM SHEET MODAL ---
  void _showDetailPengajuanModal(dynamic item) {
    final status = (item['status'] ?? 'pending').toString().toLowerCase();
    final bool isPending = status == 'pending';
    final bool isApproved = status == 'approved';

    final pengajuNama = item['pengaju']?['nama'] ?? 'Cleaner A';
    final pengajuCabang = item['pengaju']?['cabang']?['nama_cabang'] ?? '-';
    final targetNama = item['target']?['nama'] ?? 'Cleaner B';
    final targetCabang = item['target']?['cabang']?['nama_cabang'] ?? '-';

    final tglPengaju = _formatDate(item['tanggal_pengaju']);
    final tglTarget = _formatDate(item['tanggal_target']);
    final tglPengajuan = _formatDate(item['created_at'], withTime: true);
    final alasan = item['alasan'] ?? '-';
    final hrdNama = item['hrd']?['nama'] ?? 'HRD';

    Color statusColor = const Color(0xFFD97706);
    Color statusBg = const Color(0xFFFFFBEB);
    Color statusBorder = const Color(0xFFFDE68A);
    String statusLabel = 'Menunggu Persetujuan';

    if (isApproved) {
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFECFDF5);
      statusBorder = const Color(0xFFA7F3D0);
      statusLabel = 'Disetujui';
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEF2F2);
      statusBorder = const Color(0xFFFECACA);
      statusLabel = 'Ditolak';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
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

              // Title & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Tukar Libur',
                        style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      Text(
                        'Diajukan pada $tglPengajuan',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusBorder),
                    ),
                    child: Text(
                      statusLabel,
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 16),

              // Summary Box: Cleaner A & Cleaner B
              Row(
                children: [
                  Expanded(
                    child: _buildEmployeeDetailBox(
                      title: 'Pengaju (Cleaner A)',
                      nama: pengajuNama,
                      cabang: pengajuCabang,
                      liburAwal: tglPengaju,
                      liburBaru: tglTarget,
                      color: const Color(0xFF2563EB),
                      bg: const Color(0xFFEFF6FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildEmployeeDetailBox(
                      title: 'Target (Cleaner B)',
                      nama: targetNama,
                      cabang: targetCabang,
                      liburAwal: tglTarget,
                      liburBaru: tglPengaju,
                      color: const Color(0xFF059669),
                      bg: const Color(0xFFECFDF5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Alasan Box
              Text('Alasan Pengajuan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
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
                  alasan,
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                ),
              ),

              if (!isPending) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(isApproved ? Icons.verified_user_rounded : Icons.info_outline_rounded, size: 16, color: statusColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Status: $statusLabel oleh $hrdNama',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Actions if pending
              if (isPending) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleReject(item);
                        },
                        icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFDC2626)),
                        label: Text('Tolak', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleApprove(item);
                        },
                        icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                        label: Text('Setujui & Tukar', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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
                      _showNotifyCsOptions(item);
                    },
                    icon: const Icon(Icons.campaign_rounded, size: 18),
                    label: Text('Beritahu CS (Notif / WhatsApp)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmployeeDetailBox({
    required String title,
    required String nama,
    required String cabang,
    required String liburAwal,
    required String liburBaru,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(nama, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (cabang != '-')
            Text(cabang, style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
          const SizedBox(height: 8),
          Text('Libur Semula: $liburAwal', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
          Text('Libur Baru: $liburBaru', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // --- 8. FILTER BOTTOM SHEET MODAL ---
  void _showFilterModal() {
    int? tempCabangId = _selectedCabangId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Filter Tukar Libur', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
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

                  // Cabang Dropdown
                  Text('Cabang Karyawan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    initialValue: tempCabangId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Semua Cabang')),
                      ..._cabangList.map((c) => DropdownMenuItem(value: c.id, child: Text(c.namaCabang))),
                    ],
                    onChanged: (val) {
                      setModalState(() {
                        tempCabangId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Actions: Reset & Terapkan
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedCabangId = null;
                            });
                            _fetchData();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Reset Filter', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedCabangId = tempCabangId;
                            });
                            _fetchData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Terapkan Filter', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

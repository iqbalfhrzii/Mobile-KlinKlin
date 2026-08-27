import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/animated_notification_bell.dart';
import '../services/designer_service.dart';

class DesignerDashboardScreen extends StatefulWidget {
  const DesignerDashboardScreen({super.key});

  @override
  State<DesignerDashboardScreen> createState() => _DesignerDashboardScreenState();
}

class _DesignerDashboardScreenState extends State<DesignerDashboardScreen> {
  final DesignerService _service = DesignerService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = true;
  String _userName = 'Designer';
  String _selectedStatus = 'Semua Status';
  List<dynamic> _requests = [];

  // Metrics
  int _pendingCount = 0;
  int _inProgressCount = 0;
  int _doneCount = 0;
  int _totalCount = 0;

  final List<String> _statusOptions = [
    'Semua Status',
    'Pending',
    'In Progress',
    'Selesai',
    'Ditolak',
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userName = prefs.getString('user_name') ?? 'Designer';
      });
    }
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      String? statusQuery;
      if (_selectedStatus == 'Pending') {
        statusQuery = 'pending';
      } else if (_selectedStatus == 'In Progress') {
        statusQuery = 'in_progress';
      } else if (_selectedStatus == 'Selesai') {
        statusQuery = 'done';
      } else if (_selectedStatus == 'Ditolak') {
        statusQuery = 'rejected';
      }

      final res = await _service.fetchPermintaanDesign(
        search: _searchController.text.trim(),
        status: statusQuery,
        all: true,
      );

      if (res['status'] == true && res['data'] != null) {
        final dataObj = res['data'];
        List<dynamic> list = [];
        if (dataObj is Map && dataObj['data'] is List) {
          list = dataObj['data'];
        } else if (dataObj is List) {
          list = dataObj;
        }

        // Calculate metrics
        int pending = 0;
        int inProg = 0;
        int done = 0;
        for (var item in list) {
          final s = (item['status'] ?? '').toString().toLowerCase();
          if (s == 'pending' || s == 'menunggu') {
            pending++;
          } else if (s == 'in_progress' || s == 'in progress' || s == 'process' || s == 'dikerjakan') {
            inProg++;
          } else if (s == 'done' || s == 'selesai' || s == 'completed') {
            done++;
          }
        }

        if (mounted) {
          setState(() {
            _requests = list;
            _pendingCount = pending;
            _inProgressCount = inProg;
            _doneCount = done;
            _totalCount = list.length;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  String _getFormattedDate() {
    final dt = DateTime.now();
    final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: const Color(0xFF2563EB),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. HEADER
            SliverToBoxAdapter(child: _buildHeader(context)),

            // 2. BODY CONTENT
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Metrics Cards
                  _buildMetricsRow(),
                  const SizedBox(height: 18),

                  // Section Title & Search
                  _buildSearchAndFilterSection(),
                  const SizedBox(height: 14),

                  // Request List or Loading
                  if (_isLoading)
                    _buildLoadingList()
                  else if (_requests.isEmpty)
                    _buildEmptyState()
                  else
                    ..._requests.map((item) => _buildRequestCard(context, item)),

                  const SizedBox(height: 30),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 1. HEADER =================
  Widget _buildHeader(BuildContext context) {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset('assets/images/logo.png', height: 22),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AnimatedNotificationBell(size: 24),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(
                      Icons.palette_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getFormattedDate(),
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_getGreeting()},',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          Text(
            '$_userName ✨',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Kelola dan kerjakan seluruh materi kreatif & desain.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  // ================= 2. METRICS ROW =================
  Widget _buildMetricsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Pending',
            count: _pendingCount,
            icon: Icons.hourglass_top_rounded,
            color: const Color(0xFFD97706),
            bgColor: const Color(0xFFFFFBEB),
            borderColor: const Color(0xFFFDE68A),
            onTap: () {
              setState(() => _selectedStatus = 'Pending');
              _fetchData();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            title: 'In Progress',
            count: _inProgressCount,
            icon: Icons.pending_actions_rounded,
            color: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
            borderColor: const Color(0xFFBFDBFE),
            onTap: () {
              setState(() => _selectedStatus = 'In Progress');
              _fetchData();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            title: 'Selesai',
            count: _doneCount,
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF059669),
            bgColor: const Color(0xFFECFDF5),
            borderColor: const Color(0xFFECFDF5),
            onTap: () {
              setState(() => _selectedStatus = 'Selesai');
              _fetchData();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 4. SEARCH & FILTER CHIPS =================
  Widget _buildSearchAndFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Daftar Permintaan Desain',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$_totalCount Data',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Search Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Cari judul brief atau pengirim...',
              hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchController.clear();
                        _fetchData();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Filter Chips Horizontal Scroll
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _statusOptions.map((status) {
              final isSelected = _selectedStatus == status;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    status,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  showCheckmark: false,
                  onSelected: (val) {
                    if (val) {
                      setState(() => _selectedStatus = status);
                      _fetchData();
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ================= 5. REQUEST CARD =================
  Widget _buildRequestCard(BuildContext context, dynamic item) {
    final judul = item['judul'] ?? '-';
    final deskripsi = item['deskripsi'] ?? '';
    final status = (item['status'] ?? 'pending').toString().toLowerCase();
    final createdAt = item['created_at'] ?? '';
    final lampiranPengirim = item['lampiran_pengirim'];
    final lampiranDesigner = item['lampiran_designer'];
    final catatan = item['catatan_designer'];

    // Sender Info
    final pengirim = item['pengirim'];
    String senderName = '-';
    String senderRole = '';
    if (pengirim is Map) {
      senderName = pengirim['nama'] ?? pengirim['name'] ?? '-';
      if (pengirim['jabatan'] is Map) {
        senderRole = pengirim['jabatan']['nama_jabatan'] ?? '';
      }
    }

    // Accurate Status Evaluation
    final bool isDone = status == 'done' || status == 'selesai' || status == 'completed';
    final bool isInProgress = status == 'in_progress' || status == 'in progress' || status == 'process' || status == 'dikerjakan';
    final bool isRejected = status == 'rejected' || status == 'ditolak';

    Color badgeColor = const Color(0xFFD97706);
    Color badgeBg = const Color(0xFFFFFBEB);
    Color borderLeftColor = const Color(0xFFF59E0B);
    String statusText = 'Pending';

    if (isInProgress) {
      badgeColor = const Color(0xFF2563EB);
      badgeBg = const Color(0xFFEFF6FF);
      borderLeftColor = const Color(0xFF3B82F6);
      statusText = 'In Progress';
    } else if (isDone) {
      badgeColor = const Color(0xFF059669);
      badgeBg = const Color(0xFFECFDF5);
      borderLeftColor = const Color(0xFF10B981);
      statusText = 'Selesai';
    } else if (isRejected) {
      badgeColor = const Color(0xFFDC2626);
      badgeBg = const Color(0xFFFEF2F2);
      borderLeftColor = const Color(0xFFEF4444);
      statusText = 'Ditolak';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: borderLeftColor, width: 4.5)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Title & Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          judul,
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.person_rounded, size: 13, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                senderRole.isNotEmpty ? '$senderName ($senderRole)' : senderName,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),

              // Description Snippet
              if (deskripsi.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Text(
                    deskripsi,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF475569),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              // Badges for attachments / notes
              if (lampiranPengirim != null || lampiranDesigner != null || (catatan != null && catatan.toString().isNotEmpty)) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (lampiranPengirim != null)
                      _buildChipTag('Brief Terlampir', Icons.attach_file_rounded, const Color(0xFF2563EB)),
                    if (lampiranDesigner != null)
                      _buildChipTag('Hasil Terunggah', Icons.cloud_done_rounded, const Color(0xFF059669)),
                    if (catatan != null && catatan.toString().isNotEmpty)
                      _buildChipTag('Ada Catatan', Icons.comment_rounded, const Color(0xFF7C3AED)),
                  ],
                ),
              ],

              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),

              // Bottom Row: Date & Action Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => _openDetailSheet(context, item),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Lihat Detail',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.white),
                        ],
                      ),
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

  Widget _buildChipTag(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ================= 6. DETAIL & ACTION MODAL =================
  void _openDetailSheet(BuildContext context, dynamic item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DesignerActionSheet(
        item: item,
        onUpdated: _fetchData,
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildLoadingList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: Column(
        children: List.generate(
          3,
          (_) => Container(
            height: 130,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.brush_outlined, size: 36, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 14),
          Text(
            'Tidak Ada Permintaan Desain',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _selectedStatus == 'Semua Status'
                ? 'Belum ada tiket permintaan desain yang masuk saat ini.'
                : 'Tidak ada permintaan dengan filter "$_selectedStatus".',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= 6. DETAIL & ACTION BOTTOM SHEET =================
class _DesignerActionSheet extends StatefulWidget {
  final dynamic item;
  final VoidCallback onUpdated;

  const _DesignerActionSheet({
    required this.item,
    required this.onUpdated,
  });

  @override
  State<_DesignerActionSheet> createState() => _DesignerActionSheetState();
}

class _DesignerActionSheetState extends State<_DesignerActionSheet> {
  final DesignerService _service = DesignerService();
  final TextEditingController _noteController = TextEditingController();

  bool _isSaving = false;
  String? _selectedFilePath;
  String? _selectedFileName;

  @override
  void initState() {
    super.initState();
    _noteController.text = widget.item['catatan_designer'] ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf', 'zip', 'psd', 'ai', 'svg'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
        _selectedFileName = result.files.single.name;
      });
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isSaving = true);
    final id = widget.item['id'];
    try {
      final res = await _service.updatePermintaanStatus(
        id,
        status: newStatus,
        catatan: _noteController.text.trim(),
        filePath: _selectedFilePath,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        if (res['status'] == true) {
          Navigator.pop(context);
          widget.onUpdated();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Status berhasil diperbarui menjadi ${newStatus.toUpperCase()}'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Gagal memperbarui status'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final judul = widget.item['judul'] ?? '-';
    final deskripsi = widget.item['deskripsi'] ?? '';
    final status = (widget.item['status'] ?? 'pending').toString().toLowerCase();
    final lampiranPengirim = widget.item['lampiran_pengirim'];
    final lampiranDesigner = widget.item['lampiran_designer'];

    final pengirim = widget.item['pengirim'];
    String senderName = '-';
    String senderRole = '';
    String senderCabang = '';
    if (pengirim is Map) {
      senderName = pengirim['nama'] ?? pengirim['name'] ?? '-';
      if (pengirim['jabatan'] is Map) {
        senderRole = pengirim['jabatan']['nama_jabatan'] ?? '';
      }
      if (pengirim['cabang'] is Map) {
        senderCabang = pengirim['cabang']['nama_cabang'] ?? '';
      }
    }

    // Accurate Status Flags
    final bool isDone = status == 'done' || status == 'selesai' || status == 'completed';
    final bool isInProgress = status == 'in_progress' || status == 'in progress' || status == 'process' || status == 'dikerjakan';
    final bool isRejected = status == 'rejected' || status == 'ditolak';
    final bool isPending = !isDone && !isInProgress && !isRejected;

    Color badgeColor = const Color(0xFFD97706);
    Color badgeBg = const Color(0xFFFFFBEB);
    String statusText = 'Pending';

    if (isInProgress) {
      badgeColor = const Color(0xFF2563EB);
      badgeBg = const Color(0xFFEFF6FF);
      statusText = 'In Progress';
    } else if (isDone) {
      badgeColor = const Color(0xFF059669);
      badgeBg = const Color(0xFFECFDF5);
      statusText = 'Selesai';
    } else if (isRejected) {
      badgeColor = const Color(0xFFDC2626);
      badgeBg = const Color(0xFFFEF2F2);
      statusText = 'Ditolak';
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header Row: Title, Status Badge, and Close Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        judul,
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              statusText,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (senderCabang.isNotEmpty)
                            Text(
                              'Cabang: $senderCabang',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 14),

            // 1. INFORMASI PENGIRIM CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          senderName,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          senderRole.isNotEmpty ? senderRole : 'Karyawan',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 2. DESKRIPSI BRIEF
            Text(
              'Deskripsi / Brief Permintaan:',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF334155),
              ),
            ),
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
                deskripsi.isNotEmpty ? deskripsi : 'Tidak ada deskripsi detail.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: const Color(0xFF334155),
                  height: 1.45,
                ),
              ),
            ),

            // 3. LAMPIRAN DARI PENGIRIM
            if (lampiranPengirim != null && lampiranPengirim.toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  final rawPath = lampiranPengirim.toString();
                  final url = rawPath.startsWith('http')
                      ? rawPath
                      : 'https://erp.klinklin.online/storage/$rawPath';
                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file_rounded, color: Color(0xFF2563EB), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lihat Lampiran / Brief dari Pengirim',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const Icon(Icons.open_in_new_rounded, color: Color(0xFF2563EB), size: 16),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),

            // 4. TINDAK LANJUT DESIGNER
            Text(
              'Tindak Lanjut Designer:',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),

            // Catatan & Link Hasil (Drive / Figma / Canva)
            Text(
              'Catatan & Link Hasil (Drive / Canva / Figma):',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Tuliskan catatan revisi atau tempel link Google Drive / Canva / Figma...',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),

            // Upload File Hasil Desain Picker
            Text(
              'Upload File Hasil Desain (Opsional):',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _selectedFileName != null ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedFileName != null ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedFileName != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                      color: _selectedFileName != null ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedFileName ?? 'Pilih file hasil desain / ZIP / PNG / PDF...',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _selectedFileName != null ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          fontWeight: _selectedFileName != null ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_selectedFileName != null)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedFilePath = null;
                            _selectedFileName = null;
                          });
                        },
                        icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFEF4444)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            ),

            // Existing Result File Preview (if any)
            if (lampiranDesigner != null && lampiranDesigner.toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () {
                  final rawPath = lampiranDesigner.toString();
                  final url = rawPath.startsWith('http')
                      ? rawPath
                      : 'https://erp.klinklin.online/storage/$rawPath';
                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.download_done_rounded, color: Color(0xFF059669), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'File Hasil Desain Terunggah (Ketuk untuk Unduh/Lihat)',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ),
                      const Icon(Icons.open_in_new_rounded, color: Color(0xFF059669), size: 14),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // 5. CONTEXTUAL ACTION BUTTONS (Matching Web UX)
            if (_isSaving)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                ),
              )
            else ...[
              // A. Status is PENDING
              if (isPending) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: () => _updateStatus('in_progress'),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(
                          'Tandai Sedang Dikerjakan',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: () => _updateStatus('rejected'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          backgroundColor: const Color(0xFFFEF2F2),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Tolak',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ]

              // B. Status is IN PROGRESS
              else if (isInProgress) ...[
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _updateStatus('done'),
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text(
                          'Selesaikan & Kirim Hasil',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _updateStatus('pending'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFD97706),
                              side: const BorderSide(color: Color(0xFFFDE68A)),
                              backgroundColor: const Color(0xFFFFFBEB),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Kembalikan ke Pending',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _updateStatus('rejected'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(color: Color(0xFFFCA5A5)),
                              backgroundColor: const Color(0xFFFEF2F2),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Tolak Permintaan',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ]

              // C. Status is SELESAI / DONE
              else if (isDone) ...[
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Desain ini telah selesai & terkirim ke pemohon.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _updateStatus('done'),
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: Text(
                          'Perbarui Catatan / File Hasil',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => _updateStatus('in_progress'),
                      child: Text(
                        'Buka Kembali Pengerjaan (Perlu Revisi)',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
              ]

              // D. Status is DITOLAK / REJECTED
              else if (isRejected) ...[
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Permintaan ini telah ditolak.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _updateStatus('in_progress'),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(
                          'Buka Kembali & Mulai Kerjakan',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

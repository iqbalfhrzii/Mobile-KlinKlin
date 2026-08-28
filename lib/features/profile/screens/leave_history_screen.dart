import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/leave_service.dart';
import 'leave_request_screen.dart';

class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({super.key});

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  final LeaveService _service = LeaveService();
  
  bool _isLoading = true;
  List<dynamic> _history = [];
  String _activeFilter = 'semua'; // 'semua', 'pending', 'disetujui', 'ditolak'

  int _jatahCuti = 0;
  int _sisaCuti = 0;
  bool _hasQuota = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _service.getLeaveHistory(),
        _service.getLeaveQuota(),
      ]);

      final historyRes = results[0];
      final quotaRes = results[1];

      if (mounted) {
        setState(() {
          _history = historyRes['data'] ?? [];
          if (quotaRes['data'] != null) {
            _jatahCuti = quotaRes['data']['jatah_cuti'] ?? 0;
            _sisaCuti = quotaRes['data']['sisa_cuti'] ?? 0;
            _hasQuota = true;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s == 'disetujui' || s == 'diterima' || s == 'approved') {
      return const Color(0xFF059669);
    } else if (s == 'ditolak' || s == 'rejected') {
      return const Color(0xFFDC2626);
    }
    return const Color(0xFFD97706); // pending / menunggu
  }

  Color _getStatusBgColor(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s == 'disetujui' || s == 'diterima' || s == 'approved') {
      return const Color(0xFFECFDF5);
    } else if (s == 'ditolak' || s == 'rejected') {
      return const Color(0xFFFEF2F2);
    }
    return const Color(0xFFFFFBEB); // pending
  }

  String _getStatusLabel(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s == 'disetujui' || s == 'diterima' || s == 'approved') {
      return 'DISETUJUI';
    } else if (s == 'ditolak' || s == 'rejected') {
      return 'DITOLAK';
    }
    return 'MENUNGGU';
  }

  IconData _getTypeIcon(String? type) {
    final t = (type ?? '').toLowerCase();
    if (t.contains('sakit')) return Icons.medical_services_rounded;
    if (t.contains('cuti')) return Icons.beach_access_rounded;
    if (t.contains('tukar')) return Icons.event_repeat_rounded;
    return Icons.event_note_rounded;
  }

  Color _getTypeColor(String? type) {
    final t = (type ?? '').toLowerCase();
    if (t.contains('sakit')) return const Color(0xFFEA580C);
    if (t.contains('cuti')) return const Color(0xFF2563EB);
    if (t.contains('tukar')) return const Color(0xFF7C3AED);
    return const Color(0xFF0D9488);
  }

  int _calculateDays(String? startStr, String? endStr) {
    if (startStr == null || endStr == null) return 1;
    try {
      final s = DateTime.parse(startStr);
      final e = DateTime.parse(endStr);
      final diff = e.difference(s).inDays + 1;
      return diff > 0 ? diff : 1;
    } catch (_) {
      return 1;
    }
  }

  String _formatDateRange(String? startStr, String? endStr) {
    if (startStr == null) return '-';
    try {
      final s = DateTime.parse(startStr);
      final e = endStr != null ? DateTime.parse(endStr) : s;
      final isSameDay = s.year == e.year && s.month == e.month && s.day == e.day;
      
      if (isSameDay) {
        return DateFormat('d MMM yyyy', 'id_ID').format(s);
      } else if (s.year == e.year && s.month == e.month) {
        return '${s.day} - ${DateFormat('d MMM yyyy', 'id_ID').format(e)}';
      } else {
        return '${DateFormat('d MMM', 'id_ID').format(s)} - ${DateFormat('d MMM yyyy', 'id_ID').format(e)}';
      }
    } catch (_) {
      return startStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Count stats
    int countPending = 0;
    int countApproved = 0;
    int countRejected = 0;

    for (var item in _history) {
      final s = (item['status'] ?? '').toString().toLowerCase();
      if (s == 'disetujui' || s == 'diterima' || s == 'approved') {
        countApproved++;
      } else if (s == 'ditolak' || s == 'rejected') {
        countRejected++;
      } else {
        countPending++;
      }
    }

    final filtered = _history.where((item) {
      final s = (item['status'] ?? '').toString().toLowerCase();
      if (_activeFilter == 'pending') {
        return s != 'disetujui' && s != 'diterima' && s != 'approved' && s != 'ditolak' && s != 'rejected';
      } else if (_activeFilter == 'disetujui') {
        return s == 'disetujui' || s == 'diterima' || s == 'approved';
      } else if (_activeFilter == 'ditolak') {
        return s == 'ditolak' || s == 'rejected';
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                HeaderBackButton(onTap: () => Navigator.pop(context)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Riwayat Pengajuan',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Daftar permohonan cuti, izin & sakit Anda',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LeaveRequestScreen()),
                    );
                    _loadData();
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  ),
                  tooltip: 'Ajukan Cuti / Izin',
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: AppColors.primary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_hasQuota) _buildQuotaCard(),
                          const SizedBox(height: 14),
                          _buildFilterTabs(countPending, countApproved, countRejected),
                          const SizedBox(height: 14),
                          if (filtered.isEmpty)
                            _buildEmptyState()
                          else
                            ListView.separated(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return _buildLeaveCard(item);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LeaveRequestScreen()),
          );
          _loadData();
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Ajukan Cuti / Izin',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13.5),
        ),
      ),
    );
  }

  Widget _buildQuotaCard() {
    final cutiTerpakai = (_jatahCuti - _sisaCuti).clamp(0, _jatahCuti);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sisa Cuti Tahunan',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'Periode tahun berjalan',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_sisaCuti Hari Tersedia',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Total Jatah',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_jatahCuti Hari',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Terpakai',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$cutiTerpakai Hari',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFEA580C)),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Sisa Aktif',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_sisaCuti Hari',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(int pending, int approved, int rejected) {
    final tabs = [
      {'key': 'semua', 'label': 'Semua', 'count': _history.length, 'color': AppColors.textDark},
      {'key': 'pending', 'label': 'Menunggu', 'count': pending, 'color': const Color(0xFFD97706)},
      {'key': 'disetujui', 'label': 'Disetujui', 'count': approved, 'color': const Color(0xFF059669)},
      {'key': 'ditolak', 'label': 'Ditolak', 'count': rejected, 'color': const Color(0xFFDC2626)},
    ];

    return Row(
      children: tabs.map((t) {
        final isSelected = _activeFilter == t['key'];
        final color = t['color'] as Color;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () => setState(() => _activeFilter = t['key'] as String),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? color : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? color : AppColors.border,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      t['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${t['count']}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLeaveCard(dynamic item) {
    final jenis = (item['jenis_pengajuan'] ?? item['jenis'] ?? 'Cuti').toString();
    final status = (item['status'] ?? 'Pending').toString();
    final startStr = item['tanggal_mulai']?.toString();
    final endStr = item['tanggal_selesai']?.toString();
    final alasan = item['alasan']?.toString() ?? '-';
    final adminNote = item['catatan_admin']?.toString();
    final hasPhoto = item['bukti_foto'] != null || item['bukti_foto_url'] != null;

    final statusColor = _getStatusColor(status);
    final statusBgColor = _getStatusBgColor(status);
    final statusLabel = _getStatusLabel(status);

    final typeColor = _getTypeColor(jenis);
    final typeIcon = _getTypeIcon(jenis);
    final days = _calculateDays(startStr, endStr);
    final dateRange = _formatDateRange(startStr, endStr);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetailBottomSheet(item),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Type Pill & Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 13, color: typeColor),
                          const SizedBox(width: 5),
                          Text(
                            jenis.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: typeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            statusLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Date Range & Duration Badge
                Row(
                  children: [
                    const Icon(Icons.event_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        dateRange,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
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
                        '$days Hari',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Reason Preview
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.format_quote_rounded, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          alasan,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textDark,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Rejection Reason Box if Rejected
                if (status.toLowerCase().contains('tolak') && adminNote != null && adminNote.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Alasan Ditolak: $adminNote',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF7F1D1D),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (hasPhoto)
                      Row(
                        children: [
                          const Icon(Icons.attachment_rounded, size: 14, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(
                            'Ada Bukti Foto',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      children: [
                        Text(
                          'Lihat Detail',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_available_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Tidak ada pengajuan pada kategori ini.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --- DETAIL BOTTOM SHEET ---
  void _showDetailBottomSheet(dynamic item) {
    final jenis = (item['jenis_pengajuan'] ?? item['jenis'] ?? 'Cuti').toString();
    final status = (item['status'] ?? 'Pending').toString();
    final startStr = item['tanggal_mulai']?.toString();
    final endStr = item['tanggal_selesai']?.toString();
    final alasan = item['alasan']?.toString() ?? '-';
    final adminNote = item['catatan_admin']?.toString();
    final photoUrl = item['bukti_foto_url'] ?? item['bukti_foto'];
    
    String? formattedCreatedAt;
    if (item['created_at'] != null) {
      try {
        final dt = DateTime.parse(item['created_at'].toString()).toLocal();
        formattedCreatedAt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
      } catch (_) {
        formattedCreatedAt = item['created_at'].toString();
      }
    }

    final statusColor = _getStatusColor(status);
    final statusBgColor = _getStatusBgColor(status);
    final statusLabel = _getStatusLabel(status);
    final typeColor = _getTypeColor(jenis);
    final typeIcon = _getTypeIcon(jenis);
    final days = _calculateDays(startStr, endStr);
    final dateRange = _formatDateRange(startStr, endStr);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pull bar
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
              const SizedBox(height: 16),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(typeIcon, color: typeColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detail Pengajuan',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            jenis.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: typeColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 16),

              // Status Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      statusLabel == 'DISETUJUI' 
                          ? Icons.check_circle_rounded 
                          : (statusLabel == 'DITOLAK' ? Icons.cancel_rounded : Icons.pending_rounded),
                      color: statusColor,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status: $statusLabel',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                          if (statusLabel == 'MENUNGGU')
                            Text(
                              'Permohonan sedang ditinjau oleh HRD/Admin.',
                              style: GoogleFonts.inter(fontSize: 11, color: statusColor),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Detail Info Pillars
              _buildDetailRow('Periode Izin / Cuti', dateRange),
              const SizedBox(height: 10),
              _buildDetailRow('Total Durasi', '$days Hari Kerja'),
              const SizedBox(height: 10),
              _buildDetailRow('Alasan Lengkap', alasan),

              if (adminNote != null && adminNote.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildDetailRow('Catatan Admin / HRD', adminNote, isWarning: true),
              ],

              if (formattedCreatedAt != null) ...[
                const SizedBox(height: 10),
                _buildDetailRow('Waktu Pengajuan', formattedCreatedAt),
              ],

              if (photoUrl != null && photoUrl.toString().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Lampiran Bukti Foto',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    photoUrl.toString(),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 80,
                      color: const Color(0xFFF1F5F9),
                      alignment: Alignment.center,
                      child: Text('Foto tidak dapat dimuat', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isWarning = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWarning ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isWarning ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isWarning ? const Color(0xFFDC2626) : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isWarning ? const Color(0xFF7F1D1D) : AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

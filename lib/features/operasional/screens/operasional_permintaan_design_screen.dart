import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/api/api_client.dart';
import '../services/operasional_permintaan_design_service.dart';
import 'operasional_permintaan_design_form_sheet.dart';

class OperasionalPermintaanDesignScreen extends StatefulWidget {
  const OperasionalPermintaanDesignScreen({super.key});

  @override
  State<OperasionalPermintaanDesignScreen> createState() => _OperasionalPermintaanDesignScreenState();
}

class _OperasionalPermintaanDesignScreenState extends State<OperasionalPermintaanDesignScreen> {
  final _service = OperasionalPermintaanDesignService();
  final _searchController = TextEditingController();

  List<dynamic> _requests = [];
  bool _isLoading = false;
  String _selectedStatus = 'all';

  final Color _primaryThemeColor = AppColors.primaryMid; // KlinKlin Blue

  @override
  void initState() {
    super.initState();
    _fetchRequests(page: 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequests({int page = 1}) async {
    setState(() => _isLoading = true);

    final res = await _service.getPermintaanDesign(
      search: _searchController.text.trim(),
      status: _selectedStatus == 'all' ? null : _selectedStatus,
      page: page,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['status'] == true && res['data'] != null) {
          final data = res['data'];
          if (data is Map && data['data'] != null) {
            _requests = data['data'];
          } else if (data is List) {
            _requests = data;
          }
        }
      });
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'selesai':
        return Colors.green.shade700;
      case 'in_progress':
      case 'dikerjakan':
      case 'proses':
        return Colors.blue.shade700;
      case 'pending':
      case 'menunggu':
        return Colors.amber.shade900;
      case 'rejected':
      case 'ditolak':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Color _getStatusBgColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'selesai':
        return Colors.green.shade50;
      case 'in_progress':
      case 'dikerjakan':
      case 'proses':
        return Colors.blue.shade50;
      case 'pending':
      case 'menunggu':
        return Colors.amber.shade50;
      case 'rejected':
      case 'ditolak':
        return Colors.red.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'selesai':
        return 'Selesai';
      case 'in_progress':
      case 'dikerjakan':
      case 'proses':
        return 'Dikerjakan';
      case 'pending':
      case 'menunggu':
        return 'Pending';
      case 'rejected':
      case 'ditolak':
        return 'Ditolak';
      default:
        return status ?? 'Pending';
    }
  }

  void _openForm({Map<String, dynamic>? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: OperasionalPermintaanDesignFormSheet(
          initialData: item,
          onSave: () {
            Navigator.pop(context);
            _fetchRequests(page: 1);
          },
        ),
      ),
    );
  }

  void _showDetail(dynamic data) {
    final status = data['status']?.toString();
    final lampiranPengirim = data['lampiran_pengirim']?.toString();
    final catatanDesigner = data['catatan_designer']?.toString();
    final lampiranDesigner = data['lampiran_designer']?.toString();

    String formattedDate = '-';
    if (data['created_at'] != null) {
      try {
        formattedDate = DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.parse(data['created_at']));
      } catch (_) {
        formattedDate = data['created_at'].toString();
      }
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryThemeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.brush_rounded, color: _primaryThemeColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Detail Permintaan Design', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Judul & Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('JUDUL DESIGN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          Text(data['judul'] ?? '-', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusBgColor(status),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _getStatusLabel(status),
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _getStatusColor(status)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tanggal
                Text('TANGGAL PENGAJUAN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Text(formattedDate, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark)),
                const SizedBox(height: 16),

                // Brief
                Text('BRIEF & KEBUTUHAN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    (data['deskripsi'] == null || data['deskripsi'].toString().isEmpty) ? '-' : data['deskripsi'],
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),

                // Lampiran Pengirim
                if (lampiranPengirim != null && lampiranPengirim.isNotEmpty) ...[
                  Text('LAMPIRAN ANDA', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _openUrl(lampiranPengirim),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.attachment, color: Colors.blue.shade700, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lampiranPengirim.split('/').last,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.open_in_new, color: Colors.blue.shade700, size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Feedback Designer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueGrey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.palette_outlined, size: 16, color: Colors.blueGrey.shade700),
                          const SizedBox(width: 6),
                          Text('Feedback dari Designer', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if ((catatanDesigner == null || catatanDesigner.isEmpty) && (lampiranDesigner == null || lampiranDesigner.isEmpty))
                        Text('Belum ada respon atau hasil dari Designer.', style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade600))
                      else ...[
                        if (catatanDesigner != null && catatanDesigner.isNotEmpty) ...[
                          Text('Catatan:', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                          const SizedBox(height: 2),
                          Text(catatanDesigner, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark)),
                          const SizedBox(height: 8),
                        ],
                        if (lampiranDesigner != null && lampiranDesigner.isNotEmpty) ...[
                          ElevatedButton.icon(
                            onPressed: () => _openUrl(lampiranDesigner),
                            icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                            label: Text('Download Hasil Design', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade700,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryMid,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Text('Tutup', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String path) async {
    String finalUrl = path;
    if (!path.startsWith('http')) {
      final baseUrl = ApiClient.baseUrl.replaceAll('/api', '');
      final cleanPath = path.startsWith('/') ? path.substring(1) : path;
      finalUrl = '$baseUrl/storage/$cleanPath';
    }

    final uri = Uri.parse(finalUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka file lampiran')));
      }
    }
  }

  Future<void> _deleteRequest(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Permintaan?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Permintaan design ini akan dihapus dari sistem.', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final res = await _service.deletePermintaanDesign(id);
    if (mounted) Navigator.pop(context);

    if (!mounted) return;

    if (res['status'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permintaan berhasil dihapus'), backgroundColor: Colors.green),
      );
      _fetchRequests(page: 1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Gagal menghapus permintaan'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primaryMid,
        elevation: 3,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Buat Permintaan', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
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
                        'Permintaan Design',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Ajukan dan pantau status permintaan design Anda',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _fetchRequests(page: 1),
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),

          // Search and status filter bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onSubmitted: (_) => _fetchRequests(page: 1),
                          style: GoogleFonts.inter(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Cari judul design...',
                            hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                            prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _fetchRequests(page: 1),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: _primaryThemeColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(child: Icon(Icons.tune, color: Colors.white, size: 18)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Status Filter Badges
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusFilterChip('all', 'Semua Status'),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('pending', 'Pending'),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('in_progress', 'Dikerjakan'),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('completed', 'Selesai'),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('rejected', 'Ditolak'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                    ? RefreshIndicator(
                        onRefresh: () => _fetchRequests(page: 1),
                        child: ListView(
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.brush_outlined, size: 64, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Anda belum pernah membuat permintaan design.',
                                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => _openForm(),
                                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                                    label: Text('Buat Permintaan Baru', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryMid,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      elevation: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _fetchRequests(page: 1),
                        child: ListView.separated(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 80),
                          itemCount: _requests.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _requests[index];
                            final status = item['status']?.toString();
                            final isPending = status == 'pending';
                            final hasResponse = (item['catatan_designer'] != null && item['catatan_designer'].toString().isNotEmpty) ||
                                (item['lampiran_designer'] != null && item['lampiran_designer'].toString().isNotEmpty);

                            String formattedDate = '-';
                            if (item['created_at'] != null) {
                              try {
                                formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(item['created_at']));
                              } catch (_) {
                                formattedDate = item['created_at'].toString();
                              }
                            }

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Row 1: Title & Status Badge
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item['judul'] ?? '-',
                                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _getStatusBgColor(status),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.3)),
                                              ),
                                              child: Text(
                                                _getStatusLabel(status),
                                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(status)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),

                                        // Row 2: Date
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey.shade500),
                                            const SizedBox(width: 4),
                                            Text(
                                              formattedDate,
                                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Row 3: Brief preview
                                        Text(
                                          item['deskripsi'] ?? '-',
                                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),

                                        if (hasResponse) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.teal.shade200),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_circle_outline, size: 12, color: Colors.teal.shade700),
                                                const SizedBox(width: 4),
                                                Text('Ada respon dari Designer', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1, color: Color(0xFFEEEEEE)),

                                  // Footer actions
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () => _showDetail(item),
                                          style: TextButton.styleFrom(
                                            backgroundColor: AppColors.primaryMid,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Text('Lihat Detail', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                        ),
                                        if (isPending) ...[
                                          const SizedBox(width: 4),
                                          IconButton(
                                            onPressed: () => _openForm(item: item),
                                            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                            padding: const EdgeInsets.all(6),
                                            constraints: const BoxConstraints(),
                                          ),
                                          IconButton(
                                            onPressed: () => _deleteRequest(item['id']),
                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                            padding: const EdgeInsets.all(6),
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
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

  Widget _buildStatusFilterChip(String statusKey, String label) {
    final isSelected = _selectedStatus == statusKey;
    return InkWell(
      onTap: () {
        setState(() => _selectedStatus = statusKey);
        _fetchRequests(page: 1);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _primaryThemeColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _primaryThemeColor : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

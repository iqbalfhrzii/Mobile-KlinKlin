import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/file_attachment_preview.dart';
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
  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedStatus = 'all';
  Timer? _debounce;

  final Color _primaryThemeColor = AppColors.primaryMid; // KlinKlin Blue

  int get _activeFilterCount => _selectedStatus != 'all' ? 1 : 0;

  @override
  void initState() {
    super.initState();
    _fetchRequests(page: 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchRequests(page: 1);
    });
  }

  Future<void> _fetchRequests({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

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
        } else {
          if (res['message'] != null && res['message'].toString().isNotEmpty && res['status'] == false) {
            _errorMessage = res['message'].toString();
          }
        }
      });
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'selesai':
        return const Color(0xFF16A34A);
      case 'in_progress':
      case 'dikerjakan':
      case 'proses':
        return const Color(0xFF2563EB);
      case 'pending':
      case 'menunggu':
        return const Color(0xFFD97706);
      case 'rejected':
      case 'ditolak':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _getStatusBgColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'selesai':
        return const Color(0xFFDCFCE7);
      case 'in_progress':
      case 'dikerjakan':
      case 'proses':
        return const Color(0xFFDBEAFE);
      case 'pending':
      case 'menunggu':
        return const Color(0xFFFEF3C7);
      case 'rejected':
      case 'ditolak':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF1F5F9);
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

  void _openFilterModal() {
    String tempStatus = _selectedStatus;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Permintaan Design',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Divider(height: 20),
              Text(
                'Status Permintaan',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  {'val': 'all', 'label': 'Semua Status'},
                  {'val': 'pending', 'label': 'Pending'},
                  {'val': 'in_progress', 'label': 'Dikerjakan'},
                  {'val': 'completed', 'label': 'Selesai'},
                  {'val': 'rejected', 'label': 'Ditolak'},
                ].map((item) {
                  final val = item['val']!;
                  final label = item['label']!;
                  final isSelected = tempStatus == val;
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    selectedColor: _primaryThemeColor.withValues(alpha: 0.15),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: BorderSide(color: isSelected ? _primaryThemeColor : const Color(0xFFE2E8F0)),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? _primaryThemeColor : const Color(0xFF475569),
                    ),
                    onSelected: (selected) {
                      if (selected) setModalState(() => tempStatus = val);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _selectedStatus = 'all');
                        Navigator.pop(context);
                        _fetchRequests(page: 1);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Reset', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _selectedStatus = tempStatus);
                        Navigator.pop(context);
                        _fetchRequests(page: 1);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryThemeColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Terapkan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailModal(dynamic data) {
    final status = data['status']?.toString();
    final statusColor = _getStatusColor(status);
    final statusBgColor = _getStatusBgColor(status);
    final isPending = status?.toLowerCase() == 'pending' || status?.toLowerCase() == 'menunggu';

    final lampiranPengirim = (data['lampiran_pengirim'] ?? data['lampiran'] ?? data['file_lampiran'])?.toString();
    final catatanDesigner = (data['catatan_designer'] ?? data['catatan'] ?? data['keterangan'])?.toString();
    final lampiranDesigner = (data['lampiran_designer'] ?? data['file_hasil'] ?? data['hasil_design'])?.toString();

    String formattedDate = '-';
    if (data['created_at'] != null) {
      try {
        formattedDate = DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.parse(data['created_at']));
      } catch (_) {
        formattedDate = data['created_at'].toString();
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Modal Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 14, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _primaryThemeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.brush_rounded, color: _primaryThemeColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detail Permintaan Design',
                          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formattedDate,
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Content Scroll
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Hero Status Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusBgColor.withValues(alpha: 0.8),
                            statusBgColor.withValues(alpha: 0.3),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Status Pengerjaan',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.primaryMid),
                                    const SizedBox(width: 4),
                                    Text(
                                      formattedDate.split(',')[0],
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryMid),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.brush_rounded, color: statusColor, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                _getStatusLabel(status),
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Structured Information Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            icon: Icons.title_rounded,
                            label: 'Judul Design',
                            value: data['judul'] ?? '-',
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          _buildDetailRow(
                            icon: Icons.notes_rounded,
                            label: 'Brief & Kebutuhan Desain',
                            value: (data['deskripsi'] == null || data['deskripsi'].toString().trim().isEmpty) ? '-' : data['deskripsi'].toString(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 3. Lampiran Pengirim
                    if (lampiranPengirim != null && lampiranPengirim.isNotEmpty) ...[
                      FileAttachmentPreview.buildAttachmentCard(
                        context,
                        filePath: lampiranPengirim,
                        label: 'Lampiran Referensi Anda',
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 4. Feedback & Hasil dari Tim Designer
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blueGrey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.palette_outlined, size: 18, color: Colors.blueGrey.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Respon & Feedback Tim Designer',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            (catatanDesigner != null && catatanDesigner.trim().isNotEmpty) ? catatanDesigner : 'Belum ada catatan dari tim designer.',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontStyle: (catatanDesigner != null && catatanDesigner.trim().isNotEmpty) ? FontStyle.normal : FontStyle.italic,
                              color: (catatanDesigner != null && catatanDesigner.trim().isNotEmpty) ? AppColors.textDark : Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                          if (lampiranDesigner != null && lampiranDesigner.trim().isNotEmpty) ...[
                            const SizedBox(height: 14),
                            FileAttachmentPreview.buildAttachmentCard(
                              context,
                              filePath: lampiranDesigner,
                              label: 'File Hasil Desain Final',
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  FileAttachmentPreview.showPreview(
                                    context,
                                    filePath: lampiranDesigner,
                                    title: 'Hasil Desain - ${data['judul'] ?? 'Desain'}',
                                  );
                                },
                                icon: const Icon(Icons.photo_library_rounded, size: 18, color: Colors.white),
                                label: Text(
                                  'Lihat & Simpan Hasil Desain',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),

            // Modal Footer Actions
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    if (isPending) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _openForm(item: data);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFFD97706)),
                          label: Text('Edit', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFFD97706), fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFFBEB),
                            side: const BorderSide(color: Color(0xFFFDE68A)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteRequest(data['id']);
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                          label: Text('Hapus', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Color(0xFFDC2626), fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFFEF2F2),
                            side: const BorderSide(color: Color(0xFFFECACA)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: const Color(0xFF475569),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Tutup', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Buat Permintaan', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),

          // Search and Filter Bar Row (Standardized with other screens)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Cari judul design...',
                        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  _fetchRequests(page: 1);
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _openFilterModal,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _activeFilterCount > 0 ? AppColors.primaryMid.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _activeFilterCount > 0 ? AppColors.primaryMid : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.filter_list_rounded,
                          size: 18,
                          color: _activeFilterCount > 0 ? AppColors.primaryMid : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _activeFilterCount > 0 ? 'Filter ($_activeFilterCount)' : 'Filter',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _activeFilterCount > 0 ? AppColors.primaryMid : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 40, color: Colors.red),
                              const SizedBox(height: 8),
                              Text(_errorMessage, style: GoogleFonts.inter(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _fetchRequests(page: 1),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMid),
                                child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      )
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
                                        icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
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
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
                              itemCount: _requests.length,
                              itemBuilder: (context, index) {
                                final item = _requests[index];
                                final status = item['status']?.toString();
                                final isPending = status?.toLowerCase() == 'pending' || status?.toLowerCase() == 'menunggu';
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

                                final statusColor = _getStatusColor(status);
                                final statusBgColor = _getStatusBgColor(status);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.grey.shade200),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Clickable Header & Body -> Opens Detail
                                        InkWell(
                                          onTap: () => _showDetailModal(item),
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              // Header Card
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade50,
                                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.brush_rounded, size: 16, color: Color(0xFF0284C7)),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        formattedDate,
                                                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: statusBgColor,
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                                      ),
                                                      child: Text(
                                                        _getStatusLabel(status),
                                                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Body Card
                                              Padding(
                                                padding: const EdgeInsets.all(14),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    // Judul Design (Prominent Title)
                                                    Text(
                                                      item['judul'] ?? 'Permintaan Design',
                                                      style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 6),

                                                    // Brief snippet
                                                    Text(
                                                      (item['deskripsi'] == null || item['deskripsi'].toString().trim().isEmpty) ? '-' : item['deskripsi'].toString(),
                                                      style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B), height: 1.4),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),

                                                    if (hasResponse) ...[
                                                      const SizedBox(height: 10),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: Colors.teal.shade50,
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(color: Colors.teal.shade200),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.palette_outlined, size: 14, color: Colors.teal.shade700),
                                                            const SizedBox(width: 6),
                                                            Text(
                                                              'Ada respon dari tim designer',
                                                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const Divider(height: 1, color: Color(0xFFEEEEEE)),

                                        // Action Buttons Bar
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                          child: Row(
                                            children: [
                                              // Detail Link Button
                                              InkWell(
                                                onTap: () => _showDetailModal(item),
                                                borderRadius: BorderRadius.circular(6),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        'Lihat Detail',
                                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryMid),
                                                      ),
                                                      const SizedBox(width: 2),
                                                      const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primaryMid),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),

                                              if (isPending) ...[
                                                // Edit Button (Pill with label)
                                                InkWell(
                                                  onTap: () => _openForm(item: item),
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFFFBEB),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.edit_outlined, size: 14, color: Color(0xFFD97706)),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          'Edit',
                                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),

                                                // Hapus Button (Pill with label)
                                                InkWell(
                                                  onTap: () => _deleteRequest(item['id']),
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFEF2F2),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: const Color(0xFFFECACA)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          'Hapus',
                                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
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

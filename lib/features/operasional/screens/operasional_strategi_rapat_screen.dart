import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/file_attachment_preview.dart';
import '../../../core/api/api_client.dart';
import '../services/operasional_strategi_rapat_service.dart';
import 'operasional_strategi_rapat_form_sheet.dart';

class OperasionalStrategiRapatScreen extends StatefulWidget {
  const OperasionalStrategiRapatScreen({super.key});

  @override
  State<OperasionalStrategiRapatScreen> createState() => _OperasionalStrategiRapatScreenState();
}

class _OperasionalStrategiRapatScreenState extends State<OperasionalStrategiRapatScreen> {
  final _service = OperasionalStrategiRapatService();
  final _searchController = TextEditingController();
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _error = '';
  List<dynamic> _strategiList = [];
  
  int _currentPage = 1;
  int _lastPage = 1;
  
  String _selectedCabangId = 'all';
  List<dynamic> _cabangList = [];

  final ScrollController _scrollController = ScrollController();

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCabangId != 'all') count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    _fetchCabang();
    _fetchStrategi();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchCabang() async {
    try {
      final res = await ApiClient.instance.get('/operasional/cabangs');
      if (res.data != null && res.data['data'] != null) {
        setState(() {
          _cabangList = res.data['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching cabang: $e");
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _currentPage < _lastPage) {
        _fetchStrategi(page: _currentPage + 1, append: true);
      }
    }
  }

  Future<void> _fetchStrategi({int page = 1, bool append = false}) async {
    if (!append) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final res = await _service.getStrategiRapat(
        page: page,
        search: _searchController.text.trim(),
        cabangId: _selectedCabangId,
      );

      if (res['status'] == true) {
        setState(() {
          if (append) {
            _strategiList.addAll(res['data']['data'] ?? []);
          } else {
            _strategiList = res['data']['data'] ?? [];
          }
          _currentPage = res['data']['current_page'] ?? 1;
          _lastPage = res['data']['last_page'] ?? 1;
        });
      } else {
        setState(() => _error = res['message'] ?? 'Gagal memuat data rapat harian');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _openForm([dynamic strategi]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: OperasionalStrategiRapatFormSheet(
            initialData: strategi,
            cabangList: _cabangList,
            onSave: () {
              Navigator.pop(context);
              _fetchStrategi(page: 1);
            },
          ),
        ),
      ),
    );
  }

  void _showFilterModal() {
    String tempCabang = _selectedCabangId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Rapat Harian',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Filter Cabang
                  Text('Cabang', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 12)),
                        selected: tempCabang == 'all',
                        selectedColor: AppColors.primaryMid.withValues(alpha: 0.15),
                        labelStyle: GoogleFonts.inter(
                          color: tempCabang == 'all' ? AppColors.primaryMid : AppColors.textDark,
                          fontWeight: tempCabang == 'all' ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          if (selected) setModalState(() => tempCabang = 'all');
                        },
                      ),
                      ..._cabangList.map((c) {
                        final idStr = c['id'].toString();
                        final isSelected = tempCabang == idStr;
                        return ChoiceChip(
                          label: Text(c['nama_cabang'] ?? c['nama'] ?? '', style: GoogleFonts.inter(fontSize: 12)),
                          selected: isSelected,
                          selectedColor: AppColors.primaryMid.withValues(alpha: 0.15),
                          labelStyle: GoogleFonts.inter(
                            color: isSelected ? AppColors.primaryMid : AppColors.textDark,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) setModalState(() => tempCabang = idStr);
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              tempCabang = 'all';
                            });
                            setState(() {
                              _selectedCabangId = 'all';
                            });
                            Navigator.pop(context);
                            _fetchStrategi(page: 1);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Reset', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedCabangId = tempCabang;
                            });
                            Navigator.pop(context);
                            _fetchStrategi(page: 1);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryMid,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Terapkan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
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

  Color _getStatusColor(String? status) {
    if (status == 'Selesai') return const Color(0xFF16A34A);
    if (status == 'Proses') return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  Color _getStatusBgColor(String? status) {
    if (status == 'Selesai') return const Color(0xFFDCFCE7);
    if (status == 'Proses') return const Color(0xFFFEF3C7);
    return const Color(0xFFFEE2E2);
  }

  IconData _getStatusIcon(String? status) {
    if (status == 'Selesai') return Icons.check_circle_outline_rounded;
    if (status == 'Proses') return Icons.access_time_rounded;
    return Icons.pending_actions_rounded;
  }

  void _showDetailModal(dynamic strategi) {
    String tglStr = '-';
    if (strategi['tanggal'] != null) {
      try {
        tglStr = DateFormat('dd MMMM yyyy').format(DateTime.parse(strategi['tanggal'].toString()));
      } catch (_) {
        tglStr = strategi['tanggal'].toString();
      }
    }

    String tenggatStr = '-';
    if (strategi['tenggat'] != null && strategi['tenggat'].toString().isNotEmpty) {
      try {
        tenggatStr = DateFormat('dd MMMM yyyy').format(DateTime.parse(strategi['tenggat'].toString()));
      } catch (_) {
        tenggatStr = strategi['tenggat'].toString();
      }
    }

    final cabangName = strategi['cabang']?['nama_cabang'] ?? strategi['cabang']?['nama'] ?? '-';
    final namaStrategi = strategi['strategi'] ?? '-';
    final periode = strategi['periode'] ?? '-';
    final pic = strategi['pic'] != null && strategi['pic'].toString().trim().isNotEmpty ? strategi['pic'].toString().trim() : null;
    final status = strategi['status_strategi'] ?? 'Belum';
    final statusColor = _getStatusColor(status);
    final statusBgColor = _getStatusBgColor(status);
    final statusIcon = _getStatusIcon(status);

    final latarBelakang = strategi['latar_belakang'] != null && strategi['latar_belakang'].toString().trim().isNotEmpty ? strategi['latar_belakang'].toString().trim() : null;
    final target = strategi['target'] != null && strategi['target'].toString().trim().isNotEmpty ? strategi['target'].toString().trim() : null;
    final indikator = strategi['indikator_keberhasilan'] != null && strategi['indikator_keberhasilan'].toString().trim().isNotEmpty ? strategi['indikator_keberhasilan'].toString().trim() : null;
    final lampiranPath = (strategi['lampiran'] ?? strategi['file_lampiran'] ?? strategi['file'])?.toString();
    final hasLampiran = lampiranPath != null && lampiranPath.trim().isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
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

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMid.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.show_chart_rounded, color: AppColors.primaryMid, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detail Rapat Harian',
                            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                periode,
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Text(
                                  cabangName,
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                ),
                              ),
                            ],
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

              // Scrollable Content Body
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
                              statusBgColor.withValues(alpha: 0.6),
                              statusBgColor.withValues(alpha: 0.2),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Status Strategi',
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
                                        tglStr,
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
                                Icon(statusIcon, color: statusColor, size: 22),
                                const SizedBox(width: 6),
                                Text(
                                  status,
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
                              icon: Icons.store_mall_directory_outlined,
                              label: 'Cabang',
                              value: cabangName,
                            ),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            _buildDetailRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'Tanggal Rapat',
                              value: tglStr,
                            ),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            _buildDetailRow(
                              icon: Icons.date_range_outlined,
                              label: 'Periode',
                              value: periode,
                            ),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            _buildDetailRow(
                              icon: Icons.lightbulb_outline_rounded,
                              label: 'Strategi / Program',
                              value: namaStrategi,
                            ),
                            if (pic != null) ...[
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              _buildDetailRow(
                                icon: Icons.person_outline_rounded,
                                label: 'PIC Penanggung Jawab',
                                value: pic,
                              ),
                            ],
                            if (tenggatStr != '-') ...[
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              _buildDetailRow(
                                icon: Icons.hourglass_bottom_rounded,
                                label: 'Tenggat Waktu',
                                value: tenggatStr,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3. Latar Belakang Section
                      if (latarBelakang != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.notes_rounded, size: 16, color: Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Latar Belakang',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                latarBelakang,
                                style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textDark, height: 1.45),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 4. Target Section
                      if (target != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.track_changes_rounded, size: 16, color: Colors.blue),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Target & Sasaran',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                target,
                                style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF1E3A8A), height: 1.45),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 5. Indikator Keberhasilan Section
                      if (indikator != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF16A34A)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Indikator Keberhasilan',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                indikator,
                                style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF14532D), height: 1.45),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 6. Lampiran Dokumen
                      if (hasLampiran) ...[
                        FileAttachmentPreview.buildAttachmentCard(
                          context,
                          filePath: lampiranPath,
                          label: 'Lampiran Rapat Harian',
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Action Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Tutup',
                          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _openForm(strategi);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                          label: Text(
                            'Edit Data',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryMid,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
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

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStrategi(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Rapat Harian', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus data rapat harian ini?', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Hapus', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
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

    final res = await _service.deleteStrategiRapat(id);
    if (mounted) Navigator.pop(context);

    if (res['status'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Strategi berhasil dihapus'), backgroundColor: Colors.green),
        );
      }
      _fetchStrategi(page: 1);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal menghapus'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          GradientHeader(
            child: Row(
              children: [
                const AppBackButton(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rapat Harian',
                        style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kelola data rapat harian operasional',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Search & Filter Single Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Search Input
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Cari strategi, program, PIC...',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      onSubmitted: (_) => _fetchStrategi(page: 1),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Filter Button with Badge
                InkWell(
                  onTap: _showFilterModal,
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
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                    : _buildList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primaryMid,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Tambah Strategi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
      ),
    );
  }

  Widget _buildList() {
    if (_strategiList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart_rounded, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Tidak ada data rapat harian', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
      itemCount: _strategiList.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _strategiList.length) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }

        final item = _strategiList[index];

        String tglStr = '-';
        if (item['tanggal'] != null) {
          try {
            tglStr = DateFormat('dd MMM yyyy').format(DateTime.parse(item['tanggal'].toString()));
          } catch (_) {
            tglStr = item['tanggal'].toString();
          }
        }

        final cabangName = item['cabang']?['nama_cabang'] ?? item['cabang']?['nama'] ?? '-';
        final strategi = (item['strategi'] != null && item['strategi'].toString().isNotEmpty) ? item['strategi'].toString() : 'Tanpa Judul Strategi';
        final periode = item['periode'] ?? '-';
        final status = item['status_strategi'] ?? 'Belum';
        final statusColor = _getStatusColor(status);
        final statusBgColor = _getStatusBgColor(status);
        final statusIcon = _getStatusIcon(status);
        final pic = item['pic'] != null && item['pic'].toString().isNotEmpty ? item['pic'].toString() : null;

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
                // Clickable Card Header & Body -> Opens Detail
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
                            const Icon(Icons.show_chart_rounded, size: 16, color: AppColors.primaryMid),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$tglStr • $periode',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Text(
                                cabangName,
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
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
                            // Strategi / Program (Prominent Title)
                            Text(
                              strategi,
                              style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textDark),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),

                            // Status Strategi & PIC
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(statusIcon, size: 13, color: statusColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Status: $status',
                                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: statusColor),
                                      ),
                                    ],
                                  ),
                                ),
                                if (pic != null)
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        'PIC: $pic',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            if (item['target'] != null && item['target'].toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              // Info Box (Target snippet)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFF1F5F9)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.track_changes_rounded, size: 13, color: AppColors.textMuted),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        'Target: ${item['target']}',
                                        style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textMuted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
                      const Spacer(),

                      // Edit Button (Labelled Pill)
                      InkWell(
                        onTap: () => _openForm(item),
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

                      // Hapus Button (Labelled Pill)
                      InkWell(
                        onTap: () => _deleteStrategi(item['id']),
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
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

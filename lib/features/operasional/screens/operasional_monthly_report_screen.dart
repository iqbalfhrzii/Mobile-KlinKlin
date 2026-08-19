import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/api/api_client.dart';
import '../services/operasional_monthly_report_service.dart';
import 'operasional_monthly_report_form_sheet.dart';

class OperasionalMonthlyReportScreen extends StatefulWidget {
  const OperasionalMonthlyReportScreen({super.key});

  @override
  State<OperasionalMonthlyReportScreen> createState() => _OperasionalMonthlyReportScreenState();
}

class _OperasionalMonthlyReportScreenState extends State<OperasionalMonthlyReportScreen> {
  final _service = OperasionalMonthlyReportService();
  final _searchController = TextEditingController();
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _error = '';
  List<dynamic> _reportList = [];
  
  int _currentPage = 1;
  int _lastPage = 1;
  
  String _selectedCabangId = 'all';
  List<dynamic> _cabangList = [];

  final ScrollController _scrollController = ScrollController();
  
  // Indigo color for R&D section
  final Color _indigoColor = const Color(0xFF4F46E5); 

  @override
  void initState() {
    super.initState();
    _fetchCabang();
    _fetchReports();
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
        _fetchReports(page: _currentPage + 1, append: true);
      }
    }
  }

  Future<void> _fetchReports({int page = 1, bool append = false}) async {
    if (!append) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final res = await _service.getReports(
        page: page,
        search: _searchController.text,
        cabangId: _selectedCabangId,
      );

      if (res['status'] == true) {
        setState(() {
          if (append) {
            _reportList.addAll(res['data']['data'] ?? []);
          } else {
            _reportList = res['data']['data'] ?? [];
          }
          _currentPage = res['data']['current_page'] ?? 1;
          _lastPage = res['data']['last_page'] ?? 1;
        });
      } else {
        setState(() => _error = res['message'] ?? 'Unknown error');
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

  void _openForm([dynamic data]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: OperasionalMonthlyReportFormSheet(
            initialData: data,
            cabangList: _cabangList,
            onSave: () {
              Navigator.pop(context);
              _fetchReports(page: 1);
            },
          ),
        ),
      ),
    );
  }

  void _showDetail(dynamic data) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.insert_drive_file_outlined, color: _indigoColor),
                        const SizedBox(width: 8),
                        Text('Detail Monthly Report', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                Text(
                  'Periode: ${data['periode'] != null ? DateFormat('MMMM yyyy').format(DateTime.parse(data['periode'])) : '-'}',
                  style: GoogleFonts.inter(fontSize: 12, color: _indigoColor, fontWeight: FontWeight.w600),
                ),
                
                const Divider(height: 24),
                
                Text(
                  data['judul'] ?? '-',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 12),
                
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.business_outlined, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('Cabang: ${data['cabang']?['nama_cabang'] ?? data['cabang']?['nama'] ?? 'Global'}', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('PIC: ${data['pic'] ?? '-'}', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700)),
                        ],
                      ),
                      _buildStatusBadge(data['status_laporan'] ?? 'Draft'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Stacked layout for 4 sections to avoid phone width overflow
                _buildDetailCard(
                  title: 'Ringkasan',
                  icon: Icons.notes,
                  iconColor: _indigoColor,
                  bgColor: _indigoColor.withValues(alpha: 0.05),
                  borderColor: _indigoColor.withValues(alpha: 0.1),
                  content: data['ringkasan'],
                ),
                const SizedBox(height: 10),
                _buildDetailCard(
                  title: 'Kendala',
                  icon: Icons.warning_amber_rounded,
                  iconColor: Colors.red,
                  bgColor: Colors.red.shade50,
                  borderColor: Colors.red.shade100,
                  content: data['kendala'],
                  emptyMessage: 'Tidak ada kendala yang dilaporkan.',
                ),
                const SizedBox(height: 10),
                _buildDetailCard(
                  title: 'Capaian',
                  icon: Icons.emoji_events_outlined,
                  iconColor: Colors.green,
                  bgColor: Colors.green.shade50,
                  borderColor: Colors.green.shade100,
                  content: data['capaian'],
                  emptyMessage: 'Belum ada data capaian.',
                ),
                const SizedBox(height: 10),
                _buildDetailCard(
                  title: 'Rencana Bulan Depan',
                  icon: Icons.trending_up_outlined,
                  iconColor: Colors.blue,
                  bgColor: Colors.blue.shade50,
                  borderColor: Colors.blue.shade100,
                  content: data['rencana_bulan_depan'],
                  emptyMessage: 'Belum ada rencana tindak lanjut.',
                ),
                
                if (data['file_laporan'] != null && data['file_laporan'].toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Dilampirkan: ${data['file_laporan'].toString().split('/').last}',
                            style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Tutup', style: GoogleFonts.inter(color: AppColors.textDark)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    String? content,
    String emptyMessage = 'Tidak ada data.',
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: iconColor)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            (content == null || content.isEmpty) ? emptyMessage : content,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor = Colors.grey.shade100;
    Color textColor = Colors.grey.shade700;
    
    if (status.toLowerCase().contains('submitted') || status.toLowerCase().contains('selesai')) {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
    } else if (status.toLowerCase().contains('progress') || status.toLowerCase().contains('review')) {
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue.shade700;
    } else if (status.toLowerCase().contains('draft')) {
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 10, color: textColor),
          const SizedBox(width: 4),
          Text(status, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  Future<void> _deleteReport(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Data'),
        content: const Text('Apakah Anda yakin ingin menghapus laporan ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
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

    final res = await _service.deleteReport(id);
    if (mounted) Navigator.pop(context);

    if (res['status'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data berhasil dihapus'), backgroundColor: Colors.green),
        );
      }
      _fetchReports(page: 1);
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
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          GradientHeader(
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Report (R&D)',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kelola laporan bulanan operasional dan rencana tindak lanjut',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Cari Judul Laporan atau PIC...',
                        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _fetchReports(page: 1),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCabangId,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('Semua Cabang (Pusat/Global)')),
                          ..._cabangList.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['nama_cabang'] ?? c['nama'] ?? ''))),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCabangId = val);
                            _fetchReports(page: 1);
                          }
                        },
                      ),
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
        backgroundColor: _indigoColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Tambah Laporan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
      ),
    );
  }

  Widget _buildList() {
    if (_reportList.isEmpty) {
      return const Center(child: Text('Tidak ada data laporan bulanan.'));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _reportList.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _reportList.length) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }

        final item = _reportList[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['periode'] != null ? DateFormat('MMMM yyyy').format(DateTime.parse(item['periode'])) : '-',
                                style: GoogleFonts.inter(fontSize: 11, color: _indigoColor, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['judul'] ?? '-',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(item['status_laporan'] ?? 'Draft'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CABANG & PIC', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                              const SizedBox(height: 2),
                              Text(
                                item['cabang']?['nama_cabang'] ?? item['cabang']?['nama'] ?? 'Global',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'PIC: ${item['pic'] ?? '-'}',
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('RINGKASAN', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                              const SizedBox(height: 2),
                              Text(
                                (item['ringkasan'] == null || item['ringkasan'].toString().trim().isEmpty) ? '-' : item['ringkasan'],
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _showDetail(item),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.textDark,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text('Lihat Detail', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => _openForm(item),
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      onPressed: () => _deleteReport(item['id']),
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/api/api_client.dart';
import '../services/operasional_kesehatan_berkala_service.dart';
import 'operasional_kesehatan_berkala_form_sheet.dart';

class OperasionalKesehatanBerkalaScreen extends StatefulWidget {
  const OperasionalKesehatanBerkalaScreen({super.key});

  @override
  State<OperasionalKesehatanBerkalaScreen> createState() => _OperasionalKesehatanBerkalaScreenState();
}

class _OperasionalKesehatanBerkalaScreenState extends State<OperasionalKesehatanBerkalaScreen> {
  final _service = OperasionalKesehatanBerkalaService();
  final _searchController = TextEditingController();
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _error = '';
  List<dynamic> _kesehatanList = [];
  
  int _currentPage = 1;
  int _lastPage = 1;
  
  String _selectedCabangId = 'all';
  List<dynamic> _cabangList = [];

  final ScrollController _scrollController = ScrollController();
  
  // Teal color for this specific HSE section
  final Color _tealColor = const Color(0xFF0F766E); 

  @override
  void initState() {
    super.initState();
    _fetchCabang();
    _fetchKesehatan();
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
        _fetchKesehatan(page: _currentPage + 1, append: true);
      }
    }
  }

  Future<void> _fetchKesehatan({int page = 1, bool append = false}) async {
    if (!append) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final res = await _service.getDataKesehatanBerkala(
        page: page,
        search: _searchController.text,
        cabangId: _selectedCabangId,
      );

      if (res['status'] == true) {
        setState(() {
          if (append) {
            _kesehatanList.addAll(res['data']['data'] ?? []);
          } else {
            _kesehatanList = res['data']['data'] ?? [];
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
          child: OperasionalKesehatanBerkalaFormSheet(
            initialData: data,
            cabangList: _cabangList,
            onSave: () {
              Navigator.pop(context);
              _fetchKesehatan(page: 1);
            },
          ),
        ),
      ),
    );
  }

  Color _getHasilColor(String? hasil) {
    switch (hasil?.toLowerCase()) {
      case 'sehat':
        return Colors.green.shade800;
      case 'sehat dengan catatan':
        return Colors.blue.shade800;
      case 'perlu tindak lanjut':
      case 'kurang sehat':
        return Colors.amber.shade900;
      case 'tidak layak kerja':
      case 'tidak sehat':
        return Colors.red.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  Color _getHasilBgColor(String? hasil) {
    switch (hasil?.toLowerCase()) {
      case 'sehat':
        return Colors.green.shade50;
      case 'sehat dengan catatan':
        return Colors.blue.shade50;
      case 'perlu tindak lanjut':
      case 'kurang sehat':
        return Colors.amber.shade50;
      case 'tidak layak kerja':
      case 'tidak sehat':
        return Colors.red.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  void _showDetail(dynamic data) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        Icon(Icons.monitor_heart_outlined, color: _tealColor),
                        const SizedBox(width: 8),
                        Text('Detail Data Kesehatan', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
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
                const Divider(height: 32),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TANGGAL PERIKSA', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          Text(
                            data['tanggal_periksa'] != null ? DateFormat('dd MMMM yyyy').format(DateTime.parse(data['tanggal_periksa'])) : '-', 
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CABANG', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          Text(data['cabang']?['nama_cabang'] ?? data['cabang']?['nama'] ?? '-', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('KARYAWAN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          Text(data['nama_karyawan'] ?? '-', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          Text(data['jabatan'] ?? '-', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('JENIS PEMERIKSAAN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          Text(data['jenis_pemeriksaan'] ?? '-', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TEMPAT PERIKSA', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          Text(
                            data['tempat_periksa'] != null && data['tempat_periksa'].toString().trim().isNotEmpty
                                ? data['tempat_periksa']
                                : '-',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('HASIL', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getHasilBgColor(data['hasil']),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              data['hasil'] != null && data['hasil'].toString().trim().isNotEmpty ? data['hasil'] : 'N/A',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getHasilColor(data['hasil']),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                _buildDetailSection('CATATAN MEDIS', data['catatan_medis']),
                _buildDetailSection('REKOMENDASI', data['rekomendasi']),
                
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PERIKSA BERIKUTNYA', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text(data['periksa_berikutnya'] != null ? DateFormat('dd MMMM yyyy').format(DateTime.parse(data['periksa_berikutnya'])) : '-', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark)),
                  ],
                ),
                
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FILE HASIL / LAMPIRAN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text((data['file_hasil'] != null && data['file_hasil'].toString().isNotEmpty) ? 'Dilampirkan' : 'Tidak ada file lampiran', style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                  ],
                ),
                
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

  Widget _buildDetailSection(String title, String? content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
          child: Text(
            (content == null || content.isEmpty) ? '-' : content,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _deleteKesehatan(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Data'),
        content: const Text('Apakah Anda yakin ingin menghapus data kesehatan ini?'),
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

    final res = await _service.deleteDataKesehatanBerkala(id);
    if (mounted) Navigator.pop(context);

    if (res['status'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data berhasil dihapus'), backgroundColor: Colors.green),
        );
      }
      _fetchKesehatan(page: 1);
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
                        'Data Kesehatan Berkala',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kelola data pemeriksaan kesehatan karyawan',
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
                        hintText: 'Cari Nama Karyawan, Pemeriksaan...',
                        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _fetchKesehatan(page: 1),
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
                          const DropdownMenuItem(value: 'all', child: Text('Semua Cabang')),
                          ..._cabangList.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['nama_cabang'] ?? c['nama'] ?? ''))),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCabangId = val);
                            _fetchKesehatan(page: 1);
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
        backgroundColor: _tealColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Tambah Data', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildList() {
    if (_kesehatanList.isEmpty) {
      return const Center(child: Text('Tidak ada data kesehatan berkala.'));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _kesehatanList.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _kesehatanList.length) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }

        final item = _kesehatanList[index];

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
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TANGGAL & CABANG', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text(
                            item['tanggal_periksa'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['tanggal_periksa'])) : '-',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                          Text(
                            item['cabang']?['nama_cabang'] ?? item['cabang']?['nama'] ?? '-',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('KARYAWAN', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text(
                            item['nama_karyawan'] ?? '-',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            item['jabatan'] ?? '-',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PEMERIKSAAN', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text(
                            item['jenis_pemeriksaan'] ?? '-',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('HASIL', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getHasilBgColor(item['hasil']),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item['hasil'] != null && item['hasil'].toString().trim().isNotEmpty ? item['hasil'] : 'N/A',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: _getHasilColor(item['hasil']),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                      onPressed: () => _deleteKesehatan(item['id']),
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

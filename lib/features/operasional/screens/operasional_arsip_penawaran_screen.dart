import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/api/api_client.dart';
import '../services/operasional_arsip_penawaran_service.dart';
import 'operasional_arsip_penawaran_form_sheet.dart';

class OperasionalArsipPenawaranScreen extends StatefulWidget {
  const OperasionalArsipPenawaranScreen({super.key});

  @override
  State<OperasionalArsipPenawaranScreen> createState() => _OperasionalArsipPenawaranScreenState();
}

class _OperasionalArsipPenawaranScreenState extends State<OperasionalArsipPenawaranScreen> {
  final _service = OperasionalArsipPenawaranService();
  final _searchController = TextEditingController();
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _error = '';
  List<dynamic> _arsipList = [];
  
  int _currentPage = 1;
  int _lastPage = 1;
  
  String _selectedCabangId = 'all';
  List<dynamic> _cabangList = [];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchCabang();
    _fetchArsip();
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
        _fetchArsip(page: _currentPage + 1, append: true);
      }
    }
  }

  Future<void> _fetchArsip({int page = 1, bool append = false}) async {
    if (!append) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final res = await _service.getArsip(
        page: page,
        search: _searchController.text,
        cabangId: _selectedCabangId,
      );

      if (res['status'] == true) {
        setState(() {
          if (append) {
            _arsipList.addAll(res['data']['data'] ?? []);
          } else {
            _arsipList = res['data']['data'] ?? [];
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

  String _formatCurrency(dynamic value) {
    if (value == null) return '-';
    final numVal = num.tryParse(value.toString());
    if (numVal == null) return '-';
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(numVal);
  }

  void _openForm([dynamic arsip]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: OperasionalArsipPenawaranFormSheet(
            initialData: arsip,
            cabangList: _cabangList,
            onSave: () {
              Navigator.pop(context);
              _fetchArsip(page: 1);
            },
          ),
        ),
      ),
    );
  }

  void _showDetail(dynamic arsip) {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.description, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Detail Arsip', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        Text('NOMOR', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Text(arsip['nomor'] ?? '-', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TANGGAL', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Text(arsip['tanggal'] != null ? DateFormat('dd MMMM yyyy').format(DateTime.parse(arsip['tanggal'])) : '-', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
                        Text('CABANG', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            arsip['cabang']?['nama_cabang'] ?? arsip['cabang']?['nama'] ?? '-',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PERIHAL', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Text(arsip['perihal'] ?? '-', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
                        Text('NAMA CUSTOMER', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Text(arsip['nama_customer'] ?? '-', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NOMINAL', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Text(_formatCurrency(arsip['nominal']), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Text('KETERANGAN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                child: Text(
                  arsip['keterangan'] != null && arsip['keterangan'].toString().isNotEmpty ? arsip['keterangan'] : 'Tidak ada keterangan.',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                ),
              ),
              
              if (arsip['file_path'] != null) ...[
                const SizedBox(height: 16),
                Text('FILE BUKTI / DOKUMEN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () {
                    // Open file if needed
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.attach_file, size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            arsip['file_path'].toString().split('/').last,
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text('Tutup', style: GoogleFonts.inter(color: AppColors.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openForm(arsip);
                    },
                    icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                    label: Text('Edit Data', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

  Future<void> _deleteArsip(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Arsip'),
        content: const Text('Apakah Anda yakin ingin menghapus arsip penawaran ini?'),
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

    final res = await _service.deleteArsip(id);
    if (mounted) Navigator.pop(context);

    if (res['status'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arsip berhasil dihapus'), backgroundColor: Colors.green),
        );
      }
      _fetchArsip(page: 1);
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
                        'Arsip Nomor & Nominal',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kelola arsip penawaran, nomor surat, dan riwayat nominal',
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
                        hintText: 'Cari Nomor, Perihal, atau Customer...',
                        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _fetchArsip(page: 1),
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
                          ..._cabangList.map((c) => DropdownMenuItem(
                                value: c['id'].toString(),
                                child: Text(c['nama_cabang'] ?? c['nama'] ?? ''),
                              )),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCabangId = val);
                            _fetchArsip(page: 1);
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
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Tambah Arsip', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildList() {
    if (_arsipList.isEmpty) {
      return const Center(child: Text('Tidak ada arsip penawaran'));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _arsipList.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _arsipList.length) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }

        final item = _arsipList[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
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
                          Text('TANGGAL', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text(
                            item['tanggal'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['tanggal'])) : '-',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('NOMOR & PERIHAL', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text(
                            item['nomor'] ?? '-',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                          Text(
                            item['perihal'] ?? '-',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CABANG & CUSTOMER', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              item['cabang']?['nama_cabang'] ?? item['cabang']?['nama'] ?? '-',
                              style: GoogleFonts.inter(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['nama_customer'] ?? '-',
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
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('NOMINAL', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text(
                            _formatCurrency(item['nominal']),
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
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
                        backgroundColor: Colors.blue.shade900,
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
                      onPressed: () => _deleteArsip(item['id']),
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

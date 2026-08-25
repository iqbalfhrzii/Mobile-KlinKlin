import 'package:flutter/material.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'gaji_pokok_form_screen.dart';
import 'gaji_pokok_detail_screen.dart';

class GajiPokokListScreen extends StatefulWidget {
  const GajiPokokListScreen({super.key});

  @override
  State<GajiPokokListScreen> createState() => _GajiPokokListScreenState();
}

class _GajiPokokListScreenState extends State<GajiPokokListScreen> {
  final HrdService _hrdService = HrdService();
  final TextEditingController _searchCtrl = TextEditingController();
  
  List<GajiPokokModel> _gajiPokoks = [];
  List<GajiPokokModel> _filteredGajiPokoks = [];
  List<CabangModel> _cabangs = [];
  
  int? _selectedCabang;
  String _selectedStatus = 'Semua Status';
  bool _isLoading = true;

  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final cabangs = await _hrdService.fetchCabang();
      final gajiPokoks = await _hrdService.fetchGajiPokok();
      
      if (mounted) {
        setState(() {
          _cabangs = cabangs;
          _gajiPokoks = gajiPokoks;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _fetchGajiPokok() async {
    setState(() => _isLoading = true);
    try {
      final gajiPokoks = await _hrdService.fetchGajiPokok();
      if (mounted) {
        setState(() {
          _gajiPokoks = gajiPokoks;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredGajiPokoks = _gajiPokoks.where((gaji) {
        bool matchSearch = true;
        if (_searchCtrl.text.isNotEmpty) {
          final query = _searchCtrl.text.toLowerCase();
          final statusMatch = gaji.statusKaryawan.toLowerCase().contains(query);
          final cabangMatch = gaji.cabang?.namaCabang.toLowerCase().contains(query) ?? false;
          final jabatanMatch = gaji.jabatan?.namaJabatan.toLowerCase().contains(query) ?? false;
          matchSearch = statusMatch || cabangMatch || jabatanMatch;
        }

        bool matchCabang = true;
        if (_selectedCabang != null) {
          matchCabang = gaji.cabangId == _selectedCabang;
        }

        bool matchStatus = true;
        if (_selectedStatus != 'Semua Status') {
          matchStatus = gaji.statusKaryawan.toLowerCase() == _selectedStatus.toLowerCase();
        }

        return matchSearch && matchCabang && matchStatus;
      }).toList();
    });
  }

  Future<void> _deleteGajiPokok(GajiPokokModel gaji) async {
    final bool? confirm = await AppConfirmationDialog.show(
      context,
      title: 'Hapus Gaji Pokok?',
      message: 'Apakah Anda yakin ingin menghapus data gaji pokok untuk ${gaji.jabatan?.namaJabatan ?? ''} (${gaji.statusKaryawan}) di cabang ${gaji.cabang?.namaCabang ?? ''}?',
      type: ConfirmationDialogType.danger,
      customIcon: Icons.delete_forever_rounded,
      confirmText: 'Hapus',
      cancelText: 'Batal',
      isDestructive: true,
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _hrdService.deleteGajiPokok(gaji.id);
        await _fetchGajiPokok();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data berhasil dihapus')));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Cari status, cabang, atau jabatan...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (_) => _applyFilters(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: _selectedCabang,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  hint: const Text('Semua Cabang', style: TextStyle(fontSize: 14)),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Semua Cabang', style: TextStyle(fontSize: 14))),
                    ..._cabangs.map((c) => DropdownMenuItem(value: c.id, child: Text(c.namaCabang, style: const TextStyle(fontSize: 14)))),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedCabang = val);
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'Semua Status', child: Text('Semua Status', style: TextStyle(fontSize: 14))),
                    DropdownMenuItem(value: 'tetap', child: Text('Tetap', style: TextStyle(fontSize: 14))),
                    DropdownMenuItem(value: 'freelance', child: Text('Freelance', style: TextStyle(fontSize: 14))),
                    DropdownMenuItem(value: 'kontrak', child: Text('Kontrak', style: TextStyle(fontSize: 14))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedStatus = val);
                      _applyFilters();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItem(GajiPokokModel gaji) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GajiPokokDetailScreen(
                  gajiPokok: gaji,
                  onDataChanged: _fetchGajiPokok,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.teal.withValues(alpha: 0.15),
                      child: const Icon(Icons.monetization_on_rounded, color: Colors.teal, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  gaji.jabatan?.namaJabatan ?? '-',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  gaji.statusKaryawan.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Gaji Pokok: ${currencyFormatter.format(gaji.gajiPokok)}', 
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.teal.shade800), 
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.storefront_rounded, size: 12, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(gaji.cabang?.namaCabang ?? '-', style: GoogleFonts.inter(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => GajiPokokFormScreen(gajiPokok: gaji)));
                          if (res == true) _fetchGajiPokok();
                        },
                        icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                        label: Text('Edit', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blue)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24))),
                        ),
                      ),
                    ),
                    Container(width: 1, height: 24, color: Colors.grey.shade300),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _deleteGajiPokok(gaji),
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        label: Text('Hapus', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomRight: Radius.circular(24))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const GajiPokokFormScreen()));
          if (res == true) _fetchGajiPokok();
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Tambah Data', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gaji Pokok',
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Kelola master data gaji pokok',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredGajiPokoks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.money_off_csred_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text('Belum ada data gaji pokok', style: GoogleFonts.inter(color: Colors.grey)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchGajiPokok,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _filteredGajiPokoks.length,
                          itemBuilder: (ctx, i) => _buildItem(_filteredGajiPokoks[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

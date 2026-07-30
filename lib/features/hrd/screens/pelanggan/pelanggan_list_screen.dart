import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'pelanggan_form_screen.dart';

class PelangganListScreen extends StatefulWidget {
  const PelangganListScreen({super.key});

  @override
  State<PelangganListScreen> createState() => _PelangganListScreenState();
}

class _PelangganListScreenState extends State<PelangganListScreen> {
  final HrdService _hrdService = HrdService();
  final TextEditingController _searchCtrl = TextEditingController();
  
  List<PelangganHrdModel> _pelanggans = [];
  List<CabangModel> _cabangs = [];
  
  int? _selectedCabang;
  bool _isLoading = true;

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
      final pelanggans = await _hrdService.fetchPelanggan();
      
      if (mounted) {
        setState(() {
          _cabangs = cabangs;
          _pelanggans = pelanggans;
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

  Future<void> _fetchPelanggan() async {
    setState(() => _isLoading = true);
    try {
      final pelanggans = await _hrdService.fetchPelanggan(
        cabangId: _selectedCabang,
        search: _searchCtrl.text,
      );
      if (mounted) {
        setState(() {
          _pelanggans = pelanggans;
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

  Future<void> _toggleStatusPelanggan(PelangganHrdModel pelanggan) async {
    final isAktif = pelanggan.status.toLowerCase() == 'aktif';
    final newStatus = isAktif ? 'nonaktif' : 'aktif';
    final action = isAktif ? 'menonaktifkan' : 'mengaktifkan';
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${isAktif ? 'Nonaktifkan' : 'Aktifkan'} Pelanggan?'),
        content: Text('Apakah Anda yakin ingin $action ${pelanggan.namaPelanggan}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: Text(isAktif ? 'Nonaktifkan' : 'Aktifkan', style: TextStyle(color: isAktif ? Colors.red : Colors.green)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _hrdService.updatePelanggan(pelanggan.id, {'status': newStatus});
        await _fetchPelanggan();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status pelanggan berhasil diubah')));
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
              hintText: 'Cari pelanggan...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onSubmitted: (_) => _fetchPelanggan(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            value: _selectedCabang,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            hint: const Text('Semua Cabang'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Semua Cabang')),
              ..._cabangs.map((c) => DropdownMenuItem(value: c.id, child: Text(c.namaCabang))),
            ],
            onChanged: (val) {
              setState(() => _selectedCabang = val);
              _fetchPelanggan();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItem(PelangganHrdModel pelanggan) {
    final isAktif = pelanggan.status.toLowerCase() == 'aktif';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                pelanggan.namaPelanggan.isNotEmpty ? pelanggan.namaPelanggan[0].toUpperCase() : '?',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          pelanggan.namaPelanggan,
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAktif ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isAktif ? Colors.green.shade200 : Colors.red.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isAktif ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              pelanggan.status.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10, 
                                fontWeight: FontWeight.bold, 
                                color: isAktif ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.storefront_rounded, size: 16, color: Colors.blue.shade400),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pelanggan.cabang?.namaCabang ?? '-',
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined, size: 16, color: Colors.green.shade400),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pelanggan.noWa ?? '-',
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_outlined, size: 16, color: Colors.orange.shade400),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pelanggan.alamat ?? '-',
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _toggleStatusPelanggan(pelanggan),
                        icon: Icon(isAktif ? Icons.block_outlined : Icons.check_circle_outline, size: 16),
                        label: Text(isAktif ? 'Nonaktifkan' : 'Aktifkan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(
                          foregroundColor: isAktif ? Colors.red.shade600 : Colors.green.shade600,
                          backgroundColor: isAktif ? Colors.red.shade50 : Colors.green.shade50,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => PelangganFormScreen(pelanggan: pelanggan)));
                          if (res == true) _fetchPelanggan();
                        },
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text('Edit Data', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const PelangganFormScreen()));
          if (res == true) _fetchPelanggan();
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
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
                Text(
                  'Daftar Pelanggan',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pelanggans.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_alt_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text('Belum ada data pelanggan', style: GoogleFonts.inter(color: Colors.grey)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchPelanggan,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _pelanggans.length,
                          itemBuilder: (ctx, i) => _buildItem(_pelanggans[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

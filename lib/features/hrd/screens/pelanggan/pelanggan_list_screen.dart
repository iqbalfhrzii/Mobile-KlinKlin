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

  Future<void> _deletePelanggan(PelangganHrdModel pelanggan) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan Pelanggan?'),
        content: Text('Apakah Anda yakin ingin menonaktifkan ${pelanggan.namaPelanggan}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Nonaktifkan', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _hrdService.deletePelanggan(pelanggan.id);
        await _fetchPelanggan();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pelanggan dinonaktifkan')));
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
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    pelanggan.namaPelanggan.isNotEmpty ? pelanggan.namaPelanggan[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pelanggan.namaPelanggan,
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pelanggan.status.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 12, 
                          fontWeight: FontWeight.w600, 
                          color: pelanggan.status.toLowerCase() == 'aktif' ? Colors.green : Colors.red
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.storefront_rounded, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pelanggan.cabang?.namaCabang ?? '-',
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pelanggan.noWa ?? '-',
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pelanggan.alamat ?? '-',
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () async {
                    final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => PelangganFormScreen(pelanggan: pelanggan)));
                    if (res == true) _fetchPelanggan();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueAccent),
                  label: Text('Edit', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.blueAccent)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20))),
                  ),
                ),
              ),
              Container(width: 1, height: 24, color: Colors.grey.withOpacity(0.2)),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _deletePelanggan(pelanggan),
                  icon: const Icon(Icons.block_outlined, size: 18, color: Colors.redAccent),
                  label: Text('Nonaktifkan', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.redAccent)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomRight: Radius.circular(20))),
                  ),
                ),
              ),
            ],
          ),
        ],
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
                            Icon(Icons.people_alt_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
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

import 'package:flutter/material.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'karyawan_form_screen.dart';
import 'karyawan_detail_screen.dart';

class KaryawanListScreen extends StatefulWidget {
  const KaryawanListScreen({super.key});

  @override
  State<KaryawanListScreen> createState() => _KaryawanListScreenState();
}

class _KaryawanListScreenState extends State<KaryawanListScreen> {
  final HrdService _hrdService = HrdService();
  bool _isLoading = true;
  String _error = '';
  List<KaryawanModel> _karyawans = [];
  List<CabangModel> _cabangs = [];
  String _searchQuery = '';
  int? _selectedCabangId;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final data = await _hrdService.fetchKaryawan();
      final cabangs = await _hrdService.fetchCabang();
      if (mounted) {
        setState(() {
          _karyawans = data;
          _cabangs = cabangs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _delete(KaryawanModel karyawan) async {
    final confirm = await AppConfirmationDialog.show(
      context,
      title: 'Hapus Karyawan',
      message: 'Apakah Anda yakin ingin menghapus ${karyawan.nama}?',
      type: ConfirmationDialogType.danger,
      customIcon: Icons.delete_forever_rounded,
      confirmText: 'Hapus',
      cancelText: 'Batal',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await _hrdService.deleteKaryawan(karyawan.id);
        _fetchData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const KaryawanFormScreen()));
          if (res == true) _fetchData();
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Data Master', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                    Text('Karyawan', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari karyawan...',
                      hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _selectedCabangId,
                        isExpanded: true,
                        hint: Text('Semua', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                        icon: const Icon(Icons.filter_list, size: 18, color: AppColors.textMuted),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 13)),
                          ),
                          ..._cabangs.map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.namaCabang, style: GoogleFonts.inter(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedCabangId = val;
                          });
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
                    ? Center(child: Text(_error, style: const TextStyle(color: AppColors.error)))
                    : RefreshIndicator(
                        onRefresh: _fetchData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _karyawans.where((k) {
                            final matchName = k.nama.toLowerCase().contains(_searchQuery.toLowerCase());
                            final matchCabang = _selectedCabangId == null || k.cabangId == _selectedCabangId || k.cabangId == 0;
                            return matchName && matchCabang;
                          }).length,
                          itemBuilder: (context, index) {
                            final filtered = _karyawans.where((k) {
                              final matchName = k.nama.toLowerCase().contains(_searchQuery.toLowerCase());
                              final matchCabang = _selectedCabangId == null || k.cabangId == _selectedCabangId || k.cabangId == 0;
                              return matchName && matchCabang;
                            }).toList();
                            final karyawan = filtered[index];
                            return _buildItem(karyawan);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(KaryawanModel karyawan) {
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
            Navigator.push(context, MaterialPageRoute(builder: (_) => KaryawanDetailScreen(karyawan: karyawan)));
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
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      backgroundImage: karyawan.fotoProfil != null ? NetworkImage(karyawan.fotoProfil!) : null,
                      child: karyawan.fotoProfil == null ? Text(karyawan.nama.substring(0, 1).toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)) : null,
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
                                  karyawan.nama,
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: karyawan.status == 'aktif' ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  karyawan.status.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: karyawan.status == 'aktif' ? Colors.green.shade700 : Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(karyawan.email, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(karyawan.noWa ?? '-', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.work_outline_rounded, size: 12, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Text(karyawan.jabatan?.namaJabatan ?? '-', style: GoogleFonts.inter(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.storefront_rounded, size: 12, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(karyawan.cabang?.namaCabang ?? '-', style: GoogleFonts.inter(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
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
                          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => KaryawanFormScreen(karyawan: karyawan)));
                          if (res == true) _fetchData();
                        },
                        icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 18),
                        label: Text('Edit', style: GoogleFonts.inter(color: Colors.blue, fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24))),
                        ),
                      ),
                    ),
                    Container(width: 1, height: 30, color: Colors.grey.shade200),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _delete(karyawan),
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                        label: Text('Hapus', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
}

import 'package:flutter/material.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'jabatan_form_screen.dart';

class JabatanListScreen extends StatefulWidget {
  const JabatanListScreen({super.key});

  @override
  State<JabatanListScreen> createState() => _JabatanListScreenState();
}

class _JabatanListScreenState extends State<JabatanListScreen> {
  final HrdService _hrdService = HrdService();
  bool _isLoading = true;
  String _error = '';
  List<JabatanModel> _jabatans = [];
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
      final data = await _hrdService.fetchJabatan();
      final cabangs = await _hrdService.fetchCabang();
      if (mounted) {
        setState(() {
          _jabatans = data;
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

  Future<void> _delete(JabatanModel jabatan) async {
    final confirm = await AppConfirmationDialog.show(
      context,
      title: 'Hapus Jabatan',
      message: 'Apakah Anda yakin ingin menghapus ${jabatan.namaJabatan}?',
      type: ConfirmationDialogType.danger,
      customIcon: Icons.delete_forever_rounded,
      confirmText: 'Hapus',
      cancelText: 'Batal',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await _hrdService.deleteJabatan(jabatan.id);
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
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const JabatanFormScreen()));
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
                    Text('Jabatan', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
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
                      hintText: 'Cari jabatan...',
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
                          itemCount: _jabatans.where((j) {
                            final matchName = j.namaJabatan.toLowerCase().contains(_searchQuery.toLowerCase());
                            final matchCabang = _selectedCabangId == null || j.cabangId == _selectedCabangId || j.cabangId == 0;
                            return matchName && matchCabang;
                          }).length,
                          itemBuilder: (context, index) {
                            final filtered = _jabatans.where((j) {
                              final matchName = j.namaJabatan.toLowerCase().contains(_searchQuery.toLowerCase());
                              final matchCabang = _selectedCabangId == null || j.cabangId == _selectedCabangId || j.cabangId == 0;
                              return matchName && matchCabang;
                            }).toList();
                            final jabatan = filtered[index];
                            return _buildItem(jabatan);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(JabatanModel jabatan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.work_outline_rounded, color: Colors.blue, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jabatan.namaJabatan, 
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.storefront_rounded, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                jabatan.cabang?.namaCabang ?? 'Semua Cabang',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => JabatanFormScreen(jabatan: jabatan)));
                      if (res == true) _fetchData();
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text('Edit', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _delete(jabatan),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: Text('Hapus', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      backgroundColor: Colors.red.shade50,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
}

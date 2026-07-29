import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'cabang_form_screen.dart';
import 'cabang_detail_screen.dart';

class CabangListScreen extends StatefulWidget {
  const CabangListScreen({super.key});

  @override
  State<CabangListScreen> createState() => _CabangListScreenState();
}

class _CabangListScreenState extends State<CabangListScreen> {
  final HrdService _hrdService = HrdService();
  bool _isLoading = true;
  String _error = '';
  List<CabangModel> _cabangs = [];
  String _searchQuery = '';

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
      final data = await _hrdService.fetchCabang();
      if (mounted) {
        setState(() {
          _cabangs = data;
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

  Future<void> _delete(CabangModel cabang) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Cabang'),
        content: Text(
          'Apakah Anda yakin ingin menghapus ${cabang.namaCabang}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _hrdService.deleteCabang(cabang.id);
        _fetchData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
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
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CabangFormScreen()),
          );
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
                  child: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data Master',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      'Cabang',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari nama cabang...',
                hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                ? Center(
                    child: Text(
                      _error,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _cabangs
                          .where(
                            (c) => c.namaCabang.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ),
                          )
                          .length,
                      itemBuilder: (context, index) {
                        final filtered = _cabangs
                            .where(
                              (c) => c.namaCabang.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              ),
                            )
                            .toList();
                        final cabang = filtered[index];
                        return _buildItem(cabang);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(CabangModel cabang) {
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
          onTap: () async {
            final res = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CabangDetailScreen(cabang: cabang),
              ),
            );
            if (res == true) _fetchData();
          },
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cabang.namaCabang,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: Colors.redAccent,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    cabang.alamat ?? 'Tidak ada alamat',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.login_rounded, size: 14, color: Colors.blue.shade700),
                                const SizedBox(width: 4),
                                Text(cabang.jamMasuk ?? '-', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                                const SizedBox(width: 12),
                                Icon(Icons.timer_outlined, size: 14, color: Colors.orange.shade700),
                                const SizedBox(width: 4),
                                Text('${cabang.toleransiTelatMenit ?? 0}m', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                                const SizedBox(width: 12),
                                Icon(Icons.logout_rounded, size: 14, color: Colors.purple.shade700),
                                const SizedBox(width: 4),
                                Text(cabang.jamPulang ?? '-', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: cabang.status == 'aktif' ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: cabang.status == 'aktif' ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                cabang.status.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: cabang.status == 'aktif' ? Colors.green.shade700 : Colors.red.shade700,
                                ),
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
                                  final res = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CabangFormScreen(cabang: cabang),
                                    ),
                                  );
                                  if (res == true) _fetchData();
                                },
                                icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 18),
                                label: Text('Edit', style: GoogleFonts.inter(color: Colors.blue, fontWeight: FontWeight.w600)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24)),
                                  ),
                                ),
                              ),
                            ),
                            Container(width: 1, height: 30, color: Colors.grey.shade200),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () => _delete(cabang),
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                                label: Text('Hapus', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.only(bottomRight: Radius.circular(24)),
                                  ),
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

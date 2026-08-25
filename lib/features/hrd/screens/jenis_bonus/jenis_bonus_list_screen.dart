import 'package:flutter/material.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'jenis_bonus_form_screen.dart';
import 'package:dio/dio.dart';

class JenisBonusListScreen extends StatefulWidget {
  const JenisBonusListScreen({super.key});

  @override
  State<JenisBonusListScreen> createState() => _JenisBonusListScreenState();
}

class _JenisBonusListScreenState extends State<JenisBonusListScreen> {
  final HrdService _hrdService = HrdService();
  bool _isLoading = true;
  String _error = '';
  List<JenisBonusModel> _jenisBonusList = [];
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
      final data = await _hrdService.fetchJenisBonus();
      if (mounted) {
        setState(() {
          _jenisBonusList = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is DioException && e.response?.statusCode == 404) {
            _error = 'Fitur ini belum tersedia di server (404).';
          } else {
            _error = e.toString().replaceFirst('Exception: ', '');
          }
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _delete(JenisBonusModel jenisBonus) async {
    final confirm = await AppConfirmationDialog.show(
      context,
      title: 'Hapus Jenis Bonus',
      message: 'Apakah Anda yakin ingin menghapus ${jenisBonus.namaBonus}?',
      type: ConfirmationDialogType.danger,
      customIcon: Icons.delete_forever_rounded,
      confirmText: 'Hapus',
      cancelText: 'Batal',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await _hrdService.deleteJenisBonus(jenisBonus.id);
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
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const JenisBonusFormScreen()));
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
                    Text('Kategori Bonus', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari kategori bonus...',
                hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
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
                    ? Center(child: Text(_error, style: const TextStyle(color: AppColors.error)))
                    : RefreshIndicator(
                        onRefresh: _fetchData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _jenisBonusList.where((b) => b.namaBonus.toLowerCase().contains(_searchQuery.toLowerCase())).length,
                          itemBuilder: (context, index) {
                            final filtered = _jenisBonusList.where((b) => b.namaBonus.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                            final jenisBonus = filtered[index];
                            return _buildItem(jenisBonus);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(JenisBonusModel jenisBonus) {
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
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.card_giftcard_rounded, color: Colors.purple, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jenisBonus.namaBonus, 
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kategori Bonus Tambahan',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
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
                      final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => JenisBonusFormScreen(jenisBonus: jenisBonus)));
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
                    onPressed: () => _delete(jenisBonus),
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

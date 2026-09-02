import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/finance_ppn_service.dart';

class FinancePengaturanPpnScreen extends StatefulWidget {
  const FinancePengaturanPpnScreen({super.key});

  @override
  State<FinancePengaturanPpnScreen> createState() => _FinancePengaturanPpnScreenState();
}

class _FinancePengaturanPpnScreenState extends State<FinancePengaturanPpnScreen> {
  final FinancePpnService _service = FinancePpnService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _cabangs = [];
  Map<int, bool> _ppnSettings = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final cabangs = await _service.fetchCabangPpnSettings();
      final Map<int, bool> settings = {};
      for (final c in cabangs) {
        final id = int.tryParse(c['id']?.toString() ?? '') ?? 0;
        final isEnabled = c['is_ppn_enabled'] == true ||
            c['is_ppn_enabled'] == 1 ||
            c['is_ppn_enabled']?.toString() == '1' ||
            c['is_ppn_enabled']?.toString().toLowerCase() == 'true';
        settings[id] = isEnabled;
      }

      if (mounted) {
        setState(() {
          _cabangs = cabangs;
          _ppnSettings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await _service.saveCabangPpnSettings(_ppnSettings);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Pengaturan PPN cabang berhasil disimpan.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredCabangs {
    if (_searchQuery.isEmpty) return _cabangs;
    final query = _searchQuery.toLowerCase();
    return _cabangs.where((c) {
      final name = (c['nama_cabang'] ?? '').toString().toLowerCase();
      return name.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _ppnSettings.values.where((v) => v == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // 1. Header
          GradientHeader(
            padding: EdgeInsets.fromLTRB(20, 50, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pengaturan PPN',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Atur penggunaan PPN untuk setiap cabang di sini',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isSaving)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    else
                      IconButton(
                        onPressed: _loadSettings,
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                        tooltip: 'Muat ulang',
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Info Banner & Overview
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kewajiban PPN Cabang (Otoritas Penuh Finance)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E40AF),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Jika diaktifkan (Wajib), CS cabang otomatis mengenakan PPN 11% dan tidak bisa membatalkan centangnya. Jika dinonaktifkan, CS juga tidak bisa mencentangnya.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF1E3A8A),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Search and Stats Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      style: GoogleFonts.inter(fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'Cari nama cabang...',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    '$activeCount / ${_cabangs.length} Wajib',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Cabang Table Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Nama Cabang',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                  Text(
                    'Wajib PPN?',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Cabang List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _filteredCabangs.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isNotEmpty ? 'Cabang tidak ditemukan' : 'Tidak ada data cabang',
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSettings,
                        color: const Color(0xFF2563EB),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                          itemCount: _filteredCabangs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final cabang = _filteredCabangs[index];
                            final id = int.tryParse(cabang['id']?.toString() ?? '') ?? 0;
                            final name = cabang['nama_cabang'] ?? '-';
                            final isEnabled = _ppnSettings[id] ?? false;
                            final isLast = index == _filteredCabangs.length - 1;

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: isLast
                                    ? const BorderRadius.vertical(bottom: Radius.circular(14))
                                    : BorderRadius.zero,
                                border: Border(
                                  left: const BorderSide(color: Color(0xFFE2E8F0)),
                                  right: const BorderSide(color: Color(0xFFE2E8F0)),
                                  bottom: isLast
                                      ? const BorderSide(color: Color(0xFFE2E8F0))
                                      : BorderSide.none,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isEnabled
                                          ? const Color(0xFFEFF6FF)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isEnabled
                                            ? const Color(0xFFBFDBFE)
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.storefront_rounded,
                                      size: 16,
                                      color: isEnabled
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.inter(
                                            fontSize: 13.5,
                                            fontWeight: isEnabled ? FontWeight.bold : FontWeight.w500,
                                            color: isEnabled
                                                ? const Color(0xFF0F172A)
                                                : const Color(0xFF334155),
                                          ),
                                        ),
                                        Text(
                                          isEnabled ? 'Wajib PPN (11%)' : 'Tidak Wajib PPN (0%)',
                                          style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            color: isEnabled
                                                ? const Color(0xFF2563EB)
                                                : const Color(0xFF94A3B8),
                                            fontWeight: isEnabled ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: isEnabled,
                                    onChanged: (val) {
                                      setState(() {
                                        _ppnSettings[id] = val;
                                      });
                                    },
                                    activeThumbColor: const Color(0xFF2563EB),
                                    activeTrackColor: const Color(0xFFBFDBFE),
                                    inactiveThumbColor: const Color(0xFFCBD5E1),
                                    inactiveTrackColor: const Color(0xFFF1F5F9),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),

      // 6. Bottom Sticky Save Button
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 16 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_rounded, size: 18),
            label: Text(
              _isSaving ? 'Menyimpan Pengaturan...' : 'Simpan Pengaturan PPN',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}

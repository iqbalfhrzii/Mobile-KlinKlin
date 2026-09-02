import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'pelanggan_form_sheet.dart';

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
  String _selectedStatus = ''; // '' (semua), 'aktif', 'nonaktif'
  String _searchQuery = '';
  bool _isLoading = true;
  String _error = '';

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
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final futures = await Future.wait([
        _hrdService.fetchCabang(),
        _hrdService.fetchPelanggan(),
      ]);

      if (mounted) {
        setState(() {
          _cabangs = futures[0] as List<CabangModel>;
          _pelanggans = futures[1] as List<PelangganHrdModel>;
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

  Future<void> _fetchPelanggan() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final pelanggans = await _hrdService.fetchPelanggan(
        cabangId: _selectedCabang,
        search: _searchQuery,
      );
      if (mounted) {
        setState(() {
          _pelanggans = pelanggans;
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

  Future<void> _openFormModal({PelangganHrdModel? pelanggan}) async {
    final res = await PelangganFormSheet.show(
      context,
      pelanggan: pelanggan,
      cabangs: _cabangs,
    );
    if (res == true) {
      _fetchPelanggan();
    }
  }

  Future<void> _toggleStatusPelanggan(PelangganHrdModel pelanggan) async {
    final isAktif = pelanggan.status.toLowerCase() == 'aktif';
    final newStatus = isAktif ? 'nonaktif' : 'aktif';
    final action = isAktif ? 'menonaktifkan' : 'mengaktifkan';

    final bool? confirm = await AppConfirmationDialog.show(
      context,
      title: '${isAktif ? 'Nonaktifkan' : 'Aktifkan'} Pelanggan?',
      message: 'Apakah Anda yakin ingin $action data "${pelanggan.namaPelanggan}"?',
      type: isAktif ? ConfirmationDialogType.danger : ConfirmationDialogType.success,
      customIcon: isAktif ? Icons.block_rounded : Icons.check_circle_rounded,
      confirmText: isAktif ? 'Ya, Nonaktifkan' : 'Ya, Aktifkan',
      cancelText: 'Batal',
      isDestructive: isAktif,
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _hrdService.updatePelanggan(pelanggan.id, {'status': newStatus});
        await _fetchPelanggan();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status "${pelanggan.namaPelanggan}" berhasil diubah menjadi $newStatus'),
              backgroundColor: isAktif ? const Color(0xFF475569) : const Color(0xFF15803D),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal mengubah status: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return;
    final formatted = clean.startsWith('0') ? '62${clean.substring(1)}' : clean;
    final uri = Uri.parse('https://wa.me/$formatted');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka WhatsApp: $e')),
        );
      }
    }
  }

  void _copyText(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label berhasil disalin ke clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _pelanggans.where((p) {
      final q = _searchQuery.toLowerCase();
      final matchName = p.namaPelanggan.toLowerCase().contains(q);
      final matchWa = (p.noWa?.toLowerCase().contains(q) ?? false);
      final matchAddr = (p.alamat?.toLowerCase().contains(q) ?? false);
      final matchCabang = _selectedCabang == null || p.cabangId == _selectedCabang;
      final matchStatus = _selectedStatus.isEmpty || p.status.toLowerCase() == _selectedStatus;
      return (matchName || matchWa || matchAddr) && matchCabang && matchStatus;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFormModal(),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: Text(
          'Tambah Pelanggan',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header
          GradientHeader(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 10 : 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Master',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Daftar Pelanggan',
                        style: GoogleFonts.inter(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_pelanggans.length} Pelanggan',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Search Input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF64748B).withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: GoogleFonts.inter(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Cari nama, no. WA, atau alamat...',
                      hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                                _fetchPelanggan();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                    onSubmitted: (_) => _fetchPelanggan(),
                  ),
                ),

                const SizedBox(height: 10),

                // Horizontal Filters (Cabang & Status)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Cabang Filter Dropdown Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: _selectedCabang != null ? const Color(0xFFEFF6FF) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedCabang != null ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _selectedCabang,
                            isDense: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                            hint: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                              ..._cabangs.map((c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.namaCabang, style: GoogleFonts.inter(fontSize: 12)),
                                  )),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedCabang = val);
                              _fetchPelanggan();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Status Filter Chips
                      _buildFilterChip('Semua Status', '', _selectedStatus == ''),
                      const SizedBox(width: 6),
                      _buildFilterChip('Aktif', 'aktif', _selectedStatus == 'aktif'),
                      const SizedBox(width: 6),
                      _buildFilterChip('Nonaktif', 'nonaktif', _selectedStatus == 'nonaktif'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 44, color: Color(0xFFEF4444)),
                            const SizedBox(height: 10),
                            Text(
                              _error,
                              style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _fetchInitialData,
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people_alt_rounded, size: 44, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 10),
                                Text(
                                  _searchQuery.isNotEmpty || _selectedCabang != null || _selectedStatus.isNotEmpty
                                      ? 'Tidak ada pelanggan sesuai filter'
                                      : 'Belum ada data pelanggan',
                                  style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchPelanggan,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final pelanggan = filtered[index];
                                return _buildPelangganCard(pelanggan);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isSelected) {
    return InkWell(
      onTap: () => setState(() => _selectedStatus = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildPelangganCard(PelangganHrdModel pelanggan) {
    final isAktif = pelanggan.status.toLowerCase() == 'aktif';
    final cabangName = pelanggan.cabang?.namaCabang ??
        _cabangs.firstWhere((c) => c.id == pelanggan.cabangId, orElse: () => CabangModel(id: 0, namaCabang: 'Semua Cabang', status: 'aktif')).namaCabang;
    final hasWa = pelanggan.noWa != null && pelanggan.noWa!.trim().isNotEmpty && pelanggan.noWa != '-';
    final hasAlamat = pelanggan.alamat != null && pelanggan.alamat!.trim().isNotEmpty && pelanggan.alamat != '-';
    final hasCatatan = pelanggan.catatan != null && pelanggan.catatan!.trim().isNotEmpty && pelanggan.catatan != '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar Initial + Nama + Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    pelanggan.namaPelanggan.isNotEmpty ? pelanggan.namaPelanggan[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pelanggan.namaPelanggan,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.storefront_rounded, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              cabangName,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isAktif ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isAktif ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isAktif ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAktif ? 'Aktif' : 'Nonaktif',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isAktif ? const Color(0xFF059669) : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Contact & Address Details
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                children: [
                  // WhatsApp row
                  Row(
                    children: [
                      const Icon(Icons.phone_android_rounded, size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hasWa ? pelanggan.noWa! : 'Belum ada nomor WhatsApp',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: hasWa ? FontWeight.w600 : FontWeight.normal,
                            color: hasWa ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      if (hasWa) ...[
                        InkWell(
                          onTap: () => _openWhatsApp(pelanggan.noWa!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline_rounded, size: 11, color: Color(0xFF15803D)),
                                const SizedBox(width: 4),
                                Text(
                                  'Chat WA',
                                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Address row
                  if (hasAlamat) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFFEF4444)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            pelanggan.alamat!,
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF475569)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () => _copyText(pelanggan.alamat!, 'Alamat'),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.copy_rounded, size: 13, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Catatan row
                  if (hasCatatan) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.sticky_note_2_outlined, size: 14, color: Color(0xFF6366F1)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            pelanggan.catatan!,
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),

            // Actions Row: Toggle Status & Edit
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () => _toggleStatusPelanggan(pelanggan),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isAktif ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isAktif ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isAktif ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                          size: 14,
                          color: isAktif ? const Color(0xFFDC2626) : const Color(0xFF059669),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAktif ? 'Nonaktifkan' : 'Aktifkan',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isAktif ? const Color(0xFFDC2626) : const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _openFormModal(pelanggan: pelanggan),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 4),
                        Text(
                          'Edit Data',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

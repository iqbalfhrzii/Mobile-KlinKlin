import 'package:flutter/material.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'karyawan_form_sheet.dart';
import 'karyawan_detail_sheet.dart';

class KaryawanListScreen extends StatefulWidget {
  const KaryawanListScreen({super.key});

  @override
  State<KaryawanListScreen> createState() => _KaryawanListScreenState();
}

class _KaryawanListScreenState extends State<KaryawanListScreen> {
  final HrdService _hrdService = HrdService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String _error = '';
  List<KaryawanModel> _karyawans = [];
  List<CabangModel> _cabangs = [];
  List<JabatanModel> _jabatans = [];

  String _searchQuery = '';
  int? _selectedCabangId;
  String? _selectedStatusAkun;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final data = await _hrdService.fetchKaryawan();
      final cabangs = await _hrdService.fetchCabang();
      final jabatans = await _hrdService.fetchJabatan();
      if (mounted) {
        setState(() {
          _karyawans = data;
          _cabangs = cabangs;
          _jabatans = jabatans;
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

  Future<void> _openFormModal({KaryawanModel? karyawan}) async {
    final res = await KaryawanFormSheet.show(
      context,
      karyawan: karyawan,
      cabangs: _cabangs,
      jabatans: _jabatans,
    );
    if (res == true) {
      _fetchData();
    }
  }

  Future<void> _delete(KaryawanModel karyawan) async {
    final confirm = await AppConfirmationDialog.show(
      context,
      title: 'Hapus Karyawan',
      message: 'Apakah Anda yakin ingin menghapus data karyawan "${karyawan.nama}"?',
      type: ConfirmationDialogType.danger,
      customIcon: Icons.delete_forever_rounded,
      confirmText: 'Ya, Hapus',
      cancelText: 'Batal',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await _hrdService.deleteKaryawan(karyawan.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Karyawan ${karyawan.nama} berhasil dihapus'),
              backgroundColor: const Color(0xFF475569),
            ),
          );
        }
        _fetchData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _karyawans.where((k) {
      final query = _searchQuery.toLowerCase();
      final matchName = k.nama.toLowerCase().contains(query);
      final matchEmail = k.email.toLowerCase().contains(query);
      final matchWa = (k.noWa ?? '').toLowerCase().contains(query);
      final matchJabatan = (k.jabatan?.namaJabatan ?? '').toLowerCase().contains(query);
      final matchCabangName = (k.cabang?.namaCabang ?? '').toLowerCase().contains(query);
      final matchSearch = matchName || matchEmail || matchWa || matchJabatan || matchCabangName;

      final matchCabang = _selectedCabangId == null || k.cabangId == _selectedCabangId || k.cabangId == 0;
      final matchStatus = _selectedStatusAkun == null || k.status.toLowerCase() == _selectedStatusAkun!.toLowerCase();

      return matchSearch && matchCabang && matchStatus;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFormModal(),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: Text(
          'Tambah Karyawan',
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
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
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
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Karyawan',
                        style: GoogleFonts.inter(
                          fontSize: 20,
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
                    '${_karyawans.length} Karyawan',
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                // Search Input
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF64748B).withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Cari karyawan, cabang, jabatan...',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12.5),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 19),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Cabang Filter Dropdown
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _selectedCabangId != null
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF64748B).withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _selectedCabangId,
                        isExpanded: true,
                        icon: Icon(
                          Icons.filter_list_rounded,
                          size: 18,
                          color: _selectedCabangId != null
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF64748B),
                        ),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              'Semua Cabang',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: _selectedCabangId == null ? FontWeight.bold : FontWeight.w500,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ..._cabangs.map(
                            (c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text(
                                c.namaCabang,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: _selectedCabangId == c.id ? FontWeight.bold : FontWeight.w500,
                                  color: const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
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
                              onPressed: _fetchData,
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
                                const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 10),
                                Text(
                                  _searchQuery.isNotEmpty || _selectedCabangId != null
                                      ? 'Tidak ada karyawan sesuai filter'
                                      : 'Belum ada data karyawan',
                                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchData,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final karyawan = filtered[index];
                                return _buildKaryawanCard(karyawan);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildKaryawanCard(KaryawanModel karyawan) {
    final statusStr = karyawan.status.toLowerCase();
    final isAktif = statusStr == 'aktif';
    final isPending = statusStr == 'pending';

    final isKoor = (karyawan.statusKaryawan ?? '').toLowerCase().contains('koor');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () async {
            final res = await KaryawanDetailSheet.show(
              context,
              karyawan: karyawan,
              cabangs: _cabangs,
              jabatans: _jabatans,
              onEdit: () => _openFormModal(karyawan: karyawan),
            );
            if (res == true) {
              _fetchData();
            }
          },
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Header: Avatar, Name, Status Badge
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFEFF6FF),
                      backgroundImage: (karyawan.fotoProfil != null && karyawan.fotoProfil!.isNotEmpty)
                          ? NetworkImage(karyawan.fotoProfil!)
                          : null,
                      child: (karyawan.fotoProfil == null || karyawan.fotoProfil!.isEmpty)
                          ? Text(
                              karyawan.nama.isNotEmpty ? karyawan.nama.substring(0, 1).toUpperCase() : 'K',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF2563EB),
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),

                    // Name & Details
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
                                  style: GoogleFonts.inter(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Status Akun Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isAktif
                                      ? const Color(0xFFDCFCE7)
                                      : isPending
                                          ? const Color(0xFFFEF3C7)
                                          : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  karyawan.status.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isAktif
                                        ? const Color(0xFF15803D)
                                        : isPending
                                            ? const Color(0xFFB45309)
                                            : const Color(0xFFB91C1C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),

                          // Email
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 13, color: Color(0xFF64748B)),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  karyawan.email,
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          // No. WA
                          if (karyawan.noWa != null && karyawan.noWa!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF64748B)),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    karyawan.noWa!,
                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tags Row: Jabatan, Cabang, Status Pegawai
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Jabatan
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.work_outline_rounded, size: 12, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(
                            karyawan.jabatan?.namaJabatan ?? 'Staff',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Cabang
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFEDD5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.storefront_rounded, size: 12, color: Color(0xFFEA580C)),
                          const SizedBox(width: 4),
                          Text(
                            karyawan.cabang?.namaCabang ?? 'Pusat',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFFEA580C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status Pegawai (Tetap / Tetap Koor / Kontrak / Training)
                    if (karyawan.statusKaryawan != null && karyawan.statusKaryawan!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isKoor ? const Color(0xFFFFFBEB) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isKoor ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isKoor ? Icons.star_rounded : Icons.badge_outlined,
                              size: 12,
                              color: isKoor ? const Color(0xFFD97706) : const Color(0xFF475569),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              karyawan.statusKaryawan!,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isKoor ? const Color(0xFFD97706) : const Color(0xFF475569),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Card Bottom Action Buttons (Edit Pop-up & Hapus)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    // Edit Button (Direct Pop-up Modal)
                    Expanded(
                      child: InkWell(
                        onTap: () => _openFormModal(karyawan: karyawan),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.edit_outlined,
                                size: 15,
                                color: Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Edit',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Hapus Button
                    Expanded(
                      child: InkWell(
                        onTap: () => _delete(karyawan),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.delete_outline_rounded,
                                size: 15,
                                color: Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Hapus',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                            ],
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

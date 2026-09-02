import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'karyawan_form_sheet.dart';
import 'karyawan_detail_sheet.dart';

class KaryawanListScreen extends StatefulWidget {
  final int initialTabIndex;
  const KaryawanListScreen({super.key, this.initialTabIndex = 0});

  @override
  State<KaryawanListScreen> createState() => _KaryawanListScreenState();
}

class _KaryawanListScreenState extends State<KaryawanListScreen> {
  final HrdService _hrdService = HrdService();
  final TextEditingController _searchController = TextEditingController();

  late int _activeTabIndex;

  bool _isLoading = true;
  String _error = '';
  List<KaryawanModel> _karyawans = [];
  List<CabangModel> _cabangs = [];
  List<JabatanModel> _jabatans = [];

  String _searchQuery = '';
  int? _selectedCabangId;
  String? _selectedStatusAkun;

  final String _registrationUrl = 'https://erp.klinklin.online/registrasi-karyawan';

  @override
  void initState() {
    super.initState();
    _activeTabIndex = widget.initialTabIndex;
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

  void _copyRegistrationLink() {
    Clipboard.setData(ClipboardData(text: _registrationUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Link pendaftaran berhasil disalin ke clipboard!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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

  Future<void> _openApproveModal(KaryawanModel karyawan) async {
    int selectedCabang = karyawan.cabangId > 0
        ? karyawan.cabangId
        : (_cabangs.isNotEmpty ? _cabangs.first.id : 1);
    int selectedJabatan = karyawan.jabatanId > 0
        ? karyawan.jabatanId
        : (_jabatans.where((j) => j.cabangId == selectedCabang).isNotEmpty
            ? _jabatans.where((j) => j.cabangId == selectedCabang).first.id
            : 1);
    String selectedStatusKaryawan = karyawan.statusKaryawan != null &&
            ['Tetap', 'Tetap Koor', 'Kontrak', 'Training']
                .contains(karyawan.statusKaryawan)
        ? karyawan.statusKaryawan!
        : 'Training';

    final approved = await showModalBottomSheet<bool>(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final availableJabatans = _jabatans
                .where((j) => j.cabangId == selectedCabang || j.cabangId == 0)
                .toList();

            return Container(
              padding: EdgeInsets.only(
                top: 16,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.how_to_reg_rounded, color: Color(0xFF16A34A), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Setujui Karyawan Baru',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Color(0xFFE2E8F0)),

                    // Applicant Info Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          _buildAvatar(karyawan, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  karyawan.nama,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  karyawan.email,
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                ),
                                if (karyawan.noWa != null && karyawan.noWa!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'WA: ${karyawan.noWa}',
                                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Penempatan Cabang
                    Text(
                      'Penempatan Cabang *',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: _cabangs.any((c) => c.id == selectedCabang) ? selectedCabang : (_cabangs.isNotEmpty ? _cabangs.first.id : null),
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: const Icon(Icons.business_rounded, size: 18, color: Color(0xFF64748B)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      items: _cabangs.map((c) => DropdownMenuItem(value: c.id, child: Text(c.namaCabang, style: GoogleFonts.inter(fontSize: 13)))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedCabang = val;
                            final newJabs = _jabatans.where((j) => j.cabangId == val || j.cabangId == 0).toList();
                            if (newJabs.isNotEmpty && !newJabs.any((j) => j.id == selectedJabatan)) {
                              selectedJabatan = newJabs.first.id;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Jabatan
                    Text(
                      'Jabatan *',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: availableJabatans.any((j) => j.id == selectedJabatan) ? selectedJabatan : (availableJabatans.isNotEmpty ? availableJabatans.first.id : null),
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: const Icon(Icons.badge_rounded, size: 18, color: Color(0xFF64748B)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      items: availableJabatans.map((j) => DropdownMenuItem(value: j.id, child: Text(j.namaJabatan, style: GoogleFonts.inter(fontSize: 13)))).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedJabatan = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Status Pegawai
                    Text(
                      'Status Pegawai *',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatusKaryawan,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: const Icon(Icons.card_membership_rounded, size: 18, color: Color(0xFF64748B)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Freelance', child: Text('Freelance')),
                        DropdownMenuItem(value: 'Vendor', child: Text('Vendor')),
                        DropdownMenuItem(value: 'Training', child: Text('Training (Masa Percobaan)')),
                        DropdownMenuItem(value: 'Semi', child: Text('Semi')),
                        DropdownMenuItem(value: 'Tetap', child: Text('Tetap')),
                        DropdownMenuItem(value: 'Tetap Koor', child: Text('Tetap Koor (Cleaner Koor)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedStatusKaryawan = val);
                      },
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(ctx, true);
                            },
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                            label: const Text('Setujui & Aktifkan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (approved == true) {
      try {
        final payload = {
          'nama': karyawan.nama,
          'email': karyawan.email,
          'cabang_id': selectedCabang,
          'jabatan_id': selectedJabatan,
          'status': 'aktif',
          'status_karyawan': selectedStatusKaryawan,
          'no_wa': karyawan.noWa,
          'nama_bank': karyawan.namaBank,
          'no_rekening': karyawan.noRekening,
        };

        await _hrdService.updateKaryawan(karyawan.id, payload);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Karyawan ${karyawan.nama} berhasil disetujui & aktif!'),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        }
        _fetchData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menyetujui: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  Future<void> _delete(KaryawanModel karyawan) async {
    final isPending = karyawan.status.toLowerCase() == 'pending';
    final confirm = await AppConfirmationDialog.show(
      context,
      title: isPending ? 'Tolak & Hapus Pendaftaran' : 'Hapus Karyawan',
      message: isPending
          ? 'Apakah Anda yakin ingin menolak dan menghapus pendaftaran karyawan "${karyawan.nama}"?'
          : 'Apakah Anda yakin ingin menghapus data karyawan "${karyawan.nama}"?',
      type: ConfirmationDialogType.danger,
      customIcon: Icons.delete_forever_rounded,
      confirmText: isPending ? 'Ya, Tolak' : 'Ya, Hapus',
      cancelText: 'Batal',
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await _hrdService.deleteKaryawan(karyawan.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isPending ? 'Pendaftaran ${karyawan.nama} telah ditolak' : 'Karyawan ${karyawan.nama} berhasil dihapus'),
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

  Future<void> _openWhatsApp(String? rawPhone) async {
    if (rawPhone == null || rawPhone.isEmpty) return;
    var phone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('0')) {
      phone = '62${phone.substring(1)}';
    }
    final uri = Uri.parse('https://wa.me/$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Separate active and pending employees
    final activeKaryawans = _karyawans.where((k) => k.status.toLowerCase() != 'pending').toList();
    final pendingKaryawans = _karyawans.where((k) => k.status.toLowerCase() == 'pending').toList();

    final currentList = _activeTabIndex == 0 ? activeKaryawans : pendingKaryawans;

    final filtered = currentList.where((k) {
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
      floatingActionButton: _activeTabIndex == 0
          ? FloatingActionButton.extended(
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
            )
          : null,
      body: Column(
        children: [
          // 1. Header
          GradientHeader(
            padding: EdgeInsets.fromLTRB(20, 52, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 12 : 16),
            child: Column(
              children: [
                Row(
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
                        _activeTabIndex == 0
                            ? '${activeKaryawans.length} Karyawan'
                            : '${pendingKaryawans.length} Pengajuan',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Tabs Selector (Daftar Karyawan vs Acc Karyawan Baru)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activeTabIndex = 0),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _activeTabIndex == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _activeTabIndex == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_alt_rounded,
                              size: 16,
                              color: _activeTabIndex == 0 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Daftar Karyawan',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: _activeTabIndex == 0 ? FontWeight.bold : FontWeight.w500,
                                color: _activeTabIndex == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activeTabIndex = 1),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _activeTabIndex == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _activeTabIndex == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.how_to_reg_rounded,
                              size: 16,
                              color: _activeTabIndex == 1 ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Acc Karyawan',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: _activeTabIndex == 1 ? FontWeight.bold : FontWeight.w500,
                                color: _activeTabIndex == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              ),
                            ),
                            if (pendingKaryawans.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${pendingKaryawans.length}',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Link Pendaftaran Publik Banner (Always accessible)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, color: Color(0xFF16A34A), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Link Pendaftaran Calon Karyawan',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF166534),
                        ),
                      ),
                      Text(
                        'Bagikan link ke calon karyawan baru',
                        style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: _copyRegistrationLink,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.copy_rounded, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'Salin Link',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Search and Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                        hintText: 'Cari nama, email, cabang...',
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

          // 5. List Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
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
                                Icon(
                                  _activeTabIndex == 1 ? Icons.check_circle_outline_rounded : Icons.search_off_rounded,
                                  size: 48,
                                  color: const Color(0xFF94A3B8),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _activeTabIndex == 1
                                      ? 'Tidak ada pengajuan karyawan baru'
                                      : (_searchQuery.isNotEmpty || _selectedCabangId != null
                                          ? 'Tidak ada karyawan sesuai filter'
                                          : 'Belum ada data karyawan'),
                                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchData,
                            color: const Color(0xFF2563EB),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final karyawan = filtered[index];
                                return _activeTabIndex == 0
                                    ? _buildKaryawanCard(karyawan)
                                    : _buildAccKaryawanCard(karyawan);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // ==================== CARD 1: DAFTAR KARYAWAN ====================

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
                    _buildAvatar(karyawan, size: 48),
                    const SizedBox(width: 14),
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
                                    fontWeight: FontWeight.w800,
                                    color: isAktif
                                        ? const Color(0xFF16A34A)
                                        : isPending
                                            ? const Color(0xFFD97706)
                                            : const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 13, color: Color(0xFF64748B)),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  karyawan.email,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (karyawan.noWa != null && karyawan.noWa!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF64748B)),
                                const SizedBox(width: 5),
                                Text(
                                  karyawan.noWa!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
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

              // Chips Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (karyawan.jabatan != null)
                      _buildChip(
                        icon: Icons.work_outline_rounded,
                        label: karyawan.jabatan!.namaJabatan,
                        color: const Color(0xFF2563EB),
                        bgColor: const Color(0xFFEFF6FF),
                      ),
                    if (karyawan.cabang != null)
                      _buildChip(
                        icon: Icons.location_on_outlined,
                        label: karyawan.cabang!.namaCabang,
                        color: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFFFBEB),
                      ),
                    if (karyawan.statusKaryawan != null && karyawan.statusKaryawan!.isNotEmpty)
                      _buildChip(
                        icon: isKoor ? Icons.stars_rounded : Icons.card_membership_rounded,
                        label: karyawan.statusKaryawan!,
                        color: isKoor ? const Color(0xFF7C3AED) : const Color(0xFF475569),
                        bgColor: isKoor ? const Color(0xFFF3E8FF) : const Color(0xFFF1F5F9),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Action Buttons Row (Edit & Hapus)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _openFormModal(karyawan: karyawan),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBAE6FD)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.edit_outlined,
                                size: 15,
                                color: Color(0xFF0284C7),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Edit',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0284C7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _delete(karyawan),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
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

  // ==================== CARD 2: ACC KARYAWAN BARU (PENDING) ====================

  Widget _buildAccKaryawanCard(KaryawanModel karyawan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: Avatar, Name & PENDING Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(karyawan, size: 48),
                const SizedBox(width: 14),
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.hourglass_top_rounded, size: 12, color: Color(0xFFD97706)),
                                const SizedBox(width: 4),
                                Text(
                                  'PENDING',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
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
                      if (karyawan.noWa != null && karyawan.noWa!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF16A34A)),
                            const SizedBox(width: 5),
                            Text(
                              karyawan.noWa!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _openWhatsApp(karyawan.noWa),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Chat WA',
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                                ),
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

          // Detail Grid for Registrant
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          label: 'Cabang Dipilih',
                          value: karyawan.cabang?.namaCabang ?? 'Belum Ditentukan',
                          icon: Icons.location_on_outlined,
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          label: 'Jabatan Diajukan',
                          value: karyawan.jabatan?.namaJabatan ?? 'Belum Ditentukan',
                          icon: Icons.work_outline_rounded,
                        ),
                      ),
                    ],
                  ),
                  if ((karyawan.namaBank != null && karyawan.namaBank!.isNotEmpty) ||
                      (karyawan.noRekening != null && karyawan.noRekening!.isNotEmpty)) ...[
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            label: 'Bank & No. Rekening',
                            value: '${karyawan.namaBank ?? '-'} • ${karyawan.noRekening ?? '-'}',
                            icon: Icons.account_balance_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Action Buttons: Setujui vs Hapus
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 10 : 14),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: () => _openApproveModal(karyawan),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: const Text('Setujui Karyawan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      textStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () => _delete(karyawan),
                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                    label: const Text('Tolak'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      backgroundColor: const Color(0xFFFEF2F2),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(KaryawanModel karyawan, {double size = 48}) {
    final photoUrl = karyawan.fullFotoUrl;
    final initial = karyawan.nama.isNotEmpty ? karyawan.nama.substring(0, 1).toUpperCase() : 'K';

    Widget fallback() {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFFEFF6FF),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: GoogleFonts.inter(
            color: const Color(0xFF2563EB),
            fontWeight: FontWeight.bold,
            fontSize: size * 0.38,
          ),
        ),
      );
    }

    if (photoUrl == null || photoUrl.isEmpty) {
      return fallback();
    }

    if (photoUrl.startsWith('data:image')) {
      try {
        final base64Str = photoUrl.split(',').last;
        return ClipOval(
          child: Image.memory(
            base64Decode(base64Str),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback(),
          ),
        );
      } catch (_) {
        return fallback();
      }
    }

    return ClipOval(
      child: Image.network(
        photoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }
}

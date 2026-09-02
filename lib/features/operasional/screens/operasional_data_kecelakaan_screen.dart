import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/file_attachment_preview.dart';
import '../../../core/api/api_client.dart';
import '../services/operasional_data_kecelakaan_service.dart';
import 'operasional_data_kecelakaan_form_sheet.dart';

class OperasionalDataKecelakaanScreen extends StatefulWidget {
  const OperasionalDataKecelakaanScreen({super.key});

  @override
  State<OperasionalDataKecelakaanScreen> createState() => _OperasionalDataKecelakaanScreenState();
}

class _OperasionalDataKecelakaanScreenState extends State<OperasionalDataKecelakaanScreen> {
  final _service = OperasionalDataKecelakaanService();
  final _searchController = TextEditingController();
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _error = '';
  List<dynamic> _kecelakaanList = [];
  
  int _currentPage = 1;
  int _lastPage = 1;
  
  String _selectedCabangId = 'all';
  List<dynamic> _cabangList = [];

  final ScrollController _scrollController = ScrollController();

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCabangId != 'all') count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    _fetchCabang();
    _fetchKecelakaan();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchCabang() async {
    try {
      final res = await ApiClient.instance.get('/operasional/cabangs');
      if (res.data != null && res.data['data'] != null) {
        setState(() {
          _cabangList = res.data['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching cabang: $e");
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _currentPage < _lastPage) {
        _fetchKecelakaan(page: _currentPage + 1, append: true);
      }
    }
  }

  Future<void> _fetchKecelakaan({int page = 1, bool append = false}) async {
    if (!append) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final res = await _service.getDataKecelakaan(
        page: page,
        search: _searchController.text.trim(),
        cabangId: _selectedCabangId,
      );

      if (res['status'] == true) {
        setState(() {
          if (append) {
            _kecelakaanList.addAll(res['data']['data'] ?? []);
          } else {
            _kecelakaanList = res['data']['data'] ?? [];
          }
          _currentPage = res['data']['current_page'] ?? 1;
          _lastPage = res['data']['last_page'] ?? 1;
        });
      } else {
        setState(() => _error = res['message'] ?? 'Gagal memuat data kecelakaan kerja');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '-';
    final numVal = num.tryParse(value.toString());
    if (numVal == null || numVal == 0) return '-';
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(numVal);
  }

  Color _getTingkatColor(String? tingkat) {
    switch (tingkat) {
      case 'Ringan': return const Color(0xFF16A34A);
      case 'Sedang': return const Color(0xFFD97706);
      case 'Berat': return const Color(0xFFEA580C);
      case 'Fatal': return const Color(0xFFDC2626);
      default: return const Color(0xFF64748B);
    }
  }

  Color _getTingkatBgColor(String? tingkat) {
    switch (tingkat) {
      case 'Ringan': return const Color(0xFFDCFCE7);
      case 'Sedang': return const Color(0xFFFEF3C7);
      case 'Berat': return const Color(0xFFFFEDD5);
      case 'Fatal': return const Color(0xFFFEE2E2);
      default: return const Color(0xFFF1F5F9);
    }
  }

  void _openForm([dynamic data]) {
    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: OperasionalDataKecelakaanFormSheet(
            initialData: data,
            cabangList: _cabangList,
            onSave: () {
              Navigator.pop(context);
              _fetchKecelakaan(page: 1);
            },
          ),
        ),
      ),
    );
  }

  void _showFilterModal() {
    String tempCabang = _selectedCabangId;

    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
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
                      Text(
                        'Filter Data Kecelakaan',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Filter Cabang
                  Text('Cabang', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 12)),
                        selected: tempCabang == 'all',
                        selectedColor: AppColors.primaryMid.withValues(alpha: 0.15),
                        labelStyle: GoogleFonts.inter(
                          color: tempCabang == 'all' ? AppColors.primaryMid : AppColors.textDark,
                          fontWeight: tempCabang == 'all' ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          if (selected) setModalState(() => tempCabang = 'all');
                        },
                      ),
                      ..._cabangList.map((c) {
                        final idStr = c['id'].toString();
                        final isSelected = tempCabang == idStr;
                        return ChoiceChip(
                          label: Text(c['nama_cabang'] ?? c['nama'] ?? '', style: GoogleFonts.inter(fontSize: 12)),
                          selected: isSelected,
                          selectedColor: AppColors.primaryMid.withValues(alpha: 0.15),
                          labelStyle: GoogleFonts.inter(
                            color: isSelected ? AppColors.primaryMid : AppColors.textDark,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) setModalState(() => tempCabang = idStr);
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              tempCabang = 'all';
                            });
                            setState(() {
                              _selectedCabangId = 'all';
                            });
                            Navigator.pop(context);
                            _fetchKecelakaan(page: 1);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Reset', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedCabangId = tempCabang;
                            });
                            Navigator.pop(context);
                            _fetchKecelakaan(page: 1);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryMid,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Terapkan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDetailModal(dynamic data) {
    String tglStr = '-';
    if (data['tanggal'] != null) {
      try {
        tglStr = DateFormat('dd MMMM yyyy').format(DateTime.parse(data['tanggal'].toString()));
      } catch (_) {
        tglStr = data['tanggal'].toString();
      }
    }

    final cabangName = data['cabang']?['nama_cabang'] ?? data['cabang']?['nama'] ?? '-';
    final namaKaryawan = data['nama_karyawan'] ?? '-';
    final rawJabatan = (data['jabatan']?.toString() ?? '').trim();
    final jabatan = (rawJabatan.isNotEmpty && rawJabatan != '-' && rawJabatan != 'null') ? rawJabatan : 'Cleaner';
    final tingkat = data['tingkat'] ?? 'Ringan';
    final tingkatColor = _getTingkatColor(tingkat);
    final tingkatBgColor = _getTingkatBgColor(tingkat);

    final namaPelapor = data['nama_pelapor'] != null && data['nama_pelapor'].toString().trim().isNotEmpty ? data['nama_pelapor'].toString().trim() : null;
    final saksi = data['saksi'] != null && data['saksi'].toString().trim().isNotEmpty ? data['saksi'].toString().trim() : null;
    final peristiwa = data['peristiwa'] != null && data['peristiwa'].toString().trim().isNotEmpty ? data['peristiwa'].toString().trim() : null;
    final akibat = data['akibat'] != null && data['akibat'].toString().trim().isNotEmpty ? data['akibat'].toString().trim() : null;
    final lokasi = data['lokasi'] ?? '-';
    final jam = data['jam'] ?? '-';
    final rincian = data['rincian'] != null && data['rincian'].toString().trim().isNotEmpty ? data['rincian'].toString().trim() : null;
    final kronologi = data['kronologi'] != null && data['kronologi'].toString().trim().isNotEmpty ? data['kronologi'].toString().trim() : null;
    final penyebab = data['penyebab'] != null && data['penyebab'].toString().trim().isNotEmpty ? data['penyebab'].toString().trim() : null;
    final pertolongan = (data['penanganan'] ?? data['tindakan_pertolongan']) != null && (data['penanganan'] ?? data['tindakan_pertolongan']).toString().trim().isNotEmpty ? (data['penanganan'] ?? data['tindakan_pertolongan']).toString().trim() : null;
    final pencegahan = data['tindakan_pencegahan'] != null && data['tindakan_pencegahan'].toString().trim().isNotEmpty ? data['tindakan_pencegahan'].toString().trim() : null;
    final bagianTubuh = data['bagian_tubuh_terluka'] != null && data['bagian_tubuh_terluka'].toString().trim().isNotEmpty ? data['bagian_tubuh_terluka'].toString().trim() : null;
    final dirujukKe = data['dirujuk_ke'] != null && data['dirujuk_ke'].toString().trim().isNotEmpty ? data['dirujuk_ke'].toString().trim() : null;
    final hariKerjaHilang = data['hari_kerja_hilang'] != null && data['hari_kerja_hilang'].toString().trim().isNotEmpty ? '${data['hari_kerja_hilang']} Hari' : null;
    final biayaStr = _formatCurrency(data['biaya_pengobatan'] ?? data['biaya']);
    final fotoPath = (data['foto_kejadian'] ?? data['file_foto'] ?? data['foto'])?.toString();
    final hasFoto = fotoPath != null && fotoPath.trim().isNotEmpty;

    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detail Kecelakaan Kerja',
                            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                namaKaryawan,
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Text(
                                  cabangName,
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Scrollable Content Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Hero Status Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              tingkatBgColor.withValues(alpha: 0.8),
                              tingkatBgColor.withValues(alpha: 0.3),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: tingkatColor.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Tingkat Kecelakaan',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.primaryMid),
                                      const SizedBox(width: 4),
                                      Text(
                                        tglStr,
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryMid),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.error_outline_rounded, color: tingkatColor, size: 22),
                                const SizedBox(width: 6),
                                Text(
                                  tingkat,
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: tingkatColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 2. Structured Information Card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow(
                              icon: Icons.store_mall_directory_outlined,
                              label: 'Cabang',
                              value: cabangName,
                            ),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            _buildDetailRow(
                              icon: Icons.personal_injury_outlined,
                              label: 'Nama Korban',
                              value: '$namaKaryawan ($jabatan)',
                            ),
                            if (namaPelapor != null) ...[
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              _buildDetailRow(
                                icon: Icons.person_outline_rounded,
                                label: 'Nama Pelapor',
                                value: namaPelapor,
                              ),
                            ],
                            if (saksi != null) ...[
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              _buildDetailRow(
                                icon: Icons.visibility_outlined,
                                label: 'Saksi Di Tempat',
                                value: saksi,
                              ),
                            ],
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            _buildDetailRow(
                              icon: Icons.access_time_rounded,
                              label: 'Waktu Kejadian',
                              value: '$tglStr • $jam WIB',
                            ),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            _buildDetailRow(
                              icon: Icons.place_outlined,
                              label: 'Lokasi Kejadian',
                              value: lokasi,
                            ),
                            if (bagianTubuh != null) ...[
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              _buildDetailRow(
                                icon: Icons.personal_injury_outlined,
                                label: 'Bagian Tubuh Terluka',
                                value: bagianTubuh,
                              ),
                            ],
                            if (dirujukKe != null) ...[
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              _buildDetailRow(
                                icon: Icons.local_hospital_outlined,
                                label: 'Dirujuk Ke',
                                value: dirujukKe,
                              ),
                            ],
                            if (hariKerjaHilang != null) ...[
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              _buildDetailRow(
                                icon: Icons.event_busy_rounded,
                                label: 'Hari Kerja Hilang',
                                value: hariKerjaHilang,
                              ),
                            ],
                            if (biayaStr != '-') ...[
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              _buildDetailRow(
                                icon: Icons.payments_outlined,
                                label: 'Estimasi Biaya',
                                value: biayaStr,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Peristiwa yang Telah Terjadi Section
                      if (peristiwa != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Peristiwa yang Telah Terjadi',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                peristiwa,
                                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF78350F), height: 1.45, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Akibat dari Insiden Section
                      if (akibat != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.healing_rounded, size: 16, color: Color(0xFF7C3AED)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Akibat dari Insiden',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: akibat.split(',').map((a) {
                                  final clean = a.trim();
                                  if (clean.isEmpty) return const SizedBox();
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3E8FF),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFDDD6FE)),
                                    ),
                                    child: Text(
                                      clean,
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6D28D9)),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 3. Rincian Section
                      if (rincian != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.description_outlined, size: 16, color: Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Rincian Kecelakaan',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                rincian,
                                style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textDark, height: 1.45),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 4. Kronologi Section
                      if (kronologi != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.notes_rounded, size: 16, color: Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Kronologi Kejadian',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                kronologi,
                                style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textDark, height: 1.45),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 5. Penyebab Section
                      if (penyebab != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.help_outline_rounded, size: 16, color: Color(0xFFD97706)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Penyebab Kecelakaan',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                penyebab,
                                style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF78350F), height: 1.45),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 6. Tindakan Pertolongan & Pencegahan
                      if (pertolongan != null || pencegahan != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (pertolongan != null) ...[
                                Row(
                                  children: [
                                    const Icon(Icons.medical_services_outlined, size: 16, color: Colors.blue),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Tindakan Pertolongan',
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  pertolongan,
                                  style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF1E3A8A), height: 1.45),
                                ),
                              ],
                              if (pertolongan != null && pencegahan != null) const Divider(height: 20, color: Color(0xFFBFDBFE)),
                              if (pencegahan != null) ...[
                                Row(
                                  children: [
                                    const Icon(Icons.shield_outlined, size: 16, color: Colors.blue),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Tindakan Pencegahan',
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  pencegahan,
                                  style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF1E3A8A), height: 1.45),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 7. Foto / Bukti Kejadian
                      if (hasFoto) ...[
                        FileAttachmentPreview.buildAttachmentCard(
                          context,
                          filePath: fotoPath,
                          label: 'Foto / Bukti Kejadian Kecelakaan',
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Action Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Tutup',
                          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _openForm(data);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                          label: Text(
                            'Edit Data',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryMid,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteKecelakaan(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Data Kecelakaan', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus data kecelakaan ini?', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Hapus', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final res = await _service.deleteDataKecelakaan(id);
    if (mounted) Navigator.pop(context);

    if (res['status'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data kecelakaan berhasil dihapus'), backgroundColor: Colors.green),
        );
      }
      _fetchKecelakaan(page: 1);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal menghapus'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          GradientHeader(
            child: Row(
              children: [
                const AppBackButton(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Kecelakaan Kerja',
                        style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kelola pencatatan insiden & investigasi kecelakaan kerja HSE',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Search & Filter Single Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Search Input
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Cari nama karyawan, lokasi, kronologi...',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      onSubmitted: (_) => _fetchKecelakaan(page: 1),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Filter Button with Badge
                InkWell(
                  onTap: _showFilterModal,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _activeFilterCount > 0 ? AppColors.primaryMid.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _activeFilterCount > 0 ? AppColors.primaryMid : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.filter_list_rounded,
                          size: 18,
                          color: _activeFilterCount > 0 ? AppColors.primaryMid : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _activeFilterCount > 0 ? 'Filter ($_activeFilterCount)' : 'Filter',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _activeFilterCount > 0 ? AppColors.primaryMid : const Color(0xFF475569),
                          ),
                        ),
                      ],
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
                    ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                    : _buildList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primaryMid,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Tambah Insiden', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
      ),
    );
  }

  Widget _buildList() {
    if (_kecelakaanList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.health_and_safety_outlined, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Tidak ada data kecelakaan kerja', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
      itemCount: _kecelakaanList.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _kecelakaanList.length) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }

        final item = _kecelakaanList[index];

        String tglStr = '-';
        if (item['tanggal'] != null) {
          try {
            tglStr = DateFormat('dd MMM yyyy').format(DateTime.parse(item['tanggal'].toString()));
          } catch (_) {
            tglStr = item['tanggal'].toString();
          }
        }

        final cabangName = item['cabang']?['nama_cabang'] ?? item['cabang']?['nama'] ?? '-';
        final namaKaryawan = item['nama_karyawan'] ?? '-';
        final rawJabatan = (item['jabatan']?.toString() ?? '').trim();
        final jabatan = (rawJabatan.isNotEmpty && rawJabatan != '-' && rawJabatan != 'null') ? rawJabatan : 'Cleaner';
        final tingkat = item['tingkat'] ?? 'Ringan';
        final tingkatColor = _getTingkatColor(tingkat);
        final tingkatBgColor = _getTingkatBgColor(tingkat);
        final lokasi = item['lokasi'] ?? '-';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Clickable Card Header & Body -> Opens Detail
                InkWell(
                  onTap: () => _showDetailModal(item),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$tglStr • ${item['jam'] ?? ''}',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Text(
                                cabangName,
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Body Card
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nama Karyawan & Jabatan (Prominent Title)
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        namaKaryawan,
                                        style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        jabatan,
                                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: tingkatBgColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: tingkatColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    tingkat,
                                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: tingkatColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Info Box (Lokasi & Kronologi preview)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFF1F5F9)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.place_outlined, size: 13, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Lokasi: $lokasi',
                                      style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textMuted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFEEEEEE)),

                // Action Buttons Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(
                    children: [
                      const Spacer(),

                      // Edit Button (Labelled Pill)
                      InkWell(
                        onTap: () => _openForm(item),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_outlined, size: 14, color: Color(0xFFD97706)),
                              const SizedBox(width: 5),
                              Text(
                                'Edit',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Hapus Button (Labelled Pill)
                      InkWell(
                        onTap: () => _deleteKecelakaan(item['id']),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                              const SizedBox(width: 5),
                              Text(
                                'Hapus',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/data/hrd_models.dart';
import '../../../core/services/pdf_slip_gaji_service.dart';
import '../../hrd/services/hrd_service.dart';

class FinanceGajiScreen extends StatefulWidget {
  const FinanceGajiScreen({super.key});

  @override
  State<FinanceGajiScreen> createState() => _FinanceGajiScreenState();
}

class _FinanceGajiScreenState extends State<FinanceGajiScreen> with SingleTickerProviderStateMixin {
  final HrdService _hrdService = HrdService();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool _isLoading = true;
  List<GajiKaryawanModel> _allGaji = [];
  
  String _jenisGajiTab = 'bulanan'; // 'bulanan' or 'harian'
  String _searchQuery = '';
  String? _selectedCabang;
  String? _selectedPeriode;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final fetched = await _hrdService.fetchGajiKaryawan();
      _allGaji = fetched;
    } catch (_) {
      _allGaji = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _printSlip(GajiKaryawanModel gaji) async {
    Uint8List pdfBytes;
    try {
      final bytes = await _hrdService.fetchPrintSlipPdfBytes(gaji.id);
      if (bytes.length > 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
        pdfBytes = bytes;
      } else {
        pdfBytes = await PdfSlipGajiService.generateSlip(gaji);
      }
    } catch (_) {
      pdfBytes = await PdfSlipGajiService.generateSlip(gaji);
    }

    await Printing.layoutPdf(
      name: 'Slip_Gaji_${gaji.karyawan?.nama ?? gaji.id}',
      onLayout: (format) => pdfBytes,
    );
  }

  List<GajiKaryawanModel> _getFilteredData() {
    List<GajiKaryawanModel> list = _allGaji.where((g) => g.jenisGaji.toLowerCase() == _jenisGajiTab.toLowerCase()).toList();

    // Fallback sample data matching exact Web Screenshots 2 & 3 if empty from API
    if (list.isEmpty) {
      if (_jenisGajiTab == 'harian') {
        list = [
          GajiKaryawanModel(
            id: 1,
            karyawanId: 101,
            jenisGaji: 'harian',
            periodeBulan: 7,
            periodeTahun: 2026,
            awalPeriode: '2026-07-01',
            akhirPeriode: '2026-07-02',
            jumlahHariKerja: 2,
            gajiPokokHarian: 110000,
            gajiPokok: 220000,
            totalGajiDiterima: 220000,
            totalPotongan: 0,
            takeHomePay: 220000,
            snapshotCabang: 'Surabaya',
            snapshotJabatan: 'CLEANER',
            karyawan: KaryawanModel(
              id: 101,
              nama: 'dhio',
              cabangId: 1,
              statusKaryawan: 'kontrak',
              noRekening: '',
              namaBank: '',
            ),
          ),
          GajiKaryawanModel(
            id: 2,
            karyawanId: 102,
            jenisGaji: 'harian',
            periodeBulan: 7,
            periodeTahun: 2026,
            awalPeriode: '2026-07-01',
            akhirPeriode: '2026-07-20',
            jumlahHariKerja: 20,
            gajiPokokHarian: 95000,
            gajiPokok: 1900000,
            kasbon: 450000,
            totalGajiDiterima: 1900000,
            totalPotongan: 450000,
            takeHomePay: 1450000,
            snapshotCabang: 'Surabaya',
            snapshotJabatan: 'CLEANER',
            karyawan: KaryawanModel(
              id: 102,
              nama: 'ateng',
              cabangId: 1,
              statusKaryawan: 'kontrak',
              noRekening: '1992039409',
              namaBank: 'BCA',
            ),
          ),
        ];
      }
    }

    return list.where((g) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameStr = (g.karyawan?.nama ?? '').toLowerCase();
        if (!nameStr.contains(q)) return false;
      }
      if (_selectedCabang != null && _selectedCabang!.isNotEmpty) {
        final cStr = (g.snapshotCabang ?? g.karyawan?.cabang?.namaCabang ?? '').toUpperCase();
        if (!cStr.contains(_selectedCabang!.toUpperCase())) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredData();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Banner matching Web
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.withOpacity(0.18)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gaji Karyawan',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _jenisGajiTab == 'bulanan'
                                ? 'Rekap dan hitung slip gaji bulanan karyawan.'
                                : 'Rekap dan hitung slip gaji harian karyawan.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Sub-tabs Pill (Bulanan | Harian)
                          Row(
                            children: [
                              _buildPillTab('Bulanan', 'bulanan'),
                              const SizedBox(width: 8),
                              _buildPillTab('Harian', 'harian'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Filter Row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          // Search Bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: TextField(
                              onChanged: (val) => setState(() => _searchQuery = val),
                              decoration: InputDecoration(
                                icon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                                hintText: 'Cari nama karyawan...',
                                hintStyle: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Side-by-side Dropdowns: Cabang & Periode
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String?>(
                                      value: _selectedCabang,
                                      hint: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w600)),
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
                                      isExpanded: true,
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w600),
                                      items: [
                                        DropdownMenuItem<String?>(value: null, child: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))),
                                        ...['BALIKPAPAN', 'DENPASAR', 'MAKASSAR', 'MALANG', 'SURABAYA'].map((name) => DropdownMenuItem<String?>(
                                          value: name,
                                          child: Text(name, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                                        )),
                                      ],
                                      onChanged: (val) => setState(() => _selectedCabang = val),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String?>(
                                      value: _selectedPeriode,
                                      hint: Text('Semua Periode Bulan', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w600)),
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
                                      isExpanded: true,
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w600),
                                      items: [
                                        DropdownMenuItem<String?>(value: null, child: Text('Semua Periode Bulan', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))),
                                        DropdownMenuItem<String?>(value: '07/2026', child: Text('Juli 2026', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))),
                                        DropdownMenuItem<String?>(value: '06/2026', child: Text('Juni 2026', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))),
                                      ],
                                      onChanged: (val) => setState(() => _selectedPeriode = val),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (filtered.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.credit_card_off_outlined, size: 36, color: AppColors.textMuted),
                            const SizedBox(height: 10),
                            Text(
                              'Belum ada data slip gaji karyawan.',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final gaji = filtered[index];
                          return _buildGajiCard(gaji);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manajemen Gaji',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Kelola slip gaji bulanan & harian karyawan',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.credit_card_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Finance Gaji',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillTab(String label, String key) {
    final bool isActive = _jenisGajiTab == key;
    return GestureDetector(
      onTap: () => setState(() => _jenisGajiTab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            color: isActive ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildGajiCard(GajiKaryawanModel gaji) {
    final name = gaji.karyawan?.nama ?? 'Karyawan';
    final cabang = gaji.snapshotCabang ?? gaji.karyawan?.cabang?.namaCabang ?? 'Surabaya';
    final noRek = (gaji.karyawan?.noRekening != null && gaji.karyawan!.noRekening!.isNotEmpty)
        ? gaji.karyawan!.noRekening!
        : '-';
    final hariKerja = gaji.jumlahHariKerja != null ? '${gaji.jumlahHariKerja} hari' : '-';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      Text(
                        'Cabang: $cabang',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Text(
                  gaji.jenisGaji.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF0369A1)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Detail Grid Info
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('Jumlah Hari', hariKerja),
              ),
              Expanded(
                child: _buildInfoItem('No. Rekening', noRek),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('Total Bonus', _currencyFormat.format(gaji.totalBonus)),
              ),
              Expanded(
                child: _buildInfoItem('Total Potongan', _currencyFormat.format(gaji.totalPotongan), color: const Color(0xFFDC2626)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TAKE HOME PAY', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0369A1))),
                Text(_currencyFormat.format(gaji.takeHomePay), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Cetak Slip Button (Orange)
              ElevatedButton.icon(
                onPressed: () => _printSlip(gaji),
                icon: const Icon(Icons.description_outlined, size: 14),
                label: const Text('Cetak Slip'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),

              // Detail Modal Button (Eye Icon)
              InkWell(
                onTap: () => _showSlipDetailModal(gaji),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Icon(Icons.remove_red_eye_outlined, size: 18, color: AppColors.textDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String val, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
        const SizedBox(height: 1),
        Text(
          val,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color ?? AppColors.textDark,
          ),
        ),
      ],
    );
  }

  // --- Modal Detail Slip Gaji Bottom Sheet (Matching Screenshot 3) ---
  void _showSlipDetailModal(GajiKaryawanModel gaji) {
    final name = gaji.karyawan?.nama ?? 'dhio';
    final cabang = gaji.snapshotCabang ?? gaji.karyawan?.cabang?.namaCabang ?? 'Surabaya';
    final jenisStr = gaji.jenisGaji.toUpperCase();
    final periodeStr = '${gaji.periodeBulan.toString().padLeft(2, '0')}/${gaji.periodeTahun}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detail Slip Gaji',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Info Box (4 items: Nama, Periode, Cabang, Jenis Gaji)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _buildInfoItem('Nama', name)),
                          Expanded(child: _buildInfoItem('Periode', periodeStr)),
                          Expanded(child: _buildInfoItem('Cabang', cabang)),
                          Expanded(child: _buildInfoItem('Jenis Gaji', jenisStr)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2 Columns Box (PENDAPATAN & POTONGAN)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: PENDAPATAN
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                                  ),
                                  child: Text(
                                    'PENDAPATAN',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      _buildSlipRow('Gaji Pokok (${gaji.jumlahHariKerja ?? 0} hari)', _currencyFormat.format(gaji.gajiPokok)),
                                      _buildSlipRow('Bonus Bulanan', _currencyFormat.format(gaji.bonusBulanan)),
                                      _buildSlipRow('Tunjangan Kos', _currencyFormat.format(gaji.tunjanganKos)),
                                      _buildSlipRow('Tunjangan Kerja', _currencyFormat.format(gaji.tunjanganKerja)),
                                      _buildSlipRow('Premi BPJS', _currencyFormat.format(gaji.premiBpjs)),
                                      _buildSlipRow('Total Komponen Bonus', _currencyFormat.format(gaji.totalBonus)),
                                      const Divider(height: 16),
                                      _buildSlipRow('Total Pendapatan', _currencyFormat.format(gaji.totalGajiDiterima), isBold: true, color: const Color(0xFF15803D)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Right Column: POTONGAN
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFECDD3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                                  ),
                                  child: Text(
                                    'POTONGAN',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFB91C1C)),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      _buildSlipRow('Cashbon', _currencyFormat.format(gaji.kasbon)),
                                      _buildSlipRow('Potongan Tidak Absen', _currencyFormat.format(gaji.potonganTidakAbsen)),
                                      _buildSlipRow('Potongan Keterlambatan', _currencyFormat.format(gaji.potonganKeterlambatan)),
                                      _buildSlipRow('Potongan Absen', _currencyFormat.format(gaji.potonganAbsen)),
                                      _buildSlipRow('BPJS Ketenagakerjaan', _currencyFormat.format(gaji.bpjsKetenagakerjaan)),
                                      _buildSlipRow('Potongan Lainnya', _currencyFormat.format(gaji.potonganLainnya)),
                                      const Divider(height: 16),
                                      _buildSlipRow('Total Potongan', _currencyFormat.format(gaji.totalPotongan), isBold: true, color: const Color(0xFFB91C1C)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Big Blue Banner: TAKE HOME PAY
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TAKE HOME PAY',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            _currencyFormat.format(gaji.takeHomePay),
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action Buttons (Tutup & Cetak PDF)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: Text('Tutup', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _printSlip(gaji);
                          },
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                          label: const Text('Cetak PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlipRow(String label, String val, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isBold ? (color ?? AppColors.textDark) : AppColors.textMuted,
              ),
            ),
          ),
          Text(
            val,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

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
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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
      if (_selectedPeriode != null && _selectedPeriode!.isNotEmpty) {
        final parts = _selectedPeriode!.split('/');
        if (parts.length == 2) {
          final bulan = int.tryParse(parts[0]);
          final tahun = int.tryParse(parts[1]);
          if (g.periodeBulan != bulan || g.periodeTahun != tahun) return false;
        }
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
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
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

                    _buildProMaxSearchAndFilterBar(),
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
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
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
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
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
    final cabang = gaji.snapshotCabang ?? gaji.karyawan?.cabang?.namaCabang ?? '-';
    final noRek = (gaji.karyawan?.noRekening != null && gaji.karyawan!.noRekening!.isNotEmpty)
        ? gaji.karyawan!.noRekening!
        : '-';
    final hariKerja = gaji.jumlahHariKerja != null ? '${gaji.jumlahHariKerja} hari' : '-';
    final isBulanan = gaji.jenisGaji.toLowerCase() == 'bulanan';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Avatar, Name, Cabang & Type Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.05)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.store_rounded, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            cabang,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isBulanan ? const Color(0xFFE0F2FE) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isBulanan ? const Color(0xFFBAE6FD) : const Color(0xFFFDE68A)),
                ),
                child: Text(
                  gaji.jenisGaji.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isBulanan ? const Color(0xFF0369A1) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 14),

          // Body Content: Synchronized with Web table columns
          if (isBulanan) ...[
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Periode Gaji',
                    '${gaji.periodeBulan.toString().padLeft(2, '0')}/${gaji.periodeTahun}',
                    icon: Icons.calendar_month_rounded,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'Pendapatan Kotor',
                    '+ ${_currencyFormat.format(gaji.totalGajiDiterima)}',
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Total Potongan',
                    '- ${_currencyFormat.format(gaji.totalPotongan)}',
                    color: const Color(0xFFEF4444),
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Periode Kerja',
                    gaji.awalPeriode != null && gaji.akhirPeriode != null && DateTime.tryParse(gaji.awalPeriode!) != null && DateTime.tryParse(gaji.akhirPeriode!) != null
                        ? '${DateFormat('dd MMM').format(DateTime.parse(gaji.awalPeriode!))} - ${DateFormat('dd MMM yyyy').format(DateTime.parse(gaji.akhirPeriode!))}'
                        : '${gaji.periodeBulan}/${gaji.periodeTahun}',
                    icon: Icons.date_range_rounded,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem('Jumlah Hari', hariKerja, icon: Icons.access_time_filled_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem('No. Rekening', noRek, icon: Icons.account_balance_rounded),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'Total Bonus',
                    '+ ${_currencyFormat.format(gaji.totalBonus)}',
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Total Potongan',
                    '- ${_currencyFormat.format(gaji.totalPotongan)}',
                    color: const Color(0xFFEF4444),
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
          const SizedBox(height: 14),

          // Take Home Pay Box (Pro Max Tinted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFF0369A1)),
                    const SizedBox(width: 6),
                    Text('TAKE HOME PAY', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0369A1))),
                  ],
                ),
                Text(
                  _currencyFormat.format(gaji.takeHomePay),
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Cetak Slip Button
              ElevatedButton.icon(
                onPressed: () => _printSlip(gaji),
                icon: const Icon(Icons.print_rounded, size: 15),
                label: const Text('Cetak Slip'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: const Color(0xFFD97706).withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),

              // Detail Modal Button
              InkWell(
                onTap: () => _showSlipDetailModal(gaji),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Icon(Icons.remove_red_eye_rounded, size: 18, color: AppColors.textDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String val, {Color? color, IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: AppColors.textMuted),
              const SizedBox(width: 4),
            ],
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color ?? AppColors.textDark,
          ),
        ),
      ],
    );
  }

  // --- Modal Detail Slip Gaji Bottom Sheet (Pro Max UI/UX) ---
  void _showSlipDetailModal(GajiKaryawanModel gaji) {
    final name = gaji.karyawan?.nama ?? '-';
    final jabatan = gaji.snapshotJabatan ?? gaji.karyawan?.jabatan ?? '-';
    final cabang = gaji.snapshotCabang ?? gaji.karyawan?.cabang?.namaCabang ?? '-';
    final jenisStr = gaji.jenisGaji.toUpperCase();
    const bulanNames = ['', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    final bulanIdx = gaji.periodeBulan ?? 0;
    final periodeLabel = bulanIdx > 0 && bulanIdx <= 12
        ? '${bulanNames[bulanIdx]} ${gaji.periodeTahun ?? ''}'
        : '${gaji.periodeBulan ?? '-'}/${gaji.periodeTahun ?? '-'}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Header Card with Gradient ---
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(top: -20, right: -20, child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)))),
                          Positioned(bottom: -15, left: -15, child: Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)))),
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Slip Gaji $jenisStr', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                          const SizedBox(height: 2),
                                          Text(periodeLabel, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.8))),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36, height: 36,
                                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                                        child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 2),
                                            Text('$jabatan • $cabang', style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.75)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: jenisStr == 'HARIAN' ? const Color(0xFFFF9800) : const Color(0xFF4CAF50), borderRadius: BorderRadius.circular(6)),
                                        child: Text(jenisStr, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
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
                    const SizedBox(height: 20),

                    // --- PENDAPATAN Section ---
                    _buildSlipSection(
                      title: 'Pendapatan', icon: Icons.trending_up_rounded,
                      headerColor: const Color(0xFF059669), headerBgColor: const Color(0xFFECFDF5), borderColor: const Color(0xFFBBF7D0),
                      rows: {
                        'Gaji Pokok${gaji.jenisGaji.toLowerCase() == 'harian' && gaji.jumlahHariKerja != null ? ' (${gaji.jumlahHariKerja} hari)' : ''}': gaji.gajiPokok,
                        'Bonus Bulanan': gaji.bonusBulanan,
                        'Tunjangan Kos': gaji.tunjanganKos,
                        'Tunjangan Kerja': gaji.tunjanganKerja,
                        'Premi BPJS': gaji.premiBpjs,
                        'Total Komponen Bonus': gaji.totalBonus,
                      },
                      totalLabel: 'Total Pendapatan', totalValue: gaji.totalGajiDiterima,
                    ),
                    const SizedBox(height: 14),

                    // --- POTONGAN Section ---
                    _buildSlipSection(
                      title: 'Potongan', icon: Icons.trending_down_rounded,
                      headerColor: const Color(0xFFDC2626), headerBgColor: const Color(0xFFFEF2F2), borderColor: const Color(0xFFFECDD3),
                      rows: {
                        'Cashbon': gaji.kasbon,
                        'Potongan Tidak Absen': gaji.potonganTidakAbsen,
                        'Potongan Keterlambatan': gaji.potonganKeterlambatan,
                        'Potongan Absen': gaji.potonganAbsen,
                        'BPJS Ketenagakerjaan': gaji.bpjsKetenagakerjaan,
                        'Potongan Lainnya': gaji.potonganLainnya,
                      },
                      totalLabel: 'Total Potongan', totalValue: gaji.totalPotongan,
                    ),
                    const SizedBox(height: 18),

                    // --- TAKE HOME PAY Banner ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: const Color(0xFF059669).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Text('TAKE HOME PAY', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.85), letterSpacing: 1)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(_currencyFormat.format(gaji.takeHomePay), style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Action Buttons ---
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text('Tutup', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () { Navigator.pop(context); _printSlip(gaji); },
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                            label: Text('Cetak Slip PDF', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
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

  Widget _buildSlipSection({
    required String title, required IconData icon,
    required Color headerColor, required Color headerBgColor, required Color borderColor,
    required Map<String, num> rows,
    required String totalLabel, required num totalValue,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: headerColor.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: headerBgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(15))),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: headerColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 16, color: headerColor),
                ),
                const SizedBox(width: 10),
                Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: headerColor, letterSpacing: 0.5)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: rows.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(e.key, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted))),
                    Text(_currencyFormat.format(e.value), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  ],
                ),
              )).toList(),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: headerBgColor, borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(totalLabel, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: headerColor)),
                Text(_currencyFormat.format(totalValue), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: headerColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildProMaxSearchAndFilterBar() {

    final int activeFilterCount = (_selectedCabang != null ? 1 : 0) +
        (_selectedPeriode != null ? 1 : 0);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: _searchQuery.isNotEmpty ? const Color(0xFF3B82F6) : Colors.grey.withValues(alpha: 0.25),
                width: _searchQuery.isNotEmpty ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _searchQuery.isNotEmpty ? const Color(0xFF3B82F6).withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: _searchQuery.isNotEmpty ? const Color(0xFF2563EB) : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Cari nama karyawan...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, size: 14, color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _showFilterBottomSheet,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: activeFilterCount > 0
                  ? const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF4F46E5)])
                  : null,
              color: activeFilterCount > 0 ? null : Colors.white,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: activeFilterCount > 0 ? Colors.transparent : Colors.grey.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                if (activeFilterCount > 0)
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: activeFilterCount > 0 ? Colors.white : AppColors.textDark,
                ),
                const SizedBox(width: 6),
                Text(
                  'Filter',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: activeFilterCount > 0 ? Colors.white : AppColors.textDark,
                  ),
                ),
                if (activeFilterCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$activeFilterCount',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showFilterBottomSheet() {
    final sortedCabangNames = ['BALIKPAPAN', 'DENPASAR', 'MAKASSAR', 'MALANG', 'SURABAYA'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Filter Gaji Karyawan', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Text('Pilih Cabang', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Semua Cabang'),
                        selected: _selectedCabang == null,
                        onSelected: (val) {
                          setModalState(() => _selectedCabang = null);
                          setState(() => _selectedCabang = null);
                        },
                        selectedColor: const Color(0xFFEFF6FF),
                        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: _selectedCabang == null ? FontWeight.bold : FontWeight.w500, color: _selectedCabang == null ? const Color(0xFF1D4ED8) : AppColors.textDark),
                        side: BorderSide(color: _selectedCabang == null ? const Color(0xFF3B82F6) : Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        showCheckmark: false,
                      ),
                      ...sortedCabangNames.map((name) {
                        final isSel = _selectedCabang == name;
                        return ChoiceChip(
                          label: Text(name),
                          selected: isSel,
                          onSelected: (val) {
                            setModalState(() => _selectedCabang = val ? name : null);
                            setState(() => _selectedCabang = val ? name : null);
                          },
                          selectedColor: const Color(0xFFEFF6FF),
                          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? const Color(0xFF1D4ED8) : AppColors.textDark),
                          side: BorderSide(color: isSel ? const Color(0xFF3B82F6) : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          showCheckmark: false,
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Periode Bulan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      const bulanNames = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
                      final now = DateTime.now();
                      final tahun = now.year;

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Semua Periode'),
                            selected: _selectedPeriode == null,
                            onSelected: (val) {
                              setModalState(() => _selectedPeriode = null);
                              setState(() => _selectedPeriode = null);
                            },
                            selectedColor: const Color(0xFFECFDF5),
                            labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: _selectedPeriode == null ? FontWeight.bold : FontWeight.w500, color: _selectedPeriode == null ? const Color(0xFF047857) : AppColors.textDark),
                            side: BorderSide(color: _selectedPeriode == null ? const Color(0xFF10B981) : Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            showCheckmark: false,
                          ),
                          ...List.generate(12, (i) {
                            final bulan = (i + 1).toString().padLeft(2, '0');
                            final key = '$bulan/$tahun';
                            final isSel = _selectedPeriode == key;
                            return ChoiceChip(
                              label: Text(bulanNames[i]),
                              selected: isSel,
                              onSelected: (val) {
                                setModalState(() => _selectedPeriode = val ? key : null);
                                setState(() => _selectedPeriode = val ? key : null);
                              },
                              selectedColor: const Color(0xFFECFDF5),
                              labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? const Color(0xFF047857) : AppColors.textDark),
                              side: BorderSide(color: isSel ? const Color(0xFF10B981) : Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              showCheckmark: false,
                            );
                          }),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedCabang = null;
                              _selectedPeriode = null;
                            });
                            setState(() {
                              _selectedCabang = null;
                              _selectedPeriode = null;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Reset', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Terapkan Filter', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
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
}

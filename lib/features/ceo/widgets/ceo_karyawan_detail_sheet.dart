import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/data/hrd_models.dart';
import '../../hrd/services/hrd_service.dart';
import '../../hrd/screens/gaji_karyawan/gaji_karyawan_list_screen.dart';
import '../../hrd/screens/insentif/insentif_cleaner_list_screen.dart';

class CeoKaryawanDetailSheet extends StatefulWidget {
  final KaryawanModel karyawan;

  const CeoKaryawanDetailSheet({
    super.key,
    required this.karyawan,
  });

  static Future<void> show(BuildContext context, {required KaryawanModel karyawan}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CeoKaryawanDetailSheet(karyawan: karyawan),
    );
  }

  @override
  State<CeoKaryawanDetailSheet> createState() => _CeoKaryawanDetailSheetState();
}

class _CeoKaryawanDetailSheetState extends State<CeoKaryawanDetailSheet> {
  final HrdService _hrdService = HrdService();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  bool _isLoading = true;
  GajiKaryawanModel? _latestGaji;
  InsentifCleanerModel? _insentifDetail;
  int _totalBonusBulanIni = 0;
  int _jumlahOrderBonus = 0;

  bool get _isCleaner {
    final role = (widget.karyawan.jabatan?.namaJabatan ?? '').toLowerCase();
    return role.contains('cleaner');
  }

  bool get _isAktif {
    final st = widget.karyawan.status.toLowerCase();
    return st == 'aktif' || st == 'active' || st == '1';
  }

  @override
  void initState() {
    super.initState();
    _loadExecutiveFinancialData();
  }

  Future<void> _loadExecutiveFinancialData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Gaji Karyawan if available
      try {
        final gajiList = await _hrdService.fetchGajiKaryawan(
          search: widget.karyawan.nama,
        );
        final match = gajiList.where((g) => g.karyawanId == widget.karyawan.id).toList();
        if (match.isNotEmpty) {
          _latestGaji = match.first;
        }
      } catch (_) {}

      // 2. Fetch Cleaner Bonus if cleaner
      if (_isCleaner) {
        try {
          final res = await _hrdService.fetchInsentifCleanerDetail(
            widget.karyawan.id,
            filterWaktu: 'bulan_ini',
          );
          if (res != null) {
            _insentifDetail = res;
            _totalBonusBulanIni = res.totalInsentif;
            _jumlahOrderBonus = res.jumlahBonus;
          }
        } catch (_) {}
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.karyawan;
    final cabangName = k.cabang?.namaCabang ?? 'Semua Cabang';
    final jabatanName = k.jabatan?.namaJabatan ?? 'Staff';
    final statusKaryawan = k.statusKaryawan ?? 'Tetap';

    final int gajiPokokNominal = _latestGaji?.gajiPokok ?? 0;
    final int totalTunjangan = (_latestGaji?.tunjanganKos ?? 0) +
        (_latestGaji?.tunjanganKerja ?? 0) +
        (_latestGaji?.bonusBulanan ?? 0);
    final int takeHomePay = _latestGaji != null && _latestGaji!.takeHomePay > 0
        ? (_latestGaji!.takeHomePay + (_isCleaner ? _totalBonusBulanIni : 0))
        : (gajiPokokNominal + _totalBonusBulanIni + totalTunjangan);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.badge_rounded, size: 20, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profil Eksekutif Karyawan',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Monitoring Data SDM & Kompensasi',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Identity Card
                  _buildIdentityCard(k, cabangName, jabatanName, statusKaryawan),
                  const SizedBox(height: 16),

                  // Compensation Card
                  _buildCompensationCard(gajiPokokNominal, takeHomePay, totalTunjangan),
                  const SizedBox(height: 16),

                  // Detail Contact & Bank Card
                  _buildContactAndBankCard(k),
                  const SizedBox(height: 16),

                  // Riwayat Bonus Cleaner Preview (If cleaner)
                  if (_isCleaner) ...[
                    _buildCleanerBonusHistoryCard(),
                    const SizedBox(height: 16),
                  ],

                  // Navigation Shortcut Buttons
                  _buildNavigationButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard(
    KaryawanModel k,
    String cabangName,
    String jabatanName,
    String statusKaryawan,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isAktif
                        ? [const Color(0xFF2563EB), const Color(0xFF1D4ED8)]
                        : [const Color(0xFF94A3B8), const Color(0xFF64748B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  image: k.fotoProfil != null && k.fotoProfil!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(k.fotoProfil!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: k.fotoProfil == null || k.fotoProfil!.isEmpty
                    ? Center(
                        child: Text(
                          k.nama.isNotEmpty ? k.nama[0].toUpperCase() : 'K',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      k.nama,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Status Akun Chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isAktif ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isAktif ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _isAktif ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isAktif ? 'AKTIF' : 'NON-AKTIF',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _isAktif ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Status Karyawan Chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            statusKaryawan.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniTag(
                  icon: Icons.work_outline_rounded,
                  label: 'Jabatan',
                  value: jabatanName,
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _buildMiniTag(
                    icon: Icons.location_on_outlined,
                    label: 'Cabang',
                    value: cabangName,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTag({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
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

  Widget _buildCompensationCard(int gajiPokokNominal, int takeHomePay, int totalTunjangan) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                  const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF38BDF8), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Ringkasan Finansial Eksekutif',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              if (_isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Main Take Home Pay / Total Penghasilan
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isCleaner ? 'Estimasi Total (Gaji + Bonus)' : 'Total Gaji / THP',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isLoading ? 'Memuat...' : _currencyFormat.format(takeHomePay),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF34D399),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'Bulan Berjalan',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6EE7B7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Breakdown Row
          Row(
            children: [
              // Gaji Pokok
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gaji Pokok',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isLoading ? '...' : _currencyFormat.format(gajiPokokNominal),
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Bonus Bulan Ini (Khusus Cleaner / All)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isCleaner ? 'Bonus Cleaner' : 'Tunjangan',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isLoading
                            ? '...'
                            : _currencyFormat.format(_isCleaner
                                ? _totalBonusBulanIni
                                : totalTunjangan),
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFBBF24),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_isCleaner) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.cleaning_services_rounded, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text(
                  'Pekerjaan Berbonus Bulan Ini: ',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
                Text(
                  '$_jumlahOrderBonus Tugas Selesai',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactAndBankCard(KaryawanModel k) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.contact_phone_outlined, size: 16, color: Color(0xFF475569)),
              const SizedBox(width: 8),
              Text(
                'Kontak & Rekening Pembayaran',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoRow(
            icon: Icons.phone_rounded,
            label: 'No. WhatsApp',
            value: (k.noWa != null && k.noWa!.isNotEmpty) ? k.noWa! : '-',
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: k.email.isNotEmpty ? k.email : '-',
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Icons.account_balance_rounded,
            label: 'Bank & Rekening',
            value: (k.namaBank != null && k.namaBank!.isNotEmpty)
                ? '${k.namaBank} - ${k.noRekening ?? '-'}'
                : 'Belum terdaftar',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: const Color(0xFF64748B)),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCleanerBonusHistoryCard() {
    final riwayat = _insentifDetail?.riwayat ?? [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 18, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Text(
                    'Riwayat Bonus Terakhir',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${riwayat.length} Data',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (riwayat.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Belum ada bonus pekerjaan bulan ini',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ...riwayat.take(3).map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.task_alt_rounded, size: 16, color: Color(0xFF059669)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.pelanggan,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.tanggal,
                            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _currencyFormat.format(item.totalNominal),
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Column(
      children: [
        if (_isCleaner) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InsentifCleanerListScreen(showHeader: true),
                  ),
                );
              },
              icon: const Icon(Icons.paid_outlined, size: 16),
              label: Text(
                'Buka Rekap Seluruh Bonus Cleaner',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GajiKaryawanListScreen(),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long_rounded, size: 16),
            label: Text(
              'Buka Rekap Payroll & Slip Gaji',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

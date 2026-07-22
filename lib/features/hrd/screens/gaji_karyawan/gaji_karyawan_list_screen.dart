import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../../../../core/services/pdf_slip_gaji_service.dart';
import '../../services/hrd_service.dart';
import 'gaji_karyawan_form_screen.dart';
import '../insentif/insentif_cleaner_list_screen.dart';
import 'gaji_karyawan_detail_screen.dart';

class GajiKaryawanListScreen extends StatefulWidget {
  const GajiKaryawanListScreen({super.key});

  @override
  State<GajiKaryawanListScreen> createState() => _GajiKaryawanListScreenState();
}

class _GajiKaryawanListScreenState extends State<GajiKaryawanListScreen> with SingleTickerProviderStateMixin {
  final HrdService _hrdService = HrdService();
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool _isLoading = true;
  List<GajiKaryawanModel> _allData = [];
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      _allData = await _hrdService.fetchGajiKaryawan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data gaji: $e')));
      }
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

  Widget _buildList(String jenis) {
    final filteredData = _allData.where((e) => e.jenisGaji == jenis).toList();
    if (filteredData.isEmpty) {
      return Center(
        child: Text('Tidak ada data gaji $jenis.', style: GoogleFonts.inter(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filteredData.length,
      itemBuilder: (context, index) {
        final gaji = filteredData[index];
        return _buildItem(gaji, jenis);
      },
    );
  }

  Widget _buildItem(GajiKaryawanModel gaji, String jenis) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GajiKaryawanDetailScreen(gaji: gaji),
              ),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.indigo.withOpacity(0.15),
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.indigo, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  gaji.karyawan?.nama ?? '-',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  jenis == 'bulanan' 
                                    ? '${gaji.periodeBulan.toString().padLeft(2, '0')}/${gaji.periodeTahun}'
                                    : '${gaji.jumlahHariKerja} Hari',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_rounded, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'THP: ${currencyFormatter.format(gaji.takeHomePay)}', 
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.indigo.shade800), 
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.storefront_rounded, size: 12, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(gaji.snapshotCabang ?? '-', style: GoogleFonts.inter(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
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
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GajiKaryawanDetailScreen(gaji: gaji),
                            ),
                          );
                        },
                        icon: const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        label: Text('Detail', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blue)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24))),
                        ),
                      ),
                    ),
                    Container(width: 1, height: 24, color: Colors.grey.shade300),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _printSlip(gaji),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.amber),
                        label: Text('Cetak Slip', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.amber.shade700)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomRight: Radius.circular(24))),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gaji Karyawan',
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const InsentifCleanerListScreen()),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.payments_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Insentif',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            final String currentJenis = _tabController.index == 1 ? 'harian' : 'bulanan';
                            final res = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GajiKaryawanFormScreen(initialJenisGaji: currentJenis),
                              ),
                            );
                            if (res == true) _fetchData();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.5),
                  tabs: const [
                    Tab(text: 'Bulanan'),
                    Tab(text: 'Harian'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList('bulanan'),
                      _buildList('harian'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

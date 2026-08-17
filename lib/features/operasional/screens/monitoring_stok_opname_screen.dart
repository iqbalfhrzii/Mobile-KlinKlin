import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/operasional_stok_opname_service.dart';

class MonitoringStokOpnameScreen extends StatefulWidget {
  const MonitoringStokOpnameScreen({super.key});

  @override
  State<MonitoringStokOpnameScreen> createState() => _MonitoringStokOpnameScreenState();
}

class _MonitoringStokOpnameScreenState extends State<MonitoringStokOpnameScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  List<dynamic> _cabangs = [];
  Map<String, dynamic>? _currentSession;
  List<dynamic> _sessionDetails = [];

  int? _selectedCabangId;
  DateTime? _selectedPeriode;
  String _selectedTipeSesi = 'tengah_bulan';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCabangs();
    // Default to current month
    _selectedPeriode = DateTime.now();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCabangs() async {
    try {
      final cabangs = await OperasionalStokOpnameService.getCabangs();
      setState(() => _cabangs = cabangs);
      if (cabangs.isNotEmpty) {
        _selectedCabangId = cabangs.first['id'];
        _loadData();
      }
    } catch (e) {
      debugPrint('Error loading cabangs: $e');
    }
  }

  Future<void> _loadData() async {
    if (_selectedCabangId == null) return;
    
    setState(() => _isLoading = true);
    try {
      final String? periodeBulan = _selectedPeriode != null 
          ? DateFormat('MMMM yyyy', 'id').format(_selectedPeriode!) // Assuming 'Agustus 2026' or similar format is saved
          : null;

      final sessions = await OperasionalStokOpnameService.getSessions(
        cabangId: _selectedCabangId,
        periodeBulan: _selectedPeriode != null ? DateFormat('MMMM yyyy').format(_selectedPeriode!) : null, // Actually let's just format to "Agustus 2026" if that's how it's stored.
        tipeSesi: _selectedTipeSesi,
      );

      if (sessions.isNotEmpty) {
        final session = sessions.first;
        final details = await OperasionalStokOpnameService.getSessionDetails(session['id']);
        setState(() {
          _currentSession = details;
          _sessionDetails = details?['details'] ?? [];
        });
      } else {
        setState(() {
          _currentSession = null;
          _sessionDetails = [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monitoring Stok Opname',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pantau hasil checklist aset dan bahan habis pakai',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildFilterBar(),
          _buildTipeSesiSelector(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _currentSession == null
                    ? Center(
                        child: Text(
                          'Tidak ada sesi stok opname untuk filter ini',
                          style: GoogleFonts.inter(color: AppColors.textMuted),
                        ),
                      )
                    : Column(
                        children: [
                          _buildSessionInfoCard(),
                          TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            labelColor: AppColors.primary,
                            unselectedLabelColor: AppColors.textMuted,
                            indicatorColor: AppColors.primary,
                            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
                            tabs: const [
                              Tab(text: 'Mesin Alat (MSN)'),
                              Tab(text: 'Cleaning Alat (CLA)'),
                              Tab(text: 'Barang Habis Pakai (BHP)'),
                              Tab(text: 'Inventaris (INV)'),
                            ],
                          ),
                              Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildItemListView('MSN'),
                                _buildItemListView('CLA'),
                                _buildItemListView('BHP'),
                                _buildItemListView('INV'),
                              ],
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedPeriode ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  helpText: 'Pilih Periode',
                );
                if (picked != null) {
                  setState(() => _selectedPeriode = picked);
                  _loadData();
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10), color: AppColors.surface),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedPeriode != null ? DateFormat('MMMM yyyy').format(_selectedPeriode!) : 'Pilih Periode',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10), color: AppColors.surface),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<dynamic>(
                  value: _selectedCabangId,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w600),
                  items: _cabangs.map((c) => DropdownMenuItem(value: c['id'], child: Text(c['nama_cabang']))).toList(),
                  onChanged: (val) {
                    setState(() => _selectedCabangId = val as int?);
                    _loadData();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipeSesiSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _buildSesiButton('tengah_bulan', 'Awal Bulan', 'Tgl 15', Icons.event_available),
            const SizedBox(width: 12),
            _buildSesiButton('akhir_bulan', 'Akhir Bulan', 'Tgl 30', Icons.event_note),
            const SizedBox(width: 12),
            _buildSesiButton('inventaris', 'Sesuai Tanggal', 'Bebas', Icons.assignment),
          ],
        ),
      ),
    );
  }

  Widget _buildSesiButton(String value, String title, String subtitle, IconData icon) {
    final isSelected = _selectedTipeSesi == value;
    return InkWell(
      onTap: () {
        setState(() => _selectedTipeSesi = value);
        _loadData();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppColors.textDark),
            ),
            const SizedBox(width: 4),
            Text(
              '($subtitle)',
              style: GoogleFonts.inter(fontSize: 11, color: isSelected ? Colors.white70 : AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionInfoCard() {
    final status = _currentSession?['status'] ?? 'Draft';
    final isSelesai = status == 'Selesai';
    final cabangName = _cabangs.firstWhere((c) => c['id'] == _selectedCabangId, orElse: () => {'nama_cabang': '-'})['nama_cabang'];
    
    String sesiName = 'Awal Bulan';
    if (_selectedTipeSesi == 'akhir_bulan') sesiName = 'Akhir Bulan';
    if (_selectedTipeSesi == 'inventaris') sesiName = 'Sesuai Tanggal';

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sesi: $sesiName', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text('Cabang yang Dipantau: $cabangName', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelesai ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelesai ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text('STATUS SESI CS', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(isSelesai ? Icons.check : Icons.circle, size: 12, color: isSelesai ? Colors.green : Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      isSelesai ? 'Telah Diselesaikan' : 'Belum Selesai (Draft)',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: isSelesai ? Colors.green : Colors.orange),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildItemListView(String kategoriKode) {
    // Filter details based on category
    final filtered = _sessionDetails.where((detail) {
      if (kategoriKode == 'BHP') {
        final kode = detail['barang']?['kategori']?['kode_kategori'] ?? '';
        return kode == 'BHP';
      } else {
        final kode = detail['item_fisik']?['barang']?['kategori']?['kode_kategori'] ?? '';
        return kode == kategoriKode;
      }
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_outlined, size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                'Belum ada data checklist untuk kategori ini dari CS pada periode terpilih.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = filtered[index];
        final bool isBhp = kategoriKode == 'BHP';
        return isBhp ? _buildBhpCard(item) : _buildAlatCard(item);
      },
    );
  }

  Widget _buildAlatCard(dynamic item) {
    final itemFisik = item['item_fisik'] ?? {};
    final barang = itemFisik['barang'] ?? {};
    final waktu = item['created_at'] != null ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(item['created_at'])) : '-';
    final kodeQr = itemFisik['kode_qr'] ?? '-';
    final namaAlat = barang['nama_barang'] ?? '-';
    final kondisi = item['kondisi'] ?? '-';
    final fotoUrl = item['foto_path'];
    final keterangan = item['keterangan'] ?? '-';

    Color kondisiColor = Colors.grey;
    if (kondisi == 'Baik') kondisiColor = Colors.green;
    if (kondisi == 'Rusak') kondisiColor = Colors.red;
    if (kondisi == 'Hilang') kondisiColor = Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: fotoUrl != null 
                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network('http://erp.klinklin.online/storage/$fotoUrl', fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.grey)))
                : const Icon(Icons.image_not_supported, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(kodeQr, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                    Text(waktu, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(namaAlat, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kondisiColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        kondisi,
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: kondisiColor),
                      ),
                    ),
                  ],
                ),
                if (keterangan.toString().isNotEmpty && keterangan != '-') ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Keterangan:', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(keterangan, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBhpCard(dynamic item) {
    final barang = item['barang'] ?? {};
    final pembelian = item['pembelian_bhp'] ?? {};
    
    final tglBeli = pembelian['tanggal_pembelian'] != null 
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(pembelian['tanggal_pembelian'])) 
        : '-';
    final namaToko = pembelian['nama_toko'] ?? '-';
    final qtyBeli = pembelian['qty_beli'] != null ? '${pembelian['qty_beli']} pcs' : '-';
    
    final kode = barang['kode_barang'] ?? '-';
    final namaItem = barang['nama_barang'] ?? '-';
    final merk = barang['merk'] ?? '-';
    final sisa = item['sisa_akhir'] != null ? '${item['sisa_akhir']} pcs' : 'Belum diinput';
    final fotoUrl = item['foto_path'];
    final keterangan = item['keterangan'] ?? '-';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: fotoUrl != null 
                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network('http://erp.klinklin.online/storage/$fotoUrl', fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.grey)))
                : const Icon(Icons.image_not_supported, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(kode, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                    Text(tglBeli, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(namaItem, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 4),
                Text(merk, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tanggal Beli:', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                          Text(tglBeli, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Toko / Qty:', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                          Text('$namaToko ($qtyBeli)', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Sisa Opname: ', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    Text(sisa, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
                if (keterangan.toString().isNotEmpty && keterangan != '-') ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Keterangan:', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(keterangan, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

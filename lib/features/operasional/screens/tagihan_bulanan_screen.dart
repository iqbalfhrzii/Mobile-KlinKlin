import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/operasional_tagihan_service.dart';
import 'tagihan_bulanan_form_screen.dart';

class TagihanBulananScreen extends StatefulWidget {
  const TagihanBulananScreen({super.key});

  @override
  State<TagihanBulananScreen> createState() => _TagihanBulananScreenState();
}

class _TagihanBulananScreenState extends State<TagihanBulananScreen> {
  bool _isLoading = false;
  List<dynamic> _tagihans = [];
  List<dynamic> _cabangs = [];

  int? _selectedCabangId;
  DateTime? _selectedPeriode;
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadCabangs();
    _loadData();
  }

  Future<void> _loadCabangs() async {
    try {
      final cabangs = await OperasionalTagihanService.getCabangs();
      setState(() {
        _cabangs = cabangs;
      });
    } catch (e) {
      debugPrint('Error loading cabangs: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await OperasionalTagihanService.getTagihanBulanan(
        cabangId: _selectedCabangId,
        periode: _selectedPeriode != null ? DateFormat('yyyy-MM-dd').format(_selectedPeriode!) : null,
        statusBayar: _selectedStatus,
      );
      setState(() {
        _tagihans = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data tagihan: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                        'Data Tagihan Bulanan',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kelola tagihan bulanan operasional cabang',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tagihans.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ada data tagihan',
                          style: GoogleFonts.inter(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tagihans.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildTagihanCard(_tagihans[index]);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TagihanBulananFormScreen()),
          );
          if (result == true) {
            _loadData();
          }
        },
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  hint: 'Semua Cabang',
                  value: _selectedCabangId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua Cabang')),
                    ..._cabangs.map((c) => DropdownMenuItem(
                          value: c['id'],
                          child: Text(c['nama_cabang']),
                        ))
                  ],
                  onChanged: (val) {
                    setState(() => _selectedCabangId = val as int?);
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  hint: 'Semua Status',
                  value: _selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Semua Status')),
                    DropdownMenuItem(value: 'Belum Bayar', child: Text('Belum Bayar')),
                    DropdownMenuItem(value: 'Lunas', child: Text('Lunas')),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedStatus = val as String);
                    _loadData();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
                color: AppColors.surface,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    _selectedPeriode != null ? DateFormat('MMMM yyyy').format(_selectedPeriode!) : 'Pilih Periode Bulan',
                    style: GoogleFonts.inter(
                      fontSize: 14, 
                      fontWeight: _selectedPeriode != null ? FontWeight.w600 : FontWeight.normal,
                      color: _selectedPeriode != null ? AppColors.textDark : AppColors.textMuted
                    ),
                  ),
                  if (_selectedPeriode != null) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedPeriode = null);
                        _loadData();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 14, color: Colors.red),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required dynamic value,
    required List<DropdownMenuItem<dynamic>> items,
    required Function(dynamic) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
        color: AppColors.surface,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
          hint: Text(hint, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w500),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTagihanCard(dynamic item) {
    final periodeDate = DateTime.tryParse(item['periode'] ?? '');
    final periode = periodeDate != null ? DateFormat('MMMM yyyy').format(periodeDate) : '-';
    
    final jatuhTempoDate = DateTime.tryParse(item['jatuh_tempo'] ?? '');
    final jatuhTempo = jatuhTempoDate != null ? DateFormat('dd MMM yyyy').format(jatuhTempoDate) : '-';

    final isLunas = item['status_bayar'] == 'Lunas';
    final cabang = item['cabang'] != null ? item['cabang']['nama_cabang'] : '-';
    
    // Format nominal
    final formatter = NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0);
    final nominal = formatter.format(double.tryParse(item['nominal'].toString()) ?? 0);

    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TagihanBulananFormScreen(tagihan: item)),
        );
        if (result == true) {
          _loadData();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        periode,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      cabang,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLunas ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item['status_bayar'] ?? '-',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isLunas ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['jenis_tagihan']?.toString().toUpperCase() ?? '-',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nominal,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Hapus Tagihan'),
                        content: const Text('Yakin ingin menghapus data ini?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true), 
                            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      )
                    );
                    if (confirm == true) {
                      try {
                        await OperasionalTagihanService.deleteTagihan(item['id']);
                        _loadData();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              ],
            ),
            if (jatuhTempo != '-') ...[
              const SizedBox(height: 16),
              const Divider(color: AppColors.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.event_busy, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Jatuh Tempo: $jatuhTempo',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}

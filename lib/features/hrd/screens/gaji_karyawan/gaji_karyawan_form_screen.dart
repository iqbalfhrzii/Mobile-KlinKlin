import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'package:intl/intl.dart';

class GajiKaryawanFormScreen extends StatefulWidget {
  final GajiKaryawanModel draft;

  const GajiKaryawanFormScreen({super.key, required this.draft});

  @override
  State<GajiKaryawanFormScreen> createState() => _GajiKaryawanFormScreenState();
}

class _GajiKaryawanFormScreenState extends State<GajiKaryawanFormScreen> {
  final HrdService _hrdService = HrdService();
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool _isSaving = false;

  late int _bonusBulanan;
  late int _kasbon;
  late int _potonganLainnya;
  late int _totalPotongan;
  late int _totalGajiDiterima;
  late int _takeHomePay;

  final TextEditingController _keteranganPotonganCtrl = TextEditingController();
  final TextEditingController _bonusBulananCtrl = TextEditingController();
  final TextEditingController _kasbonCtrl = TextEditingController();
  final TextEditingController _potonganLainnyaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bonusBulanan = widget.draft.bonusBulanan;
    _kasbon = widget.draft.kasbon;
    _potonganLainnya = widget.draft.potonganLainnya;
    _keteranganPotonganCtrl.text = widget.draft.keteranganPotonganLainnya ?? '';
    
    _bonusBulananCtrl.text = _bonusBulanan.toString();
    _kasbonCtrl.text = _kasbon.toString();
    _potonganLainnyaCtrl.text = _potonganLainnya.toString();

    _calculateTotal();
  }

  @override
  void dispose() {
    _keteranganPotonganCtrl.dispose();
    _bonusBulananCtrl.dispose();
    _kasbonCtrl.dispose();
    _potonganLainnyaCtrl.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    setState(() {
      int pendapatan = widget.draft.gajiPokok + 
                       _bonusBulanan + 
                       widget.draft.tunjanganKos + 
                       widget.draft.tunjanganKerja + 
                       widget.draft.premiBpjs +
                       widget.draft.totalBonusLainnya;
      
      _totalPotongan = _kasbon + 
                       widget.draft.potonganTidakAbsen +
                       widget.draft.potonganKeterlambatan + 
                       widget.draft.potonganAbsen +
                       widget.draft.bpjsKetenagakerjaan + 
                       _potonganLainnya;

      _totalGajiDiterima = pendapatan;
      _takeHomePay = _totalGajiDiterima - _totalPotongan;
    });
  }

  Future<void> _saveGaji() async {
    setState(() => _isSaving = true);
    try {
      final dataToSave = {
        'karyawan_id': widget.draft.karyawanId,
        'jenis_gaji': widget.draft.jenisGaji,
        'jumlah_hari_kerja': widget.draft.jumlahHariKerja,
        'gaji_pokok_harian': widget.draft.gajiPokokHarian,
        'periode_bulan': widget.draft.periodeBulan,
        'periode_tahun': widget.draft.periodeTahun,
        'awal_periode': widget.draft.awalPeriode,
        'akhir_periode': widget.draft.akhirPeriode,
        'tanggal_cetak': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'snapshot_cabang': widget.draft.snapshotCabang,
        'snapshot_jabatan': widget.draft.snapshotJabatan,
        'snapshot_status': widget.draft.snapshotStatus,
        
        'gaji_pokok': widget.draft.gajiPokok,
        'tunjangan_kos': widget.draft.tunjanganKos,
        'tunjangan_kerja': widget.draft.tunjanganKerja,
        'premi_bpjs': widget.draft.premiBpjs,
        'bonus_bulanan': _bonusBulanan,
        'total_bonus_lainnya': widget.draft.totalBonusLainnya,
        
        'kasbon': _kasbon,
        'potongan_tidak_absen': widget.draft.potonganTidakAbsen,
        'potongan_keterlambatan': widget.draft.potonganKeterlambatan,
        'potongan_absen': widget.draft.potonganAbsen,
        'bpjs_ketenagakerjaan': widget.draft.bpjsKetenagakerjaan,
        'potongan_lainnya': _potonganLainnya,
        'keterangan_potongan_lainnya': _keteranganPotonganCtrl.text,
        
        'total_potongan': _totalPotongan,
        'total_gaji_diterima': _totalGajiDiterima,
        'take_home_pay': _takeHomePay,
      };

      await _hrdService.createGajiKaryawan(dataToSave);
      
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slip gaji berhasil disimpan!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan gaji: $e')));
      }
    }
  }

  Widget _buildSummaryRow(String label, int amount, {bool isMinus = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 14, color: isBold ? AppColors.textDark : AppColors.textMuted, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            isMinus ? '- ${currencyFormatter.format(amount)}' : currencyFormatter.format(amount),
            style: GoogleFonts.inter(
              fontSize: 14, 
              color: isMinus ? Colors.red : (isBold ? Colors.indigo : AppColors.textDark), 
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow(String label, TextEditingController controller, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark))),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                prefixText: 'Rp ',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
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
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Text(
                  'Review Gaji Karyawan',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Colors.indigo),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.draft.karyawan?.nama ?? widget.draft.snapshotCabang ?? '-', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
                              Text('${widget.draft.snapshotJabatan} • ${widget.draft.snapshotCabang}', style: GoogleFonts.inter(fontSize: 12, color: Colors.indigo.shade700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Text('PENDAPATAN', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        _buildSummaryRow('Gaji Pokok', widget.draft.gajiPokok),
                        _buildSummaryRow('Tunjangan Kos', widget.draft.tunjanganKos),
                        _buildSummaryRow('Tunjangan Kerja', widget.draft.tunjanganKerja),
                        _buildSummaryRow('Premi BPJS', widget.draft.premiBpjs),
                        _buildEditableRow('Bonus Bulanan', _bonusBulananCtrl, (val) {
                          _bonusBulanan = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                          _calculateTotal();
                        }),
                        const Divider(height: 24),
                        _buildSummaryRow('TOTAL PENDAPATAN', _totalGajiDiterima, isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text('POTONGAN', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        _buildSummaryRow('Absen/Terlambat', widget.draft.potonganAbsen + widget.draft.potonganKeterlambatan + widget.draft.potonganTidakAbsen),
                        _buildSummaryRow('BPJS Ketenagakerjaan', widget.draft.bpjsKetenagakerjaan),
                        _buildEditableRow('Kasbon', _kasbonCtrl, (val) {
                          _kasbon = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                          _calculateTotal();
                        }),
                        _buildEditableRow('Potongan Lain', _potonganLainnyaCtrl, (val) {
                          _potonganLainnya = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                          _calculateTotal();
                        }),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _keteranganPotonganCtrl,
                          decoration: InputDecoration(
                            hintText: 'Keterangan potongan lain (opsional)',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            isDense: true,
                          ),
                        ),
                        const Divider(height: 24),
                        _buildSummaryRow('TOTAL POTONGAN', _totalPotongan, isMinus: true, isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.indigo.shade600, Colors.indigo.shade900]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('TAKE HOME PAY', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(currencyFormatter.format(_takeHomePay), style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.yellowAccent)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveGaji,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Simpan Slip Gaji', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

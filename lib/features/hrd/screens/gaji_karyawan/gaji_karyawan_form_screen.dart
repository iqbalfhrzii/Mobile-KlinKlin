import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';

/// Membuka Pop-up Bottom Sheet Modal Form Gaji Karyawan
Future<bool?> showGajiKaryawanFormModal(
  BuildContext context, {
  GajiKaryawanModel? gajiToEdit,
  String initialJenisGaji = 'bulanan',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => GajiKaryawanFormBottomSheet(
      gajiToEdit: gajiToEdit,
      initialJenisGaji: initialJenisGaji,
    ),
  );
}

class GajiKaryawanFormBottomSheet extends StatefulWidget {
  final GajiKaryawanModel? gajiToEdit;
  final String initialJenisGaji;

  const GajiKaryawanFormBottomSheet({
    super.key,
    this.gajiToEdit,
    this.initialJenisGaji = 'bulanan',
  });

  @override
  State<GajiKaryawanFormBottomSheet> createState() => _GajiKaryawanFormBottomSheetState();
}

class _GajiKaryawanFormBottomSheetState extends State<GajiKaryawanFormBottomSheet> {
  final HrdService _hrdService = HrdService();
  final _formKey = GlobalKey<FormState>();
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final dateFormatter = DateFormat('yyyy-MM-dd');
  final displayDateFormatter = DateFormat('MM/dd/yyyy');
  final numberFormat = NumberFormat('#,###', 'id_ID');

  bool _isLoadingMaster = true;
  bool _isSaving = false;

  List<CabangModel> _cabangs = [];
  List<KaryawanModel> _karyawans = [];
  List<KaryawanModel> _filteredKaryawans = [];
  List<GajiPokokModel> _gajiPokoks = [];

  // Identitas
  late String _jenisGaji;
  DateTime _tanggalCetak = DateTime.now();
  int _periodeBulan = DateTime.now().month;
  int _periodeTahun = DateTime.now().year;
  late DateTime _awalPeriode;
  late DateTime _akhirPeriode;

  int? _selectedCabangId;
  int? _selectedKaryawanId;
  KaryawanModel? _selectedKaryawan;
  
  final TextEditingController _periodeTahunCtrl = TextEditingController(text: DateTime.now().year.toString());
  final TextEditingController _jumlahHariKerjaCtrl = TextEditingController(text: '0');

  // Pendapatan
  int _tarifGajiHarian = 0;
  int _gajiPokokVal = 0;
  bool _isBpjsAktif = false;
  
  final TextEditingController _bonusBulananCtrl = TextEditingController(text: '0');
  final TextEditingController _tunjanganKosCtrl = TextEditingController(text: '0');
  final TextEditingController _tunjanganKerjaCtrl = TextEditingController(text: '0');

  // Bonus Detail
  final TextEditingController _bonusReviewCtrl = TextEditingController(text: '0');
  final TextEditingController _bonusTglMerahCtrl = TextEditingController(text: '0');
  final TextEditingController _totalKmCtrl = TextEditingController(text: '0');
  final TextEditingController _totalDeepCleanCtrl = TextEditingController(text: '0');
  final TextEditingController _totalSalonCtrl = TextEditingController(text: '0');
  final TextEditingController _totalTipsCtrl = TextEditingController(text: '0');
  final TextEditingController _totalParkirCtrl = TextEditingController(text: '0');
  final TextEditingController _totalLemburCtrl = TextEditingController(text: '0');
  final TextEditingController _totalUangMakanCtrl = TextEditingController(text: '0');
  final TextEditingController _totalBonusLainnyaCtrl = TextEditingController(text: '0');

  // Potongan
  final TextEditingController _kasbonCtrl = TextEditingController(text: '0');
  final TextEditingController _potonganTidakAbsenCtrl = TextEditingController(text: '0');
  final TextEditingController _potonganKeterlambatanCtrl = TextEditingController(text: '0');
  final TextEditingController _potonganAbsenCtrl = TextEditingController(text: '0');
  final TextEditingController _bpjsKetenagakerjaanCtrl = TextEditingController(text: '0');
  final TextEditingController _potonganLainnyaCtrl = TextEditingController(text: '0');
  final TextEditingController _keteranganPotonganLainnyaCtrl = TextEditingController();
  final TextEditingController _saldoJhtCtrl = TextEditingController(text: '0');

  // Totals
  int _totalBonus = 0;
  int _totalPotongan = 0;
  int _totalGajiDiterima = 0;
  int _takeHomePay = 0;

  String _formatAmount(int val) {
    if (val == 0) return '0';
    return numberFormat.format(val).replaceAll(',', '.');
  }

  int _parseCtrl(TextEditingController c) {
    final clean = c.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(clean) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _jenisGaji = widget.gajiToEdit?.jenisGaji ?? widget.initialJenisGaji;
    
    final now = DateTime.now();
    _periodeBulan = now.month;
    _periodeTahun = now.year;

    if (_jenisGaji == 'bulanan') {
      _awalPeriode = DateTime(now.year, now.month - 1, 28);
      _akhirPeriode = DateTime(now.year, now.month, 27);
    } else {
      _awalPeriode = DateTime(now.year, now.month, 1);
      _akhirPeriode = DateTime(now.year, now.month + 1, 0);
    }

    _fetchMasterData();
  }

  @override
  void dispose() {
    _periodeTahunCtrl.dispose();
    _jumlahHariKerjaCtrl.dispose();
    _bonusBulananCtrl.dispose();
    _tunjanganKosCtrl.dispose();
    _tunjanganKerjaCtrl.dispose();
    _bonusReviewCtrl.dispose();
    _bonusTglMerahCtrl.dispose();
    _totalKmCtrl.dispose();
    _totalDeepCleanCtrl.dispose();
    _totalSalonCtrl.dispose();
    _totalTipsCtrl.dispose();
    _totalParkirCtrl.dispose();
    _totalLemburCtrl.dispose();
    _totalUangMakanCtrl.dispose();
    _totalBonusLainnyaCtrl.dispose();
    _kasbonCtrl.dispose();
    _potonganTidakAbsenCtrl.dispose();
    _potonganKeterlambatanCtrl.dispose();
    _potonganAbsenCtrl.dispose();
    _bpjsKetenagakerjaanCtrl.dispose();
    _potonganLainnyaCtrl.dispose();
    _keteranganPotonganLainnyaCtrl.dispose();
    _saldoJhtCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMasterData() async {
    try {
      final cabangs = await _hrdService.fetchCabang();
      final karyawans = await _hrdService.fetchKaryawan();
      final gajiPokoks = await _hrdService.fetchGajiPokok();

      if (mounted) {
        setState(() {
          _cabangs = cabangs;
          _karyawans = karyawans;
          _gajiPokoks = gajiPokoks;
          _isLoadingMaster = false;
        });

        if (widget.gajiToEdit != null) {
          _populateEditData(widget.gajiToEdit!);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data master: $e')));
        setState(() => _isLoadingMaster = false);
      }
    }
  }

  void _populateEditData(GajiKaryawanModel g) {
    _selectedCabangId = g.karyawan?.cabangId;
    _onCabangChanged(_selectedCabangId, resetKaryawan: false);
    _selectedKaryawanId = g.karyawanId;
    _selectedKaryawan = g.karyawan;

    _periodeBulan = g.periodeBulan ?? DateTime.now().month;
    _periodeTahun = g.periodeTahun ?? DateTime.now().year;
    _periodeTahunCtrl.text = _periodeTahun.toString();
    
    if (g.awalPeriode != null) _awalPeriode = DateTime.tryParse(g.awalPeriode!) ?? _awalPeriode;
    if (g.akhirPeriode != null) _akhirPeriode = DateTime.tryParse(g.akhirPeriode!) ?? _akhirPeriode;

    _jumlahHariKerjaCtrl.text = (g.jumlahHariKerja ?? 0).toString();
    _tarifGajiHarian = g.gajiPokokHarian;
    _gajiPokokVal = g.gajiPokok;

    _bonusBulananCtrl.text = _formatAmount(g.bonusBulanan);
    _tunjanganKosCtrl.text = _formatAmount(g.tunjanganKos);
    _tunjanganKerjaCtrl.text = _formatAmount(g.tunjanganKerja);
    _isBpjsAktif = g.premiBpjs > 0;

    _bonusReviewCtrl.text = _formatAmount(g.bonusReview);
    _bonusTglMerahCtrl.text = _formatAmount(g.bonusTanggalMerah);
    _totalKmCtrl.text = _formatAmount(g.totalKilometer);
    _totalDeepCleanCtrl.text = _formatAmount(g.totalDeepclean);
    _totalSalonCtrl.text = _formatAmount(g.totalSalon);
    _totalTipsCtrl.text = _formatAmount(g.totalTips);
    _totalParkirCtrl.text = _formatAmount(g.totalParkir);
    _totalLemburCtrl.text = _formatAmount(g.totalLembur);
    _totalUangMakanCtrl.text = _formatAmount(g.totalUangMakan);
    _totalBonusLainnyaCtrl.text = _formatAmount(g.totalBonusLainnya);

    _kasbonCtrl.text = _formatAmount(g.kasbon);
    _potonganTidakAbsenCtrl.text = _formatAmount(g.potonganTidakAbsen);
    _potonganKeterlambatanCtrl.text = _formatAmount(g.potonganKeterlambatan);
    _potonganAbsenCtrl.text = _formatAmount(g.potonganAbsen);
    _bpjsKetenagakerjaanCtrl.text = _formatAmount(g.bpjsKetenagakerjaan);
    _potonganLainnyaCtrl.text = _formatAmount(g.potonganLainnya);
    _keteranganPotonganLainnyaCtrl.text = g.keteranganPotonganLainnya ?? '';

    _calculateAll();
  }

  void _onCabangChanged(int? cabangId, {bool resetKaryawan = true}) {
    setState(() {
      _selectedCabangId = cabangId;
      if (resetKaryawan) {
        _selectedKaryawanId = null;
        _selectedKaryawan = null;
      }
      if (cabangId != null) {
        _filteredKaryawans = _karyawans.where((k) => k.cabangId == cabangId).toList();
      } else {
        _filteredKaryawans = [];
      }
    });
    if (resetKaryawan) {
      _applyMasterGajiForSelectedKaryawan();
    }
  }

  void _onKaryawanChanged(int? karyawanId) {
    if (karyawanId == null) {
      setState(() {
        _selectedKaryawanId = null;
        _selectedKaryawan = null;
      });
      _applyMasterGajiForSelectedKaryawan();
      return;
    }

    final k = _karyawans.firstWhere((element) => element.id == karyawanId);
    setState(() {
      _selectedKaryawanId = karyawanId;
      _selectedKaryawan = k;
    });

    _applyMasterGajiForSelectedKaryawan();
  }

  void _applyMasterGajiForSelectedKaryawan() {
    if (_selectedKaryawan == null) {
      setState(() {
        _tarifGajiHarian = 0;
        _gajiPokokVal = 0;
        _bonusBulananCtrl.text = '0';
        _tunjanganKosCtrl.text = '0';
        _tunjanganKerjaCtrl.text = '0';
        _isBpjsAktif = false;
      });
      _calculateAll();
      return;
    }

    final k = _selectedKaryawan!;

    // Lookup Master Gaji Pokok
    // 1. Exact match cabang, jabatan, status_karyawan
    GajiPokokModel? master;
    final exactMatches = _gajiPokoks.where(
      (g) => g.cabangId == k.cabangId && 
             g.jabatanId == k.jabatanId && 
             g.statusKaryawan.toLowerCase() == (k.statusKaryawan ?? '').toLowerCase(),
    );
    if (exactMatches.isNotEmpty) {
      master = exactMatches.first;
    } else {
      // 2. Match by cabang and jabatan
      final cabangJabatanMatches = _gajiPokoks.where(
        (g) => g.cabangId == k.cabangId && g.jabatanId == k.jabatanId,
      );
      if (cabangJabatanMatches.isNotEmpty) {
        master = cabangJabatanMatches.first;
      } else {
        // 3. Fallback by jabatan
        final jabatanMatches = _gajiPokoks.where((g) => g.jabatanId == k.jabatanId);
        if (jabatanMatches.isNotEmpty) {
          master = jabatanMatches.first;
        }
      }
    }

    if (master != null) {
      setState(() {
        if (_jenisGaji == 'harian') {
          _tarifGajiHarian = master!.gajiPokokHarian;
          _bonusBulananCtrl.text = '0';
          _isBpjsAktif = false;
          _tunjanganKosCtrl.text = _formatAmount(master.tunjanganKos);
          _tunjanganKerjaCtrl.text = _formatAmount(master.tunjanganKerja);
          
          final int hari = int.tryParse(_jumlahHariKerjaCtrl.text) ?? 0;
          _gajiPokokVal = _tarifGajiHarian * hari;
        } else {
          _gajiPokokVal = master!.gajiPokok;
          _bonusBulananCtrl.text = _formatAmount(master.bonusBulanan);
          _tunjanganKosCtrl.text = _formatAmount(master.tunjanganKos);
          _tunjanganKerjaCtrl.text = _formatAmount(master.tunjanganKerja);
          _isBpjsAktif = master.premiBpjs > 0;
        }
      });
    } else {
      setState(() {
        _tarifGajiHarian = 0;
        _gajiPokokVal = 0;
        _bonusBulananCtrl.text = '0';
        _tunjanganKosCtrl.text = '0';
        _tunjanganKerjaCtrl.text = '0';
        _isBpjsAktif = false;
      });
    }

    _calculateAll();
  }

  int get _calculatedDaysInPeriod {
    if (_akhirPeriode.isAfter(_awalPeriode) || _akhirPeriode.isAtSameMomentAs(_awalPeriode)) {
      return _akhirPeriode.difference(_awalPeriode).inDays + 1;
    }
    return 0;
  }

  void _onPeriodeBulanTahunChanged() {
    setState(() {
      if (_jenisGaji == 'bulanan') {
        _awalPeriode = DateTime(_periodeTahun, _periodeBulan - 1, 28);
        _akhirPeriode = DateTime(_periodeTahun, _periodeBulan, 27);
      } else {
        _awalPeriode = DateTime(_periodeTahun, _periodeBulan, 1);
        _akhirPeriode = DateTime(_periodeTahun, _periodeBulan + 1, 0);
      }
    });
    _applyMasterGajiForSelectedKaryawan();
  }

  void _calculateAll() {
    int hari = int.tryParse(_jumlahHariKerjaCtrl.text) ?? 0;
    if (_jenisGaji == 'harian') {
      _gajiPokokVal = _tarifGajiHarian * hari;
    }

    int bBulanan = _parseCtrl(_bonusBulananCtrl);
    int tKos = _parseCtrl(_tunjanganKosCtrl);
    int tKerja = _parseCtrl(_tunjanganKerjaCtrl);
    int premiBpjs = _isBpjsAktif ? 35000 : 0;

    // Bonus Detail
    int bReview = _parseCtrl(_bonusReviewCtrl);
    int bTglMerah = _parseCtrl(_bonusTglMerahCtrl);
    int totalKm = _parseCtrl(_totalKmCtrl);
    int totalDeep = _parseCtrl(_totalDeepCleanCtrl);
    int totalSalon = _parseCtrl(_totalSalonCtrl);
    int totalTips = _parseCtrl(_totalTipsCtrl);
    int totalParkir = _parseCtrl(_totalParkirCtrl);
    int totalLembur = _parseCtrl(_totalLemburCtrl);
    int totalMakan = _parseCtrl(_totalUangMakanCtrl);
    int bLainnya = _parseCtrl(_totalBonusLainnyaCtrl);

    _totalBonus = bReview + bTglMerah + totalKm + totalDeep + totalSalon + totalTips + totalParkir + totalLembur + totalMakan + bLainnya;

    // Potongan Detail
    int kasbon = _parseCtrl(_kasbonCtrl);
    int potTidakAbsen = _parseCtrl(_potonganTidakAbsenCtrl);
    int potKeterlambatan = _parseCtrl(_potonganKeterlambatanCtrl);
    int potAbsen = _parseCtrl(_potonganAbsenCtrl);
    int bpjsKetenagakerjaan = _parseCtrl(_bpjsKetenagakerjaanCtrl);
    int potLainnya = _parseCtrl(_potonganLainnyaCtrl);

    _totalPotongan = kasbon + potTidakAbsen + potKeterlambatan + potAbsen + bpjsKetenagakerjaan + potLainnya;

    _totalGajiDiterima = _gajiPokokVal + bBulanan + tKos + tKerja + premiBpjs + _totalBonus;
    _takeHomePay = _totalGajiDiterima - _totalPotongan;

    if (mounted) setState(() {});
  }

  Future<void> _selectDate(BuildContext context, DateTime initial, ValueChanged<DateTime> onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      onPicked(picked);
      _calculateAll();
    }
  }

  Future<void> _saveGaji() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedKaryawanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wajib memilih karyawan')));
      return;
    }

    setState(() => _isSaving = true);

    final data = {
      'karyawan_id': _selectedKaryawanId,
      'jenis_gaji': _jenisGaji,
      'jumlah_hari_kerja': int.tryParse(_jumlahHariKerjaCtrl.text) ?? 0,
      'gaji_pokok_harian': _tarifGajiHarian,
      'periode_bulan': _periodeBulan,
      'periode_tahun': _periodeTahun,
      'tanggal_cetak': dateFormatter.format(_tanggalCetak),
      'awal_periode': dateFormatter.format(_awalPeriode),
      'akhir_periode': dateFormatter.format(_akhirPeriode),
      'snapshot_cabang': _selectedKaryawan?.cabang?.namaCabang ?? '',
      'snapshot_jabatan': _selectedKaryawan?.jabatan?.namaJabatan ?? '',
      'snapshot_status': _selectedKaryawan?.statusKaryawan ?? '',
      
      'gaji_pokok': _gajiPokokVal,
      'bonus_bulanan': _parseCtrl(_bonusBulananCtrl),
      'tunjangan_kos': _parseCtrl(_tunjanganKosCtrl),
      'tunjangan_kerja': _parseCtrl(_tunjanganKerjaCtrl),
      'premi_bpjs': _isBpjsAktif ? 35000 : 0,

      'bonus_review': _parseCtrl(_bonusReviewCtrl),
      'bonus_tanggal_merah': _parseCtrl(_bonusTglMerahCtrl),
      'total_kilometer': _parseCtrl(_totalKmCtrl),
      'total_deepclean': _parseCtrl(_totalDeepCleanCtrl),
      'total_salon': _parseCtrl(_totalSalonCtrl),
      'total_tips': _parseCtrl(_totalTipsCtrl),
      'total_parkir': _parseCtrl(_totalParkirCtrl),
      'total_lembur': _parseCtrl(_totalLemburCtrl),
      'total_uang_makan': _parseCtrl(_totalUangMakanCtrl),
      'total_bonus_lainnya': _parseCtrl(_totalBonusLainnyaCtrl),
      'total_bonus': _totalBonus,

      'kasbon': _parseCtrl(_kasbonCtrl),
      'potongan_tidak_absen': _parseCtrl(_potonganTidakAbsenCtrl),
      'potongan_keterlambatan': _parseCtrl(_potonganKeterlambatanCtrl),
      'potongan_absen': _parseCtrl(_potonganAbsenCtrl),
      'bpjs_ketenagakerjaan': _parseCtrl(_bpjsKetenagakerjaanCtrl),
      'potongan_lainnya': _parseCtrl(_potonganLainnyaCtrl),
      'keterangan_potongan_lainnya': _keteranganPotonganLainnyaCtrl.text,
      'total_potongan': _totalPotongan,

      'total_gaji_diterima': _totalGajiDiterima,
      'take_home_pay': _takeHomePay,
      'saldo_jht': _parseCtrl(_saldoJhtCtrl),
    };

    try {
      await _hrdService.createGajiKaryawan(data);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slip gaji berhasil disimpan!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    }
  }

  Widget _buildNumericInput(String label, TextEditingController controller, {String? hint, VoidCallback? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint ?? '0',
            prefixText: 'Rp ',
            prefixStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            isDense: true,
          ),
          onChanged: (_) {
            _calculateAll();
            if (onChanged != null) onChanged();
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.post_add_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.gajiToEdit == null 
                            ? 'Form Gaji ${_jenisGaji.toUpperCase()} (Slip)' 
                            : 'Edit Slip Gaji',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Otomatis menghitung gaji, bonus, dan potongan',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
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

          Expanded(
            child: _isLoadingMaster
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- SECTION 1: IDENTITAS SLIP ---
                          _buildSectionHeader('IDENTITAS SLIP', Icons.badge_outlined, const Color(0xFF2563EB)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF64748B).withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Jenis Gaji', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          setState(() => _jenisGaji = 'bulanan');
                                          _onPeriodeBulanTahunChanged();
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            color: _jenisGaji == 'bulanan' ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: _jenisGaji == 'bulanan' ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0)),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Bulanan',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: _jenisGaji == 'bulanan' ? FontWeight.bold : FontWeight.w500,
                                                color: _jenisGaji == 'bulanan' ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          setState(() => _jenisGaji = 'harian');
                                          _onPeriodeBulanTahunChanged();
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            color: _jenisGaji == 'harian' ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: _jenisGaji == 'harian' ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0)),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Harian',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: _jenisGaji == 'harian' ? FontWeight.bold : FontWeight.w500,
                                                color: _jenisGaji == 'harian' ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Tanggal Cetak', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                          const SizedBox(height: 6),
                                          InkWell(
                                            onTap: () => _selectDate(context, _tanggalCetak, (d) => _tanggalCetak = d),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(displayDateFormatter.format(_tanggalCetak), style: GoogleFonts.inter(fontSize: 13)),
                                                  const Icon(Icons.calendar_today, size: 14, color: Color(0xFF64748B)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Periode Bulan & Tahun', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: DropdownButtonFormField<int>(
                                                  value: _periodeBulan,
                                                  isExpanded: true,
                                                  decoration: InputDecoration(
                                                    filled: true,
                                                    fillColor: const Color(0xFFF8FAFC),
                                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                  ),
                                                  items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text((i + 1).toString().padLeft(2, '0')))),
                                                  onChanged: (v) {
                                                    if (v != null) {
                                                      setState(() => _periodeBulan = v);
                                                      _onPeriodeBulanTahunChanged();
                                                    }
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: TextFormField(
                                                  controller: _periodeTahunCtrl,
                                                  keyboardType: TextInputType.number,
                                                  textAlign: TextAlign.center,
                                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                                  decoration: InputDecoration(
                                                    filled: true,
                                                    fillColor: const Color(0xFFF8FAFC),
                                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                                    isDense: true,
                                                  ),
                                                  onChanged: (v) {
                                                    _periodeTahun = int.tryParse(v) ?? DateTime.now().year;
                                                    _onPeriodeBulanTahunChanged();
                                                  },
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

                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Awal Periode', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                          const SizedBox(height: 6),
                                          InkWell(
                                            onTap: () => _selectDate(context, _awalPeriode, (d) {
                                              _awalPeriode = d;
                                            }),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(displayDateFormatter.format(_awalPeriode), style: GoogleFonts.inter(fontSize: 13)),
                                                  const Icon(Icons.calendar_month, size: 14, color: Color(0xFF64748B)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Akhir Periode', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                          const SizedBox(height: 6),
                                          InkWell(
                                            onTap: () => _selectDate(context, _akhirPeriode, (d) {
                                              _akhirPeriode = d;
                                            }),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(displayDateFormatter.format(_akhirPeriode), style: GoogleFonts.inter(fontSize: 13)),
                                                  const Icon(Icons.calendar_month, size: 14, color: Color(0xFF64748B)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                Text('Cabang *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<int>(
                                  value: _selectedCabangId,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  items: _cabangs.map((c) => DropdownMenuItem(value: c.id, child: Text(c.namaCabang))).toList(),
                                  onChanged: (val) => _onCabangChanged(val),
                                  validator: (v) => v == null ? 'Wajib pilih cabang' : null,
                                ),
                                const SizedBox(height: 14),

                                Text('ID Karyawan / Nama *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<int>(
                                  value: _selectedKaryawanId,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  items: _filteredKaryawans.map((k) => DropdownMenuItem(value: k.id, child: Text('${k.id} - ${k.nama}'))).toList(),
                                  onChanged: _selectedCabangId == null ? null : _onKaryawanChanged,
                                  validator: (v) => v == null ? 'Wajib pilih karyawan' : null,
                                  hint: Text(_selectedCabangId == null ? 'Pilih cabang dulu' : 'Pilih karyawan'),
                                ),

                                if (_selectedKaryawan != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Nama Karyawan', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                                  const SizedBox(height: 2),
                                                  Text(_selectedKaryawan?.nama ?? '-', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Jabatan', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                                  const SizedBox(height: 2),
                                                  Text(_selectedKaryawan?.jabatan?.namaJabatan ?? '-', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Status', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                                  const SizedBox(height: 2),
                                                  Text(_selectedKaryawan?.statusKaryawan ?? '-', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                if (_jenisGaji == 'harian') ...[
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Jumlah Hari Kerja *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                      if (_calculatedDaysInPeriod > 0)
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              _jumlahHariKerjaCtrl.text = _calculatedDaysInPeriod.toString();
                                            });
                                            _calculateAll();
                                          },
                                          child: Text(
                                            'Set $_calculatedDaysInPeriod Hari',
                                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _jumlahHariKerjaCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      suffixText: 'Hari',
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    ),
                                    onChanged: (_) => _calculateAll(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // --- SECTION 2: PENDAPATAN ---
                          _buildSectionHeader('PENDAPATAN', Icons.arrow_circle_up_rounded, const Color(0xFF059669)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF64748B).withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_jenisGaji == 'harian') ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFA7F3D0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Tarif Gaji Pokok Harian',
                                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF047857), fontWeight: FontWeight.w500),
                                            ),
                                            Text(
                                              currencyFormatter.format(_tarifGajiHarian),
                                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF065F46)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        const Divider(height: 1, color: Color(0xFFD1FAE5)),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Total Gaji Pokok',
                                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF065F46)),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${_jumlahHariKerjaCtrl.text.isEmpty ? "0" : _jumlahHariKerjaCtrl.text} hari × ${currencyFormatter.format(_tarifGajiHarian)}',
                                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF059669), fontWeight: FontWeight.w500),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              currencyFormatter.format(_gajiPokokVal),
                                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF047857)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ] else ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Total Gaji Pokok', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                                      Text(currencyFormatter.format(_gajiPokokVal), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF047857))),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                _buildNumericInput(
                                  _jenisGaji == 'harian' ? 'Bonus Bulanan (Harian: Rp 0)' : 'Bonus Bulanan',
                                  _bonusBulananCtrl,
                                  hint: _jenisGaji == 'harian' ? '0 (Harian)' : '0',
                                ),
                                const SizedBox(height: 10),
                                _buildNumericInput('Tunjangan Kos', _tunjanganKosCtrl),
                                const SizedBox(height: 10),
                                _buildNumericInput('Tunjangan Kerja', _tunjanganKerjaCtrl),
                                const SizedBox(height: 10),

                                InkWell(
                                  onTap: () {
                                    setState(() => _isBpjsAktif = !_isBpjsAktif);
                                    _calculateAll();
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _isBpjsAktif ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: _isBpjsAktif ? const Color(0xFF6EE7B7) : const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _isBpjsAktif ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                          color: _isBpjsAktif ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text('Premi BPJS Aktif (+ Rp 35.000)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Sub-Section: Komponen Total Bonus
                                Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    title: Text('Komponen Total Bonus', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF047857))),
                                    subtitle: Text('Akumulasi: ${currencyFormatter.format(_totalBonus)}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                                    childrenPadding: const EdgeInsets.symmetric(vertical: 6),
                                    children: [
                                      _buildNumericInput('Bonus Review', _bonusReviewCtrl),
                                      const SizedBox(height: 8),
                                      _buildNumericInput('Bonus Tgl Merah', _bonusTglMerahCtrl),
                                      const SizedBox(height: 8),
                                      _buildNumericInput('Total Kilometer', _totalKmCtrl),
                                      const SizedBox(height: 8),
                                      _buildNumericInput('Total DeepClean', _totalDeepCleanCtrl),
                                      const SizedBox(height: 8),
                                      _buildNumericInput('Total Salon', _totalSalonCtrl),
                                      const SizedBox(height: 8),
                                      _buildNumericInput('Total Tips', _totalTipsCtrl),
                                      const SizedBox(height: 8),
                                      _buildNumericInput('Total Parkir', _totalParkirCtrl),
                                      const SizedBox(height: 8),
                                      _buildNumericInput('Total Lembur', _totalLemburCtrl),
                                      const SizedBox(height: 8),
                                      _buildNumericInput('Total Uang Makan', _totalUangMakanCtrl),
                                      const SizedBox(height: 8),
                                      _buildNumericInput('Bonus Lainnya', _totalBonusLainnyaCtrl),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // --- SECTION 3: POTONGAN ---
                          _buildSectionHeader('POTONGAN', Icons.arrow_circle_down_rounded, const Color(0xFFDC2626)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF64748B).withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _buildNumericInput('Cashbon', _kasbonCtrl),
                                const SizedBox(height: 8),
                                _buildNumericInput('Potongan Tidak Absen', _potonganTidakAbsenCtrl),
                                const SizedBox(height: 8),
                                _buildNumericInput('Potongan Keterlambatan', _potonganKeterlambatanCtrl),
                                const SizedBox(height: 8),
                                _buildNumericInput('Potongan Absen', _potonganAbsenCtrl),
                                const SizedBox(height: 8),
                                _buildNumericInput('BPJS Ketenagakerjaan', _bpjsKetenagakerjaanCtrl),
                                const SizedBox(height: 8),
                                _buildNumericInput('Potongan Lainnya', _potonganLainnyaCtrl),
                                const SizedBox(height: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Keterangan Potongan Lainnya', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _keteranganPotonganLainnyaCtrl,
                                      decoration: InputDecoration(
                                        hintText: 'Tulis alasan potongan...',
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        isDense: true,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Total Potongan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFB91C1C))),
                                      Text('- ${currencyFormatter.format(_totalPotongan)}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFFB91C1C))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // --- SECTION 4: HASIL AKHIR (TAKE HOME PAY) ---
                          _buildSectionHeader('HASIL AKHIR (TAKE HOME PAY)', Icons.account_balance_wallet_rounded, const Color(0xFF1D4ED8)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8), Color(0xFF2563EB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TAKE HOME PAY (GAJI BERSIH)',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  currencyFormatter.format(_takeHomePay),
                                  style: GoogleFonts.inter(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Pendapatan: ${currencyFormatter.format(_totalGajiDiterima)}',
                                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.9)),
                                      ),
                                      Text(
                                        'Potongan: -${currencyFormatter.format(_totalPotongan)}',
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFFCA5A5)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: _buildNumericInput('Saldo JHT (Informasi)', _saldoJhtCtrl),
                          ),
                          const SizedBox(height: 24),

                          // --- BUTTONS ---
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: BorderSide(color: Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: Text('Batal', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveGaji,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : Text('Simpan Slip Gaji', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ),
                            ],
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
}

/// Fallback / Compatibility wrapper jika ada yang memanggil GajiKaryawanFormScreen
class GajiKaryawanFormScreen extends StatelessWidget {
  final GajiKaryawanModel? gajiToEdit;
  final String initialJenisGaji;

  const GajiKaryawanFormScreen({
    super.key,
    this.gajiToEdit,
    this.initialJenisGaji = 'bulanan',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(gajiToEdit == null ? 'Form Gaji' : 'Edit Gaji', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: GajiKaryawanFormBottomSheet(
        gajiToEdit: gajiToEdit,
        initialJenisGaji: initialJenisGaji,
      ),
    );
  }
}

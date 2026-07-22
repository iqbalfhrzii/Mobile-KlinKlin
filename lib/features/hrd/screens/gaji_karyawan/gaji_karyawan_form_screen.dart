import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';

class GajiKaryawanFormScreen extends StatefulWidget {
  final GajiKaryawanModel? gajiToEdit;
  final String initialJenisGaji;

  const GajiKaryawanFormScreen({
    super.key,
    this.gajiToEdit,
    this.initialJenisGaji = 'bulanan',
  });

  @override
  State<GajiKaryawanFormScreen> createState() => _GajiKaryawanFormScreenState();
}

class _GajiKaryawanFormScreenState extends State<GajiKaryawanFormScreen> {
  final HrdService _hrdService = HrdService();
  final _formKey = GlobalKey<FormState>();
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final dateFormatter = DateFormat('yyyy-MM-dd');

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
  DateTime _awalPeriode = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _akhirPeriode = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  int? _selectedCabangId;
  int? _selectedKaryawanId;
  KaryawanModel? _selectedKaryawan;
  
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

  @override
  void initState() {
    super.initState();
    _jenisGaji = widget.gajiToEdit?.jenisGaji ?? widget.initialJenisGaji;
    _fetchMasterData();
  }

  @override
  void dispose() {
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
    _onCabangChanged(_selectedCabangId);
    _selectedKaryawanId = g.karyawanId;
    _selectedKaryawan = g.karyawan;

    _periodeBulan = g.periodeBulan ?? DateTime.now().month;
    _periodeTahun = g.periodeTahun ?? DateTime.now().year;
    
    if (g.awalPeriode != null) _awalPeriode = DateTime.tryParse(g.awalPeriode!) ?? _awalPeriode;
    if (g.akhirPeriode != null) _akhirPeriode = DateTime.tryParse(g.akhirPeriode!) ?? _akhirPeriode;

    _jumlahHariKerjaCtrl.text = (g.jumlahHariKerja ?? 0).toString();
    _tarifGajiHarian = g.gajiPokokHarian;
    _gajiPokokVal = g.gajiPokok;

    _bonusBulananCtrl.text = g.bonusBulanan.toString();
    _tunjanganKosCtrl.text = g.tunjanganKos.toString();
    _tunjanganKerjaCtrl.text = g.tunjanganKerja.toString();
    _isBpjsAktif = g.premiBpjs > 0;

    _bonusReviewCtrl.text = g.bonusReview.toString();
    _bonusTglMerahCtrl.text = g.bonusTanggalMerah.toString();
    _totalKmCtrl.text = g.totalKilometer.toString();
    _totalDeepCleanCtrl.text = g.totalDeepclean.toString();
    _totalSalonCtrl.text = g.totalSalon.toString();
    _totalTipsCtrl.text = g.totalTips.toString();
    _totalParkirCtrl.text = g.totalParkir.toString();
    _totalLemburCtrl.text = g.totalLembur.toString();
    _totalUangMakanCtrl.text = g.totalUangMakan.toString();
    _totalBonusLainnyaCtrl.text = g.totalBonusLainnya.toString();

    _kasbonCtrl.text = g.kasbon.toString();
    _potonganTidakAbsenCtrl.text = g.potonganTidakAbsen.toString();
    _potonganKeterlambatanCtrl.text = g.potonganKeterlambatan.toString();
    _potonganAbsenCtrl.text = g.potonganAbsen.toString();
    _bpjsKetenagakerjaanCtrl.text = g.bpjsKetenagakerjaan.toString();
    _potonganLainnyaCtrl.text = g.potonganLainnya.toString();
    _keteranganPotonganLainnyaCtrl.text = g.keteranganPotonganLainnya ?? '';

    _calculateAll();
  }

  void _onCabangChanged(int? cabangId) {
    setState(() {
      _selectedCabangId = cabangId;
      _selectedKaryawanId = null;
      _selectedKaryawan = null;
      if (cabangId != null) {
        _filteredKaryawans = _karyawans.where((k) => k.cabangId == cabangId).toList();
      } else {
        _filteredKaryawans = [];
      }
    });
  }

  void _onKaryawanChanged(int? karyawanId) {
    if (karyawanId == null) return;
    final k = _karyawans.firstWhere((element) => element.id == karyawanId);
    setState(() {
      _selectedKaryawanId = karyawanId;
      _selectedKaryawan = k;
    });

    // Lookup Master Gaji Pokok
    final master = _gajiPokoks.firstWhere(
      (g) => g.cabangId == k.cabangId && 
             g.jabatanId == k.jabatanId && 
             (g.statusKaryawan ?? '').toLowerCase() == (k.statusKaryawan ?? '').toLowerCase(),
      orElse: () => GajiPokokModel(
        id: 0, cabangId: 0, jabatanId: 0, statusKaryawan: '', 
        gajiPokok: 0, bonusBulanan: 0, tunjanganKos: 0, 
        tunjanganKerja: 0, gajiPokokHarian: 0, premiBpjs: 0
      ),
    );

    if (master.id != 0) {
      setState(() {
        _tarifGajiHarian = master.gajiPokokHarian;
        _bonusBulananCtrl.text = master.bonusBulanan.toString();
        _tunjanganKosCtrl.text = master.tunjanganKos.toString();
        _tunjanganKerjaCtrl.text = master.tunjanganKerja.toString();
        _isBpjsAktif = master.premiBpjs > 0;

        if (_jenisGaji == 'harian') {
          int hari = int.tryParse(_jumlahHariKerjaCtrl.text) ?? 0;
          _gajiPokokVal = _tarifGajiHarian * hari;
        } else {
          _gajiPokokVal = master.gajiPokok;
        }
      });
      _calculateAll();
    }
  }

  void _calculateAll() {
    int parseCtrl(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    int hari = int.tryParse(_jumlahHariKerjaCtrl.text) ?? 0;
    if (_jenisGaji == 'harian') {
      _gajiPokokVal = _tarifGajiHarian * hari;
    }

    int bBulanan = parseCtrl(_bonusBulananCtrl);
    int tKos = parseCtrl(_tunjanganKosCtrl);
    int tKerja = parseCtrl(_tunjanganKerjaCtrl);
    int premiBpjs = _isBpjsAktif ? 35000 : 0;

    // Bonus Detail
    int bReview = parseCtrl(_bonusReviewCtrl);
    int bTglMerah = parseCtrl(_bonusTglMerahCtrl);
    int totalKm = parseCtrl(_totalKmCtrl);
    int totalDeep = parseCtrl(_totalDeepCleanCtrl);
    int totalSalon = parseCtrl(_totalSalonCtrl);
    int totalTips = parseCtrl(_totalTipsCtrl);
    int totalParkir = parseCtrl(_totalParkirCtrl);
    int totalLembur = parseCtrl(_totalLemburCtrl);
    int totalMakan = parseCtrl(_totalUangMakanCtrl);
    int bLainnya = parseCtrl(_totalBonusLainnyaCtrl);

    _totalBonus = bReview + bTglMerah + totalKm + totalDeep + totalSalon + totalTips + totalParkir + totalLembur + totalMakan + bLainnya;

    // Potongan Detail
    int kasbon = parseCtrl(_kasbonCtrl);
    int potTidakAbsen = parseCtrl(_potonganTidakAbsenCtrl);
    int potKeterlambatan = parseCtrl(_potonganKeterlambatanCtrl);
    int potAbsen = parseCtrl(_potonganAbsenCtrl);
    int bpjsKetenagakerjaan = parseCtrl(_bpjsKetenagakerjaanCtrl);
    int potLainnya = parseCtrl(_potonganLainnyaCtrl);

    _totalPotongan = kasbon + potTidakAbsen + potKeterlambatan + potAbsen + bpjsKetenagakerjaan + potLainnya;

    _totalGajiDiterima = _gajiPokokVal + bBulanan + tKos + tKerja + premiBpjs + _totalBonus;
    _takeHomePay = _totalGajiDiterima - _totalPotongan;

    setState(() {});
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
      setState(() {});
    }
  }

  Future<void> _saveGaji() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedKaryawanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wajib memilih karyawan')));
      return;
    }

    setState(() => _isSaving = true);

    int parseCtrl(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

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
      'bonus_bulanan': parseCtrl(_bonusBulananCtrl),
      'tunjangan_kos': parseCtrl(_tunjanganKosCtrl),
      'tunjangan_kerja': parseCtrl(_tunjanganKerjaCtrl),
      'premi_bpjs': _isBpjsAktif ? 35000 : 0,

      'bonus_review': parseCtrl(_bonusReviewCtrl),
      'bonus_tanggal_merah': parseCtrl(_bonusTglMerahCtrl),
      'total_kilometer': parseCtrl(_totalKmCtrl),
      'total_deepclean': parseCtrl(_totalDeepCleanCtrl),
      'total_salon': parseCtrl(_totalSalonCtrl),
      'total_tips': parseCtrl(_totalTipsCtrl),
      'total_parkir': parseCtrl(_totalParkirCtrl),
      'total_lembur': parseCtrl(_totalLemburCtrl),
      'total_uang_makan': parseCtrl(_totalUangMakanCtrl),
      'total_bonus_lainnya': parseCtrl(_totalBonusLainnyaCtrl),
      'total_bonus': _totalBonus,

      'kasbon': parseCtrl(_kasbonCtrl),
      'potongan_tidak_absen': parseCtrl(_potonganTidakAbsenCtrl),
      'potongan_keterlambatan': parseCtrl(_potonganKeterlambatanCtrl),
      'potongan_absen': parseCtrl(_potonganAbsenCtrl),
      'bpjs_ketenagakerjaan': parseCtrl(_bpjsKetenagakerjaanCtrl),
      'potongan_lainnya': parseCtrl(_potonganLainnyaCtrl),
      'keterangan_potongan_lainnya': _keteranganPotonganLainnyaCtrl.text,
      'total_potongan': _totalPotongan,

      'total_gaji_diterima': _totalGajiDiterima,
      'take_home_pay': _takeHomePay,
      'saldo_jht': parseCtrl(_saldoJhtCtrl),
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
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint ?? '0',
            prefixText: 'Rp ',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                  widget.gajiToEdit == null 
                    ? 'Form Gaji ${_jenisGaji.toUpperCase()} (Slip)' 
                    : 'Edit Slip Gaji',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingMaster
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- SECTION 1: IDENTITAS SLIP ---
                          _buildSectionHeader('IDENTITAS SLIP', Icons.badge_outlined, Colors.indigo),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Jenis Gaji', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: RadioListTile<String>(
                                        value: 'bulanan',
                                        groupValue: _jenisGaji,
                                        title: const Text('Bulanan', style: TextStyle(fontSize: 14)),
                                        onChanged: (val) {
                                          setState(() => _jenisGaji = val!);
                                          _calculateAll();
                                        },
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                      ),
                                    ),
                                    Expanded(
                                      child: RadioListTile<String>(
                                        value: 'harian',
                                        groupValue: _jenisGaji,
                                        title: const Text('Harian', style: TextStyle(fontSize: 14)),
                                        onChanged: (val) {
                                          setState(() => _jenisGaji = val!);
                                          _calculateAll();
                                        },
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Tanggal Cetak', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                          const SizedBox(height: 6),
                                          InkWell(
                                            onTap: () => _selectDate(context, _tanggalCetak, (d) => _tanggalCetak = d),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(dateFormatter.format(_tanggalCetak), style: GoogleFonts.inter(fontSize: 13)),
                                                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Bulan & Tahun', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: DropdownButtonFormField<int>(
                                                  value: _periodeBulan,
                                                  isExpanded: true,
                                                  decoration: InputDecoration(filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                                                  items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                                                  onChanged: (v) => setState(() => _periodeBulan = v!),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: DropdownButtonFormField<int>(
                                                  value: _periodeTahun,
                                                  isExpanded: true,
                                                  decoration: InputDecoration(filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                                                  items: [DateTime.now().year - 1, DateTime.now().year, DateTime.now().year + 1].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                                                  onChanged: (v) => setState(() => _periodeTahun = v!),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Awal Periode', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                          const SizedBox(height: 6),
                                          InkWell(
                                            onTap: () => _selectDate(context, _awalPeriode, (d) => _awalPeriode = d),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(dateFormatter.format(_awalPeriode), style: GoogleFonts.inter(fontSize: 13)),
                                                  const Icon(Icons.calendar_month, size: 16, color: Colors.grey),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Akhir Periode', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                          const SizedBox(height: 6),
                                          InkWell(
                                            onTap: () => _selectDate(context, _akhirPeriode, (d) => _akhirPeriode = d),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(dateFormatter.format(_akhirPeriode), style: GoogleFonts.inter(fontSize: 13)),
                                                  const Icon(Icons.calendar_month, size: 16, color: Colors.grey),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Text('Cabang *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<int>(
                                  value: _selectedCabangId,
                                  decoration: InputDecoration(filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                                  items: _cabangs.map((c) => DropdownMenuItem(value: c.id, child: Text(c.namaCabang))).toList(),
                                  onChanged: _onCabangChanged,
                                  validator: (v) => v == null ? 'Wajib pilih' : null,
                                ),
                                const SizedBox(height: 12),

                                Text('Nama Karyawan *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<int>(
                                  value: _selectedKaryawanId,
                                  decoration: InputDecoration(filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                                  items: _filteredKaryawans.map((k) => DropdownMenuItem(value: k.id, child: Text(k.nama))).toList(),
                                  onChanged: _selectedCabangId == null ? null : _onKaryawanChanged,
                                  validator: (v) => v == null ? 'Wajib pilih' : null,
                                  hint: Text(_selectedCabangId == null ? 'Pilih cabang dulu' : 'Pilih karyawan'),
                                ),

                                if (_selectedKaryawan != null) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Jabatan', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                                            Text(_selectedKaryawan?.jabatan?.namaJabatan ?? '-', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Status', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                                            Text(_selectedKaryawan?.statusKaryawan?.toUpperCase() ?? '-', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                const SizedBox(height: 12),
                                Text('Jumlah Hari Kerja *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _jumlahHariKerjaCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    suffixText: 'Hari',
                                    filled: true,
                                    fillColor: AppColors.surface,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                  onChanged: (_) => _calculateAll(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // --- SECTION 2: PENDAPATAN ---
                          _buildSectionHeader('PENDAPATAN', Icons.arrow_upward_rounded, Colors.teal),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                            child: Column(
                              children: [
                                if (_jenisGaji == 'harian') ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Tarif Gaji Pokok Harian', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                                      Text(currencyFormatter.format(_tarifGajiHarian), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total Gaji Pokok', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                                    Text(currencyFormatter.format(_gajiPokokVal), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.teal.shade800)),
                                  ],
                                ),
                                const Divider(height: 20),

                                _buildNumericInput('Bonus Bulanan', _bonusBulananCtrl),
                                const SizedBox(height: 12),
                                _buildNumericInput('Tunjangan Kos', _tunjanganKosCtrl),
                                const SizedBox(height: 12),
                                _buildNumericInput('Tunjangan Kerja', _tunjanganKerjaCtrl),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    SizedBox(
                                      width: 24, height: 24,
                                      child: Checkbox(
                                        value: _isBpjsAktif,
                                        onChanged: (val) {
                                          _isBpjsAktif = val ?? false;
                                          _calculateAll();
                                        },
                                        activeColor: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Premi BPJS Aktif (+ Rp 35.000)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Sub-Section: Komponen Total Bonus
                                Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    title: Text('Komponen Total Bonus', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
                                    subtitle: Text('Akumulasi: ${currencyFormatter.format(_totalBonus)}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                                    childrenPadding: const EdgeInsets.symmetric(vertical: 8),
                                    children: [
                                      _buildNumericInput('Bonus Review', _bonusReviewCtrl),
                                      const SizedBox(height: 10),
                                      _buildNumericInput('Bonus Tgl Merah', _bonusTglMerahCtrl),
                                      const SizedBox(height: 10),
                                      _buildNumericInput('Total Kilometer', _totalKmCtrl),
                                      const SizedBox(height: 10),
                                      _buildNumericInput('Total DeepClean', _totalDeepCleanCtrl),
                                      const SizedBox(height: 10),
                                      _buildNumericInput('Total Salon', _totalSalonCtrl),
                                      const SizedBox(height: 10),
                                      _buildNumericInput('Total Tips', _totalTipsCtrl),
                                      const SizedBox(height: 10),
                                      _buildNumericInput('Total Parkir', _totalParkirCtrl),
                                      const SizedBox(height: 10),
                                      _buildNumericInput('Total Lembur', _totalLemburCtrl),
                                      const SizedBox(height: 10),
                                      _buildNumericInput('Total Uang Makan', _totalUangMakanCtrl),
                                      const SizedBox(height: 10),
                                      _buildNumericInput('Bonus Lainnya', _totalBonusLainnyaCtrl),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // --- SECTION 3: POTONGAN ---
                          _buildSectionHeader('POTONGAN', Icons.arrow_downward_rounded, Colors.red),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                            child: Column(
                              children: [
                                _buildNumericInput('Cashbon', _kasbonCtrl),
                                const SizedBox(height: 10),
                                _buildNumericInput('Potongan Tidak Absen', _potonganTidakAbsenCtrl),
                                const SizedBox(height: 10),
                                _buildNumericInput('Potongan Keterlambatan', _potonganKeterlambatanCtrl),
                                const SizedBox(height: 10),
                                _buildNumericInput('Potongan Absen', _potonganAbsenCtrl),
                                const SizedBox(height: 10),
                                _buildNumericInput('BPJS Ketenagakerjaan', _bpjsKetenagakerjaanCtrl),
                                const SizedBox(height: 10),
                                _buildNumericInput('Potongan Lainnya', _potonganLainnyaCtrl),
                                const SizedBox(height: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Keterangan Potongan Lainnya', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _keteranganPotonganLainnyaCtrl,
                                      decoration: InputDecoration(
                                        hintText: 'Tulis alasan potongan...',
                                        filled: true,
                                        fillColor: AppColors.surface,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total Potongan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
                                    Text('- ${currencyFormatter.format(_totalPotongan)}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // --- SECTION 4: HASIL AKHIR ---
                          _buildSectionHeader('HASIL AKHIR (TAKE HOME PAY)', Icons.account_balance_wallet_rounded, Colors.indigo),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Pendapatan Kotor (Gaji Diterima)', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark)),
                                    Text(currencyFormatter.format(_totalGajiDiterima), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total Potongan', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark)),
                                    Text('- ${currencyFormatter.format(_totalPotongan)}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red)),
                                  ],
                                ),
                                const Divider(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [Colors.indigo.shade600, Colors.indigo.shade900]),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('TAKE HOME PAY', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                                      Text(currencyFormatter.format(_takeHomePay), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.yellowAccent)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildNumericInput('SALDO JHT (INFORMASI)', _saldoJhtCtrl),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),

                          // --- BUTTONS ---
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text('Batal', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveGaji,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : Text('Simpan Slip Gaji', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
      ],
    );
  }
}

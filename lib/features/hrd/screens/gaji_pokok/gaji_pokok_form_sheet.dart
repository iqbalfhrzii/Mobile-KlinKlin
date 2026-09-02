import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';

class GajiPokokFormSheet extends StatefulWidget {
  final GajiPokokModel? gajiPokok;
  final List<CabangModel>? cabangs;
  final List<JabatanModel>? jabatans;

  const GajiPokokFormSheet({
    super.key,
    this.gajiPokok,
    this.cabangs,
    this.jabatans,
  });

  static Future<bool?> show(
    BuildContext context, {
    GajiPokokModel? gajiPokok,
    List<CabangModel>? cabangs,
    List<JabatanModel>? jabatans,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GajiPokokFormSheet(
        gajiPokok: gajiPokok,
        cabangs: cabangs,
        jabatans: jabatans,
      ),
    );
  }

  @override
  State<GajiPokokFormSheet> createState() => _GajiPokokFormSheetState();
}

class _GajiPokokFormSheetState extends State<GajiPokokFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final HrdService _hrdService = HrdService();

  late TextEditingController _gajiPokokCtrl;
  late TextEditingController _bonusBulananCtrl;
  late TextEditingController _tunjanganKosCtrl;
  late TextEditingController _tunjanganKerjaCtrl;
  late TextEditingController _gajiPokokHarianCtrl;

  int? _selectedCabang;
  int? _selectedJabatan;
  String _status = 'TETAP';

  List<CabangModel> _cabangs = [];
  List<JabatanModel> _jabatans = [];

  bool _isLoading = false;
  bool _isLoadingRef = true;
  bool _isBpjsAktif = true;

  final List<String> _statusOptions = [
    'FREELANCE',
    'VENDOR',
    'TRAINING',
    'SEMI',
    'TETAP',
    'TETAP KOOR',
  ];

  @override
  void initState() {
    super.initState();
    _gajiPokokCtrl = TextEditingController(text: widget.gajiPokok != null ? widget.gajiPokok!.gajiPokok.toString() : '');
    _bonusBulananCtrl = TextEditingController(text: widget.gajiPokok != null ? widget.gajiPokok!.bonusBulanan.toString() : '');
    _tunjanganKosCtrl = TextEditingController(text: widget.gajiPokok != null ? widget.gajiPokok!.tunjanganKos.toString() : '');
    _tunjanganKerjaCtrl = TextEditingController(text: widget.gajiPokok != null ? widget.gajiPokok!.tunjanganKerja.toString() : '');
    _gajiPokokHarianCtrl = TextEditingController(text: widget.gajiPokok != null ? widget.gajiPokok!.gajiPokokHarian.toString() : '');

    _isBpjsAktif = widget.gajiPokok == null ? true : (widget.gajiPokok!.premiBpjs > 0);

    _selectedCabang = widget.gajiPokok?.cabangId;
    _selectedJabatan = widget.gajiPokok?.jabatanId;

    if (widget.gajiPokok != null) {
      final statusVal = widget.gajiPokok!.statusKaryawan.toUpperCase();
      _status = _statusOptions.contains(statusVal) ? statusVal : 'TETAP';
    }

    if (widget.cabangs != null && widget.cabangs!.isNotEmpty && widget.jabatans != null && widget.jabatans!.isNotEmpty) {
      _cabangs = widget.cabangs!;
      _jabatans = widget.jabatans!;
      if (_selectedCabang == null && _cabangs.isNotEmpty) _selectedCabang = _cabangs.first.id;
      if (_selectedJabatan == null && _jabatans.isNotEmpty) _selectedJabatan = _jabatans.first.id;
      _isLoadingRef = false;
    } else {
      _fetchRefs();
    }
  }

  Future<void> _fetchRefs() async {
    try {
      final futures = await Future.wait([
        _hrdService.fetchCabang(),
        _hrdService.fetchJabatan(),
      ]);

      if (mounted) {
        setState(() {
          _cabangs = futures[0] as List<CabangModel>;
          _jabatans = futures[1] as List<JabatanModel>;
          if (_selectedCabang == null && _cabangs.isNotEmpty) _selectedCabang = _cabangs.first.id;
          if (_selectedJabatan == null && _jabatans.isNotEmpty) _selectedJabatan = _jabatans.first.id;
          _isLoadingRef = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRef = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat referensi: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _gajiPokokCtrl.dispose();
    _bonusBulananCtrl.dispose();
    _tunjanganKosCtrl.dispose();
    _tunjanganKerjaCtrl.dispose();
    _gajiPokokHarianCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCabang == null || _selectedJabatan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih Cabang dan Jabatan terlebih dahulu'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = {
        'cabang_id': _selectedCabang,
        'jabatan_id': _selectedJabatan,
        'status_karyawan': _status,
        'gaji_pokok': int.tryParse(_gajiPokokCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        'bonus_bulanan': int.tryParse(_bonusBulananCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        'tunjangan_kos': int.tryParse(_tunjanganKosCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        'tunjangan_kerja': int.tryParse(_tunjanganKerjaCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        'gaji_pokok_harian': int.tryParse(_gajiPokokHarianCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        'premi_bpjs': _isBpjsAktif ? 35000 : 0,
      };

      if (widget.gajiPokok == null) {
        await _hrdService.createGajiPokok(data);
      } else {
        await _hrdService.updateGajiPokok(widget.gajiPokok!.id, data);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.gajiPokok == null
                  ? 'Standar gaji pokok berhasil ditambahkan'
                  : 'Standar gaji pokok berhasil diperbarui',
            ),
            backgroundColor: const Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString().replaceFirst('Exception: ', '');
        if (e is DioException && e.response?.data != null) {
          final data = e.response!.data;
          if (data is Map) {
            if (data['errors'] != null && data['errors'] is Map) {
              final errors = data['errors'] as Map;
              if (errors.isNotEmpty) {
                errMsg = errors.values.first.first.toString();
              }
            } else if (data['message'] != null) {
              errMsg = data['message'].toString();
            }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.gajiPokok != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle pill
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isEdit ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_note_rounded : Icons.monetization_on_rounded,
                      color: isEdit ? const Color(0xFF2563EB) : const Color(0xFF059669),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Standar Gaji Pokok' : 'Tambah Standar Gaji Pokok',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEdit ? 'Sesuaikan besaran standar gaji per jabatan & status' : 'Tentukan standar kompensasi dan tunjangan',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 14),

              // Form Body
              _isLoadingRef
                  ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                  : Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Row: Cabang & Jabatan
                            Row(
                              children: [
                                // Cabang
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Cabang',
                                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: _selectedCabang,
                                            isExpanded: true,
                                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                                            hint: Text('Cabang', style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8))),
                                            items: _cabangs.map((c) {
                                              return DropdownMenuItem<int>(
                                                value: c.id,
                                                child: Text(
                                                  c.namaCabang,
                                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (val) => setState(() => _selectedCabang = val),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Jabatan
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Jabatan',
                                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: _selectedJabatan,
                                            isExpanded: true,
                                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                                            hint: Text('Jabatan', style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8))),
                                            items: _jabatans.map((j) {
                                              return DropdownMenuItem<int>(
                                                value: j.id,
                                                child: Text(
                                                  j.namaJabatan,
                                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (val) => setState(() => _selectedJabatan = val),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // 2. Status Karyawan
                            Text(
                              'Status Karyawan',
                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _status,
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                                  items: _statusOptions.map((s) {
                                    return DropdownMenuItem<String>(
                                      value: s,
                                      child: Text(
                                        s,
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _status = val);
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 14),

                            // 3. Komponen Gaji (Gaji Pokok Bulanan & Harian)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMoneyField(
                                    label: 'Gaji Pokok (Bulan)',
                                    controller: _gajiPokokCtrl,
                                    hint: '0',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMoneyField(
                                    label: 'Gaji Pokok Harian',
                                    controller: _gajiPokokHarianCtrl,
                                    hint: '0',
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // 4. Bonus Bulanan & Tunjangan Kos
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMoneyField(
                                    label: 'Bonus Bulanan',
                                    controller: _bonusBulananCtrl,
                                    hint: '0',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMoneyField(
                                    label: 'Tunjangan Kos',
                                    controller: _tunjanganKosCtrl,
                                    hint: '0',
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // 5. Tunjangan Kerja
                            _buildMoneyField(
                              label: 'Tunjangan Kerja',
                              controller: _tunjanganKerjaCtrl,
                              hint: '0',
                            ),

                            const SizedBox(height: 16),

                            // 6. Checkbox Premi BPJS
                            InkWell(
                              onTap: () => setState(() => _isBpjsAktif = !_isBpjsAktif),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: _isBpjsAktif ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _isBpjsAktif ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _isBpjsAktif,
                                      activeColor: const Color(0xFF16A34A),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      onChanged: (val) => setState(() => _isBpjsAktif = val ?? false),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Premi BPJS Ketenagakerjaan Aktif',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '+ Rp 35.000 / bulan',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              color: const Color(0xFF16A34A),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),

              const SizedBox(height: 16),

              // Actions: Batal & Simpan
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading || _isLoadingRef ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  isEdit ? 'Simpan Perubahan' : 'Tambah Standar Gaji',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoneyField({
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 6, top: 12, bottom: 12),
              child: Text(
                'Rp',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}

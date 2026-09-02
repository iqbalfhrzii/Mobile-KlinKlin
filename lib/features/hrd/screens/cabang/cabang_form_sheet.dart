import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'package:geolocator/geolocator.dart';

class CabangFormSheet extends StatefulWidget {
  final CabangModel? cabang;

  const CabangFormSheet({super.key, this.cabang});

  static Future<bool?> show(BuildContext context, {CabangModel? cabang}) {
    return showModalBottomSheet<bool>(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CabangFormSheet(cabang: cabang),
    );
  }

  @override
  State<CabangFormSheet> createState() => _CabangFormSheetState();
}

class _CabangFormSheetState extends State<CabangFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final HrdService _hrdService = HrdService();

  late TextEditingController _namaCtrl;
  late TextEditingController _kodeCtrl;
  late TextEditingController _alamatCtrl;
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;
  late TextEditingController _radiusCtrl;
  late TextEditingController _jamMasukCtrl;
  late TextEditingController _toleransiCtrl;
  late TextEditingController _jamPulangCtrl;
  late TextEditingController _targetOmzetCtrl;
  String _status = 'aktif';
  bool _isLoading = false;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController(text: widget.cabang?.namaCabang);
    _kodeCtrl = TextEditingController(text: widget.cabang?.kodeCabang);
    _alamatCtrl = TextEditingController(text: widget.cabang?.alamat);
    _latCtrl = TextEditingController(text: widget.cabang?.latitude?.toString() ?? '');
    _lngCtrl = TextEditingController(text: widget.cabang?.longitude?.toString() ?? '');
    _radiusCtrl = TextEditingController(text: widget.cabang?.radiusAbsensiMeter?.toString() ?? (widget.cabang == null ? '100' : ''));
    _jamMasukCtrl = TextEditingController(text: widget.cabang?.jamMasuk ?? '08:00');
    _toleransiCtrl = TextEditingController(text: widget.cabang?.toleransiTelatMenit?.toString() ?? '15');
    _jamPulangCtrl = TextEditingController(text: widget.cabang?.jamPulang ?? '17:00');
    _targetOmzetCtrl = TextEditingController(text: widget.cabang?.targetOmzet?.toString() ?? '');

    if (widget.cabang != null) {
      _status = widget.cabang!.status;
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _kodeCtrl.dispose();
    _alamatCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radiusCtrl.dispose();
    _jamMasukCtrl.dispose();
    _toleransiCtrl.dispose();
    _jamPulangCtrl.dispose();
    _targetOmzetCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('GPS belum aktif. Silakan aktifkan lokasi.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Izin lokasi ditolak.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi ditolak secara permanen. Silakan atur di Pengaturan HP.');
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _latCtrl.text = position.latitude.toString();
        _lngCtrl.text = position.longitude.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lokasi kantor berhasil diambil.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    TimeOfDay initialTime = const TimeOfDay(hour: 8, minute: 0);
    if (controller.text.isNotEmpty && controller.text.contains(':')) {
      final parts = controller.text.split(':');
      if (parts.length >= 2) {
        initialTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 8,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      final String formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        controller.text = formattedTime;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_latCtrl.text.isEmpty || _lngCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan ambil titik lokasi kantor atau isi koordinat.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (_radiusCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Radius absensi wajib diisi.'), backgroundColor: Color(0xFFDC2626)),
      );
      return;
    }

    int? radius = int.tryParse(_radiusCtrl.text);
    if (radius == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Radius harus berupa angka bulat.'), backgroundColor: Color(0xFFDC2626)),
      );
      return;
    }

    if (radius < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Radius absensi minimal 20 meter.'), backgroundColor: Color(0xFFDC2626)),
      );
      return;
    }

    if (radius > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Radius absensi maksimal 1.000 meter.'), backgroundColor: Color(0xFFDC2626)),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = {
        'nama_cabang': _namaCtrl.text.trim(),
        'kode_cabang': _kodeCtrl.text.trim().toUpperCase(),
        'alamat': _alamatCtrl.text.trim(),
        'status': _status,
        'latitude': _latCtrl.text.trim(),
        'longitude': _lngCtrl.text.trim(),
        'radius_absensi_meter': _radiusCtrl.text.trim(),
        'jam_masuk': _jamMasukCtrl.text.trim(),
        'toleransi_telat_menit': _toleransiCtrl.text.trim(),
        'jam_pulang': _jamPulangCtrl.text.trim(),
        'target_omzet': _targetOmzetCtrl.text.trim().isEmpty ? null : _targetOmzetCtrl.text.trim(),
      };

      if (widget.cabang == null) {
        await _hrdService.createCabang(data);
      } else {
        await _hrdService.updateCabang(widget.cabang!.id, data);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.cabang == null ? 'Cabang berhasil ditambahkan' : 'Cabang berhasil diperbarui'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.cabang != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 12, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 16 : 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isEdit ? Icons.edit_location_alt_rounded : Icons.add_business_rounded,
                    color: const Color(0xFF2563EB),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Edit Cabang' : 'Tambah Cabang',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        isEdit ? 'Perbarui informasi operasional cabang' : 'Daftarkan cabang operasional baru',
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
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  tooltip: 'Tutup',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Form Body
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Nama Cabang
                    _buildLabel('Nama Cabang *'),
                    TextFormField(
                      controller: _namaCtrl,
                      decoration: _inputDecoration(
                        hint: 'Contoh: Kantor Pusat, Surabaya',
                        prefixIcon: Icons.business_rounded,
                      ),
                      style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w500),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Nama cabang wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    // 2. Kode Cabang
                    _buildLabel('Kode cabang (Singkatan 3 Huruf, misal: SBY, BPN)'),
                    TextFormField(
                      controller: _kodeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _inputDecoration(
                        hint: 'Contoh: HQ, SBY, MLG',
                        prefixIcon: Icons.badge_outlined,
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Alamat
                    _buildLabel('Alamat Cabang'),
                    TextFormField(
                      controller: _alamatCtrl,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        hint: 'Masukkan alamat lengkap kantor cabang...',
                        prefixIcon: Icons.location_on_outlined,
                      ),
                      style: GoogleFonts.inter(fontSize: 13.5),
                    ),
                    const SizedBox(height: 16),

                    // 4. Target Omzet
                    _buildLabel('Target Omzet (Opsional)'),
                    TextFormField(
                      controller: _targetOmzetCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        hint: '0.0',
                        prefixIcon: Icons.monetization_on_outlined,
                      ),
                      style: GoogleFonts.inter(fontSize: 13.5),
                    ),
                    const SizedBox(height: 20),

                    // 5. Lokasi Absensi Cleaner Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.gps_fixed_rounded, size: 18, color: Color(0xFF2563EB)),
                              const SizedBox(width: 8),
                              Text(
                                'Lokasi Absensi Cleaner',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Ambil Lokasi Button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isGettingLocation ? null : _getLocation,
                              icon: _isGettingLocation
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                                    )
                                  : const Icon(Icons.my_location_rounded, size: 18, color: Color(0xFF2563EB)),
                              label: Text(
                                _isGettingLocation ? 'Mengambil GPS...' : 'Ambil Lokasi Kantor Saat Ini',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF93C5FD), width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Latitude & Longitude Row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSmallLabel('Latitude'),
                                    TextFormField(
                                      controller: _latCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                      decoration: _compactInputDecoration(hint: 'Mis. -7.98'),
                                      style: GoogleFonts.inter(fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSmallLabel('Longitude'),
                                    TextFormField(
                                      controller: _lngCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                      decoration: _compactInputDecoration(hint: 'Mis. 112.63'),
                                      style: GoogleFonts.inter(fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Radius
                          _buildSmallLabel('Radius Absensi (meter)'),
                          TextFormField(
                            controller: _radiusCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _compactInputDecoration(hint: '100'),
                            style: GoogleFonts.inter(fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 6. Pengaturan Absensi Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFFD97706)),
                              const SizedBox(width: 8),
                              Text(
                                'Pengaturan Absensi',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 3 Column: Jam Masuk, Toleransi, Jam Pulang
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSmallLabel('Jam Masuk'),
                                    InkWell(
                                      onTap: () => _selectTime(context, _jamMasukCtrl),
                                      child: IgnorePointer(
                                        child: TextFormField(
                                          controller: _jamMasukCtrl,
                                          textAlign: TextAlign.center,
                                          decoration: _compactInputDecoration(
                                            hint: '08:00',
                                            suffixIcon: Icons.schedule_rounded,
                                          ),
                                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSmallLabel('Toleransi (Mnt)'),
                                    TextFormField(
                                      controller: _toleransiCtrl,
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      decoration: _compactInputDecoration(hint: '15'),
                                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSmallLabel('Jam Pulang'),
                                    InkWell(
                                      onTap: () => _selectTime(context, _jamPulangCtrl),
                                      child: IgnorePointer(
                                        child: TextFormField(
                                          controller: _jamPulangCtrl,
                                          textAlign: TextAlign.center,
                                          decoration: _compactInputDecoration(
                                            hint: '17:00',
                                            suffixIcon: Icons.schedule_rounded,
                                          ),
                                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 7. Status Cabang
                    _buildLabel('Status Cabang'),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _status = 'aktif'),
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _status == 'aktif' ? const Color(0xFF059669) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 16,
                                      color: _status == 'aktif' ? Colors.white : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Aktif',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _status == 'aktif' ? Colors.white : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _status = 'nonaktif'),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _status == 'nonaktif' ? const Color(0xFFDC2626) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cancel_rounded,
                                      size: 16,
                                      color: _status == 'nonaktif' ? Colors.white : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Nonaktif',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _status == 'nonaktif' ? Colors.white : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Submit & Cancel Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              'Batal',
                              style: GoogleFonts.inter(
                                fontSize: 14,
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
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    isEdit ? 'Simpan Perubahan' : 'Tambah Cabang',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildSmallLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: const Color(0xFF64748B), size: 20) : null,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }

  InputDecoration _compactInputDecoration({required String hint, IconData? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12),
      suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: const Color(0xFF64748B), size: 16) : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }
}

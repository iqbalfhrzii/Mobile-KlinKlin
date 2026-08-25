import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'package:geolocator/geolocator.dart';

class CabangFormScreen extends StatefulWidget {
  final CabangModel? cabang;
  const CabangFormScreen({super.key, this.cabang});

  @override
  State<CabangFormScreen> createState() => _CabangFormScreenState();
}

class _CabangFormScreenState extends State<CabangFormScreen> {
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
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('GPS belum aktif.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Izin lokasi ditolak.');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi ditolak secara permanen. Silakan atur di Setting.');
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
          const SnackBar(content: Text('Lokasi kantor berhasil diambil.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
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
    
    // Validations
    if (_latCtrl.text.isEmpty || _lngCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan ambil titik lokasi kantor otomatis atau isi secara manual.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_radiusCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Radius absensi wajib diisi.'), backgroundColor: Colors.red),
      );
      return;
    }

    int? radius = int.tryParse(_radiusCtrl.text);
    if (radius == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Radius harus berupa angka bulat.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (radius < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Radius absensi minimal 20 meter.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (radius > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Radius absensi maksimal 1.000 meter.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = {
        'nama_cabang': _namaCtrl.text,
        'kode_cabang': _kodeCtrl.text.toUpperCase(),
        'alamat': _alamatCtrl.text,
        'status': _status,
        'latitude': _latCtrl.text,
        'longitude': _lngCtrl.text,
        'radius_absensi_meter': _radiusCtrl.text,
        'jam_masuk': _jamMasukCtrl.text,
        'toleransi_telat_menit': _toleransiCtrl.text,
        'jam_pulang': _jamPulangCtrl.text,
        'target_omzet': _targetOmzetCtrl.text.isEmpty ? null : _targetOmzetCtrl.text,
      };

      if (widget.cabang == null) {
        await _hrdService.createCabang(data);
      } else {
        await _hrdService.updateCabang(widget.cabang!.id, data);
      }
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _isLoading = false);
      }
    }
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
                  widget.cabang == null ? 'Tambah Cabang' : 'Edit Cabang',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField(
                      label: 'Nama Cabang *',
                      controller: _namaCtrl,
                      hint: 'Masukkan nama cabang',
                      validator: (val) => val == null || val.isEmpty ? 'Nama cabang wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      label: 'Kode Cabang (Singkatan 3 Huruf, misal: SBY, BPN)',
                      controller: _kodeCtrl,
                      hint: 'HQ, SBY, MLG...',
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      label: 'Alamat',
                      controller: _alamatCtrl,
                      hint: 'Masukkan alamat cabang',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      label: 'Target Omzet (Opsional)',
                      controller: _targetOmzetCtrl,
                      hint: 'Masukkan target pendapatan',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),
                    Text('Lokasi Absensi Cleaner', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _getLocation,
                        icon: const Icon(Icons.location_on, color: AppColors.primary),
                        label: Text('Ambil Lokasi Kantor Saat Ini', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: 'Latitude',
                            controller: _latCtrl,
                            hint: 'Mis. -7.98',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            label: 'Longitude',
                            controller: _lngCtrl,
                            hint: 'Mis. 112.63',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      label: 'Radius Absensi (meter)',
                      controller: _radiusCtrl,
                      hint: 'Mis. 100',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),
                    Text('Pengaturan Absensi', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectTime(context, _jamMasukCtrl),
                            child: AbsorbPointer(
                              child: _buildField(
                                label: 'Jam Masuk',
                                controller: _jamMasukCtrl,
                                hint: '08:00',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            label: 'Toleransi (Menit)',
                            controller: _toleransiCtrl,
                            hint: '15',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectTime(context, _jamPulangCtrl),
                            child: AbsorbPointer(
                              child: _buildField(
                                label: 'Jam Pulang',
                                controller: _jamPulangCtrl,
                                hint: '17:00',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Status', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'aktif', child: Text('Aktif')),
                        DropdownMenuItem(value: 'nonaktif', child: Text('Nonaktif')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _status = val);
                      },
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                            : Text('Simpan', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
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

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          keyboardType: keyboardType,
          readOnly: readOnly,
          style: GoogleFonts.inter(fontSize: 14, color: readOnly ? AppColors.textMuted : AppColors.textDark),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}

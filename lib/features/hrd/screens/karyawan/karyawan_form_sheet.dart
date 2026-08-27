import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/api/api_client.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import '../../../../../core/utils/image_compress_helper.dart';

class KaryawanFormSheet extends StatefulWidget {
  final KaryawanModel? karyawan;
  final List<CabangModel>? cabangs;
  final List<JabatanModel>? jabatans;

  const KaryawanFormSheet({
    super.key,
    this.karyawan,
    this.cabangs,
    this.jabatans,
  });

  static Future<bool?> show(
    BuildContext context, {
    KaryawanModel? karyawan,
    List<CabangModel>? cabangs,
    List<JabatanModel>? jabatans,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => KaryawanFormSheet(
        karyawan: karyawan,
        cabangs: cabangs,
        jabatans: jabatans,
      ),
    );
  }

  @override
  State<KaryawanFormSheet> createState() => _KaryawanFormSheetState();
}

class _KaryawanFormSheetState extends State<KaryawanFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final HrdService _hrdService = HrdService();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _namaCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _pinCtrl;
  late TextEditingController _noWaCtrl;
  late TextEditingController _namaBankCtrl;
  late TextEditingController _noRekeningCtrl;

  int? _selectedCabang;
  int? _selectedJabatan;
  String _status = 'aktif';
  String _statusKaryawan = 'Tetap';

  String? _selectedPhotoPath;
  String? _currentPhotoUrl;
  bool _removeExistingPhoto = false;

  List<CabangModel> _cabangs = [];
  List<JabatanModel> _jabatans = [];

  bool _isLoading = false;
  bool _isLoadingRef = false;
  bool _obscurePin = true;

  // Status Pegawai strictly matching web + koor
  static const List<Map<String, String>> _statusPegawaiOptions = [
    {'value': 'Tetap', 'label': 'Tetap'},
    {'value': 'Tetap Koor', 'label': 'Tetap Koor (Cleaner Koor)'},
    {'value': 'Kontrak', 'label': 'Kontrak'},
    {'value': 'Training', 'label': 'Training'},
  ];

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController(text: widget.karyawan?.nama);
    _emailCtrl = TextEditingController(text: widget.karyawan?.email);
    _pinCtrl = TextEditingController();
    _noWaCtrl = TextEditingController(text: widget.karyawan?.noWa);
    _namaBankCtrl = TextEditingController(text: widget.karyawan?.namaBank);
    _noRekeningCtrl = TextEditingController(text: widget.karyawan?.noRekening);

    _selectedCabang = widget.karyawan?.cabangId;
    _selectedJabatan = widget.karyawan?.jabatanId;
    _currentPhotoUrl = widget.karyawan?.fotoProfil;

    if (widget.karyawan != null) {
      final statusVal = widget.karyawan!.status.toLowerCase();
      _status = ['aktif', 'nonaktif', 'pending'].contains(statusVal) ? statusVal : 'aktif';

      if (widget.karyawan!.statusKaryawan != null && widget.karyawan!.statusKaryawan!.isNotEmpty) {
        final statusKar = widget.karyawan!.statusKaryawan!;
        final found = _statusPegawaiOptions.firstWhere(
          (opt) =>
              opt['value']!.toLowerCase() == statusKar.toLowerCase() ||
              (statusKar.toLowerCase().contains('koor') && opt['value'] == 'Tetap Koor'),
          orElse: () => _statusPegawaiOptions.first,
        );
        _statusKaryawan = found['value']!;
      } else {
        _statusKaryawan = 'Tetap';
      }
    } else {
      _statusKaryawan = 'Tetap';
    }

    if (widget.cabangs != null &&
        widget.cabangs!.isNotEmpty &&
        widget.jabatans != null &&
        widget.jabatans!.isNotEmpty) {
      _cabangs = widget.cabangs!;
      _jabatans = widget.jabatans!;
      _initDefaultSelections();
    } else {
      _fetchRefs();
    }
  }

  void _initDefaultSelections() {
    if (_selectedCabang == null && _cabangs.isNotEmpty) {
      _selectedCabang = _cabangs.first.id;
    }
    final available = _jabatans.where((j) => j.cabangId == _selectedCabang).toList();
    if (available.isNotEmpty && !available.any((j) => j.id == _selectedJabatan)) {
      _selectedJabatan = available.first.id;
    }
  }

  Future<void> _fetchRefs() async {
    setState(() => _isLoadingRef = true);
    try {
      final cabangs = await _hrdService.fetchCabang();
      final jabatans = await _hrdService.fetchJabatan();
      if (mounted) {
        setState(() {
          _cabangs = cabangs;
          _jabatans = jabatans;
          _initDefaultSelections();
          _isLoadingRef = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRef = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat referensi cabang & jabatan: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _pinCtrl.dispose();
    _noWaCtrl.dispose();
    _namaBankCtrl.dispose();
    _noRekeningCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        final compressed = await ImageCompressHelper.compressXFileIfNeeded(picked);
        if (compressed != null) {
          setState(() {
            _selectedPhotoPath = compressed.path;
            _removeExistingPhoto = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih foto: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pilih Foto Profil',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              title: Text('Ambil Foto Kamera', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_rounded, color: Color(0xFF475569), size: 20),
              ),
              title: Text('Pilih dari Galeri', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_selectedPhotoPath != null || (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty && !_removeExistingPhoto))
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                ),
                title: Text('Hapus Foto', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFFDC2626))),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedPhotoPath = null;
                    _removeExistingPhoto = true;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCabang == null || _selectedJabatan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih cabang dan jabatan terlebih dahulu'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = <String, dynamic>{
        'nama': _namaCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'no_wa': _noWaCtrl.text.trim(),
        'cabang_id': _selectedCabang,
        'jabatan_id': _selectedJabatan,
        'status': _status,
        'status_karyawan': _statusKaryawan,
        'nama_bank': _namaBankCtrl.text.trim().isEmpty ? null : _namaBankCtrl.text.trim(),
        'no_rekening': _noRekeningCtrl.text.trim().isEmpty ? null : _noRekeningCtrl.text.trim(),
      };

      int karyawanId;
      if (widget.karyawan == null) {
        data['pin'] = _pinCtrl.text.trim().isNotEmpty ? _pinCtrl.text.trim() : '123456';
        final newKaryawan = await _hrdService.createKaryawan(data);
        karyawanId = newKaryawan.id;
      } else {
        if (_pinCtrl.text.trim().isNotEmpty) {
          data['pin'] = _pinCtrl.text.trim();
        }
        final updatedKaryawan = await _hrdService.updateKaryawan(widget.karyawan!.id, data);
        karyawanId = updatedKaryawan.id;
      }

      // If photo was selected, upload it
      if (_selectedPhotoPath != null) {
        try {
          await _hrdService.updateKaryawanFoto(karyawanId, _selectedPhotoPath!);
        } catch (photoErr) {
          // Log or silently ignore non-critical photo failure if main data saved
          debugPrint('Gagal upload foto karyawan: $photoErr');
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString();
        if (e is DioException && e.response?.data != null) {
          final resData = e.response!.data;
          if (resData is Map) {
            if (resData['errors'] != null && resData['errors'] is Map) {
              final errors = resData['errors'] as Map;
              if (errors.isNotEmpty) {
                errMsg = errors.values.first.first.toString();
              }
            } else if (resData['message'] != null) {
              errMsg = resData['message'].toString();
            } else {
              errMsg = resData.toString();
            }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.karyawan != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final availableJabatans = _jabatans.where((j) => j.cabangId == _selectedCabang).toList();

    // Ensure selected jabatan is valid for current cabang
    if (availableJabatans.isNotEmpty && !availableJabatans.any((j) => j.id == _selectedJabatan)) {
      _selectedJabatan = availableJabatans.first.id;
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header modal
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isEdit ? Icons.person_outline_rounded : Icons.person_add_alt_1_rounded,
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
                          isEdit ? 'Edit Karyawan' : 'Tambah Karyawan Baru',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEdit
                              ? 'Kelola data identitas dan penempatan karyawan'
                              : 'Lengkapi identitas dan akses cabang karyawan',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Form Content (Scrollable)
            Expanded(
              child: _isLoadingRef
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Cabang & Jabatan (Side-by-side)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Cabang
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Cabang *',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF334155),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: _selectedCabang,
                                            isExpanded: true,
                                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                                            items: _cabangs.map((c) => DropdownMenuItem(
                                              value: c.id,
                                              child: Text(
                                                c.namaCabang,
                                                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            )).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  _selectedCabang = val;
                                                  final newJabs = _jabatans.where((j) => j.cabangId == val).toList();
                                                  if (newJabs.isNotEmpty) {
                                                    _selectedJabatan = newJabs.first.id;
                                                  } else {
                                                    _selectedJabatan = null;
                                                  }
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Jabatan
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Jabatan *',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF334155),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: _selectedJabatan,
                                            isExpanded: true,
                                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                                            hint: Text(
                                              availableJabatans.isEmpty ? 'Tidak ada jabatan' : 'Pilih Jabatan',
                                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                                            ),
                                            items: availableJabatans.map((j) => DropdownMenuItem(
                                              value: j.id,
                                              child: Text(
                                                j.namaJabatan,
                                                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            )).toList(),
                                            onChanged: availableJabatans.isEmpty ? null : (val) {
                                              if (val != null) setState(() => _selectedJabatan = val);
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // 2. Nama Lengkap
                            _buildTextField(
                              label: 'Nama Lengkap *',
                              controller: _namaCtrl,
                              hint: 'Contoh: Aminuddin Ghufron',
                              prefixIcon: Icons.person_outline_rounded,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
                            ),

                            const SizedBox(height: 14),

                            // 3. Email
                            _buildTextField(
                              label: 'Email *',
                              controller: _emailCtrl,
                              hint: 'contoh@klinklin.com',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                                if (!v.contains('@')) return 'Format email tidak valid';
                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            // 4. PIN & No. WA (Side-by-side)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // PIN
                                Expanded(
                                  child: _buildTextField(
                                    label: isEdit ? 'PIN (Opsional)' : 'PIN Keamanan',
                                    controller: _pinCtrl,
                                    hint: isEdit ? 'Biarkan kosong' : 'Default: 123456',
                                    prefixIcon: Icons.lock_outline_rounded,
                                    obscureText: _obscurePin,
                                    keyboardType: TextInputType.number,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                        size: 18,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                      onPressed: () => setState(() => _obscurePin = !_obscurePin),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // No. WA
                                Expanded(
                                  child: _buildTextField(
                                    label: 'No. WhatsApp',
                                    controller: _noWaCtrl,
                                    hint: '08123456789',
                                    prefixIcon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // 5. Foto Profil & Nama Bank (Side-by-side)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Foto Profil Picker
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Foto Profil',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF334155),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      InkWell(
                                        onTap: _showImageSourcePicker,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          height: 48,
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _selectedPhotoPath != null
                                                  ? const Color(0xFF2563EB)
                                                  : const Color(0xFFCBD5E1),
                                              width: _selectedPhotoPath != null ? 1.4 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              _buildPhotoThumbnail(),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _selectedPhotoPath != null
                                                      ? 'Foto dipilih'
                                                      : (!_removeExistingPhoto && _currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty)
                                                          ? 'Ubah foto'
                                                          : 'Pilih foto...',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    fontWeight: _selectedPhotoPath != null ? FontWeight.w600 : FontWeight.normal,
                                                    color: _selectedPhotoPath != null
                                                        ? const Color(0xFF2563EB)
                                                        : const Color(0xFF64748B),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Icon(
                                                _selectedPhotoPath != null ? Icons.check_circle_rounded : Icons.photo_camera_outlined,
                                                size: 18,
                                                color: _selectedPhotoPath != null ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Nama Bank
                                Expanded(
                                  child: _buildTextField(
                                    label: 'Nama Bank',
                                    controller: _namaBankCtrl,
                                    hint: 'BCA / BRI / Mandiri',
                                    prefixIcon: Icons.account_balance_outlined,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // 6. No. Rekening & Status Pegawai (Side-by-side)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // No. Rekening
                                Expanded(
                                  child: _buildTextField(
                                    label: 'No. Rekening',
                                    controller: _noRekeningCtrl,
                                    hint: '1234567890',
                                    prefixIcon: Icons.credit_card_outlined,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Status Pegawai
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Status Pegawai *',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF334155),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _statusKaryawan,
                                            isExpanded: true,
                                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                                            items: _statusPegawaiOptions.map((opt) => DropdownMenuItem(
                                              value: opt['value'],
                                              child: Text(
                                                opt['label']!,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: opt['value'] == 'Tetap Koor' ? FontWeight.bold : FontWeight.w500,
                                                  color: opt['value'] == 'Tetap Koor' ? const Color(0xFFD97706) : const Color(0xFF0F172A),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            )).toList(),
                                            onChanged: (val) {
                                              if (val != null) setState(() => _statusKaryawan = val);
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // 7. Status Akun
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status Akun *',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _status,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'aktif',
                                          child: Row(
                                            children: [
                                              Icon(Icons.circle, color: Color(0xFF16A34A), size: 10),
                                              SizedBox(width: 8),
                                              Text('Aktif', style: TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'nonaktif',
                                          child: Row(
                                            children: [
                                              Icon(Icons.circle, color: Color(0xFFDC2626), size: 10),
                                              SizedBox(width: 8),
                                              Text('Nonaktif', style: TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'pending',
                                          child: Row(
                                            children: [
                                              Icon(Icons.circle, color: Color(0xFFD97706), size: 10),
                                              SizedBox(width: 8),
                                              Text('Pending', style: TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) setState(() => _status = val);
                                      },
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

            // Fixed Bottom Action Bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0A000000),
                    offset: Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                        backgroundColor: Colors.white,
                      ),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
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
                        backgroundColor: const Color(0xFF2563EB), // Solid Blue
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isEdit ? 'Simpan Perubahan' : 'Tambah Karyawan',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail() {
    if (_selectedPhotoPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(_selectedPhotoPath!),
          width: 32,
          height: 32,
          fit: BoxFit.cover,
        ),
      );
    }
    if (!_removeExistingPhoto && _currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty) {
      final trimmed = _currentPhotoUrl!.trim();
      if (trimmed.startsWith('data:image')) {
        try {
          final base64Str = trimmed.split(',').last;
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              base64Decode(base64Str),
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          );
        } catch (_) {}
      } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            trimmed,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultPhotoIcon(),
          ),
        );
      } else {
        final baseDomain = ApiClient.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            '$baseDomain/storage/$trimmed',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultPhotoIcon(),
          ),
        );
      }
    }
    return _defaultPhotoIcon();
  }

  Widget _defaultPhotoIcon() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(
        Icons.camera_alt_outlined,
        size: 17,
        color: Color(0xFF2563EB),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: const Color(0xFF64748B), size: 18) : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/api/api_client.dart';
import '../services/lapor_kecelakaan_service.dart';
import '../../../core/utils/image_compress_helper.dart';

class LaporKecelakaanScreen extends StatefulWidget {
  const LaporKecelakaanScreen({super.key});

  @override
  State<LaporKecelakaanScreen> createState() => _LaporKecelakaanScreenState();
}

class _LaporKecelakaanScreenState extends State<LaporKecelakaanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = LaporKecelakaanService();
  final _picker = ImagePicker();

  bool _isLoading = false;
  bool _isLoadingProfile = true;

  // Auto-filled info
  int _cabangId = 0;
  String _namaCabang = '-';

  // Cleaners list for dropdown
  List<dynamic> _cleanerList = [];
  bool _isLoadingCleaners = false;
  String? _selectedCleanerId;
  String? _selectedCleanerJabatan;

  // Form Controllers
  final _namaPelaporCtrl = TextEditingController();
  final _namaKorbanCtrl = TextEditingController();
  final _lokasiCtrl = TextEditingController();
  final _saksiCtrl = TextEditingController();
  final _kronologiCtrl = TextEditingController();
  final _peristiwaLainnyaCtrl = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Multi-select for Peristiwa
  final List<String> _peristiwaOptions = [
    'Kecelakaan di perjalanan ( berangkat dan pulang dari kantor, berangkat dan pulang dari rumah customer )',
    'Terjatuh atau tergelincir saat pengerjaan di rumah customer',
    'Terjatuh dari ketinggian',
    'Ergonomi ( posisi tubuh yang tidak sesuai saat mengangkat/mengerjakan sesuatu )',
    'Terjepit saat pengerjaan di ruang terbatas ( tandon, lorong, kolong tidur/meja )',
    'Terkena chemical ( kerak, HF, HCL, H2O2/PN )',
    'Pingsan atau tidak sadar diri',
    'Sesak nafas',
    'Tertusuk benda tajam',
    'Lainnya',
  ];
  final Set<String> _selectedPeristiwa = {};

  // Multi-select for Akibat
  final List<String> _akibatOptions = [
    'Kerugian Waktu',
    'Kerugian Fisik',
    'Cedera Fisik',
    'Kerugian Finansial',
    'Cancel Customer',
  ];
  final Set<String> _selectedAkibat = {};

  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _namaPelaporCtrl.dispose();
    _namaKorbanCtrl.dispose();
    _lokasiCtrl.dispose();
    _saksiCtrl.dispose();
    _kronologiCtrl.dispose();
    _peristiwaLainnyaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _namaCabang = prefs.getString('user_branch') ?? '-';
      _cabangId = prefs.getInt('user_cabang_id') ?? prefs.getInt('user_branch_id') ?? 0;
      _namaPelaporCtrl.text = prefs.getString('user_name') ?? '';

      // Refresh from API
      try {
        final me = await AuthService.getMe();
        final data = me['data'] ?? me;
        if (mounted && data != null) {
          setState(() {
            if (data['cabang'] is Map) {
              _namaCabang = data['cabang']['nama_cabang'] ?? _namaCabang;
              _cabangId = data['cabang']['id'] ?? _cabangId;
            } else if (data['cabang_id'] != null) {
              _cabangId = int.tryParse(data['cabang_id'].toString()) ?? _cabangId;
            }
            if (data['nama'] != null && _namaPelaporCtrl.text.isEmpty) {
              _namaPelaporCtrl.text = data['nama'];
            }
          });
        }
      } catch (_) {}

      // Fetch cleaners for this branch
      await _fetchCleaners(_cabangId > 0 ? _cabangId : null);
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _fetchCleaners(int? cabangId) async {
    setState(() => _isLoadingCleaners = true);
    try {
      final url = (cabangId != null && cabangId > 0)
          ? '/karyawans?cabang_id=$cabangId&all=true'
          : '/karyawans?all=true';
      final res = await ApiClient.instance.get(url);
      List<dynamic> list = [];
      if (res.data != null) {
        if (res.data['data'] is List) {
          list = res.data['data'];
        } else if (res.data['data']?['data'] is List) {
          list = res.data['data']['data'];
        } else if (res.data is List) {
          list = res.data;
        }
      }

      if (list.isEmpty && cabangId != null && cabangId > 0) {
        final fallbackRes = await ApiClient.instance.get('/karyawans?all=true');
        if (fallbackRes.data != null) {
          if (fallbackRes.data['data'] is List) {
            list = fallbackRes.data['data'];
          } else if (fallbackRes.data['data']?['data'] is List) {
            list = fallbackRes.data['data']['data'];
          } else if (fallbackRes.data is List) {
            list = fallbackRes.data;
          }
        }
      }

      // Filter to strictly cleaner roles (exclude CS, HRD, Finance, Admin, etc.)
      list = list.where((c) {
        final jab = (c['jabatan']?['nama_jabatan'] ?? c['jabatan_nama'] ?? c['jabatan']?.toString() ?? '').toLowerCase().trim();
        final isExcluded = jab == 'cs' ||
            jab.contains('customer service') ||
            jab.contains('admin') ||
            jab.contains('finance') ||
            jab.contains('hrd') ||
            jab.contains('ceo') ||
            jab.contains('manager');
        if (isExcluded) return false;
        return jab.contains('cleaner') || jab.isEmpty;
      }).toList();

      if (mounted) {
        setState(() {
          _cleanerList = list;
          _isLoadingCleaners = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching cleaners: $e");
      if (mounted) {
        setState(() => _isLoadingCleaners = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        final compressed = await ImageCompressHelper.compressXFileIfNeeded(picked);
        if (compressed != null) {
          setState(() {
            _selectedImage = compressed;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih gambar: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFDC2626),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFDC2626),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submitForm() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal kejadian wajib dipilih'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jam kejadian wajib dipilih'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap lengkapi semua kolom bertanda bintang (*)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedPeristiwa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu jenis peristiwa yang telah terjadi'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedPeristiwa.contains('Lainnya') && _peristiwaLainnyaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keterangan peristiwa "Lainnya" wajib diisi'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedAkibat.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu akibat dari insiden tersebut'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto kondisi / peristiwa wajib dilampirkan'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirm = await AppConfirmationDialog.show(
      context,
      title: 'Kirim Laporan Kecelakaan?',
      message: 'Laporan insiden ini akan langsung diteruskan ke tim Operasional, Admin, dan Manajemen.',
      type: ConfirmationDialogType.warning,
      confirmText: 'Ya, Kirim Laporan',
      cancelText: 'Batal',
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final String tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final String jamStr = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

    final res = await _service.submitLaporan(
      cabangId: _cabangId > 0 ? _cabangId : 1,
      tanggal: tanggalStr,
      jam: jamStr,
      namaPelapor: _namaPelaporCtrl.text.trim(),
      namaKorban: _namaKorbanCtrl.text.trim(),
      jabatan: _selectedCleanerJabatan ?? 'Cleaner',
      lokasi: _lokasiCtrl.text.trim(),
      saksi: _saksiCtrl.text.trim(),
      peristiwaList: _selectedPeristiwa.toList(),
      peristiwaLainnya: _selectedPeristiwa.contains('Lainnya') ? _peristiwaLainnyaCtrl.text.trim() : null,
      akibatList: _selectedAkibat.toList(),
      kronologi: _kronologiCtrl.text.trim(),
      fotoFile: _selectedImage,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['status'] == true) {
      await AppConfirmationDialog.show(
        context,
        title: 'Laporan Terkirim!',
        message: 'Laporan kecelakaan kerja berhasil dikirim dan tersimpan di database Operasional.',
        type: ConfirmationDialogType.success,
        confirmText: 'Selesai',
        cancelText: '',
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } else {
      AppConfirmationDialog.show(
        context,
        title: 'Gagal Mengirim Laporan',
        message: res['message'] ?? 'Terjadi kesalahan sistem.',
        type: ConfirmationDialogType.danger,
        confirmText: 'Tutup',
        cancelText: '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            child: Row(
              children: [
                const AppBackButton(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lapor Kecelakaan Kerja',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Form pelaporan insiden operasional',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body Form
          Expanded(
            child: _isLoadingProfile
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFDC2626)))
                : Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        // Branch & Auto Banner
                        _buildBranchBanner(),
                        const SizedBox(height: 16),

                        // Section 1: Waktu & Pelapor
                        _buildCard(
                          title: 'Waktu & Pihak Terlibat',
                          icon: Icons.access_time_rounded,
                          iconColor: const Color(0xFF2563EB),
                          children: [
                            Row(
                              children: [
                                // Tanggal
                                Expanded(
                                  child: _buildPickerButton(
                                    label: 'Tanggal Kejadian *',
                                    icon: Icons.calendar_today_rounded,
                                    value: _selectedDate != null ? DateFormat('dd MMM yyyy').format(_selectedDate!) : null,
                                    hint: 'Pilih Tanggal',
                                    onTap: _selectDate,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Jam
                                Expanded(
                                  child: _buildPickerButton(
                                    label: 'Jam Kejadian *',
                                    icon: Icons.schedule_rounded,
                                    value: _selectedTime != null
                                        ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')} WIB'
                                        : null,
                                    hint: 'Pilih Jam',
                                    onTap: _selectTime,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Nama Pelapor
                            _buildTextField(
                              controller: _namaPelaporCtrl,
                              label: 'Nama Pelapor *',
                              hint: 'Nama lengkap pelapor',
                              icon: Icons.person_outline_rounded,
                              validator: (val) => val == null || val.trim().isEmpty ? 'Nama pelapor wajib diisi' : null,
                            ),
                            const SizedBox(height: 14),

                            // Saksi Di Tempat
                            _buildTextField(
                              controller: _saksiCtrl,
                              label: 'Saksi Di Tempat *',
                              hint: 'Nama rekan kerja / customer yang menyaksikan',
                              icon: Icons.visibility_outlined,
                              validator: (val) => val == null || val.trim().isEmpty ? 'Saksi di tempat wajib diisi' : null,
                            ),
                            const SizedBox(height: 14),

                            // Pilih Korban Dari Rekan Kerja Cabang (Dropdown)
                            _buildCleanerDropdown(),
                            const SizedBox(height: 14),

                            // Nama Korban (Bisa Input Manual)
                            _buildTextField(
                              controller: _namaKorbanCtrl,
                              label: 'Nama Korban (Bisa Input Manual) *',
                              hint: 'Nama korban kecelakaan / insiden...',
                              icon: Icons.personal_injury_outlined,
                              validator: (val) => val == null || val.trim().isEmpty ? 'Nama korban wajib diisi' : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Section 2: Lokasi Kejadian
                        _buildCard(
                          title: 'Lokasi Kejadian',
                          icon: Icons.location_on_outlined,
                          iconColor: const Color(0xFFDC2626),
                          children: [
                            _buildTextField(
                              controller: _lokasiCtrl,
                              label: 'Lokasi Detail Kejadian *',
                              hint: 'Contoh: Rumah Customer Jl. Darmo Permai No. 12, Lantai 2',
                              icon: Icons.place_outlined,
                              maxLines: 2,
                              validator: (val) => val == null || val.trim().isEmpty ? 'Lokasi kejadian wajib diisi' : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Section 3: Peristiwa yang telah terjadi (Multiple)
                        _buildCard(
                          title: 'Peristiwa yang Telah Terjadi *',
                          subtitle: 'Bisa pilih lebih dari satu yang sesuai',
                          icon: Icons.warning_amber_rounded,
                          iconColor: const Color(0xFFD97706),
                          children: [
                            ..._peristiwaOptions.map((opt) {
                              final isSelected = _selectedPeristiwa.contains(opt);
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedPeristiwa.remove(opt);
                                    } else {
                                      _selectedPeristiwa.add(opt);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                        color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          opt,
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            color: isSelected ? const Color(0xFF991B1B) : const Color(0xFF334155),
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            if (_selectedPeristiwa.contains('Lainnya')) ...[
                              const SizedBox(height: 6),
                              _buildTextField(
                                controller: _peristiwaLainnyaCtrl,
                                label: 'Keterangan Peristiwa Lainnya *',
                                hint: 'Tuliskan jenis peristiwa secara spesifik...',
                                icon: Icons.edit_note_rounded,
                                maxLines: 2,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Section 4: Akibat dari insiden tersebut (Multiple)
                        _buildCard(
                          title: 'Akibat dari Insiden Tersebut *',
                          subtitle: 'Bisa pilih lebih dari satu yang dialami',
                          icon: Icons.healing_rounded,
                          iconColor: const Color(0xFF9333EA),
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _akibatOptions.map((opt) {
                                final isSelected = _selectedAkibat.contains(opt);
                                return FilterChip(
                                  label: Text(opt),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedAkibat.add(opt);
                                      } else {
                                        _selectedAkibat.remove(opt);
                                      }
                                    });
                                  },
                                  selectedColor: const Color(0xFFEDE9FE),
                                  checkmarkColor: const Color(0xFF7C3AED),
                                  backgroundColor: const Color(0xFFF8FAFC),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFCBD5E1),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFF475569),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Section 5: Detail Peristiwa & Kronologi
                        _buildCard(
                          title: 'Detail Kronologi Peristiwa *',
                          icon: Icons.article_outlined,
                          iconColor: const Color(0xFF0D9488),
                          children: [
                            _buildTextField(
                              controller: _kronologiCtrl,
                              label: 'Ceritakan Kronologi Kejadian *',
                              hint: 'Jelaskan kronologi kejadian secara runtut dan jelas...',
                              icon: Icons.subject_rounded,
                              maxLines: 4,
                              validator: (val) => val == null || val.trim().isEmpty ? 'Detail kronologi wajib diisi' : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Section 6: Foto Kondisi / Peristiwa
                        _buildCard(
                          title: 'Foto Kondisi / Peristiwa *',
                          subtitle: 'Lampirkan bukti foto cedera/lokasi kejadian',
                          icon: Icons.camera_alt_outlined,
                          iconColor: const Color(0xFFE11D48),
                          children: [
                            if (_selectedImage != null) ...[
                              Container(
                                width: double.infinity,
                                height: 200,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                  image: DecorationImage(
                                    image: FileImage(_selectedImage!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: InkWell(
                                        onTap: () => setState(() => _selectedImage = null),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.6),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _pickImage(ImageSource.camera),
                                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                                    label: const Text('Kamera'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      foregroundColor: const Color(0xFFDC2626),
                                      side: const BorderSide(color: Color(0xFFDC2626)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _pickImage(ImageSource.gallery),
                                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                                    label: const Text('Galeri'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      foregroundColor: const Color(0xFF475569),
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.send_rounded, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Kirim Laporan Kecelakaan',
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
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

  Widget _buildBranchBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.business_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kantor Cabang Terdeteksi',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  _namaCabang,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF93C5FD)),
            ),
            child: Text(
              'Otomatis',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPickerButton({
    required String label,
    required IconData icon,
    required String? value,
    required String hint,
    required VoidCallback onTap,
  }) {
    final hasValue = value != null && value.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: hasValue ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasValue ? value : hint,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                      color: hasValue ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
            prefixIcon: maxLines == 1 ? Icon(icon, size: 18, color: const Color(0xFF64748B)) : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  void _showCleanerPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final Map<String, dynamic> uniqueCleaners = {};
            for (var c in _cleanerList) {
              if (c['id'] != null) {
                final jab = (c['jabatan']?['nama_jabatan'] ?? c['jabatan_nama'] ?? c['jabatan']?.toString() ?? '').toLowerCase().trim();
                final isExcluded = jab == 'cs' ||
                    jab.contains('customer service') ||
                    jab.contains('admin') ||
                    jab.contains('finance') ||
                    jab.contains('hrd') ||
                    jab.contains('ceo') ||
                    jab.contains('manager');
                if (!isExcluded && (jab.contains('cleaner') || jab.isEmpty)) {
                  uniqueCleaners[c['id'].toString()] = c;
                }
              }
            }
            final list = uniqueCleaners.values.where((c) {
              final name = (c['nama'] ?? c['nama_karyawan'] ?? '').toString().toLowerCase();
              final jab = (c['jabatan']?['nama_jabatan'] ?? c['jabatan_nama'] ?? c['jabatan']?.toString() ?? '').toLowerCase();
              return name.contains(searchQuery.toLowerCase()) || jab.contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pilih Rekan Kerja Korban',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kantor Cabang: $_namaCabang',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        onChanged: (val) {
                          setModalState(() {
                            searchQuery = val;
                          });
                        },
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Cari nama rekan kerja...',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _isLoadingCleaners
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFDC2626)))
                        : list.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFEF2F2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.person_off_outlined, color: Color(0xFFDC2626), size: 32),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Tidak ada data rekan kerja',
                                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Anda dapat langsung mengetikkan nama korban di kolom isian manual di bawah.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: () => Navigator.pop(ctx),
                                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                                        label: const Text('Input Nama Manual'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFDC2626),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                itemCount: list.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                itemBuilder: (context, index) {
                                  final item = list[index];
                                  final idStr = item['id'].toString();
                                  final name = item['nama'] ?? item['nama_karyawan'] ?? '-';
                                  final jab = item['jabatan']?['nama_jabatan'] ?? item['jabatan_nama'] ?? item['jabatan']?.toString() ?? 'Cleaner';
                                  final isSelected = _selectedCleanerId == idStr;

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedCleanerId = idStr;
                                        _namaKorbanCtrl.text = name;
                                        _selectedCleanerJabatan = jab;
                                      });
                                      Navigator.pop(ctx);
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: isSelected ? const Color(0xFFDC2626) : const Color(0xFFEFF6FF),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected ? Colors.white : const Color(0xFF2563EB),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13.5,
                                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                    color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEFF6FF),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    jab,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF2563EB),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isSelected)
                                            const Icon(Icons.check_circle_rounded, color: Color(0xFFDC2626), size: 20),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCleanerDropdown() {
    String displayName = '';
    if (_selectedCleanerId != null && _cleanerList.isNotEmpty) {
      final match = _cleanerList.firstWhere(
        (c) => c['id'].toString() == _selectedCleanerId,
        orElse: () => null,
      );
      if (match != null) {
        final name = match['nama'] ?? match['nama_karyawan'] ?? '';
        final jab = match['jabatan']?['nama_jabatan'] ?? match['jabatan_nama'] ?? match['jabatan']?.toString() ?? 'Cleaner';
        displayName = '$name ($jab)';
      }
    } else if (_namaKorbanCtrl.text.isNotEmpty) {
      displayName = _namaKorbanCtrl.text;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pilih Korban Dari Rekan Kerja Cabang',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
            if (_isLoadingCleaners)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFDC2626)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _showCleanerPickerModal,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_outline_rounded, size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayName.isNotEmpty
                        ? displayName
                        : (_isLoadingCleaners
                            ? 'Memuat rekan kerja...'
                            : 'Pilih rekan kerja / cleaner...'),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: displayName.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                      color: displayName.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ketuk untuk memilih rekan kerja (bisa juga diketik manual di kolom bawah)',
          style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

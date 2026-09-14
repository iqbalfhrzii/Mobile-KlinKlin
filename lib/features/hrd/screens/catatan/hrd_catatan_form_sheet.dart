import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import '../../services/hrd_catatan_service.dart';

class HrdCatatanFormSheet extends StatefulWidget {
  final CatatanHrdModel? catatan;
  final String? initialJenis;
  final int? preselectedKaryawanId;

  const HrdCatatanFormSheet({
    super.key,
    this.catatan,
    this.initialJenis,
    this.preselectedKaryawanId,
  });

  static Future<bool?> show(
    BuildContext context, {
    CatatanHrdModel? catatan,
    String? initialJenis,
    int? preselectedKaryawanId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HrdCatatanFormSheet(
        catatan: catatan,
        initialJenis: initialJenis,
        preselectedKaryawanId: preselectedKaryawanId,
      ),
    );
  }

  @override
  State<HrdCatatanFormSheet> createState() => _HrdCatatanFormSheetState();
}

class _HrdCatatanFormSheetState extends State<HrdCatatanFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final HrdService _hrdService = HrdService();
  final HrdCatatanService _catatanService = HrdCatatanService();

  late String _jenis;
  DateTime _tanggal = DateTime.now();
  int? _selectedKaryawanId;
  String? _selectedKaryawanName;
  int? _selectedPelangganId;
  String? _selectedPelangganName;
  int? _selectedPengajuanIzinCutiId;

  late TextEditingController _keteranganCtrl;
  late TextEditingController _tindakanCtrl;

  bool _isLoadingMaster = true;
  bool _isSubmitting = false;
  bool _isLoadingIzinSakit = false;

  List<KaryawanModel> _karyawans = [];
  List<PelangganHrdModel> _pelanggans = [];
  List<Map<String, dynamic>> _izinSakitList = [];

  @override
  void initState() {
    super.initState();
    final c = widget.catatan;
    _jenis = c?.jenis ?? widget.initialJenis ?? 'komplain';
    if (!['komplain', 'sakit', 'individu'].contains(_jenis)) {
      _jenis = 'komplain';
    }

    if (c != null) {
      _tanggal = c.tanggal;
      _selectedKaryawanId = c.karyawanId;
      _selectedKaryawanName = c.karyawan?.namaLengkap;
      _selectedPelangganId = c.pelangganId;
      _selectedPelangganName = c.pelanggan?.namaPelanggan;
      _selectedPengajuanIzinCutiId = c.pengajuanIzinCutiId;
      _keteranganCtrl = TextEditingController(text: c.keterangan);
      _tindakanCtrl = TextEditingController(text: c.tindakan ?? '');
    } else {
      _selectedKaryawanId = widget.preselectedKaryawanId;
      _keteranganCtrl = TextEditingController();
      _tindakanCtrl = TextEditingController();
    }

    _fetchMaster();
  }

  @override
  void dispose() {
    _keteranganCtrl.dispose();
    _tindakanCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMaster() async {
    try {
      final res = await Future.wait([
        _hrdService.fetchKaryawan(),
        _hrdService.fetchPelanggan(),
      ]);

      if (mounted) {
        setState(() {
          _karyawans = res[0] as List<KaryawanModel>;
          _pelanggans = res[1] as List<PelangganHrdModel>;

          if (_selectedKaryawanId != null && _selectedKaryawanName == null) {
            final found = _karyawans.where((k) => k.id == _selectedKaryawanId).firstOrNull;
            if (found != null) {
              _selectedKaryawanName = found.namaLengkap;
            }
          }
          if (_selectedPelangganId != null && _selectedPelangganName == null) {
            final found = _pelanggans.where((p) => p.id == _selectedPelangganId).firstOrNull;
            if (found != null) {
              _selectedPelangganName = found.namaPelanggan;
            }
          }
          _isLoadingMaster = false;
        });

        if (_selectedKaryawanId != null && _jenis == 'sakit') {
          _loadIzinSakit(_selectedKaryawanId!);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMaster = false);
    }
  }

  Future<void> _loadIzinSakit(int karyawanId) async {
    setState(() => _isLoadingIzinSakit = true);
    try {
      final list = await _catatanService.fetchIzinSakit(karyawanId);
      if (mounted) {
        setState(() {
          _izinSakitList = list;
          _isLoadingIzinSakit = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingIzinSakit = false);
    }
  }

  void _onKaryawanChanged(KaryawanModel k) {
    setState(() {
      _selectedKaryawanId = k.id;
      _selectedKaryawanName = k.namaLengkap;
      _selectedPengajuanIzinCutiId = null;
    });
    if (_jenis == 'sakit') {
      _loadIzinSakit(k.id);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _tanggal = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedKaryawanId == null) {
      _showError('Pilih cleaner / karyawan terlebih dahulu');
      return;
    }

    if (_jenis == 'komplain' && _selectedPelangganId == null) {
      _showError('Pilih pelanggan yang mengajukan komplain');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_tanggal);
      final payload = <String, dynamic>{
        'jenis': _jenis,
        'karyawan_id': _selectedKaryawanId,
        'tanggal': dateStr,
        'keterangan': _keteranganCtrl.text.trim(),
      };

      if (_jenis == 'komplain') {
        payload['pelanggan_id'] = _selectedPelangganId;
        if (_tindakanCtrl.text.trim().isNotEmpty) {
          payload['tindakan'] = _tindakanCtrl.text.trim();
        }
      } else if (_jenis == 'sakit') {
        if (_selectedPengajuanIzinCutiId != null) {
          payload['pengajuan_izin_cuti_id'] = _selectedPengajuanIzinCutiId;
        }
      }

      if (widget.catatan == null) {
        await _catatanService.createCatatan(payload);
      } else {
        await _catatanService.updateCatatan(widget.catatan!.id, payload);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.catatan == null
                  ? 'Catatan ${_getJenisLabel(_jenis)} berhasil disimpan'
                  : 'Catatan ${_getJenisLabel(_jenis)} berhasil diperbarui',
            ),
            backgroundColor: const Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Gagal menyimpan catatan';
        if (e is DioException && e.response?.data != null) {
          final data = e.response!.data;
          if (data is Map) {
            if (data['message'] != null) {
              msg = data['message'].toString();
            } else if (data['errors'] != null && data['errors'] is Map) {
              msg = (data['errors'] as Map).values.first.first.toString();
            }
          }
        }
        _showError(msg);
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _getJenisLabel(String j) {
    switch (j) {
      case 'komplain':
        return 'Komplain';
      case 'sakit':
        return 'Sakit';
      case 'individu':
        return 'Individu';
      default:
        return 'Catatan';
    }
  }

  void _showKaryawanPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SearchablePickerModal<KaryawanModel>(
        title: 'Pilih Cleaner / Karyawan',
        hint: 'Cari nama cleaner...',
        items: _karyawans,
        filter: (k, q) =>
            k.namaLengkap.toLowerCase().contains(q.toLowerCase()) ||
            (k.cabang?.namaCabang.toLowerCase().contains(q.toLowerCase()) ?? false),
        itemTitle: (k) => k.namaLengkap,
        itemSubtitle: (k) => '${k.jabatan?.namaJabatan ?? "-"} • ${k.cabang?.namaCabang ?? "-"}',
        selectedId: _selectedKaryawanId,
        itemId: (k) => k.id,
        onSelected: (k) {
          _onKaryawanChanged(k);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showPelangganPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SearchablePickerModal<PelangganHrdModel>(
        title: 'Pilih Pelanggan',
        hint: 'Cari nama pelanggan...',
        items: _pelanggans,
        filter: (p, q) =>
            p.namaPelanggan.toLowerCase().contains(q.toLowerCase()) ||
            (p.telepon?.contains(q) ?? false),
        itemTitle: (p) => p.namaPelanggan,
        itemSubtitle: (p) => p.telepon != null && p.telepon!.isNotEmpty ? p.telepon! : 'No. HP belum terdaftar',
        selectedId: _selectedPelangganId,
        itemId: (p) => p.id,
        onSelected: (p) {
          setState(() {
            _selectedPelangganId = p.id;
            _selectedPelangganName = p.namaPelanggan;
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.catatan != null;

    Color themeColor;
    IconData themeIcon;
    switch (_jenis) {
      case 'komplain':
        themeColor = const Color(0xFFE11D48);
        themeIcon = Icons.report_problem_rounded;
        break;
      case 'sakit':
        themeColor = const Color(0xFF0D9488);
        themeIcon = Icons.healing_rounded;
        break;
      case 'individu':
      default:
        themeColor = const Color(0xFF6366F1);
        themeIcon = Icons.assignment_ind_rounded;
        break;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle pill
              const SizedBox(height: 12),
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
              const SizedBox(height: 14),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(themeIcon, color: themeColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit
                                ? 'Edit Catatan ${_getJenisLabel(_jenis)}'
                                : 'Tambah Catatan ${_getJenisLabel(_jenis)}',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEdit
                                ? 'Perbarui informasi catatan HRD cleaner'
                                : 'Catat evaluasi & rekam jejak cleaner',
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
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Content Form
              Flexible(
                child: _isLoadingMaster
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        children: [
                          // 1. Selector Jenis Catatan (if not editing)
                          if (!isEdit) ...[
                            Text(
                              'Pilih Jenis Catatan',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildJenisSelector(),
                            const SizedBox(height: 18),
                          ],

                          // 2. Karyawan / Cleaner Picker
                          Text(
                            'Cleaner / Karyawan *',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildPickerTile(
                            icon: Icons.person_rounded,
                            label: _selectedKaryawanName ?? 'Pilih cleaner...',
                            isSelected: _selectedKaryawanId != null,
                            onTap: _showKaryawanPicker,
                          ),
                          const SizedBox(height: 16),

                          // 3. Tanggal
                          Text(
                            'Tanggal Kejadian / Catatan *',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildPickerTile(
                            icon: Icons.calendar_today_rounded,
                            label: DateFormat('EEEE, dd MMMM yyyy').format(_tanggal),
                            isSelected: true,
                            onTap: _pickDate,
                          ),
                          const SizedBox(height: 16),

                          // 4. Jenis-Specific Fields
                          if (_jenis == 'komplain') ...[
                            // Pelanggan Picker
                            Text(
                              'Customer / Pelanggan *',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildPickerTile(
                              icon: Icons.storefront_rounded,
                              label: _selectedPelangganName ?? 'Pilih customer...',
                              isSelected: _selectedPelangganId != null,
                              onTap: _showPelangganPicker,
                            ),
                            const SizedBox(height: 16),

                            // Keterangan Komplain
                            Text(
                              'Keterangan Komplain *',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _keteranganCtrl,
                              maxLines: 4,
                              decoration: _inputDecoration(
                                hint: 'Jelaskan detail komplain dari customer mengenai pengerjaan cleaner...',
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Keterangan komplain wajib diisi' : null,
                            ),
                            const SizedBox(height: 16),

                            // Tindakan
                            Text(
                              'Tindakan HRD / Penyelesaian',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _tindakanCtrl,
                              maxLines: 3,
                              decoration: _inputDecoration(
                                hint: 'Contoh: Diberi teguran, recleaning ulang, pembinaan SOP, dll...',
                              ),
                            ),
                          ] else if (_jenis == 'sakit') ...[
                            // Link ke Izin Sakit
                            _buildIzinSakitLinkSection(),
                            const SizedBox(height: 16),

                            // Keterangan Sakit
                            Text(
                              'Keterangan Sakit / Diagnosa *',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _keteranganCtrl,
                              maxLines: 4,
                              decoration: _inputDecoration(
                                hint: 'Keterangan sakit (misal: Demam tinggi, tifus 3 hari, surat dokter terlampir)...',
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Keterangan sakit wajib diisi' : null,
                            ),
                          ] else ...[
                            // Individu
                            Text(
                              'Catatan Individu Cleaner *',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _keteranganCtrl,
                              maxLines: 5,
                              decoration: _inputDecoration(
                                hint: 'Tulis catatan individu mengenai cleaner (misal: sering emosi saat pengerjaan, etos kerja tinggi, catatan komunikasi dengan rekan kerja, dll)...',
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Catatan individu wajib diisi' : null,
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(isEdit ? Icons.save_rounded : Icons.add_circle_outline_rounded, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          isEdit ? 'Simpan Perubahan' : 'Simpan Catatan',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJenisSelector() {
    final options = [
      {'key': 'komplain', 'label': 'Komplain', 'icon': Icons.report_problem_rounded, 'color': const Color(0xFFE11D48)},
      {'key': 'sakit', 'label': 'Sakit', 'icon': Icons.healing_rounded, 'color': const Color(0xFF0D9488)},
      {'key': 'individu', 'label': 'Individu', 'icon': Icons.assignment_ind_rounded, 'color': const Color(0xFF6366F1)},
    ];

    return Row(
      children: options.map((opt) {
        final key = opt['key'] as String;
        final label = opt['label'] as String;
        final icon = opt['icon'] as IconData;
        final color = opt['color'] as Color;
        final isSelected = _jenis == key;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _jenis = key;
                if (key == 'sakit' && _selectedKaryawanId != null) {
                  _loadIzinSakit(_selectedKaryawanId!);
                }
              });
            },
            child: Container(
              margin: EdgeInsets.only(
                right: key != options.last['key'] ? 8 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected ? color : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIzinSakitLinkSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCCFBF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link_rounded, size: 18, color: Color(0xFF0D9488)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tautkan Dari Izin Sakit Cleaner',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF134E4A),
                  ),
                ),
              ),
              if (_isLoadingIzinSakit)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D9488)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Bisa dipilih jika cleaner sudah mengajukan izin sakit di aplikasi, atau ketik manual di bawah jika tanpa pengajuan.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF0F766E),
            ),
          ),
          const SizedBox(height: 10),
          if (_selectedKaryawanId == null)
            Text(
              'Pilih cleaner terlebih dahulu untuk melihat izin sakit mereka.',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB45309)),
            )
          else if (_izinSakitList.isEmpty && !_isLoadingIzinSakit)
            Text(
              'Tidak ada pengajuan izin sakit tercatat untuk cleaner ini. Silakan input manual keterangan sakit di bawah.',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
            )
          else ...[
            DropdownButtonFormField<int?>(
              initialValue: _selectedPengajuanIzinCutiId,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF99F6E4)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF99F6E4)),
                ),
              ),
              hint: Text(
                '-- Pilih Izin Sakit Diajukan --',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(
                    'Input Manual (Tanpa Tautan Izin)',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                  ),
                ),
                ..._izinSakitList.map((item) {
                  final id = int.tryParse(item['id'].toString());
                  final tglMulai = item['tanggal_mulai'] ?? '-';
                  final tglSelesai = item['tanggal_selesai'] ?? '-';
                  final alasan = item['alasan'] ?? 'Izin Sakit';
                  return DropdownMenuItem<int?>(
                    value: id,
                    child: Text(
                      '$tglMulai s/d $tglSelesai ($alasan)',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedPengajuanIzinCutiId = val;
                  if (val != null) {
                    final found = _izinSakitList.firstWhere(
                      (e) => int.tryParse(e['id'].toString()) == val,
                      orElse: () => {},
                    );
                    if (found.isNotEmpty) {
                      if (found['tanggal_mulai'] != null) {
                        final parsed = DateTime.tryParse(found['tanggal_mulai'].toString());
                        if (parsed != null) _tanggal = parsed;
                      }
                      if (found['alasan'] != null) {
                        _keteranganCtrl.text = found['alasan'].toString();
                      }
                    }
                  }
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPickerTile({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppColors.primary : const Color(0xFF94A3B8)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8), size: 20),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}

class _SearchablePickerModal<T> extends StatefulWidget {
  final String title;
  final String hint;
  final List<T> items;
  final bool Function(T item, String query) filter;
  final String Function(T item) itemTitle;
  final String Function(T item)? itemSubtitle;
  final int? selectedId;
  final int Function(T item) itemId;
  final void Function(T item) onSelected;

  const _SearchablePickerModal({
    required this.title,
    required this.hint,
    required this.items,
    required this.filter,
    required this.itemTitle,
    this.itemSubtitle,
    required this.selectedId,
    required this.itemId,
    required this.onSelected,
  });

  @override
  State<_SearchablePickerModal<T>> createState() => _SearchablePickerModalState<T>();
}

class _SearchablePickerModalState<T> extends State<_SearchablePickerModal<T>> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items.where((e) => widget.filter(e, _query)).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
              hintText: widget.hint,
              hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ditemukan data sesuai pencarian',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, idx) {
                      final item = filtered[idx];
                      final isSelected = widget.itemId(item) == widget.selectedId;
                      return ListTile(
                        onTap: () => widget.onSelected(item),
                        title: Text(
                          widget.itemTitle(item),
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AppColors.primary : const Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: widget.itemSubtitle != null
                            ? Text(
                                widget.itemSubtitle!(item),
                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                              )
                            : null,
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

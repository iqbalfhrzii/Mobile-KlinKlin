import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/api/api_client.dart';
import '../services/operasional_tagihan_service.dart';

class TagihanBulananFormScreen extends StatefulWidget {
  final dynamic tagihan; // null for add, not null for edit

  const TagihanBulananFormScreen({super.key, this.tagihan});

  @override
  State<TagihanBulananFormScreen> createState() => _TagihanBulananFormScreenState();
}

class _TagihanBulananFormScreenState extends State<TagihanBulananFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  List<dynamic> _cabangs = [];

  final _nominalCtrl = TextEditingController();
  final _nominalDibayarCtrl = TextEditingController();
  final _keteranganCtrl = TextEditingController();

  int? _cabangId;
  DateTime? _periode;
  String? _jenisTagihan;
  DateTime? _jatuhTempo;
  String _statusBayar = 'Belum Bayar';
  DateTime? _tanggalBayar;

  File? _buktiBayarFile;
  String? _existingBuktiUrl;

  final List<Map<String, dynamic>> _jenisTagihanList = [
    {'value': 'sewa', 'label': 'Sewa', 'icon': Icons.home_work_rounded, 'color': Color(0xFF7C3AED)},
    {'value': 'listrik', 'label': 'Listrik', 'icon': Icons.bolt_rounded, 'color': Color(0xFFD97706)},
    {'value': 'air', 'label': 'Air', 'icon': Icons.water_drop_rounded, 'color': Color(0xFF0284C7)},
    {'value': 'internet', 'label': 'Internet', 'icon': Icons.wifi_rounded, 'color': Color(0xFF0D9488)},
    {'value': 'telepon', 'label': 'Telepon', 'icon': Icons.phone_in_talk_rounded, 'color': Color(0xFF059669)},
    {'value': 'kebersihan', 'label': 'Kebersihan', 'icon': Icons.cleaning_services_rounded, 'color': Color(0xFFEA580C)},
    {'value': 'keamanan', 'label': 'Keamanan', 'icon': Icons.security_rounded, 'color': Color(0xFF475569)},
    {'value': 'pajak', 'label': 'Pajak', 'icon': Icons.account_balance_rounded, 'color': Color(0xFFDC2626)},
    {'value': 'lainnya', 'label': 'Lainnya', 'icon': Icons.receipt_long_rounded, 'color': AppColors.primary},
  ];

  @override
  void initState() {
    super.initState();
    _loadCabangs();
    _initData();
  }

  @override
  void dispose() {
    _nominalCtrl.dispose();
    _nominalDibayarCtrl.dispose();
    _keteranganCtrl.dispose();
    super.dispose();
  }

  void _initData() {
    if (widget.tagihan != null) {
      final t = widget.tagihan;
      _cabangId = t['cabang_id'];
      if (t['periode'] != null) _periode = DateTime.tryParse(t['periode']);
      _jenisTagihan = t['jenis_tagihan'];
      
      // Clean nominal string
      final rawNominal = t['nominal']?.toString() ?? '';
      _nominalCtrl.text = rawNominal.replaceAll('.00', '').replaceAll('.0', '');

      if (t['jatuh_tempo'] != null) _jatuhTempo = DateTime.tryParse(t['jatuh_tempo']);
      _statusBayar = t['status_bayar'] ?? 'Belum Bayar';
      if (t['tanggal_bayar'] != null) _tanggalBayar = DateTime.tryParse(t['tanggal_bayar']);
      
      if (t['nominal_dibayar'] != null) {
        final rawDibayar = t['nominal_dibayar'].toString();
        _nominalDibayarCtrl.text = rawDibayar.replaceAll('.00', '').replaceAll('.0', '');
      }
      
      _keteranganCtrl.text = t['keterangan'] ?? '';
      
      final rawBukti = t['bukti_bayar_url'] ?? t['bukti_bayar'];
      if (rawBukti != null && rawBukti.toString().isNotEmpty) {
        _existingBuktiUrl = _getImageUrl(rawBukti.toString());
      }
    } else {
      _periode = DateTime(DateTime.now().year, DateTime.now().month, 1);
    }
  }

  String _getImageUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final baseDomain = ApiClient.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    if (cleanPath.startsWith('storage/')) {
      return '$baseDomain/$cleanPath';
    }
    return '$baseDomain/storage/$cleanPath';
  }

  Future<void> _loadCabangs() async {
    try {
      final cabangs = await OperasionalTagihanService.getCabangs();
      if (mounted) {
        setState(() => _cabangs = cabangs);
      }
    } catch (e) {
      debugPrint('Error loading cabangs: $e');
    }
  }

  Future<void> _showImagePickerSheet() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pilih Sumber Foto',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPickerOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Kamera',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildPickerOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Galeri',
                    color: const Color(0xFF059669),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _buktiBayarFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_periode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih periode bulanan terlebih dahulu'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final cleanNominal = _nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      final cleanNominalDibayar = _nominalDibayarCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');

      final data = <String, dynamic>{
        'cabang_id': _cabangId,
        'periode': DateFormat('yyyy-MM-dd').format(_periode!),
        'jenis_tagihan': _jenisTagihan,
        'nominal': cleanNominal,
        'status_bayar': _statusBayar,
      };

      if (_jatuhTempo != null) {
        data['jatuh_tempo'] = DateFormat('yyyy-MM-dd').format(_jatuhTempo!);
      }
      
      if (_statusBayar == 'Lunas') {
        if (_tanggalBayar != null) {
          data['tanggal_bayar'] = DateFormat('yyyy-MM-dd').format(_tanggalBayar!);
        } else {
          data['tanggal_bayar'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
        }
        data['nominal_dibayar'] = cleanNominalDibayar.isNotEmpty ? cleanNominalDibayar : cleanNominal;
      }
      
      if (_keteranganCtrl.text.isNotEmpty) {
        data['keterangan'] = _keteranganCtrl.text;
      }
      
      if (_buktiBayarFile != null) {
        data['bukti_bayar'] = _buktiBayarFile!.path;
      }

      if (widget.tagihan != null) {
        await OperasionalTagihanService.updateTagihan(widget.tagihan['id'], data);
      } else {
        await OperasionalTagihanService.createTagihan(data);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.tagihan != null ? 'Tagihan berhasil diperbarui' : 'Tagihan baru berhasil dibuat'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
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
    final isEdit = widget.tagihan != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Enhanced Header
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Edit Tagihan Bulanan' : 'Tambah Tagihan Baru',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEdit ? 'Perbarui data tagihan operasional cabang' : 'Lengkapi data tagihan operasional cabang',
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

          // Scrollable Form
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // SECTION 1: Informasi Cabang & Tagihan
                  _buildSectionCard(
                    title: 'Informasi Cabang & Periode',
                    icon: Icons.storefront_rounded,
                    children: [
                      _buildDropdownField(
                        label: 'Cabang Operasional',
                        value: _cabangId,
                        icon: Icons.storefront_rounded,
                        hint: 'Pilih Cabang',
                        items: _cabangs
                            .map((c) => DropdownMenuItem(
                                  value: c['id'] as int,
                                  child: Text(c['nama_cabang'] ?? '-'),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => _cabangId = val as int),
                        validator: (val) => val == null ? 'Pilih cabang operasional' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildDatePickerField(
                        label: 'Periode Tagihan (Bulan & Tahun)',
                        date: _periode,
                        icon: Icons.calendar_month_rounded,
                        hint: 'Pilih Bulan & Tahun',
                        onSelected: (date) => setState(() => _periode = date),
                        format: 'MMMM yyyy',
                      ),
                      const SizedBox(height: 16),
                      _buildJenisTagihanSelector(),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // SECTION 2: Nominal & Jatuh Tempo
                  _buildSectionCard(
                    title: 'Nominal & Jatuh Tempo',
                    icon: Icons.payments_rounded,
                    children: [
                      _buildCurrencyField(
                        label: 'Nominal Tagihan',
                        controller: _nominalCtrl,
                        validator: (val) => (val == null || val.isEmpty) ? 'Nominal tagihan wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildDatePickerField(
                        label: 'Tanggal Jatuh Tempo (Opsional)',
                        date: _jatuhTempo,
                        icon: Icons.event_outlined,
                        hint: 'Pilih Tanggal Jatuh Tempo',
                        onSelected: (date) => setState(() => _jatuhTempo = date),
                        format: 'dd MMMM yyyy',
                        isOptional: true,
                        onClear: () => setState(() => _jatuhTempo = null),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // SECTION 3: Status Pembayaran
                  _buildSectionCard(
                    title: 'Status & Bukti Pembayaran',
                    icon: Icons.verified_rounded,
                    children: [
                      Text(
                        'Status Pembayaran',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 10),
                      _buildStatusSelectorTiles(),

                      if (_statusBayar == 'Lunas') ...[
                        const SizedBox(height: 18),
                        _buildDatePickerField(
                          label: 'Tanggal Pembayaran',
                          date: _tanggalBayar ?? DateTime.now(),
                          icon: Icons.event_available_rounded,
                          hint: 'Pilih Tanggal Bayar',
                          onSelected: (date) => setState(() => _tanggalBayar = date),
                          format: 'dd MMMM yyyy',
                        ),
                        const SizedBox(height: 16),
                        _buildCurrencyField(
                          label: 'Nominal yang Dibayarkan (Opsional)',
                          controller: _nominalDibayarCtrl,
                          hint: 'Sama dengan nominal tagihan jika dikosongkan',
                        ),
                        const SizedBox(height: 16),
                        _buildBuktiBayarUploader(),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // SECTION 4: Keterangan
                  _buildSectionCard(
                    title: 'Catatan Tambahan',
                    icon: Icons.notes_rounded,
                    children: [
                      _buildTextField(
                        label: 'Keterangan (Opsional)',
                        controller: _keteranganCtrl,
                        hint: 'Contoh: Tagihan listrik periode Agustus, no meter 123456...',
                        maxLines: 3,
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
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
                              Icon(isEdit ? Icons.save_rounded : Icons.check_circle_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                isEdit ? 'SIMPAN PERUBAHAN' : 'BUAT TAGIHAN SEKARANG',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION CONTAINER ---
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // --- STATUS SELECTOR TILES ---
  Widget _buildStatusSelectorTiles() {
    return Row(
      children: [
        Expanded(
          child: _buildStatusTile(
            title: 'Belum Bayar',
            subtitle: 'Tertunda',
            icon: Icons.pending_actions_rounded,
            isSelected: _statusBayar == 'Belum Bayar',
            color: const Color(0xFFD97706),
            onTap: () => setState(() => _statusBayar = 'Belum Bayar'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusTile(
            title: 'Lunas',
            subtitle: 'Sudah Dibayar',
            icon: Icons.check_circle_rounded,
            isSelected: _statusBayar == 'Lunas',
            color: const Color(0xFF059669),
            onTap: () {
              setState(() {
                _statusBayar = 'Lunas';
                _tanggalBayar ??= DateTime.now();
                if (_nominalDibayarCtrl.text.isEmpty) {
                  _nominalDibayarCtrl.text = _nominalCtrl.text;
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? color : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isSelected ? color.withValues(alpha: 0.8) : const Color(0xFF94A3B8),
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

  // --- JENIS TAGIHAN SELECTOR ---
  Widget _buildJenisTagihanSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategori / Jenis Tagihan',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _jenisTagihan,
              isExpanded: true,
              hint: Row(
                children: [
                  const Icon(Icons.category_rounded, size: 18, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 10),
                  Text(
                    'Pilih Kategori Tagihan',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              items: _jenisTagihanList.map((item) {
                final icon = item['icon'] as IconData;
                final color = item['color'] as Color;
                final label = item['label'] as String;
                final val = item['value'] as String;

                return DropdownMenuItem<String>(
                  value: val,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, size: 16, color: color),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _jenisTagihan = val),
            ),
          ),
        ),
      ],
    );
  }

  // --- BUKTI BAYAR UPLOADER ---
  Widget _buildBuktiBayarUploader() {
    final bool hasFile = _buktiBayarFile != null;
    final bool hasExisting = _existingBuktiUrl != null && _existingBuktiUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bukti Transfer / Struk Pembayaran',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        if (hasFile || hasExisting)
          Stack(
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: hasFile
                      ? Image.file(_buktiBayarFile!, fit: BoxFit.cover)
                      : Image.network(
                          _existingBuktiUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_rounded, size: 36, color: Colors.grey),
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showImagePickerSheet,
                      icon: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                      label: Text('Ganti', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _buktiBayarFile = null;
                          _existingBuktiUrl = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.delete_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        else
          InkWell(
            onTap: _showImagePickerSheet,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload Bukti Pembayaran',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Format: JPG, PNG, maks 2MB',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // --- FORM FIELDS HELPER ---
  Widget _buildCurrencyField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            hintText: hint ?? '0',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
            prefixIcon: Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Rp',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B)),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required dynamic value,
    required IconData icon,
    required String hint,
    required List<DropdownMenuItem<dynamic>> items,
    required Function(dynamic) onChanged,
    String? Function(dynamic)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<dynamic>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
            prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 18),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? date,
    required IconData icon,
    required String hint,
    required Function(DateTime) onSelected,
    String format = 'dd MMMM yyyy',
    bool isOptional = false,
    VoidCallback? onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) onSelected(picked);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(
                color: date != null ? AppColors.primary.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, color: date != null ? AppColors.primary : const Color(0xFF94A3B8), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    date != null ? DateFormat(format).format(date) : hint,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: date != null ? FontWeight.w600 : FontWeight.w400,
                      color: date != null ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                if (isOptional && date != null && onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                      child: Icon(Icons.close_rounded, size: 14, color: Colors.red.shade600),
                    ),
                  )
                else
                  const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/operasional_kantor_service.dart';

class KantorKlinklinFormScreen extends StatefulWidget {
  final dynamic cabang;
  final List<dynamic>? allCabangs;

  const KantorKlinklinFormScreen({super.key, this.cabang, this.allCabangs});

  @override
  State<KantorKlinklinFormScreen> createState() => _KantorKlinklinFormScreenState();
}

class _KantorKlinklinFormScreenState extends State<KantorKlinklinFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _cabangNameCtrl = TextEditingController();
  final _picNamaCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();
  final _noTelpCtrl = TextEditingController();
  final _hargaSewaCtrl = TextEditingController();

  int? _selectedCabangId;
  String _statusKantor = 'Aset';
  DateTime? _awalSewa;
  DateTime? _akhirSewa;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _cabangNameCtrl.dispose();
    _picNamaCtrl.dispose();
    _alamatCtrl.dispose();
    _noTelpCtrl.dispose();
    _hargaSewaCtrl.dispose();
    super.dispose();
  }

  void _initData() {
    final c = widget.cabang;
    if (c != null) {
      _selectedCabangId = c['id'];
      _cabangNameCtrl.text = c['nama_cabang'] ?? '';
      _picNamaCtrl.text = c['pic_nama'] ?? '';
      _alamatCtrl.text = c['alamat'] ?? '';
      _noTelpCtrl.text = c['no_telp'] ?? '';

      _statusKantor = c['status_kantor'] ?? 'Aset';

      if (_statusKantor == 'Sewa') {
        final rawHarga = c['harga_sewa']?.toString() ?? '';
        _hargaSewaCtrl.text = rawHarga.replaceAll('.00', '').replaceAll('.0', '');
        if (c['awal_sewa'] != null) _awalSewa = DateTime.tryParse(c['awal_sewa']);
        if (c['akhir_sewa'] != null) _akhirSewa = DateTime.tryParse(c['akhir_sewa']);
      }
    } else if (widget.allCabangs != null && widget.allCabangs!.isNotEmpty) {
      final first = widget.allCabangs!.first;
      _selectedCabangId = first['id'];
      _cabangNameCtrl.text = first['nama_cabang'] ?? '';
      _picNamaCtrl.text = first['pic_nama'] ?? '';
      _alamatCtrl.text = first['alamat'] ?? '';
      _noTelpCtrl.text = first['no_telp'] ?? '';
      _statusKantor = first['status_kantor'] ?? 'Aset';
      if (_statusKantor == 'Sewa') {
        final rawHarga = first['harga_sewa']?.toString() ?? '';
        _hargaSewaCtrl.text = rawHarga.replaceAll('.00', '').replaceAll('.0', '');
        if (first['awal_sewa'] != null) _awalSewa = DateTime.tryParse(first['awal_sewa']);
        if (first['akhir_sewa'] != null) _akhirSewa = DateTime.tryParse(first['akhir_sewa']);
      }
    }
  }

  void _onCabangChanged(int? newId) {
    if (newId == null) return;
    setState(() {
      _selectedCabangId = newId;
      final selectedCabangData = (widget.allCabangs ?? []).firstWhere(
        (c) => c['id'] == _selectedCabangId,
        orElse: () => null,
      );
      if (selectedCabangData != null) {
        _cabangNameCtrl.text = selectedCabangData['nama_cabang'] ?? '';
        _picNamaCtrl.text = selectedCabangData['pic_nama'] ?? '';
        _alamatCtrl.text = selectedCabangData['alamat'] ?? '';
        _noTelpCtrl.text = selectedCabangData['no_telp'] ?? '';
        _statusKantor = selectedCabangData['status_kantor'] ?? 'Aset';

        if (_statusKantor == 'Sewa') {
          final rawHarga = selectedCabangData['harga_sewa']?.toString() ?? '';
          _hargaSewaCtrl.text = rawHarga.replaceAll('.00', '').replaceAll('.0', '');
          if (selectedCabangData['awal_sewa'] != null) {
            _awalSewa = DateTime.tryParse(selectedCabangData['awal_sewa']);
          }
          if (selectedCabangData['akhir_sewa'] != null) {
            _akhirSewa = DateTime.tryParse(selectedCabangData['akhir_sewa']);
          }
        } else {
          _hargaSewaCtrl.clear();
          _awalSewa = null;
          _akhirSewa = null;
        }
      }
    });
  }

  String _calculateDuration() {
    if (_awalSewa == null || _akhirSewa == null) return '';
    final days = _akhirSewa!.difference(_awalSewa!).inDays;
    if (days < 0) return 'Tanggal akhir tidak valid';
    final months = (days / 30.44).round();
    final years = (days / 365.25).floor();
    if (years >= 1) {
      final remMonths = months % 12;
      return remMonths > 0 ? '$years Tahun $remMonths Bulan ($days Hari)' : '$years Tahun ($days Hari)';
    }
    return '$months Bulan ($days Hari)';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCabangId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih cabang terlebih dahulu'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_statusKantor == 'Sewa') {
      if (_awalSewa == null || _akhirSewa == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Periode awal dan akhir sewa wajib diisi untuk status Sewa'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (_akhirSewa!.isBefore(_awalSewa!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tanggal akhir sewa tidak boleh sebelum tanggal awal sewa'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final cleanHarga = _hargaSewaCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');

      final data = <String, dynamic>{
        'pic_nama': _picNamaCtrl.text.trim().isNotEmpty ? _picNamaCtrl.text.trim() : null,
        'alamat': _alamatCtrl.text,
        'no_telp': _noTelpCtrl.text,
        'status_kantor': _statusKantor,
      };

      if (_statusKantor == 'Sewa') {
        data['harga_sewa'] = cleanHarga;
        data['awal_sewa'] = DateFormat('yyyy-MM-dd').format(_awalSewa!);
        data['akhir_sewa'] = DateFormat('yyyy-MM-dd').format(_akhirSewa!);
      } else {
        data['harga_sewa'] = null;
        data['awal_sewa'] = null;
        data['akhir_sewa'] = null;
      }

      await OperasionalKantorService.updateKantor(_selectedCabangId!, data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informasi kantor cabang berhasil diperbarui'),
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
    final isEdit = widget.cabang != null;
    final durationText = _calculateDuration();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Enhanced Header
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            child: Row(
              children: [
                const AppBackButton(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Edit Kantor Klinklin' : 'Tambah Riwayat Kantor Klinklin',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kelola data alamat dan riwayat sewa kantor untuk setiap cabang',
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

          // Scrollable Form Content
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // SECTION 1: Identitas Cabang
                  _buildSectionCard(
                    title: 'Cabang & Penanggung Jawab',
                    icon: Icons.storefront_rounded,
                    children: [
                      if (widget.allCabangs != null && widget.allCabangs!.isNotEmpty && !isEdit)
                        _buildDropdownField(
                          label: 'Pilih Cabang *',
                          value: _selectedCabangId,
                          icon: Icons.business_rounded,
                          hint: 'Pilih Cabang',
                          items: widget.allCabangs!
                              .map((c) => DropdownMenuItem(
                                    value: c['id'] as int,
                                    child: Text(c['nama_cabang'] ?? '-'),
                                  ))
                              .toList(),
                          onChanged: (val) => _onCabangChanged(val as int?),
                          validator: (val) => val == null ? 'Pilih cabang operasional' : null,
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Cabang Operasional',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _cabangNameCtrl.text.isNotEmpty ? _cabangNameCtrl.text : 'Cabang Terpilih',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      _buildTextField(
                        label: 'Nama PIC',
                        controller: _picNamaCtrl,
                        icon: Icons.person_outline_rounded,
                        hint: 'Masukkan nama penanggung jawab',
                      ),

                      const SizedBox(height: 16),

                      _buildTextField(
                        label: 'Nomor Telepon Kantor',
                        controller: _noTelpCtrl,
                        icon: Icons.phone_in_talk_rounded,
                        keyboardType: TextInputType.phone,
                        hint: 'Contoh: 08123456789 / 0542-123456',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // SECTION 2: Alamat Lengkap
                  _buildSectionCard(
                    title: 'Alamat Lokasi Kantor',
                    icon: Icons.location_on_rounded,
                    children: [
                      _buildTextField(
                        label: 'Alamat Lengkap Kantor',
                        controller: _alamatCtrl,
                        maxLines: 3,
                        hint: 'Masukkan alamat lengkap kantor cabang (Jalan, RT/RW, Kelurahan, Kecamatan, Kota)...',
                        validator: (val) => (val == null || val.isEmpty) ? 'Alamat kantor wajib diisi' : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // SECTION 3: Status Kepemilikan
                  _buildSectionCard(
                    title: 'Status Kepemilikan Kantor',
                    icon: Icons.domain_verification_rounded,
                    children: [
                      Text(
                        'Pilih Status Kantor',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildStatusSelectorTiles(),

                      // If SEWA: Show Lease Input Fields
                      if (_statusKantor == 'Sewa') ...[
                        const SizedBox(height: 20),
                        const Divider(color: Color(0xFFF1F5F9), height: 1),
                        const SizedBox(height: 16),

                        Text(
                          'Detail Perjanjian Sewa',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                        const SizedBox(height: 12),

                        _buildCurrencyField(
                          label: 'Harga / Biaya Sewa (Rp)',
                          controller: _hargaSewaCtrl,
                          hint: 'Contoh: 35000000',
                          validator: (val) {
                            if (_statusKantor == 'Sewa' && (val == null || val.isEmpty)) {
                              return 'Harga sewa wajib diisi untuk status Sewa';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _buildDatePickerField(
                                label: 'Awal Sewa',
                                date: _awalSewa,
                                icon: Icons.calendar_today_rounded,
                                hint: 'Pilih Tanggal',
                                onSelected: (date) => setState(() => _awalSewa = date),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDatePickerField(
                                label: 'Akhir Sewa',
                                date: _akhirSewa,
                                icon: Icons.event_available_rounded,
                                hint: 'Pilih Tanggal',
                                onSelected: (date) => setState(() => _akhirSewa = date),
                              ),
                            ),
                          ],
                        ),

                        if (durationText.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFDDD6FE)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.timelapse_rounded, size: 16, color: Color(0xFF7C3AED)),
                                const SizedBox(width: 8),
                                Text(
                                  'Durasi Kontrak: $durationText',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF6D28D9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
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
                              const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'SIMPAN INFORMASI KANTOR',
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
            title: 'Aset Tetap',
            subtitle: 'Milik Perusahaan',
            icon: Icons.verified_rounded,
            isSelected: _statusKantor == 'Aset',
            color: const Color(0xFF059669),
            onTap: () {
              setState(() {
                _statusKantor = 'Aset';
                _hargaSewaCtrl.clear();
                _awalSewa = null;
                _akhirSewa = null;
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusTile(
            title: 'Sewa Kantor',
            subtitle: 'Kontrak Berkala',
            icon: Icons.home_work_rounded,
            isSelected: _statusKantor == 'Sewa',
            color: const Color(0xFF7C3AED),
            onTap: () {
              setState(() {
                _statusKantor = 'Sewa';
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
                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Rp',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF7C3AED)),
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
              borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
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
    IconData? icon,
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
            prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF94A3B8), size: 18) : null,
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
    String format = 'dd MMM yyyy',
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
              firstDate: DateTime(2015),
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
                color: date != null ? const Color(0xFF7C3AED).withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, color: date != null ? const Color(0xFF7C3AED) : const Color(0xFF94A3B8), size: 18),
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
                const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

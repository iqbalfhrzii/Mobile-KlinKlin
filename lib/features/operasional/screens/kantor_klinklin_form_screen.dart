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

  void _initData() {
    final c = widget.cabang;
    if (c != null) {
      _selectedCabangId = c['id'];
      _cabangNameCtrl.text = c['nama_cabang'] ?? '';
      _alamatCtrl.text = c['alamat'] ?? '';
      _noTelpCtrl.text = c['no_telp'] ?? '';
      
      _statusKantor = c['status_kantor'] ?? 'Aset';
      
      if (_statusKantor == 'Sewa') {
        _hargaSewaCtrl.text = (c['harga_sewa'] != null) ? c['harga_sewa'].toString() : '';
        if (c['awal_sewa'] != null) _awalSewa = DateTime.tryParse(c['awal_sewa']);
        if (c['akhir_sewa'] != null) _akhirSewa = DateTime.tryParse(c['akhir_sewa']);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCabangId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih cabang terlebih dahulu')));
      return;
    }
    
    if (_statusKantor == 'Sewa') {
      if (_awalSewa == null || _akhirSewa == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Periode awal dan akhir sewa wajib diisi')));
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final data = <String, dynamic>{
        'alamat': _alamatCtrl.text,
        'no_telp': _noTelpCtrl.text,
        'status_kantor': _statusKantor,
      };

      if (_statusKantor == 'Sewa') {
        data['harga_sewa'] = _hargaSewaCtrl.text;
        data['awal_sewa'] = DateFormat('yyyy-MM-dd').format(_awalSewa!);
        data['akhir_sewa'] = DateFormat('yyyy-MM-dd').format(_akhirSewa!);
      }

      await OperasionalKantorService.updateKantor(_selectedCabangId!, data);
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
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
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                Text(
                  widget.cabang == null ? 'Tambah Kantor Klinklin' : 'Edit Kantor Klinklin',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDropdownField(
                          label: 'Cabang',
                          value: _selectedCabangId,
                          hint: 'Pilih Cabang',
                          items: (widget.allCabangs ?? []).map((c) => DropdownMenuItem(
                            value: c['id'] as int,
                            child: Text(c['nama_cabang']),
                          )).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedCabangId = val as int;
                              // Auto-fill other fields if available in the selected cabang
                              final selectedCabangData = (widget.allCabangs ?? []).firstWhere((c) => c['id'] == _selectedCabangId, orElse: () => null);
                              if (selectedCabangData != null) {
                                _cabangNameCtrl.text = selectedCabangData['nama_cabang'] ?? '';
                                _alamatCtrl.text = selectedCabangData['alamat'] ?? '';
                                _noTelpCtrl.text = selectedCabangData['no_telp'] ?? '';
                                _statusKantor = selectedCabangData['status_kantor'] ?? 'Aset';
                                
                                if (_statusKantor == 'Sewa') {
                                  _hargaSewaCtrl.text = (selectedCabangData['harga_sewa'] != null) ? selectedCabangData['harga_sewa'].toString() : '';
                                  if (selectedCabangData['awal_sewa'] != null) _awalSewa = DateTime.tryParse(selectedCabangData['awal_sewa']);
                                  if (selectedCabangData['akhir_sewa'] != null) _akhirSewa = DateTime.tryParse(selectedCabangData['akhir_sewa']);
                                } else {
                                  _hargaSewaCtrl.clear();
                                  _awalSewa = null;
                                  _akhirSewa = null;
                                }
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        _buildTextField(
                          label: 'Alamat',
                          controller: _alamatCtrl,
                          maxLines: 3,
                          validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildTextField(
                                label: 'No Telepon',
                                controller: _noTelpCtrl,
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDropdownField(
                                label: 'Status',
                                value: _statusKantor,
                                items: const [
                                  DropdownMenuItem(value: 'Aset', child: Text('Aset')),
                                  DropdownMenuItem(value: 'Sewa', child: Text('Sewa')),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _statusKantor = val as String;
                                    if (_statusKantor == 'Aset') {
                                      _hargaSewaCtrl.clear();
                                      _awalSewa = null;
                                      _akhirSewa = null;
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        _buildTextField(
                          label: 'Harga Sewa',
                          controller: _hargaSewaCtrl,
                          keyboardType: TextInputType.number,
                          hintText: 'Rp',
                          helperText: 'Kosongkan bila status Aset',
                          validator: (val) => (_statusKantor == 'Sewa' && val!.isEmpty) ? 'Wajib diisi untuk status Sewa' : null,
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildDatePicker(
                                label: 'Awal Sewa',
                                date: _awalSewa,
                                onSelected: (date) => setState(() => _awalSewa = date),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDatePicker(
                                label: 'Akhir Sewa',
                                date: _akhirSewa,
                                onSelected: (date) => setState(() => _akhirSewa = date),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),
                        
                        ElevatedButton(
                          onPressed: _isLoading ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('SIMPAN', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        const SizedBox(height: 16),
                      ],
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool readOnly = false,
    String? helperText,
    String? hintText,
    IconData? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          readOnly: readOnly,
          style: GoogleFonts.inter(color: readOnly ? AppColors.textMuted : AppColors.textDark, fontSize: 14),
          decoration: InputDecoration(
            hintText: hintText,
            helperText: helperText,
            helperStyle: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
            filled: true,
            fillColor: readOnly ? AppColors.surfaceBlue : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: readOnly ? Colors.transparent : AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: readOnly ? Colors.transparent : AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: readOnly ? Colors.transparent : AppColors.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required dynamic value,
    required List<DropdownMenuItem<dynamic>> items,
    required Function(dynamic) onChanged,
    String? hint,
    IconData? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 8),
        DropdownButtonFormField<dynamic>(
          value: value,
          hint: hint != null ? Text(hint, style: GoogleFonts.inter(color: AppColors.textMuted)) : null,
          items: items,
          onChanged: onChanged,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required Function(DateTime) onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) onSelected(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null ? DateFormat('dd/MM/yyyy').format(date) : 'mm/dd/yyyy',
                  style: GoogleFonts.inter(fontSize: 13, color: date != null ? AppColors.textDark : AppColors.textMuted),
                ),
                const Icon(Icons.calendar_today, color: AppColors.textMuted, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
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

  final List<String> _jenisTagihans = [
    'sewa', 'listrik', 'air', 'internet', 'telepon', 'kebersihan', 'keamanan', 'pajak', 'lainnya'
  ];

  @override
  void initState() {
    super.initState();
    _loadCabangs();
    _initData();
  }

  void _initData() {
    if (widget.tagihan != null) {
      final t = widget.tagihan;
      _cabangId = t['cabang_id'];
      if (t['periode'] != null) _periode = DateTime.tryParse(t['periode']);
      _jenisTagihan = t['jenis_tagihan'];
      _nominalCtrl.text = t['nominal'].toString();
      if (t['jatuh_tempo'] != null) _jatuhTempo = DateTime.tryParse(t['jatuh_tempo']);
      _statusBayar = t['status_bayar'] ?? 'Belum Bayar';
      if (t['tanggal_bayar'] != null) _tanggalBayar = DateTime.tryParse(t['tanggal_bayar']);
      if (t['nominal_dibayar'] != null) _nominalDibayarCtrl.text = t['nominal_dibayar'].toString();
      _keteranganCtrl.text = t['keterangan'] ?? '';
      _existingBuktiUrl = t['bukti_bayar_url']; // Assume backend sends full url, or we build it
    }
  }

  Future<void> _loadCabangs() async {
    try {
      final cabangs = await OperasionalTagihanService.getCabangs();
      setState(() => _cabangs = cabangs);
    } catch (e) {
      debugPrint('Error loading cabangs: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _buktiBayarFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_periode == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih periode bulanan')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = <String, dynamic>{
        'cabang_id': _cabangId,
        'periode': DateFormat('yyyy-MM-dd').format(_periode!),
        'jenis_tagihan': _jenisTagihan,
        'nominal': _nominalCtrl.text,
        'status_bayar': _statusBayar,
      };

      if (_jatuhTempo != null) data['jatuh_tempo'] = DateFormat('yyyy-MM-dd').format(_jatuhTempo!);
      if (_statusBayar == 'Lunas') {
        if (_tanggalBayar != null) data['tanggal_bayar'] = DateFormat('yyyy-MM-dd').format(_tanggalBayar!);
        data['nominal_dibayar'] = _nominalDibayarCtrl.text.isNotEmpty ? _nominalDibayarCtrl.text : _nominalCtrl.text;
      }
      if (_keteranganCtrl.text.isNotEmpty) data['keterangan'] = _keteranganCtrl.text;
      
      // Bukti upload can use multipart file in Dio
      if (_buktiBayarFile != null) {
        data['bukti_bayar'] = await _buktiBayarFile!.path; // OperasionalTagihanService needs to handle MultipartFile
      }

      if (widget.tagihan != null) {
        await OperasionalTagihanService.updateTagihan(widget.tagihan['id'], data);
      } else {
        await OperasionalTagihanService.createTagihan(data);
      }
      
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
      backgroundColor: AppColors.surface,
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
                  widget.tagihan != null ? 'Edit Tagihan' : 'Tambah Tagihan',
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
                  _buildDropdownField(
                    label: 'Cabang',
                    value: _cabangId,
                    items: _cabangs.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['nama_cabang']))).toList(),
                    onChanged: (val) => setState(() => _cabangId = val as int),
                    validator: (val) => val == null ? 'Pilih Cabang' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildDatePicker(
                    label: 'Periode (Bulan & Tahun)',
                    date: _periode,
                    onSelected: (date) => setState(() => _periode = date),
                    format: 'MMMM yyyy',
                  ),
                  const SizedBox(height: 16),
                  
                  _buildDropdownField(
                    label: 'Jenis Tagihan',
                    value: _jenisTagihan,
                    items: _jenisTagihans.map((j) => DropdownMenuItem(value: j, child: Text(j.toUpperCase()))).toList(),
                    onChanged: (val) => setState(() => _jenisTagihan = val as String),
                    validator: (val) => val == null ? 'Pilih Jenis Tagihan' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    label: 'Nominal Tagihan (Rp)',
                    controller: _nominalCtrl,
                    keyboardType: TextInputType.number,
                    validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildDatePicker(
                    label: 'Jatuh Tempo (Opsional)',
                    date: _jatuhTempo,
                    onSelected: (date) => setState(() => _jatuhTempo = date),
                  ),
                  const SizedBox(height: 16),

                  const Divider(color: AppColors.border),
                  const SizedBox(height: 16),

                  Text('Status Pembayaran', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Belum Bayar', style: GoogleFonts.inter(fontSize: 13)),
                          value: 'Belum Bayar',
                          groupValue: _statusBayar,
                          onChanged: (val) => setState(() => _statusBayar = val!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Lunas', style: GoogleFonts.inter(fontSize: 13)),
                          value: 'Lunas',
                          groupValue: _statusBayar,
                          onChanged: (val) => setState(() => _statusBayar = val!),
                        ),
                      ),
                    ],
                  ),
                  
                  if (_statusBayar == 'Lunas') ...[
                    const SizedBox(height: 16),
                    _buildDatePicker(
                      label: 'Tanggal Bayar',
                      date: _tanggalBayar,
                      onSelected: (date) => setState(() => _tanggalBayar = date),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Nominal Dibayar (Opsional)',
                      controller: _nominalDibayarCtrl,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    
                    Text('Bukti Pembayaran (Opsional)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBlue,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _buktiBayarFile != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_buktiBayarFile!, fit: BoxFit.cover))
                            : _existingBuktiUrl != null
                                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_existingBuktiUrl!, fit: BoxFit.cover))
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add_photo_alternate, color: AppColors.primary, size: 32),
                                      const SizedBox(height: 8),
                                      Text('Upload Foto', style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary)),
                                    ],
                                  ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Keterangan (Opsional)',
                    controller: _keteranganCtrl,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  
                  ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5E5CE6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('SIMPAN', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(height: 40),
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
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
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
    String? Function(dynamic)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 8),
        DropdownButtonFormField<dynamic>(
          value: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
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
    String format = 'dd MMM yyyy',
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null ? DateFormat(format).format(date) : 'Pilih Tanggal',
                  style: GoogleFonts.inter(fontSize: 14, color: date != null ? AppColors.textDark : AppColors.textMuted),
                ),
                const Icon(Icons.calendar_today, color: AppColors.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

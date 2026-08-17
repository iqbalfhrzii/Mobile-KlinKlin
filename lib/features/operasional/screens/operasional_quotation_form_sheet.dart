import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../services/operasional_quotation_service.dart';

class OperasionalQuotationFormSheet extends StatefulWidget {
  final dynamic initialData;
  final VoidCallback onSave;

  const OperasionalQuotationFormSheet({
    super.key,
    this.initialData,
    required this.onSave,
  });

  @override
  State<OperasionalQuotationFormSheet> createState() => _OperasionalQuotationFormSheetState();
}

class _OperasionalQuotationFormSheetState extends State<OperasionalQuotationFormSheet> {
  final _service = OperasionalQuotationService();
  
  bool _isLoading = false;
  
  // Controllers
  final _tanggalController = TextEditingController();
  final _expDateController = TextEditingController();
  final _namaCustomerController = TextEditingController();
  final _noWaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _jobLocationController = TextEditingController();
  final _diskonController = TextEditingController(text: '0');
  
  bool _alatChemical = true;
  bool _usePpn = true;
  bool _usePph = false;
  
  List<Map<String, dynamic>> _rincian = [];
  
  int? _cabangId;

  @override
  void initState() {
    super.initState();
    _initData();
  }
  
  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    final userCabangId = prefs.getInt('user_cabang_id');
    if (userCabangId != null) {
      _cabangId = userCabangId;
    }

    if (widget.initialData != null) {
      final data = widget.initialData;
      _tanggalController.text = data['tanggal']?.toString().split(' ')[0] ?? '';
      _expDateController.text = data['exp_date']?.toString().split(' ')[0] ?? '';
      _namaCustomerController.text = data['nama_customer'] ?? '';
      _noWaController.text = data['no_wa_customer'] ?? '';
      _alamatController.text = data['alamat'] ?? '';
      _jobLocationController.text = data['job_location'] ?? '';
      _diskonController.text = (data['diskon'] ?? 0).toString();
      _alatChemical = data['alat_chemical_klinklin'] == 1 || data['alat_chemical_klinklin'] == true;
      _usePpn = (data['ppn'] ?? 0) > 0;
      _usePph = (data['pph'] ?? 0) > 0;
      _cabangId = data['cabang_id'] ?? _cabangId;
      
      if (data['rincian'] != null) {
        if (data['rincian'] is List) {
           _rincian = List<Map<String, dynamic>>.from(data['rincian'].map((item) => {
             'deskripsi': TextEditingController(text: item['deskripsi']),
             'qty': TextEditingController(text: item['qty'].toString()),
             'harga': TextEditingController(text: item['harga'].toString()),
           }));
        } else if (data['rincian'] is String) {
          // If stored as JSON string
          // Parse logic here if needed
        }
      }
    } else {
      _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _expDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 14)));
      _rincian.add(_createEmptyRincian());
    }
  }

  Map<String, dynamic> _createEmptyRincian() {
    return {
      'deskripsi': TextEditingController(),
      'qty': TextEditingController(text: '1'),
      'harga': TextEditingController(text: '0'),
    };
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _expDateController.dispose();
    _namaCustomerController.dispose();
    _noWaController.dispose();
    _alamatController.dispose();
    _jobLocationController.dispose();
    _diskonController.dispose();
    for (var item in _rincian) {
      item['deskripsi'].dispose();
      item['qty'].dispose();
      item['harga'].dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  double get _subtotal {
    double total = 0;
    for (var item in _rincian) {
      double qty = double.tryParse(item['qty'].text) ?? 0;
      double harga = double.tryParse(item['harga'].text) ?? 0;
      total += (qty * harga);
    }
    return total;
  }

  double get _grandTotal {
    double diskon = double.tryParse(_diskonController.text) ?? 0;
    double dasar = (_subtotal - diskon).clamp(0, double.infinity);
    double ppnVal = _usePpn ? dasar * 0.11 : 0;
    double pphVal = _usePph ? dasar * 0.02 : 0;
    return dasar + ppnVal - pphVal;
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  Future<void> _save() async {
    if (_namaCustomerController.text.isEmpty || _tanggalController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi field yang wajib (*)'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final rincianList = _rincian.map((e) => {
      'deskripsi': e['deskripsi'].text,
      'qty': double.tryParse(e['qty'].text) ?? 0,
      'harga': double.tryParse(e['harga'].text) ?? 0,
    }).toList();

    final data = {
      'tanggal': _tanggalController.text,
      'exp_date': _expDateController.text,
      'cabang_id': _cabangId ?? 1,
      'nama_customer': _namaCustomerController.text,
      'no_wa_customer': _noWaController.text,
      'alamat': _alamatController.text,
      'job_location': _jobLocationController.text,
      'alat_chemical_klinklin': _alatChemical ? 1 : 0,
      'diskon': double.tryParse(_diskonController.text) ?? 0,
      'ppn': _usePpn ? 11 : 0,
      'pph': _usePph ? 2 : 0,
      'rincian': rincianList,
    };

    Map<String, dynamic> res;
    if (widget.initialData != null) {
      res = await _service.updateQuotation(widget.initialData['id'], data);
    } else {
      res = await _service.storeQuotation(data);
    }

    setState(() => _isLoading = false);

    if (res['status'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Berhasil disimpan'), backgroundColor: Colors.green),
      );
      widget.onSave();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Gagal menyimpan'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool required = false, bool readOnly = false, VoidCallback? onTap, int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
            children: required ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))] : [],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: readOnly && onTap == null ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit_document, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      widget.initialData != null ? 'Edit Penawaran' : 'Buat Penawaran Baru',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Form Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('INFORMASI PENAWARAN'),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Tanggal', _tanggalController, required: true, readOnly: true, onTap: () => _selectDate(_tanggalController))),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Exp Date', _expDateController, required: true, readOnly: true, onTap: () => _selectDate(_expDateController))),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle('DATA CUSTOMER'),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Nama Customer', _namaCustomerController, required: true)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('No WA Customer', _noWaController, keyboardType: TextInputType.phone)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField('Alamat Customer', _alamatController, required: true, maxLines: 2),
                  const SizedBox(height: 16),
                  _buildTextField('Job Location', _jobLocationController, maxLines: 2),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle('RINCIAN PENAWARAN'),
                  
                  // Dynamic list
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _rincian.length,
                    itemBuilder: (context, index) {
                      final item = _rincian[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildTextField('Deskripsi', item['deskripsi']),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: _buildTextField('Qty', item['qty'], keyboardType: TextInputType.number),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: _buildTextField('Harga', item['harga'], keyboardType: TextInputType.number),
                            ),
                            if (_rincian.length > 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 28, left: 4),
                                child: InkWell(
                                  onTap: () => setState(() => _rincian.removeAt(index)),
                                  child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _rincian.add(_createEmptyRincian())),
                      icon: const Icon(Icons.add, size: 16, color: Colors.green),
                      label: Text('Tambah Baris Rincian', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Totals Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _alatChemical,
                                        onChanged: (v) => setState(() => _alatChemical = v ?? false),
                                        activeColor: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Alat & Chemical dari Klinklin', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                          Text('Akan tercetak di dokumen', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                children: [
                                  _buildTextField('Diskon Tambahan (Rp)', _diskonController, keyboardType: TextInputType.number),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CheckboxListTile(
                                          title: Text('PPN (11%)', style: GoogleFonts.inter(fontSize: 11)),
                                          value: _usePpn,
                                          onChanged: (v) => setState(() => _usePpn = v ?? false),
                                          controlAffinity: ListTileControlAffinity.leading,
                                          contentPadding: EdgeInsets.zero,
                                          activeColor: AppColors.primary,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      Expanded(
                                        child: CheckboxListTile(
                                          title: Text('PPh (2%)', style: GoogleFonts.inter(fontSize: 11)),
                                          value: _usePph,
                                          onChanged: (v) => setState(() => _usePph = v ?? false),
                                          controlAffinity: ListTileControlAffinity.leading,
                                          contentPadding: EdgeInsets.zero,
                                          activeColor: AppColors.primary,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(),
                        ),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('GRAND TOTAL', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                            Text(_formatCurrency(_grandTotal), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Footer Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Batal', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Simpan Perubahan', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

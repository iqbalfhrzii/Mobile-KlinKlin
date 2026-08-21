import 'dart:convert';
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
  bool _isLoadingCabangs = true;
  
  // Controllers
  final _noQuotationController = TextEditingController();
  final _tanggalController = TextEditingController();
  final _expDateController = TextEditingController();
  final _namaCustomerController = TextEditingController();
  final _noWaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _jobLocationController = TextEditingController();
  final _diskonController = TextEditingController(text: '0');
  
  bool _sameAsCustomerAddress = false;
  bool _alatChemical = true;
  bool _usePpn = false;
  bool _usePph = false;
  
  List<Map<String, dynamic>> _rincian = [];
  List<dynamic> _cabangs = [];
  
  int? _cabangId;
  String _userRole = '';
  bool _isOperasionalOrAdmin = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }
  
  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    final r = _userRole.toLowerCase();
    _isOperasionalOrAdmin = r.contains('operasional') || r.contains('admin') || r.contains('ceo') || r.contains('superadmin');
    
    final userCabangId = prefs.getInt('user_cabang_id');
    if (userCabangId != null) {
      _cabangId = userCabangId;
    }

    try {
      final cabangs = await _service.getCabangs();
      if (mounted) {
        setState(() {
          _cabangs = cabangs;
          _isLoadingCabangs = false;
          if (_cabangId == null && _cabangs.isNotEmpty) {
            _cabangId = _cabangs.first['id'];
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCabangs = false);
    }

    if (widget.initialData != null) {
      final data = widget.initialData;
      _noQuotationController.text = data['no_quotation'] ?? '';
      _tanggalController.text = data['tanggal']?.toString().split('T')[0].split(' ')[0] ?? '';
      _expDateController.text = data['exp_date']?.toString().split('T')[0].split(' ')[0] ?? '';
      _namaCustomerController.text = data['nama_customer'] ?? '';
      _noWaController.text = data['no_wa_customer'] ?? '';
      _alamatController.text = data['alamat'] ?? '';
      _jobLocationController.text = data['job_location'] ?? '';
      
      final diskonRaw = (data['diskon'] ?? 0).toString();
      _diskonController.text = diskonRaw.contains('.') ? diskonRaw.split('.')[0] : diskonRaw;
      
      _alatChemical = data['alat_chemical_klinklin'] == 1 || data['alat_chemical_klinklin'] == true || data['alat_chemical_klinklin'] == '1';
      
      final num ppnNum = num.tryParse(data['ppn']?.toString() ?? '0') ?? 0;
      final num pphNum = num.tryParse(data['pph']?.toString() ?? '0') ?? 0;
      _usePpn = ppnNum > 0;
      _usePph = pphNum > 0;
      
      _cabangId = data['cabang_id'] ?? _cabangId;
      
      dynamic rawRincian = data['rincian'];
      if (rawRincian is String) {
        try {
          rawRincian = jsonDecode(rawRincian);
        } catch (_) {}
      }
      
      _rincian = [];
      if (rawRincian is List && rawRincian.isNotEmpty) {
        for (var item in rawRincian) {
          final deskripsi = item['deskripsi']?.toString() ?? '';
          final qty = (item['qty'] ?? 1).toString();
          final hargaRaw = (item['harga'] ?? 0).toString();
          final harga = hargaRaw.contains('.') ? hargaRaw.split('.')[0] : hargaRaw;
          _rincian.add({
            'deskripsi': TextEditingController(text: deskripsi),
            'qty': TextEditingController(text: qty),
            'harga': TextEditingController(text: harga),
          });
        }
      }
      
      if (_rincian.isEmpty) {
        _rincian.add(_createEmptyRincian());
      }
    } else {
      _noQuotationController.text = 'Terisi otomatis (Auto Generate)';
      _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _expDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 14)));
      _usePpn = false;
      _usePph = false;
      _rincian = [_createEmptyRincian()];
    }

    if (mounted) setState(() {});
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
    _noQuotationController.dispose();
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
    if (_namaCustomerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama Customer wajib diisi!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_alamatController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alamat Customer wajib diisi!'), backgroundColor: Colors.red),
      );
      return;
    }

    final validRincian = _rincian.where((e) => e['deskripsi'].text.trim().isNotEmpty).toList();
    if (validRincian.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal ada 1 rincian layanan/barang yang diisi!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final rincianList = validRincian.map((e) => {
      'deskripsi': e['deskripsi'].text.trim(),
      'qty': double.tryParse(e['qty'].text) ?? 1,
      'harga': double.tryParse(e['harga'].text) ?? 0,
    }).toList();

    final data = {
      'tanggal': _tanggalController.text,
      'exp_date': _expDateController.text,
      'cabang_id': _cabangId ?? 1,
      'nama_customer': _namaCustomerController.text.trim(),
      'no_wa_customer': _noWaController.text.trim(),
      'alamat': _alamatController.text.trim(),
      'job_location': _sameAsCustomerAddress ? _alamatController.text.trim() : _jobLocationController.text.trim(),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Penawaran berhasil disimpan'), backgroundColor: Colors.green),
        );
        widget.onSave();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gagal menyimpan penawaran'), backgroundColor: Colors.red),
        );
      }
    }
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
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMid.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.request_quote_rounded, color: AppColors.primaryMid, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.initialData != null ? 'Edit Penawaran' : 'Buat Penawaran Baru',
                      style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
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
                  // 1. INFORMASI PENAWARAN
                  _buildSectionTitle('INFORMASI PENAWARAN'),
                  
                  if (widget.initialData == null) ...[
                    // No Quotation & Cabang Row (Hanya muncul saat Buat Penawaran Baru)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildTextField(
                            'No Quotation',
                            _noQuotationController,
                            required: true,
                            readOnly: true,
                            hintText: 'Auto Generate',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  text: 'Cabang',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                  children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (!_isOperasionalOrAdmin && _cabangId != null && _cabangs.isNotEmpty)
                                Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 14, color: AppColors.primaryMid),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _cabangs.firstWhere((c) => c['id'] == _cabangId, orElse: () => {'nama_cabang': 'Cabang $_cabangId'})['nama_cabang'] ??
                                              _cabangs.firstWhere((c) => c['id'] == _cabangId, orElse: () => {'nama': 'Cabang $_cabangId'})['nama'] ??
                                              'Cabang $_cabangId',
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: _isLoadingCabangs
                                      ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                                      : DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: _cabangId,
                                            isExpanded: true,
                                            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                                            items: _cabangs.map((c) {
                                              return DropdownMenuItem<int>(
                                                value: c['id'],
                                                child: Text(c['nama_cabang'] ?? c['nama'] ?? 'Cabang ${c['id']}'),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              if (val != null) setState(() => _cabangId = val);
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
                  ],

                  // Tanggal & Exp Date Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'Tanggal',
                          _tanggalController,
                          required: true,
                          readOnly: true,
                          suffixIcon: Icons.calendar_today_outlined,
                          onTap: () => _selectDate(_tanggalController),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          'Exp Date',
                          _expDateController,
                          required: true,
                          readOnly: true,
                          suffixIcon: Icons.event_busy_outlined,
                          onTap: () => _selectDate(_expDateController),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  // 2. DATA CUSTOMER
                  _buildSectionTitle('DATA CUSTOMER'),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'Nama Customer',
                          _namaCustomerController,
                          required: true,
                          hintText: 'Nama Perorangan / PT',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          'No WA Customer',
                          _noWaController,
                          keyboardType: TextInputType.phone,
                          hintText: '08xxxxxxxxxx',
                          suffixIcon: Icons.chat_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    'Alamat Customer',
                    _alamatController,
                    required: true,
                    maxLines: 2,
                    hintText: 'Alamat lengkap tempat tinggal/kantor customer...',
                  ),
                  const SizedBox(height: 14),
                  
                  // Job Location with Auto-fill check
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Job Location (Lokasi Pengerjaan)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _sameAsCustomerAddress = !_sameAsCustomerAddress;
                            if (_sameAsCustomerAddress) {
                              _jobLocationController.text = _alamatController.text;
                            }
                          });
                        },
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _sameAsCustomerAddress,
                                onChanged: (v) {
                                  setState(() {
                                    _sameAsCustomerAddress = v ?? false;
                                    if (_sameAsCustomerAddress) {
                                      _jobLocationController.text = _alamatController.text;
                                    }
                                  });
                                },
                                activeColor: AppColors.primaryMid,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('Sama dg alamat', style: GoogleFonts.inter(fontSize: 11, color: AppColors.primaryMid, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: _sameAsCustomerAddress ? Colors.grey.shade100 : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _jobLocationController,
                      maxLines: 2,
                      readOnly: _sameAsCustomerAddress,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Kosongkan bila sama dengan alamat customer...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  // 3. RINCIAN PENAWARAN
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('RINCIAN PENAWARAN'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryMid.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_rincian.length} Baris',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryMid),
                        ),
                      ),
                    ],
                  ),
                  
                  // Dynamic Items List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _rincian.length,
                    itemBuilder: (context, index) {
                      final item = _rincian[index];
                      final qty = double.tryParse(item['qty'].text) ?? 0;
                      final harga = double.tryParse(item['harga'].text) ?? 0;
                      final rowTotal = qty * harga;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                                  child: Text('#${index + 1}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Layanan / Barang', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                ),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      final removed = _rincian.removeAt(index);
                                      removed['deskripsi'].dispose();
                                      removed['qty'].dispose();
                                      removed['harga'].dispose();
                                      if (_rincian.isEmpty) {
                                        _rincian.add(_createEmptyRincian());
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 16),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildSimpleInput(
                              controller: item['deskripsi'],
                              hint: 'Contoh: Cuci Kasur King Size, Fogging Disinfektan...',
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Qty', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                      const SizedBox(height: 4),
                                      _buildSimpleInput(
                                        controller: item['qty'],
                                        keyboardType: TextInputType.number,
                                        hint: '1',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Harga Satuan (Rp)', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                      const SizedBox(height: 4),
                                      _buildSimpleInput(
                                        controller: item['harga'],
                                        keyboardType: TextInputType.number,
                                        hint: '0',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Subtotal', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatCurrency(rowTotal),
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryMid),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  // Add Item Button
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _rincian.add(_createEmptyRincian())),
                    icon: const Icon(Icons.add, size: 16, color: AppColors.primaryMid),
                    label: Text('Tambah Baris Rincian', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryMid)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryMid),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 4. OPSI & PERHITUNGAN BIAYA
                  _buildSectionTitle('OPSI & PERHITUNGAN BIAYA'),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        // Alat Chemical Checkbox
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _alatChemical,
                                  onChanged: (v) => setState(() => _alatChemical = v ?? false),
                                  activeColor: AppColors.primaryMid,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Alat & Chemical dari Klinklin', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                    Text('Bila dicentang, catatan ini tercetak di dokumen', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Diskon Input
                        _buildTextField('Diskon Tambahan (Rp)', _diskonController, keyboardType: TextInputType.number, hintText: '0'),
                        const SizedBox(height: 8),

                        // PPN & PPh Checkboxes
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _usePpn,
                                      onChanged: (v) => setState(() => _usePpn = v ?? false),
                                      activeColor: AppColors.primaryMid,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Text('PPN (11%)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _usePph,
                                      onChanged: (v) => setState(() => _usePph = v ?? false),
                                      activeColor: AppColors.primaryMid,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Text('PPh (2%)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(),
                        ),
                        
                        // Live Summary Table
                        _buildSummaryRow('Subtotal', _formatCurrency(_subtotal)),
                        if (double.tryParse(_diskonController.text) != null && double.parse(_diskonController.text) > 0) ...[
                          const SizedBox(height: 4),
                          _buildSummaryRow('Diskon', '- ${_formatCurrency(double.parse(_diskonController.text))}', color: Colors.red),
                        ],
                        if (_usePpn) ...[
                          const SizedBox(height: 4),
                          _buildSummaryRow('PPN (11%)', '+ ${_formatCurrency((_subtotal - (double.tryParse(_diskonController.text) ?? 0)).clamp(0, double.infinity) * 0.11)}'),
                        ],
                        if (_usePph) ...[
                          const SizedBox(height: 4),
                          _buildSummaryRow('PPh (2%)', '- ${_formatCurrency((_subtotal - (double.tryParse(_diskonController.text) ?? 0)).clamp(0, double.infinity) * 0.02)}', color: Colors.red),
                        ],
                        const SizedBox(height: 10),

                        // Highlighted Grand Total Banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryMid.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primaryMid.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('GRAND TOTAL', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryMid)),
                              Text(_formatCurrency(_grandTotal), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryMid)),
                            ],
                          ),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Batal', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryMid,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            widget.initialData != null ? 'Simpan Perubahan' : 'Simpan Penawaran',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleInput({
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(fontSize: 12),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
        Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color ?? AppColors.textDark)),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool required = false,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hintText,
    IconData? suffixIcon,
  }) {
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
        const SizedBox(height: 6),
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
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              suffixIcon: suffixIcon != null ? Icon(suffixIcon, size: 18, color: Colors.grey.shade600) : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryMid,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

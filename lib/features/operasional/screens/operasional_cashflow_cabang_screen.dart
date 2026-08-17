import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../services/operasional_cashflow_cabang_service.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }
    double value = double.parse(newValue.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final formatter = NumberFormat.currency(
        locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    String newText = formatter.format(value);
    return newValue.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length));
  }
}

class OperasionalCashflowCabangScreen extends StatefulWidget {
  const OperasionalCashflowCabangScreen({super.key});

  @override
  State<OperasionalCashflowCabangScreen> createState() => _OperasionalCashflowCabangScreenState();
}

class _OperasionalCashflowCabangScreenState extends State<OperasionalCashflowCabangScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _cashflows = [];
  List<dynamic> _cabangList = [];
  bool _isLoading = false;
  
  int? _selectedCabangId;
  String _selectedArus = 'Semua Arus';
  
  final List<String> _arusOptions = ['Semua Arus', 'Masuk', 'Keluar'];

  @override
  void initState() {
    super.initState();
    _fetchCabangList();
    _fetchData();
  }

  Future<void> _fetchCabangList() async {
    try {
      final response = await OperasionalCashflowCabangService.getCabangs();
      if (response['success'] == true) {
        setState(() {
          _cabangList = response['data'] ?? [];
        });
      }
    } catch (e) {
      print('Error fetching cabang: $e');
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final response = await OperasionalCashflowCabangService.getCashflow(
        search: _searchController.text,
        cabangId: _selectedCabangId,
        arus: _selectedArus,
      );
      if (response['success'] == true) {
        setState(() {
          _cashflows = response['data'] ?? [];
        });
      }
    } catch (e) {
      print('Error fetching cashflow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat data cashflow')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteCashflow(int id) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Data'),
        content: const Text('Yakin ingin menghapus data cashflow ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      final response = await OperasionalCashflowCabangService.deleteCashflow(id);
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data berhasil dihapus')),
          );
        }
        _fetchData();
      }
    } catch (e) {
      print('Error deleting cashflow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus data')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showFormBottomSheet({Map<String, dynamic>? data}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FormCashflowBottomSheet(
        data: data,
        cabangList: _cabangList,
        onSaved: () {
          _fetchData();
        },
      ),
    );
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return 'Rp 0';
    try {
      double parsedValue = double.parse(value.toString());
      final format = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
      return format.format(parsedValue);
    } catch (e) {
      return 'Rp 0';
    }
  }

  String _formatDate(String? date) {
    if (date == null) return '-';
    try {
      DateTime dt = DateTime.parse(date);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (e) {
      return date;
    }
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF005B9F) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF005B9F) : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF005B9F).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Data Cashflow Cabang',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF005B9F),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Header Background with Search and Filter
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF005B9F),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => _fetchData(),
                    decoration: InputDecoration(
                      hintText: 'Cari keterangan atau kategori...',
                      hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
                      border: InputBorder.none,
                      icon: const Icon(Icons.search, color: Color(0xFF005B9F)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Filter Cabang
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _selectedCabangId,
                            hint: Text('Semua Cabang', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
                            dropdownColor: const Color(0xFF005B9F),
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Semua Cabang'),
                              ),
                              ..._cabangList.map((cabang) {
                                return DropdownMenuItem<int?>(
                                  value: cabang['id'],
                                  child: Text(cabang['nama_cabang']),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedCabangId = value;
                              });
                              _fetchData();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Filter Arus (Masuk / Keluar)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _arusOptions.map((arus) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildFilterChip(
                          arus,
                          _selectedArus == arus,
                          () {
                            setState(() {
                              _selectedArus = arus;
                            });
                            _fetchData();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _cashflows.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.money_off, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada data cashflow',
                              style: GoogleFonts.inter(
                                color: Colors.grey.shade500,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _cashflows.length,
                          itemBuilder: (context, index) {
                            final item = _cashflows[index];
                            final isMasuk = item['arus'] == 'Masuk' || item['arus']?.toString().contains('Masuk') == true;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 15,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    // Buka opsi edit/hapus
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Top Row: Arus and Date
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isMasuk
                                                    ? Colors.green.withOpacity(0.1)
                                                    : Colors.red.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isMasuk ? Icons.arrow_downward : Icons.arrow_upward,
                                                    size: 14,
                                                    color: isMasuk ? Colors.green : Colors.red,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    isMasuk ? 'Masuk' : 'Keluar',
                                                    style: GoogleFonts.inter(
                                                      color: isMasuk ? Colors.green : Colors.red,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              _formatDate(item['tanggal']),
                                              style: GoogleFonts.inter(
                                                color: Colors.grey.shade500,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // Nominal
                                        Text(
                                          _formatCurrency(item['nominal']),
                                          style: GoogleFonts.inter(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF2D3142),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Category and Method
                                        Row(
                                          children: [
                                            Icon(Icons.category_outlined, size: 14, color: Colors.grey.shade500),
                                            const SizedBox(width: 4),
                                            Text(
                                              item['kategori_kas'] ?? '-',
                                              style: GoogleFonts.inter(
                                                color: Colors.grey.shade700,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Icon(Icons.payment_outlined, size: 14, color: Colors.grey.shade500),
                                            const SizedBox(width: 4),
                                            Text(
                                              item['metode'] ?? '-',
                                              style: GoogleFonts.inter(
                                                color: Colors.grey.shade700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // Description
                                        if (item['keterangan'] != null && item['keterangan'].toString().isNotEmpty) ...[
                                          Text(
                                            item['keterangan'],
                                            style: GoogleFonts.inter(
                                              color: Colors.grey.shade600,
                                              fontSize: 13,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        const Divider(),
                                        // Bottom row: Cabang and Actions
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.location_on, size: 14, color: Color(0xFF005B9F)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  item['cabang']?['nama_cabang'] ?? 'Unknown',
                                                  style: GoogleFonts.inter(
                                                    color: const Color(0xFF005B9F),
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                if (item['bukti'] != null)
                                                  IconButton(
                                                    icon: const Icon(Icons.attach_file, color: Colors.grey, size: 20),
                                                    onPressed: () {
                                                      // Opsi buka bukti
                                                    },
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                const SizedBox(width: 12),
                                                IconButton(
                                                  icon: const Icon(Icons.edit_outlined, color: Colors.orange, size: 20),
                                                  onPressed: () => _showFormBottomSheet(data: item),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                                const SizedBox(width: 12),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                                  onPressed: () => _deleteCashflow(item['id']),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                              ],
                                            )
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormBottomSheet(),
        backgroundColor: const Color(0xFF005B9F),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Tambah Data', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _FormCashflowBottomSheet extends StatefulWidget {
  final Map<String, dynamic>? data;
  final List<dynamic> cabangList;
  final VoidCallback onSaved;

  const _FormCashflowBottomSheet({
    this.data,
    required this.cabangList,
    required this.onSaved,
  });

  @override
  State<_FormCashflowBottomSheet> createState() => _FormCashflowBottomSheetState();
}

class _FormCashflowBottomSheetState extends State<_FormCashflowBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final TextEditingController _tanggalController = TextEditingController();
  final TextEditingController _kategoriController = TextEditingController();
  final TextEditingController _nominalController = TextEditingController();
  final TextEditingController _metodeController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();

  int? _selectedCabangId;
  String? _selectedArus;
  
  File? _selectedFile;
  String? _fileName;

  final List<String> _arusOptions = ['Masuk', 'Keluar'];

  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      _tanggalController.text = widget.data!['tanggal'] ?? '';
      _selectedCabangId = widget.data!['cabang_id'];
      
      String arusData = widget.data!['arus'] ?? '';
      if (arusData.contains('Masuk')) _selectedArus = 'Masuk';
      else if (arusData.contains('Keluar')) _selectedArus = 'Keluar';
      
      _kategoriController.text = widget.data!['kategori_kas'] ?? '';
      
      double nom = double.tryParse(widget.data!['nominal']?.toString() ?? '0') ?? 0;
      final format = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
      _nominalController.text = format.format(nom);
      
      _metodeController.text = widget.data!['metode'] ?? '';
      _keteranganController.text = widget.data!['keterangan'] ?? '';
      
      if (widget.data!['bukti'] != null) {
        _fileName = widget.data!['bukti'].toString().split('/').last;
      }
    } else {
      _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? initialDate;
    if (_tanggalController.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(_tanggalController.text);
      } catch (e) {
        initialDate = DateTime.now();
      }
    } else {
      initialDate = DateTime.now();
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF005B9F),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _tanggalController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _fileName = result.files.single.name;
        });
      }
    } catch (e) {
      print('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memilih file')),
      );
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCabangId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cabang harus dipilih')));
      return;
    }
    if (_selectedArus == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arus kas harus dipilih')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Clean nominal
      String nominalStr = _nominalController.text.replaceAll(RegExp(r'[^0-9]'), '');

      final data = {
        'tanggal': _tanggalController.text,
        'cabang_id': _selectedCabangId.toString(),
        'arus': _selectedArus,
        'kategori_kas': _kategoriController.text,
        'nominal': nominalStr,
        'metode': _metodeController.text,
        'keterangan': _keteranganController.text,
      };

      if (widget.data == null) {
        await OperasionalCashflowCabangService.createCashflow(data, file: _selectedFile);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data berhasil ditambahkan')));
        }
      } else {
        await OperasionalCashflowCabangService.updateCashflow(widget.data!['id'], data, file: _selectedFile);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data berhasil diperbarui')));
        }
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      print('Error saving cashflow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan data')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: GoogleFonts.inter(
              color: const Color(0xFF2D3142),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            children: [
              if (validator != null)
                TextSpan(
                  text: ' *',
                  style: GoogleFonts.inter(color: Colors.red),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF2D3142)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade500) : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: maxLines > 1 ? 16 : 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF005B9F), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF005B9F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.money, color: Color(0xFF005B9F), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.data == null ? 'Tambah Cashflow' : 'Edit Cashflow',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2D3142),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: _tanggalController,
                        label: 'Tanggal',
                        hint: 'Pilih Tanggal',
                        icon: Icons.calendar_today_outlined,
                        readOnly: true,
                        onTap: () => _selectDate(context),
                        validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Cabang
                      RichText(
                        text: TextSpan(
                          text: 'Cabang',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF2D3142),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            TextSpan(text: ' *', style: GoogleFonts.inter(color: Colors.red)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _selectedCabangId,
                        hint: Text('Pilih Cabang', style: GoogleFonts.inter(color: Colors.grey.shade400)),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        items: widget.cabangList.map<DropdownMenuItem<int>>((cabang) {
                          return DropdownMenuItem<int>(
                            value: cabang['id'],
                            child: Text(cabang['nama_cabang']),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedCabangId = value),
                        validator: (v) => v == null ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),

                      // Arus Kas
                      RichText(
                        text: TextSpan(
                          text: 'Arus Kas',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF2D3142),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            TextSpan(text: ' *', style: GoogleFonts.inter(color: Colors.red)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedArus,
                        hint: Text('Masuk (Pemasukan) / Keluar (Pengeluaran)', style: GoogleFonts.inter(color: Colors.grey.shade400)),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        items: _arusOptions.map<DropdownMenuItem<String>>((arus) {
                          return DropdownMenuItem<String>(
                            value: arus,
                            child: Text(arus == 'Masuk' ? 'Masuk (Pemasukan)' : 'Keluar (Pengeluaran)'),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedArus = value),
                        validator: (v) => v == null ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _nominalController,
                        label: 'Nominal',
                        hint: 'Rp 0',
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyInputFormatter()],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Wajib diisi';
                          if (v == 'Rp 0') return 'Nominal tidak boleh 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _kategoriController,
                        label: 'Kategori Kas',
                        hint: 'mis. Biaya Operasional',
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _metodeController,
                        label: 'Metode Pembayaran',
                        hint: 'mis. Cash, Transfer Bank',
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _keteranganController,
                        label: 'Keterangan',
                        hint: 'Tambahkan catatan jika diperlukan...',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Bukti File
                      Text(
                        'Bukti',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF2D3142),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickFile,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F1F8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Choose File',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF005B9F),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _fileName ?? 'No file chosen',
                                  style: GoogleFonts.inter(
                                    color: _fileName != null ? const Color(0xFF2D3142) : Colors.grey.shade500,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_fileName != null && _selectedFile == null)
                        Text(
                          'File saat ini: $_fileName',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.blue),
                        ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            
            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.inter(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005B9F),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Simpan Data',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
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
}

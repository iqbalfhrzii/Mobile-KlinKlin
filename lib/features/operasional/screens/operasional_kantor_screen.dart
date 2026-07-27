import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/operasional_service.dart';

class OperasionalKantorScreen extends StatefulWidget {
  const OperasionalKantorScreen({super.key});

  @override
  State<OperasionalKantorScreen> createState() => _OperasionalKantorScreenState();
}

class _OperasionalKantorScreenState extends State<OperasionalKantorScreen> {
  final _service = OperasionalService();
  bool _isLoading = true;
  String _error = '';
  List<dynamic> _cabangs = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final res = await _service.getCabangs();
      setState(() {
        _cabangs = res['data'] ?? [];
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '-';
    final numVal = num.tryParse(value.toString()) ?? 0;
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(numVal);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return '-';
    }
  }

  void _showEditDialog(Map<String, dynamic>? cabang) {
    String? selectedCabangId = cabang != null ? cabang['id'].toString() : null;
    final alamatController = TextEditingController(text: cabang?['alamat'] ?? '');
    final noTelpController = TextEditingController(text: cabang?['no_telp'] ?? '');
    String selectedStatus = cabang?['status_kantor'] ?? 'Sewa';
    final hargaSewaController = TextEditingController(
      text: cabang?['harga_sewa'] != null ? num.parse(cabang!['harga_sewa'].toString()).toInt().toString() : ''
    );
    DateTime? awalSewa = cabang?['awal_sewa'] != null ? DateTime.tryParse(cabang!['awal_sewa']) : null;
    DateTime? akhirSewa = cabang?['akhir_sewa'] != null ? DateTime.tryParse(cabang!['akhir_sewa']) : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(
                cabang == null ? 'Tambah Kantor Klinklin' : 'Edit Kantor Klinklin',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cabang *', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedCabangId,
                          hint: Text('Pilih Cabang', style: GoogleFonts.inter(fontSize: 14)),
                          items: _cabangs.map((c) {
                            return DropdownMenuItem<String>(
                              value: c['id'].toString(),
                              child: Text(c['nama_cabang'], style: GoogleFonts.inter(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: cabang != null ? null : (val) {
                            setModalState(() {
                              selectedCabangId = val;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Alamat *', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: alamatController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No Telepon', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: noTelpController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                                style: GoogleFonts.inter(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Status', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: selectedStatus,
                                    items: ['Aset', 'Sewa'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.inter(fontSize: 14)))).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setModalState(() => selectedStatus = val);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Harga Sewa', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: hargaSewaController,
                      keyboardType: TextInputType.number,
                      enabled: selectedStatus == 'Sewa',
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text('Kosongkan bila status Aset', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Awal Sewa', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark)),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: selectedStatus == 'Aset' ? null : () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: awalSewa ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2050),
                                  );
                                  if (date != null) {
                                    setModalState(() => awalSewa = date);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                    color: selectedStatus == 'Aset' ? Colors.grey.shade100 : Colors.white,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        awalSewa != null ? DateFormat('MM/dd/yyyy').format(awalSewa!) : 'mm/dd/yyyy',
                                        style: GoogleFonts.inter(fontSize: 14, color: awalSewa != null ? AppColors.textDark : Colors.grey),
                                      ),
                                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Akhir Sewa', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark)),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: selectedStatus == 'Aset' ? null : () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: akhirSewa ?? (awalSewa ?? DateTime.now()),
                                    firstDate: awalSewa ?? DateTime(2000),
                                    lastDate: DateTime(2050),
                                  );
                                  if (date != null) {
                                    setModalState(() => akhirSewa = date);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                    color: selectedStatus == 'Aset' ? Colors.grey.shade100 : Colors.white,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        akhirSewa != null ? DateFormat('MM/dd/yyyy').format(akhirSewa!) : 'mm/dd/yyyy',
                                        style: GoogleFonts.inter(fontSize: 14, color: akhirSewa != null ? AppColors.textDark : Colors.grey),
                                      ),
                                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedCabangId == null || alamatController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cabang dan Alamat harus diisi')));
                      return;
                    }

                    final data = {
                      'alamat': alamatController.text.trim(),
                      'no_telp': noTelpController.text.trim(),
                      'status_kantor': selectedStatus,
                    };

                    if (selectedStatus == 'Sewa') {
                      data['harga_sewa'] = hargaSewaController.text.trim();
                      if (awalSewa != null) data['awal_sewa'] = DateFormat('yyyy-MM-dd').format(awalSewa!);
                      if (akhirSewa != null) data['akhir_sewa'] = DateFormat('yyyy-MM-dd').format(akhirSewa!);
                    }

                    try {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (c) => const Center(child: CircularProgressIndicator()),
                      );
                      
                      await _service.updateKantor(int.parse(selectedCabangId!), data);
                      
                      if (context.mounted) {
                        Navigator.pop(context); // close loading
                        Navigator.pop(context); // close dialog
                        _fetchData();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kantor berhasil diperbarui')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context); // close loading
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Simpan', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: GradientHeader(
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kantor Klinklin',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kantor Klinklin',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kelola data alamat dan sewa kantor untuk setiap cabang',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showEditDialog(null),
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: Text('Tambah', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A), // Dark color from screenshot
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty
                      ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                      : _buildTable(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTable() {
    if (_cabangs.isEmpty) return const Center(child: Text('Tidak ada data'));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
          columns: [
            DataColumn(label: Text('CABANG', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
            DataColumn(label: Text('ALAMAT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
            DataColumn(label: Text('STATUS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
            DataColumn(label: Text('HARGA SEWA', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
            DataColumn(label: Text('AWAL SEWA', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
            DataColumn(label: Text('AKHIR SEWA', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
            DataColumn(label: Text('AKSI', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
          ],
          rows: _cabangs.map((c) {
            final isAset = c['status_kantor'] == 'Aset';
            
            return DataRow(
              cells: [
                DataCell(Text(c['nama_cabang'] ?? '-', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textDark))),
                DataCell(Text(c['alamat']?.toString().isEmpty ?? true ? '-' : c['alamat'], style: GoogleFonts.inter(color: AppColors.textDark))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAset ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isAset ? Colors.green : Colors.orange),
                    ),
                    child: Text(
                      c['status_kantor'] ?? '-',
                      style: GoogleFonts.inter(
                        color: isAset ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(isAset ? '-' : _formatCurrency(c['harga_sewa']), style: GoogleFonts.inter(color: AppColors.textDark))),
                DataCell(Text(isAset ? '-' : _formatDate(c['awal_sewa']), style: GoogleFonts.inter(color: AppColors.textDark))),
                DataCell(Text(isAset ? '-' : _formatDate(c['akhir_sewa']), style: GoogleFonts.inter(color: AppColors.textDark))),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                    onPressed: () => _showEditDialog(c),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

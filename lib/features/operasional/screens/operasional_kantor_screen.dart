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

  void _showEditSheet(Map<String, dynamic>? cabang) {
    String? selectedCabangId = cabang != null ? cabang['id'].toString() : null;
    final alamatController = TextEditingController(text: cabang?['alamat'] ?? '');
    final noTelpController = TextEditingController(text: cabang?['no_telp'] ?? '');
    String selectedStatus = cabang?['status_kantor'] ?? 'Sewa';
    final hargaSewaController = TextEditingController(
      text: cabang?['harga_sewa'] != null ? num.parse(cabang!['harga_sewa'].toString()).toInt().toString() : ''
    );
    DateTime? awalSewa = cabang?['awal_sewa'] != null ? DateTime.tryParse(cabang!['awal_sewa']) : null;
    DateTime? akhirSewa = cabang?['akhir_sewa'] != null ? DateTime.tryParse(cabang!['akhir_sewa']) : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cabang == null ? 'Tambah Kantor Klinklin' : 'Edit Kantor Klinklin',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFFEEEEEE)),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                      children: [
                        _buildLabel('Cabang *'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
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
                                setModalState(() => selectedCabangId = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Alamat *'),
                        TextField(
                          controller: alamatController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.all(16),
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
                                  _buildLabel('No Telepon'),
                                  TextField(
                                    controller: noTelpController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.all(16),
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
                                  _buildLabel('Status'),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(12),
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
                        _buildLabel('Harga Sewa'),
                        TextField(
                          controller: hargaSewaController,
                          keyboardType: TextInputType.number,
                          enabled: selectedStatus == 'Sewa',
                          decoration: InputDecoration(
                            prefixText: 'Rp ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.all(16),
                            filled: selectedStatus == 'Aset',
                            fillColor: selectedStatus == 'Aset' ? Colors.grey.shade100 : Colors.white,
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
                                  _buildLabel('Awal Sewa'),
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
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(12),
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
                                  _buildLabel('Akhir Sewa'),
                                  InkWell(
                                    onTap: selectedStatus == 'Aset' ? null : () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: akhirSewa ?? DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2050),
                                      );
                                      if (date != null) {
                                        setModalState(() => akhirSewa = date);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(12),
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
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (selectedCabangId == null || alamatController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cabang dan Alamat harus diisi')));
                          return;
                        }
                        
                        try {
                          final data = {
                            'alamat': alamatController.text,
                            'no_telp': noTelpController.text,
                            'status_kantor': selectedStatus,
                            'harga_sewa': selectedStatus == 'Sewa' ? hargaSewaController.text : null,
                            'awal_sewa': selectedStatus == 'Sewa' && awalSewa != null ? DateFormat('yyyy-MM-dd').format(awalSewa!) : null,
                            'akhir_sewa': selectedStatus == 'Sewa' && akhirSewa != null ? DateFormat('yyyy-MM-dd').format(akhirSewa!) : null,
                          };
                          
                          await _service.updateKantor(int.parse(selectedCabangId!), data);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil menyimpan data', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
                            _fetchData();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString(), style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                          }
                        }
                      },
                      child: Text('Simpan Data', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daftar Kantor Cabang',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kelola data alamat dan sewa kantor',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showEditSheet(null),
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: Text('Tambah', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                    : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_cabangs.isEmpty) return const Center(child: Text('Tidak ada data'));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _cabangs.length,
      itemBuilder: (context, index) {
        final c = _cabangs[index];
        final isAset = c['status_kantor'] == 'Aset';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: Radius.zero, bottomRight: Radius.zero),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.business_rounded, size: 18, color: Colors.blue.shade700),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          c['nama_cabang'] ?? '-',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isAset ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isAset ? Colors.green.shade200 : Colors.orange.shade200),
                      ),
                      child: Text(
                        c['status_kantor'] ?? 'Belum Diatur',
                        style: GoogleFonts.inter(
                          color: isAset ? Colors.green.shade700 : Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c['alamat']?.toString().isEmpty ?? true ? 'Alamat belum diatur' : c['alamat'],
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Detail Sewa/Aset
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('HARGA SEWA', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                const SizedBox(height: 4),
                                Text(
                                  c['harga_sewa'] != null ? _formatCurrency(c['harga_sewa']) : '-',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 40, color: Colors.grey.shade300),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('PERIODE SEWA', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                const SizedBox(height: 4),
                                Text(
                                  (c['awal_sewa'] != null && c['akhir_sewa'] != null)
                                      ? '${_formatDate(c['awal_sewa'])} - ${_formatDate(c['akhir_sewa'])}'
                                      : '-',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditSheet(c),
                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                        label: const Text('Edit Kantor'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

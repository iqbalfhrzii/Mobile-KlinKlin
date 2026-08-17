import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../services/operasional_purchase_order_service.dart';
import '../../../core/api/api_client.dart';

class OperasionalPurchaseOrderScreen extends StatefulWidget {
  const OperasionalPurchaseOrderScreen({super.key});

  @override
  State<OperasionalPurchaseOrderScreen> createState() => _OperasionalPurchaseOrderScreenState();
}

class _OperasionalPurchaseOrderScreenState extends State<OperasionalPurchaseOrderScreen> {
  bool _isLoading = false;
  List<dynamic> _purchaseOrders = [];
  List<dynamic> _cabangs = [];

  int? _selectedCabangId;
  String? _selectedStatus;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCabangs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCabangs() async {
    try {
      final dio = ApiClient.instance;
      final res = await dio.get('/operasional/cabangs');
      setState(() {
        _cabangs = res.data['data'] ?? [];
      });
      _loadData();
    } catch (e) {
      debugPrint('Error loading cabangs: $e');
      _loadData();
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await OperasionalPurchaseOrderService.getPurchaseOrders(
        search: _searchController.text,
        cabangId: _selectedCabangId,
        status: _selectedStatus,
      );
      setState(() {
        _purchaseOrders = data['data'] ?? [];
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteData(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Data'),
        content: const Text('Yakin ingin menghapus purchase order ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await OperasionalPurchaseOrderService.deletePurchaseOrder(id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data berhasil dihapus')));
      _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isLoading = false);
    }
  }

  void _showFormModal({Map<String, dynamic>? item}) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FormBottomSheet(
        item: item,
        cabangs: _cabangs,
      ),
    );
    
    if (result == true) {
      _loadData();
    }
  }

  void _openFile(String path) async {
    final url = Uri.parse('https://erp.klinklin.online/$path');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka file')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Purchase Order',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kelola data purchase order kantor cabang',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showFormModal(),
                  icon: const Icon(Icons.add_circle, color: Colors.white, size: 28),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Tambah PO',
                ),
              ],
            ),
          ),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: _purchaseOrders.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: _purchaseOrders.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              return _buildItemCard(_purchaseOrders[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10), color: AppColors.surface),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Cari PO, Barang, atau Supplier...',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10), color: AppColors.surface),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<dynamic>(
                      value: _selectedCabangId,
                      isExpanded: true,
                      hint: Text('Semua Cabang', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600),
                      items: [
                        DropdownMenuItem(value: null, child: Text('Semua Cabang', style: GoogleFonts.inter(fontWeight: FontWeight.normal))),
                        ..._cabangs.map((c) => DropdownMenuItem(value: c['id'], child: Text(c['nama_cabang']))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedCabangId = val as int?);
                        _loadData();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10), color: AppColors.surface),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatus,
                      isExpanded: true,
                      hint: Text('Semua Status', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600),
                      items: [
                        DropdownMenuItem(value: null, child: Text('Semua Status', style: GoogleFonts.inter(fontWeight: FontWeight.normal))),
                        DropdownMenuItem(value: 'Draft', child: Text('Draft', style: GoogleFonts.inter(color: Colors.grey))),
                        DropdownMenuItem(value: 'Diterima Sebagian', child: Text('Diterima Sebagian', style: GoogleFonts.inter(color: Colors.orange))),
                        DropdownMenuItem(value: 'Selesai', child: Text('Selesai', style: GoogleFonts.inter(color: Colors.green))),
                        DropdownMenuItem(value: 'Batal', child: Text('Batal', style: GoogleFonts.inter(color: Colors.red))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedStatus = val);
                        _loadData();
                      },
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Tidak ada data Purchase Order.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final tgl = item['tanggal_po'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(item['tanggal_po'])) : '-';
    final noPo = item['no_po'] ?? '-';
    final cabang = item['cabang']?['nama_cabang'] ?? '-';
    final supplier = item['supplier'] ?? '-';
    final barang = item['nama_barang'] ?? '-';
    
    // Format quantity string
    final qtyNumber = double.tryParse(item['jumlah']?.toString() ?? '0') ?? 0;
    final qtyStr = qtyNumber == qtyNumber.toInt() ? qtyNumber.toInt().toString() : qtyNumber.toStringAsFixed(2);
    final satuan = item['satuan'] ?? '';
    final total = item['total_harga'] != null ? NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(double.parse(item['total_harga'].toString())) : '-';
    
    final status = item['status_po'] ?? '-';
    final hasFile = item['file_po'] != null;

    Color statusColor = Colors.grey;
    if (status == 'Draft') statusColor = Colors.grey;
    if (status == 'Diterima Sebagian') statusColor = Colors.orange;
    if (status == 'Selesai') statusColor = Colors.green;
    if (status == 'Batal') statusColor = Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(noPo, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const SizedBox(height: 4),
                      Text(tgl, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 8),
                      Text(cabang, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      const SizedBox(height: 2),
                      Text(supplier, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(barang, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      const SizedBox(height: 2),
                      Text('$qtyStr $satuan', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 8),
                      Text(total, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(status, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                ),
                Row(
                  children: [
                    if (hasFile) ...[
                      IconButton(
                        onPressed: () => _openFile(item['file_po']),
                        icon: const Icon(Icons.attach_file, color: AppColors.textMuted, size: 18),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        tooltip: 'Lihat Berkas',
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      onPressed: () => _showFormModal(item: item),
                      icon: const Icon(Icons.edit_outlined, color: Colors.orange, size: 18),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      tooltip: 'Edit',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => _deleteData(item['id']),
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      tooltip: 'Hapus',
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// Bottom Sheet Form (Create / Edit)
// ---------------------------------------------------------
class _FormBottomSheet extends StatefulWidget {
  final Map<String, dynamic>? item;
  final List<dynamic> cabangs;

  const _FormBottomSheet({this.item, required this.cabangs});

  @override
  State<_FormBottomSheet> createState() => _FormBottomSheetState();
}

class _FormBottomSheetState extends State<_FormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _noPoController = TextEditingController();
  final _supplierController = TextEditingController();
  final _noTelpController = TextEditingController();
  final _kodeBarangController = TextEditingController();
  final _namaBarangController = TextEditingController();
  final _jumlahController = TextEditingController();
  final _satuanController = TextEditingController();
  final _hargaSatuanController = TextEditingController();
  final _jumlahDiterimaController = TextEditingController();
  final _keteranganController = TextEditingController();

  DateTime? _tanggalPo;
  DateTime? _tanggalDiterima;
  int? _cabangId;
  String _statusPo = 'Draft';
  File? _selectedFile;
  
  double _totalHarga = 0.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      final data = widget.item!;
      _noPoController.text = data['no_po'] ?? '';
      _tanggalPo = data['tanggal_po'] != null ? DateTime.parse(data['tanggal_po']) : null;
      _cabangId = data['cabang_id'];
      _supplierController.text = data['supplier'] ?? '';
      _noTelpController.text = data['no_telepon_supplier'] ?? '';
      _kodeBarangController.text = data['kode_barang'] ?? '';
      _namaBarangController.text = data['nama_barang'] ?? '';
      
      final qty = double.tryParse(data['jumlah']?.toString() ?? '0') ?? 0;
      _jumlahController.text = qty == qty.toInt() ? qty.toInt().toString() : qty.toString();
      
      _satuanController.text = data['satuan'] ?? '';
      
      final harga = double.tryParse(data['harga_satuan']?.toString() ?? '0') ?? 0;
      _hargaSatuanController.text = harga == harga.toInt() ? harga.toInt().toString() : harga.toString();
      
      _statusPo = data['status_po'] ?? 'Draft';
      _tanggalDiterima = data['tanggal_diterima'] != null ? DateTime.parse(data['tanggal_diterima']) : null;
      
      if (data['jumlah_diterima'] != null) {
        final qtyDiterima = double.tryParse(data['jumlah_diterima']?.toString() ?? '0') ?? 0;
        _jumlahDiterimaController.text = qtyDiterima == qtyDiterima.toInt() ? qtyDiterima.toInt().toString() : qtyDiterima.toString();
      }
      
      _keteranganController.text = data['keterangan'] ?? '';
      _calculateTotal();
    }
  }

  @override
  void dispose() {
    _noPoController.dispose();
    _supplierController.dispose();
    _noTelpController.dispose();
    _kodeBarangController.dispose();
    _namaBarangController.dispose();
    _jumlahController.dispose();
    _satuanController.dispose();
    _hargaSatuanController.dispose();
    _jumlahDiterimaController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    final qty = double.tryParse(_jumlahController.text.replaceAll(',', '.')) ?? 0.0;
    final harga = double.tryParse(_hargaSatuanController.text.replaceAll(',', '.')) ?? 0.0;
    setState(() {
      _totalHarga = qty * harga;
    });
  }

  Future<void> _pickDate(bool isTanggalPo) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isTanggalPo ? (_tanggalPo ?? DateTime.now()) : (_tanggalDiterima ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isTanggalPo) {
          _tanggalPo = picked;
        } else {
          _tanggalDiterima = picked;
        }
      });
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tanggalPo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tanggal PO wajib diisi')));
      return;
    }
    if (_cabangId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cabang wajib diisi')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = {
        'no_po': _noPoController.text,
        'tanggal_po': DateFormat('yyyy-MM-dd').format(_tanggalPo!),
        'cabang_id': _cabangId,
        'supplier': _supplierController.text,
        'no_telepon_supplier': _noTelpController.text,
        'kode_barang': _kodeBarangController.text,
        'nama_barang': _namaBarangController.text,
        'jumlah': _jumlahController.text.replaceAll(',', '.'),
        'satuan': _satuanController.text,
        'harga_satuan': _hargaSatuanController.text.replaceAll(',', '.'),
        'total_harga': _totalHarga,
        'status_po': _statusPo,
        'keterangan': _keteranganController.text,
      };

      if (_tanggalDiterima != null) {
        payload['tanggal_diterima'] = DateFormat('yyyy-MM-dd').format(_tanggalDiterima!);
      }
      if (_jumlahDiterimaController.text.isNotEmpty) {
        payload['jumlah_diterima'] = _jumlahDiterimaController.text.replaceAll(',', '.');
      }

      if (widget.item == null) {
        await OperasionalPurchaseOrderService.createPurchaseOrder(payload, file: _selectedFile);
      } else {
        await OperasionalPurchaseOrderService.updatePurchaseOrder(widget.item!['id'], payload, file: _selectedFile);
      }
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(widget.item == null ? 'Tambah Data Purchase Order' : 'Edit Data Purchase Order', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('INFORMASI PURCHASE ORDER'),
                    _buildTextField('No PO *', _noPoController, hint: 'mis. PO-2026-001'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildDatePicker('Tanggal PO *', _tanggalPo, true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDropdownCabang()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Supplier *', _supplierController)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('No Telepon Supplier', _noTelpController, keyboardType: TextInputType.phone)),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('DETAIL BARANG'),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Kode Barang', _kodeBarangController)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('Nama Barang *', _namaBarangController)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Jumlah *', _jumlahController, keyboardType: TextInputType.numberWithOptions(decimal: true), onChanged: (_) => _calculateTotal())),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('Satuan', _satuanController, hint: 'mis. Pcs, Box, Kg')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Harga Satuan', _hargaSatuanController, prefixText: 'Rp ', keyboardType: TextInputType.numberWithOptions(decimal: true), onChanged: (_) => _calculateTotal())),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Harga', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(color: Colors.grey[100], border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
                                child: Text('Rp ${_totalHarga.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(height: 4),
                              Text('Dihitung otomatis', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('STATUS & PENERIMAAN'),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status PO *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10), color: AppColors.surface),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _statusPo,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark),
                              items: const [
                                DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                                DropdownMenuItem(value: 'Diterima Sebagian', child: Text('Diterima Sebagian')),
                                DropdownMenuItem(value: 'Selesai', child: Text('Selesai')),
                                DropdownMenuItem(value: 'Batal', child: Text('Batal')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _statusPo = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildDatePicker('Tanggal Diterima', _tanggalDiterima, false)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('Jumlah Diterima', _jumlahDiterimaController, keyboardType: TextInputType.numberWithOptions(decimal: true))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField('Keterangan', _keteranganController, maxLines: 3),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('File PO (Bukti / Invoice)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickFile,
                              icon: const Icon(Icons.attach_file, size: 16),
                              label: const Text('Choose File'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedFile != null ? _selectedFile!.path.split('/').last : (widget.item?['file_po'] != null ? 'File tersimpan' : 'No file chosen'),
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 100), // padding for floating button
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textDark, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Simpan Data', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const Divider(color: AppColors.border),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hint, String? prefixText, int maxLines = 1, TextInputType? keyboardType, Function(String)? onChanged}) {
    bool isRequired = label.contains('*');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: isRequired ? (val) => val == null || val.isEmpty ? 'Wajib diisi' : null : null,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? value, bool isTanggalPo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pickDate(isTanggalPo),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10), color: AppColors.surface),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value != null ? DateFormat('MM/dd/yyyy').format(value) : 'mm/dd/yyyy', style: GoogleFonts.inter(fontSize: 14, color: value != null ? AppColors.textDark : AppColors.textMuted)),
                const Icon(Icons.calendar_today, size: 16, color: AppColors.textDark),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownCabang() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cabang *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10), color: AppColors.surface),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _cabangId,
              isExpanded: true,
              hint: Text('Pilih Cabang', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark),
              items: widget.cabangs.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text(c['nama_cabang']))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _cabangId = val);
              },
            ),
          ),
        ),
      ],
    );
  }
}

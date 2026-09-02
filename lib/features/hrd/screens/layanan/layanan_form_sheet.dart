import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';

class LayananFormSheet extends StatefulWidget {
  final LayananModel? layanan;
  final List<CabangModel>? cabangs;

  const LayananFormSheet({
    super.key,
    this.layanan,
    this.cabangs,
  });

  static Future<bool?> show(
    BuildContext context, {
    LayananModel? layanan,
    List<CabangModel>? cabangs,
  }) {
    return showModalBottomSheet<bool>(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LayananFormSheet(
        layanan: layanan,
        cabangs: cabangs,
      ),
    );
  }

  @override
  State<LayananFormSheet> createState() => _LayananFormSheetState();
}

class _LayananFormSheetState extends State<LayananFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final HrdService _hrdService = HrdService();

  late TextEditingController _namaCtrl;
  int? _selectedCabang;
  String _status = 'aktif';
  List<CabangModel> _cabangs = [];
  bool _isLoading = false;
  bool _isLoadingCabang = false;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController(text: widget.layanan?.namaLayanan);
    _selectedCabang = widget.layanan?.cabangId;
    if (widget.layanan != null) {
      _status = widget.layanan!.status.toLowerCase();
    }

    if (widget.cabangs != null && widget.cabangs!.isNotEmpty) {
      _cabangs = widget.cabangs!;
      if (_selectedCabang == null && _cabangs.isNotEmpty) {
        _selectedCabang = _cabangs.first.id;
      }
    } else {
      _fetchCabang();
    }
  }

  Future<void> _fetchCabang() async {
    setState(() => _isLoadingCabang = true);
    try {
      final res = await _hrdService.fetchCabang();
      if (mounted) {
        setState(() {
          _cabangs = res;
          if (_selectedCabang == null && _cabangs.isNotEmpty) {
            _selectedCabang = _cabangs.first.id;
          }
          _isLoadingCabang = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCabang = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat daftar cabang: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCabang == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih cabang terlebih dahulu'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = {
        'nama_layanan': _namaCtrl.text.trim(),
        'cabang_id': _selectedCabang,
        'status': _status,
      };

      if (widget.layanan == null) {
        await _hrdService.createLayanan(data);
      } else {
        await _hrdService.updateLayanan(widget.layanan!.id, data);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.layanan == null
                  ? 'Layanan "${_namaCtrl.text}" berhasil ditambahkan'
                  : 'Layanan "${_namaCtrl.text}" berhasil diperbarui',
            ),
            backgroundColor: const Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString().replaceFirst('Exception: ', '');
        if (e is DioException && e.response?.data != null) {
          final data = e.response!.data;
          if (data is Map) {
            if (data['errors'] != null && data['errors'] is Map) {
              final errors = data['errors'] as Map;
              if (errors.isNotEmpty) {
                errMsg = errors.values.first.first.toString();
              }
            } else if (data['message'] != null) {
              errMsg = data['message'].toString();
            }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.layanan != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(24, 14, 24, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 16 : 28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle pill
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isEdit ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_note_rounded : Icons.cleaning_services_rounded,
                      color: isEdit ? const Color(0xFF2563EB) : const Color(0xFF059669),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Layanan' : 'Tambah Layanan Baru',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEdit ? 'Perbarui informasi layanan operasional' : 'Daftarkan layanan baru ke sistem cabang',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 18),

              // 1. Nama Layanan
              Text(
                'Nama Layanan',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _namaCtrl,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Contoh: Deep Clean, Cuci Kasur King, Pindahan',
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.cleaning_services_outlined, color: Color(0xFF64748B), size: 19),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
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
                    borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Nama layanan wajib diisi';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 2. Cabang
              Text(
                'Cabang Operasional',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              _isLoadingCabang
                  ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                  : Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedCabang,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                          hint: Text('Pilih Cabang', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
                          items: _cabangs.map((c) {
                            return DropdownMenuItem<int>(
                              value: c.id,
                              child: Row(
                                children: [
                                  const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF64748B)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      c.namaCabang,
                                      style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w500, color: const Color(0xFF0F172A)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedCabang = val);
                          },
                        ),
                      ),
                    ),

              const SizedBox(height: 16),

              // 3. Status Layanan
              Text(
                'Status Layanan',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildStatusRadio(
                      label: 'Aktif',
                      value: 'aktif',
                      selected: _status == 'aktif',
                      color: const Color(0xFF059669),
                      bgColor: const Color(0xFFECFDF5),
                      onTap: () => setState(() => _status = 'aktif'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatusRadio(
                      label: 'Nonaktif',
                      value: 'nonaktif',
                      selected: _status == 'nonaktif',
                      color: const Color(0xFFDC2626),
                      bgColor: const Color(0xFFFEF2F2),
                      onTap: () => setState(() => _status = 'nonaktif'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              // Actions: Batal & Simpan
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  isEdit ? 'Simpan Perubahan' : 'Tambah Layanan',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRadio({
    required String label,
    required String value,
    required bool selected,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? bgColor : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: selected ? color : const Color(0xFF94A3B8),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? color : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/data/customer_model.dart';
import '../../../core/services/customer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditCustomerScreen extends StatefulWidget {
  final CustomerModel customer;
  const EditCustomerScreen({super.key, required this.customer});

  @override
  State<EditCustomerScreen> createState() => _EditCustomerScreenState();
}

class _EditCustomerScreenState extends State<EditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _notesCtrl;

  late String _status;
  bool _saving = false;

  static const _statuses = ['aktif', 'non aktif'];

  static const _statusColors = {
    'aktif': AppColors.statusDone,
    'non aktif': AppColors.statusCancel,
  };

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.customer.name);
    _phoneCtrl = TextEditingController(text: widget.customer.phone == '-' ? '' : widget.customer.phone);
    _addressCtrl = TextEditingController(text: widget.customer.address == '-' ? '' : widget.customer.address);
    _notesCtrl = TextEditingController(text: widget.customer.notes);
    
    // Sesuaikan format status
    final st = widget.customer.status.toLowerCase().replaceAll(' ', '');
    _status = st == 'aktif' ? 'aktif' : 'non aktif';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            child: Row(
              children: [
                HeaderBackButton(onTap: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit Pelanggan', style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white,
                    )),
                    Text('Ubah data pelanggan', style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.white.withOpacity(0.65),
                    )),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCard('Informasi Pribadi', [
                      _buildField(
                        controller: _nameCtrl,
                        label: 'Nama Lengkap',
                        hint: 'cth. Budi Santoso',
                        icon: Icons.person_outline_rounded,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _phoneCtrl,
                        label: 'Nomor HP',
                        hint: 'cth. 08123456789',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                          if (v.trim().length < 9) return 'Nomor tidak valid';
                          return null;
                        },
                      ),
                    ]),
                    const SizedBox(height: 14),
                    _buildCard('Lokasi', [
                      _buildField(
                        controller: _addressCtrl,
                        label: 'Alamat Lengkap',
                        hint: 'cth. Jl. Ahmad Yani No. 5, Malang',
                        icon: Icons.home_outlined,
                        maxLines: 3,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                      ),
                    ]),
                    const SizedBox(height: 14),
                    _buildCard('Status Pelanggan', [
                      Text('Tentukan status keaktifan pelanggan ini', style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textMuted,
                      )),
                      const SizedBox(height: 10),
                      Row(
                        children: _statuses.map((s) {
                          final sel = _status == s;
                          final color = _statusColors[s]!;
                          final label = s == 'aktif' ? 'Aktif' : 'Non Aktif';
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _status = s),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: EdgeInsets.only(right: s == _statuses.last ? 0 : 8),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: sel ? color.withOpacity(0.12) : AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: sel ? color : AppColors.border,
                                    width: sel ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      s == 'aktif' ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                                      size: 18, color: sel ? color : AppColors.textMuted,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(label, style: GoogleFonts.inter(
                                      fontSize: 12, fontWeight: FontWeight.w600,
                                      color: sel ? color : AppColors.textMuted,
                                    )),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    _buildCard('Catatan (opsional)', [
                      _buildField(
                        controller: _notesCtrl,
                        label: 'Catatan CS',
                        hint: 'cth. Pelanggan lebih suka siang hari...',
                        icon: Icons.note_outlined,
                        maxLines: 3,
                        required: false,
                      ),
                    ]),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text('✓ Simpan Perubahan', style: GoogleFonts.inter(
                                fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
                              )),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w600,
            color: AppColors.textMuted, letterSpacing: 0.5,
          )),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool required = true,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label + (required ? ' *' : ''), style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textDark,
        )),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
            prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final branchStr = prefs.getString('user_branch'); 
      
      final updatedCustomer = await CustomerService.updateCustomer(widget.customer.id, {
        'cabang_id': 1, // Assuming default branch ID = 1 for now like addCustomer
        'nama_pelanggan': _nameCtrl.text.trim(),
        'no_wa': _phoneCtrl.text.trim(),
        'alamat': _addressCtrl.text.trim(),
        'status': _status == 'non aktif' ? 'nonaktif' : _status,
      });

      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Pelanggan ${updatedCustomer.name} berhasil diperbarui!',
              style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppColors.statusDone,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        Navigator.pop(context, updatedCustomer);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', ''), style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppColors.statusCancel,
        ));
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../services/operasional_permintaan_design_service.dart';

class OperasionalPermintaanDesignFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final VoidCallback onSave;

  const OperasionalPermintaanDesignFormSheet({
    super.key,
    this.initialData,
    required this.onSave,
  });

  @override
  State<OperasionalPermintaanDesignFormSheet> createState() => _OperasionalPermintaanDesignFormSheetState();
}

class _OperasionalPermintaanDesignFormSheetState extends State<OperasionalPermintaanDesignFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _service = OperasionalPermintaanDesignService();

  late TextEditingController _judulController;
  late TextEditingController _deskripsiController;

  String? _selectedFilePath;
  bool _isLoading = false;

  final Color _primaryThemeColor = AppColors.primaryMid; // KlinKlin Blue

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _judulController = TextEditingController(text: data?['judul'] ?? '');
    _deskripsiController = TextEditingController(text: data?['deskripsi'] ?? '');
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'zip'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final Map<String, dynamic> data = {
      'judul': _judulController.text.trim(),
      'deskripsi': _deskripsiController.text.trim(),
    };

    Map<String, dynamic> res;
    if (widget.initialData != null) {
      res = await _service.updatePermintaanDesign(widget.initialData!['id'], data, filePath: _selectedFilePath);
    } else {
      res = await _service.storePermintaanDesign(data, filePath: _selectedFilePath);
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (res['status'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Permintaan design berhasil dikirim'), backgroundColor: Colors.green),
      );
      widget.onSave();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Gagal mengirim permintaan'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String fileDisplay = 'No file chosen';
    if (_selectedFilePath != null) {
      fileDisplay = _selectedFilePath!.split('/').last.split('\\').last;
    } else if (widget.initialData?['lampiran_pengirim'] != null) {
      fileDisplay = widget.initialData!['lampiran_pengirim'].toString().split('/').last;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag indicator
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryThemeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.brush_rounded, color: _primaryThemeColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.initialData != null ? 'Edit Permintaan Design' : 'Buat Permintaan Design',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      Text(
                        'Ajukan kebutuhan design grafis / media ke designer',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
          const Divider(height: 16),

          // Body Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Judul Permintaan
                    Text('Judul Permintaan *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _judulController,
                      style: GoogleFonts.inter(fontSize: 14),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Judul permintaan wajib diisi' : null,
                      decoration: InputDecoration(
                        hintText: 'Misal: Poster Promo Kemerdekaan',
                        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _primaryThemeColor, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Deskripsi & Brief
                    Text('Deskripsi & Kebutuhan (Brief) *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _deskripsiController,
                      maxLines: 5,
                      style: GoogleFonts.inter(fontSize: 14),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Deskripsi & brief wajib diisi' : null,
                      decoration: InputDecoration(
                        hintText: 'Jelaskan secara detail apa yang Anda butuhkan, warna, teks, dimensi, format output, dll.',
                        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _primaryThemeColor, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Lampiran Referensi (Opsional)
                    Text('Lampiran Referensi (Opsional)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: _pickFile,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                                border: Border(right: BorderSide(color: Colors.grey.shade300)),
                              ),
                              child: Text('Choose File', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _primaryThemeColor)),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                fileDisplay,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: fileDisplay == 'No file chosen' ? Colors.grey.shade400 : AppColors.textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (_selectedFilePath != null)
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.red),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() => _selectedFilePath = null),
                            ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Format: PNG, JPG, PDF, ZIP (Maks. 10MB)', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // Footer Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textDark, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMid,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 1,
                    shadowColor: AppColors.primaryMid.withValues(alpha: 0.4),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Kirim Permintaan', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../services/operasional_pengumuman_service.dart';

class OperasionalPengumumanFormSheet extends StatefulWidget {
  final VoidCallback onSave;

  const OperasionalPengumumanFormSheet({
    super.key,
    required this.onSave,
  });

  @override
  State<OperasionalPengumumanFormSheet> createState() => _OperasionalPengumumanFormSheetState();
}

class _OperasionalPengumumanFormSheetState extends State<OperasionalPengumumanFormSheet> {
  final _service = OperasionalPengumumanService();
  
  final _judulController = TextEditingController();
  final _isiController = TextEditingController();
  
  bool _isLoadingOptions = true;
  bool _isLoadingSubmit = false;

  List<dynamic> _cabangList = [];
  List<String> _jabatanList = [
    'CEO',
    'Designer',
    'Finance',
    'HRD',
    'Marketing',
    'Operasional',
    'Cleaner',
    'CS',
  ];

  final Set<String> _selectedRoles = {};
  final Set<int> _selectedCabangIds = {};

  String? _selectedFilePath;

  final Color _primaryThemeColor = const Color(0xFF059669); // Emerald green for announcements

  /// Returns true if only HQ-level roles (CEO, Designer, Finance, HRD, Marketing, Operasional) are selected
  bool get _isOnlyHqRolesSelected {
    if (_selectedRoles.isEmpty) return false;
    return _selectedRoles.every((role) {
      final r = role.toLowerCase().trim();
      return !r.contains('cleaner') && !r.contains('cs') && !r.contains('customer service');
    });
  }

  void _syncCabangWithSelectedRoles() {
    if (_isOnlyHqRolesSelected) {
      final kp = _cabangList.firstWhere(
        (c) => (c['nama_cabang'] ?? c['nama'] ?? '').toString().toLowerCase().contains('pusat'),
        orElse: () => _cabangList.isNotEmpty ? _cabangList.first : null,
      );
      if (kp != null) {
        final int kpId = int.parse(kp['id'].toString());
        _selectedCabangIds.clear();
        _selectedCabangIds.add(kpId);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchOptions();
  }

  @override
  void dispose() {
    _judulController.dispose();
    _isiController.dispose();
    super.dispose();
  }

  Future<void> _fetchOptions() async {
    setState(() => _isLoadingOptions = true);
    final res = await _service.getFormOptions();
    if (mounted) {
      setState(() {
        _isLoadingOptions = false;
        if (res['status'] == true && res['data'] != null) {
          final data = res['data'];
          if (data['cabangs'] != null && data['cabangs'] is List) {
            _cabangList = data['cabangs'];
          }
          if (data['jabatans'] != null && data['jabatans'] is List) {
            final List<String> fetched = List<String>.from(data['jabatans'].map((e) => e.toString()));
            if (fetched.isNotEmpty) {
              _jabatanList = fetched;
            }
          }
          _syncCabangWithSelectedRoles();
        }
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'zip', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
      });
    }
  }

  Future<void> _submit() async {
    if (_judulController.text.trim().isEmpty || _isiController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap isi judul dan pesan pengumuman (*)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoadingSubmit = true);

    final Map<String, dynamic> data = {
      'judul': _judulController.text.trim(),
      'isi': _isiController.text.trim(),
    };

    if (_selectedRoles.isNotEmpty) {
      data['target_roles'] = _selectedRoles.toList();
    }

    if (_isOnlyHqRolesSelected) {
      final kp = _cabangList.firstWhere(
        (c) => (c['nama_cabang'] ?? c['nama'] ?? '').toString().toLowerCase().contains('pusat'),
        orElse: () => null,
      );
      if (kp != null) {
        data['target_cabangs'] = [int.parse(kp['id'].toString())];
      }
    } else if (_selectedCabangIds.isNotEmpty) {
      data['target_cabangs'] = _selectedCabangIds.toList();
    }

    final res = await _service.storePengumuman(data, filePath: _selectedFilePath);

    setState(() => _isLoadingSubmit = false);

    if (!mounted) return;

    if (res['status'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Pengumuman berhasil dibuat & notifikasi dikirim'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onSave();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Gagal membuat pengumuman'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String? fileDisplayName;
    if (_selectedFilePath != null) {
      fileDisplayName = _selectedFilePath!.split('/').last.split('\\').last;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Sheet Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 14, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryThemeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.campaign_rounded, color: _primaryThemeColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buat Pengumuman Baru',
                        style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kirim notifikasi pengumuman ke cabang & divisi',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Form Body
          Expanded(
            child: _isLoadingOptions
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Judul Pengumuman
                        RichText(
                          text: TextSpan(
                            text: 'Judul Pengumuman',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                            children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            controller: _judulController,
                            style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textDark),
                            decoration: InputDecoration(
                              hintText: 'Misal: Libur Nasional / Penyesuaian SOP',
                              hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400),
                              prefixIcon: const Icon(Icons.title_rounded, size: 18, color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Section Target Penerima Box
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.group_outlined, size: 18, color: _primaryThemeColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pilih Target / Penerima',
                                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // 1. Target Jabatan
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Berdasarkan Jabatan (Opsional)',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (_selectedRoles.length == _jabatanList.length) {
                                          _selectedRoles.clear();
                                        } else {
                                          _selectedRoles.addAll(_jabatanList);
                                        }
                                        _syncCabangWithSelectedRoles();
                                      });
                                    },
                                    child: Text(
                                      _selectedRoles.length == _jabatanList.length ? 'Batal Semua' : 'Pilih Semua',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryThemeColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _jabatanList.map((role) {
                                  final isSelected = _selectedRoles.contains(role);
                                  return FilterChip(
                                    label: Text(role),
                                    selected: isSelected,
                                    selectedColor: _primaryThemeColor.withValues(alpha: 0.15),
                                    backgroundColor: Colors.white,
                                    side: BorderSide(color: isSelected ? _primaryThemeColor : const Color(0xFFCBD5E1)),
                                    labelStyle: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? _primaryThemeColor : const Color(0xFF334155),
                                    ),
                                    checkmarkColor: _primaryThemeColor,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedRoles.add(role);
                                        } else {
                                          _selectedRoles.remove(role);
                                        }
                                        _syncCabangWithSelectedRoles();
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),

                              // 2. Target Cabang
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Berdasarkan Cabang (Opsional)',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                  ),
                                  if (_isOnlyHqRolesSelected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD1FAE5),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF6EE7B7)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.lock_rounded, size: 11, color: Color(0xFF065F46)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Terkunci ke Kantor Pusat',
                                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF065F46)),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (_selectedCabangIds.length == _cabangList.length) {
                                            _selectedCabangIds.clear();
                                          } else {
                                            _selectedCabangIds.addAll(_cabangList.map((c) => int.parse(c['id'].toString())));
                                          }
                                        });
                                      },
                                      child: Text(
                                        _selectedCabangIds.length == _cabangList.length ? 'Batal Semua' : 'Pilih Semua',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryThemeColor),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _cabangList.map((c) {
                                  final int cId = int.parse(c['id'].toString());
                                  final String cName = c['nama_cabang'] ?? c['nama'] ?? 'Cabang';
                                  final bool isPusat = cName.toLowerCase().contains('pusat');
                                  final bool isLocked = _isOnlyHqRolesSelected;
                                  final bool isSelected = isLocked ? isPusat : _selectedCabangIds.contains(cId);

                                  return Opacity(
                                    opacity: isLocked && !isPusat ? 0.38 : 1.0,
                                    child: FilterChip(
                                      label: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(cName),
                                          if (isLocked && isPusat) ...[
                                            const SizedBox(width: 4),
                                            const Icon(Icons.lock_rounded, size: 12, color: Color(0xFF059669)),
                                          ],
                                        ],
                                      ),
                                      selected: isSelected,
                                      selectedColor: _primaryThemeColor.withValues(alpha: 0.15),
                                      backgroundColor: Colors.white,
                                      side: BorderSide(
                                        color: isSelected
                                            ? _primaryThemeColor
                                            : (isLocked && !isPusat ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1)),
                                      ),
                                      labelStyle: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected
                                            ? _primaryThemeColor
                                            : (isLocked && !isPusat ? const Color(0xFF94A3B8) : const Color(0xFF334155)),
                                      ),
                                      checkmarkColor: _primaryThemeColor,
                                      onSelected: isLocked && !isPusat
                                          ? (_) {
                                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Jabatan yang dipilih (${_selectedRoles.join(', ')}) hanya berlokasi di Kantor Pusat.'),
                                                  duration: const Duration(seconds: 2),
                                                  backgroundColor: const Color(0xFF0F172A),
                                                ),
                                              );
                                            }
                                          : (selected) {
                                              if (isLocked && isPusat) return;
                                              setState(() {
                                                if (selected) {
                                                  _selectedCabangIds.add(cId);
                                                } else {
                                                  _selectedCabangIds.remove(cId);
                                                }
                                              });
                                            },
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),

                              // Info Alert
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _isOnlyHqRolesSelected ? const Color(0xFFECFDF5) : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _isOnlyHqRolesSelected ? const Color(0xFFA7F3D0) : Colors.blue.shade200),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      _isOnlyHqRolesSelected ? Icons.verified_user_rounded : Icons.info_outline_rounded,
                                      size: 15,
                                      color: _isOnlyHqRolesSelected ? const Color(0xFF059669) : Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _isOnlyHqRolesSelected
                                            ? 'Jabatan yang dipilih (${_selectedRoles.join(', ')}) merupakan divisi Kantor Pusat, sehingga target cabang otomatis dikunci ke Kantor Pusat.'
                                            : (_selectedRoles.isEmpty && _selectedCabangIds.isEmpty
                                                ? 'Jika jabatan dan cabang tidak ada yang dicentang, maka pesan akan dikirim ke Semua Karyawan.'
                                                : 'Pengumuman akan dikirimkan kepada karyawan yang sesuai dengan kombinasi jabatan dan cabang yang dipilih.'),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: _isOnlyHqRolesSelected ? const Color(0xFF065F46) : Colors.blue.shade800,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Isi Pengumuman
                        RichText(
                          text: TextSpan(
                            text: 'Isi Pengumuman',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                            children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            controller: _isiController,
                            minLines: 4,
                            maxLines: 8,
                            style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textDark, height: 1.45),
                            decoration: InputDecoration(
                              hintText: 'Tulis pesan pengumuman di sini...',
                              hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400, height: 1.4),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Lampiran File (Opsional)
                        Text(
                          'Lampiran File (Opsional)',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickFile,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: fileDisplayName != null ? _primaryThemeColor.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: fileDisplayName != null ? _primaryThemeColor.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
                                width: fileDisplayName != null ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: fileDisplayName != null ? _primaryThemeColor.withValues(alpha: 0.12) : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Icon(
                                    fileDisplayName != null ? Icons.insert_drive_file_rounded : Icons.cloud_upload_outlined,
                                    color: fileDisplayName != null ? _primaryThemeColor : const Color(0xFF64748B),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fileDisplayName ?? 'Pilih Berkas Lampiran',
                                        style: GoogleFonts.inter(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: fileDisplayName != null ? AppColors.textDark : const Color(0xFF334155),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        fileDisplayName != null ? 'Ketuk untuk mengganti file' : 'Format: PDF, Word, Excel, ZIP, Gambar (Maks. 10MB)',
                                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_selectedFilePath != null) ...[
                                  IconButton(
                                    icon: const Icon(Icons.cancel_rounded, color: Colors.red, size: 20),
                                    onPressed: () => setState(() => _selectedFilePath = null),
                                    tooltip: 'Hapus file terpilih',
                                  ),
                                ] else ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Text(
                                      'Pilih File',
                                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: _primaryThemeColor),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
          ),

          // Bottom Action Footer
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _isLoadingSubmit ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF64748B), fontSize: 13.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingSubmit ? null : _submit,
                      icon: _isLoadingSubmit
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      label: Text(
                        _isLoadingSubmit ? 'Mengirim...' : 'Kirim Pengumuman',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryThemeColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

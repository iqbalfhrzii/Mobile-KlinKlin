import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/utils/image_compress_helper.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  String? _photoPath;
  bool _isPhotoRemoved = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? 'CS';
      _photoPath = prefs.getString('user_photo');
    });

    try {
      final meResponse = await AuthService.getMe();
      final me = meResponse['data'] ?? meResponse;
      if (mounted) {
        setState(() {
          _nameController.text = me['nama'] ?? _nameController.text;
          _photoPath = me['foto_profil'];
        });
      }
    } catch (_) {
      // Ignore
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showPhotoOptions() {
    final hasPhoto = _photoPath != null && _photoPath!.isNotEmpty && !_isPhotoRemoved;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Foto Profil',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 20),
                ),
                title: Text('Ambil dari Kamera', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.blue, size: 20),
                ),
                title: Text('Pilih dari Galeri', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (hasPhoto) ...[
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                  ),
                  title: Text('Hapus Foto Profil', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeletePhoto();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      final compressed = await ImageCompressHelper.compressXFileIfNeeded(pickedFile);
      if (compressed != null) {
        setState(() {
          _photoPath = compressed.path;
          _isPhotoRemoved = false;
        });
      }
    }
  }

  void _confirmDeletePhoto() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Foto Profil?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Foto profil Anda akan dihapus dan kembali menggunakan inisial nama.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _photoPath = null;
                _isPhotoRemoved = true;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text('Hapus', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Nama tidak boleh kosong', style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.updateProfile(
        _nameController.text.trim(),
        _photoPath,
        isPhotoRemoved: _isPhotoRemoved,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Profil berhasil diperbarui', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context, true); // true to indicate changed
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', ''), style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _photoPath != null && _photoPath!.isNotEmpty && !_isPhotoRemoved;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                GradientHeader(
                  padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
                  child: Row(
                    children: [
                      HeaderBackButton(onTap: () => Navigator.pop(context)),
                      const SizedBox(width: 12),
                      Text('Edit Profil', style: GoogleFonts.inter(
                          fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: _showPhotoOptions,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                _buildAvatar(),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Ketuk untuk mengubah foto',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ),
                        if (hasPhoto) ...[
                          const SizedBox(height: 6),
                          Center(
                            child: InkWell(
                              onTap: _confirmDeletePhoto,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.delete_outline_rounded, size: 15, color: AppColors.error),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Hapus Foto Profil',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nama Lengkap', style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark
                            )),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nameController,
                              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark),
                              decoration: InputDecoration(
                                hintText: 'Masukkan nama lengkap',
                                hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                ),
                                filled: true,
                                fillColor: AppColors.surface,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: Text('Simpan Perubahan', style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white
                            )),
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

  Widget _buildAvatar() {
    final nameFallback = _nameController.text.isEmpty ? 'CS' : _nameController.text;
    if (_isPhotoRemoved) {
      return InitialsAvatar(name: nameFallback, size: 100);
    }
    return AppAvatar(
      photoUrl: _photoPath,
      name: nameFallback,
      size: 100,
    );
  }
}

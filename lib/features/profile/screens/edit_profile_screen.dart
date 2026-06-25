import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/badges.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  String? _photoPath;
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (pickedFile != null) {
      setState(() {
        _photoPath = pickedFile.path;
      });
    }
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
      await AuthService.updateProfile(_nameController.text.trim(), _photoPath);
      if (mounted) {
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
                            onTap: _pickImage,
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
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text('Ketuk untuk mengubah foto', style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textMuted
                          )),
                        ),
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
    if (_photoPath == null || _photoPath!.isEmpty) {
      return InitialsAvatar(name: nameFallback, size: 100);
    }
    
    if (_photoPath!.startsWith('data:image')) {
      try {
        final base64Str = _photoPath!.split(',').last;
        return ClipOval(child: Image.memory(base64Decode(base64Str), width: 100, height: 100, fit: BoxFit.cover));
      } catch (_) {
        return InitialsAvatar(name: nameFallback, size: 100);
      }
    }
    
    if (_photoPath!.startsWith('http')) {
      return ClipOval(child: Image.network(_photoPath!, width: 100, height: 100, fit: BoxFit.cover, errorBuilder: (_, __, ___) => InitialsAvatar(name: nameFallback, size: 100)));
    }
    
    if (_photoPath!.startsWith('/')) {
      return ClipOval(child: Image.file(File(_photoPath!), width: 100, height: 100, fit: BoxFit.cover, errorBuilder: (_, __, ___) => InitialsAvatar(name: nameFallback, size: 100)));
    }
    
    return ClipOval(child: Image.network('http://192.168.1.242:8000/storage/$_photoPath', width: 100, height: 100, fit: BoxFit.cover, errorBuilder: (_, __, ___) => InitialsAvatar(name: nameFallback, size: 100)));
  }
}

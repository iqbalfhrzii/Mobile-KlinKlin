import re

path = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\profile\screens\leave_request_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Imports
if 'image_picker' not in content:
    content = content.replace("import 'package:intl/intl.dart';", "import 'package:intl/intl.dart';\nimport 'package:image_picker/image_picker.dart';\nimport 'dart:typed_data';")

# Variables
if '_photoBytes' not in content:
    content = content.replace("bool _isLoading = false;", "Uint8List? _photoBytes;\n  String? _photoName;\n  bool _isLoading = false;")

# _pickImage
if '_pickImage' not in content:
    pick_func = """
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _photoBytes = bytes;
        _photoName = pickedFile.name;
      });
    }
  }

  Future<void> _submit"""
    content = content.replace("  Future<void> _submit", pick_func)

# Submit call
content = re.sub(
    r"        _reasonController\.text,\n        null, // No photo support in backend\n",
    r"        _reasonController.text,\n        _photoBytes,\n        _photoName,\n",
    content
)

# UI
if 'Bukti Foto' not in content:
    ui = """
                    const SizedBox(height: 20),
                    Text('Bukti Foto (Opsional)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickImage,
                      child: Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                        ),
                        child: _photoBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(_photoBytes!, fit: BoxFit.cover, width: double.infinity),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.primary.withValues(alpha: 0.5)),
                                  const SizedBox(height: 8),
                                  Text('Tap untuk unggah foto (Opsional)', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                ],
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),"""
    content = content.replace("                    const SizedBox(height: 40),", ui)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Restored photo upload with memory')

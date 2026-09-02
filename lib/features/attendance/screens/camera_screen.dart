import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/image_compress_helper.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isReady = false;
  bool _isTakingPhoto = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _useFallbackSystemCamera();
        return;
      }

      // Find front camera first
      int frontIndex = _cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      _selectedCameraIndex = frontIndex >= 0 ? frontIndex : 0;

      await _setupController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      if (mounted) {
        _useFallbackSystemCamera();
      }
    }
  }

  Future<void> _setupController(CameraDescription cameraDescription) async {
    final prevController = _controller;
    if (prevController != null) {
      await prevController.dispose();
    }

    final newController = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await newController.initialize();
      if (mounted) {
        setState(() {
          _controller = newController;
          _isReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        _useFallbackSystemCamera();
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2 || _isTakingPhoto) return;
    setState(() => _isReady = false);
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _useFallbackSystemCamera() async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (photo != null && mounted) {
        await _processAndConfirmPhoto(photo);
      } else if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _processAndConfirmPhoto(XFile photo) async {
    File finalFile = File(photo.path);
    try {
      finalFile = await ImageCompressHelper.compressIfNeeded(finalFile, targetQuality: 80);
    } catch (_) {}

    if (!mounted) return;
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Foto Selfie'),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(finalFile, fit: BoxFit.cover),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ulangi'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gunakan Foto'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      Navigator.pop(context, finalFile);
    } else {
      try {
        if (finalFile.existsSync()) finalFile.deleteSync();
      } catch (_) {}
    }
  }

  Future<void> _takePhoto() async {
    if (_isTakingPhoto) return;

    setState(() => _isTakingPhoto = true);

    try {
      XFile? photo;
      if (_controller != null && _controller!.value.isInitialized) {
        try {
          photo = await _controller!.takePicture();
        } catch (camErr) {
          // If iOS AVFoundation throws Error -11803 or any camera exception, fallback to system image picker camera
          final picker = ImagePicker();
          photo = await picker.pickImage(
            source: ImageSource.camera,
            preferredCameraDevice: CameraDevice.front,
            imageQuality: 85,
            maxWidth: 1200,
            maxHeight: 1200,
          );
        }
      } else {
        final picker = ImagePicker();
        photo = await picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 85,
          maxWidth: 1200,
          maxHeight: 1200,
        );
      }

      if (photo != null && mounted) {
        await _processAndConfirmPhoto(photo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTakingPhoto = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Menyiapkan kamera...',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: _useFallbackSystemCamera,
                icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                label: const Text('Buka Kamera Sistem', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1 / _controller!.value.aspectRatio,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),

          // Top Bar (Back & Flip Camera)
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                if (_cameras.length > 1)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 24),
                      onPressed: _toggleCamera,
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Bar (Capture button & Fallback button)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _takePhoto,
                    child: Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: _isTakingPhoto ? Colors.white54 : Colors.transparent,
                      ),
                      child: Center(
                        child: _isTakingPhoto
                            ? const SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                              )
                            : Container(
                                height: 60,
                                width: 60,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _useFallbackSystemCamera,
                  icon: const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 16),
                  label: const Text(
                    'Gunakan Kamera Sistem',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../services/leave_service.dart';
import 'leave_history_screen.dart';

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final LeaveService _service = LeaveService();
  
  String _leaveType = 'cuti';
  DateTime? _startDate;
  DateTime? _endDate;
  Uint8List? _photoBytes;
  String? _photoName;
  bool _isLoading = false;
  
  int _jatahCuti = 0;
  int _sisaCuti = 0;
  bool _isLoadingQuota = true;

  @override
  void initState() {
    super.initState();
    _loadQuota();
  }
  
  Future<void> _loadQuota() async {
    try {
      final res = await _service.getLeaveQuota();
      if (mounted) {
        setState(() {
          _jatahCuti = res['data']['jatah_cuti'];
          _sisaCuti = res['data']['sisa_cuti'];
          _isLoadingQuota = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingQuota = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 7)), // Allow backdate a bit for emergencies
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }


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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_startDate == null || _endDate == null) {
      SnackbarUtils.showError(context, 'Pilih tanggal mulai dan selesai');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final startStr = DateFormat('yyyy-MM-dd').format(_startDate!);
      final endStr = DateFormat('yyyy-MM-dd').format(_endDate!);
      
      await _service.submitLeaveRequest(
        _leaveType,
        startStr,
        endStr,
        _reasonController.text,
        _photoBytes,
        _photoName,
      );
      
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Pengajuan berhasil dikirim');
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveHistoryScreen()));
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        HeaderBackButton(onTap: () => Navigator.pop(context)),
                        const SizedBox(width: 12),
                        Text('Pengajuan Cuti / Izin', style: GoogleFonts.inter(
                          fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
                        )),
                      ],
                    ),
                    HeaderIconButton(
                      icon: Icons.history,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveHistoryScreen())),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Ajukan cuti atau izin Anda di sini', style: GoogleFonts.inter(
                  fontSize: 14, color: Colors.white.withValues(alpha: 0.8),
                )),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isLoadingQuota && _leaveType == 'cuti') ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBlue,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sisa Cuti Tahunan', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                const SizedBox(height: 4),
                                Text('$_sisaCuti Hari', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ],
                            ),
                            Icon(Icons.event_available_rounded, color: AppColors.primary, size: 32),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    Text('Jenis Pengajuan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text('Cuti', style: GoogleFonts.inter(fontSize: 14)),
                            value: 'cuti',
                            groupValue: _leaveType,
                            onChanged: (val) => setState(() => _leaveType = val!),
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.primary,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text('Izin', style: GoogleFonts.inter(fontSize: 14)),
                            value: 'izin',
                            groupValue: _leaveType,
                            onChanged: (val) => setState(() => _leaveType = val!),
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    Text('Tanggal', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    _startDate != null ? DateFormat('dd MMM yyyy').format(_startDate!) : 'Mulai',
                                    style: GoogleFonts.inter(fontSize: 14, color: _startDate != null ? AppColors.textDark : AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    _endDate != null ? DateFormat('dd MMM yyyy').format(_endDate!) : 'Selesai',
                                    style: GoogleFonts.inter(fontSize: 14, color: _endDate != null ? AppColors.textDark : AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    Text('Alasan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Tuliskan alasan pengajuan Anda',
                        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Alasan harus diisi' : null,
                    ),
                    

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
                    
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text('Kirim Pengajuan', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
  
  // 'cuti' = Cuti Bulanan/Tahunan, 'cuti_khusus' = Cuti Khusus, 'izin' = Izin
  String _leaveType = 'cuti';
  String _specialLeaveType = 'Melahirkan / Bersalin';
  
  DateTime? _startDate;
  DateTime? _endDate;
  Uint8List? _photoBytes;
  String? _photoName;
  bool _isLoading = false;
  
  int _jatahCuti = 0;
  int _sisaCuti = 0;
  bool _isLoadingQuota = true;

  final List<Map<String, dynamic>> _specialLeaveOptions = [
    {
      'title': 'Melahirkan / Bersalin',
      'icon': Icons.pregnant_woman_rounded,
      'duration_info': '3 Bulan / Sesuai Rujukan',
      'desc': 'Cuti bersalin bagi karyawan wanita',
    },
    {
      'title': 'Pekerja Menikah',
      'icon': Icons.favorite_rounded,
      'duration_info': '3 Hari',
      'desc': 'Pernikahan karyawan bersangkutan',
    },
    {
      'title': 'Istri Melahirkan / Keguguran',
      'icon': Icons.child_friendly_rounded,
      'duration_info': '2 Hari',
      'desc': 'Mendampingi istri melahirkan / keguguran',
    },
    {
      'title': 'Menikahkan Anak',
      'icon': Icons.celebration_rounded,
      'duration_info': '2 Hari',
      'desc': 'Acara pernikahan putra/putri kandung',
    },
    {
      'title': 'Khitanan / Baptis Anak',
      'icon': Icons.family_restroom_rounded,
      'duration_info': '2 Hari',
      'desc': 'Acara khitanan atau baptis anak',
    },
    {
      'title': 'Keluarga Inti Meninggal',
      'icon': Icons.sentiment_very_dissatisfied_rounded,
      'duration_info': '2 Hari',
      'desc': 'Suami/Istri, Orang Tua/Mertua, Anak/Menantu',
    },
    {
      'title': 'Keluarga Serumah Meninggal',
      'icon': Icons.home_rounded,
      'duration_info': '1 Hari',
      'desc': 'Anggota keluarga lain dalam satu rumah',
    },
    {
      'title': 'Ibadah Haji / Umrah',
      'icon': Icons.mosque_rounded,
      'duration_info': 'Sesuai Jadwal Ibadah',
      'desc': 'Menunaikan ibadah keagamaan wajib',
    },
    {
      'title': 'Cuti Khusus Lainnya',
      'icon': Icons.more_horiz_rounded,
      'duration_info': 'Sesuai Kebijakan HRD',
      'desc': 'Cuti khusus di luar ketentuan di atas',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadQuota();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
  
  Future<void> _loadQuota() async {
    try {
      final res = await _service.getLeaveQuota();
      if (mounted) {
        setState(() {
          _jatahCuti = res['data']['jatah_cuti'] ?? 0;
          _sisaCuti = res['data']['sisa_cuti'] ?? 0;
          _isLoadingQuota = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingQuota = false);
      }
    }
  }

  int get _selectedDurationDays {
    if (_startDate == null || _endDate == null) return 0;
    final diff = _endDate!.difference(_startDate!).inDays + 1;
    return diff > 0 ? diff : 1;
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
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

  void _removePhoto() {
    setState(() {
      _photoBytes = null;
      _photoName = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_startDate == null || _endDate == null) {
      SnackbarUtils.showError(context, 'Pilih tanggal mulai dan selesai');
      return;
    }

    if (_leaveType == 'cuti') {
      if (_selectedDurationDays > _sisaCuti) {
        SnackbarUtils.showError(context, 'Sisa cuti Anda ($_sisaCuti hari) tidak mencukupi untuk durasi pengajuan ini ($_selectedDurationDays hari).');
        return;
      }
    }

    setState(() => _isLoading = true);
    
    try {
      final startStr = DateFormat('yyyy-MM-dd').format(_startDate!);
      final endStr = DateFormat('yyyy-MM-dd').format(_endDate!);
      
      await _service.submitLeaveRequest(
        _leaveType,
        startStr,
        endStr,
        _reasonController.text.trim(),
        _photoBytes,
        _photoName,
        subType: _leaveType == 'cuti_khusus' ? _specialLeaveType : null,
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

  void _showSpecialLeavePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.star_rounded, color: Color(0xFF7C3AED), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih Jenis Cuti Khusus',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                        Text(
                          'Tidak memotong kuota cuti bulanan/tahunan',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF7C3AED), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _specialLeaveOptions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final opt = _specialLeaveOptions[index];
                  final isSelected = _specialLeaveType == opt['title'];

                  return InkWell(
                    onTap: () {
                      setState(() => _specialLeaveType = opt['title']);
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF5F3FF) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              opt['icon'] as IconData,
                              size: 20,
                              color: isSelected ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        opt['title'] as String,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? const Color(0xFF5B21B6) : const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEDE9FE),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        opt['duration_info'] as String,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF7C3AED),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  opt['desc'] as String,
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF94A3B8),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
                        Text(
                          'Pengajuan Cuti / Izin',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    HeaderIconButton(
                      icon: Icons.history_rounded,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveHistoryScreen())),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Ajukan cuti bulanan, cuti khusus, atau izin',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quota Card if Cuti Bulanan
                    if (!_isLoadingQuota && _leaveType == 'cuti') ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.event_available_rounded, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sisa Jatah Cuti Bulanan',
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$_sisaCuti Hari',
                                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Jatah: $_jatahCuti Hari',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Section Title: Jenis Pengajuan
                    Text(
                      'PILIH JENIS PENGAJUAN',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),

                    // 3 Choice Cards
                    _buildLeaveTypeCard(
                      value: 'cuti',
                      title: 'Cuti Bulanan / Tahunan',
                      subtitle: 'Memotong jatah sisa cuti Anda',
                      icon: Icons.beach_access_rounded,
                      activeColor: const Color(0xFF0284C7),
                      activeBg: const Color(0xFFF0F9FF),
                      tagText: 'Potong Kuota',
                    ),
                    const SizedBox(height: 10),

                    _buildLeaveTypeCard(
                      value: 'cuti_khusus',
                      title: 'Cuti Khusus',
                      subtitle: 'Melahirkan, Menikah, Ibadah, dll',
                      icon: Icons.star_rounded,
                      activeColor: const Color(0xFF7C3AED),
                      activeBg: const Color(0xFFFAF5FF),
                      tagText: 'Bebas Kuota ✨',
                    ),
                    const SizedBox(height: 10),

                    _buildLeaveTypeCard(
                      value: 'izin',
                      title: 'Izin Sakit / Keperluan Pribadi',
                      subtitle: 'Sakit dengan bukti dokter / keperluan mendesak',
                      icon: Icons.medical_services_rounded,
                      activeColor: const Color(0xFFEA580C),
                      activeBg: const Color(0xFFFFF7ED),
                      tagText: 'Izin Harian',
                    ),

                    // Special Leave Subtype Selector (Shown when cuti_khusus is selected)
                    if (_leaveType == 'cuti_khusus') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Kategori Cuti Khusus',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF5B21B6)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Tidak Potong Cuti',
                                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: _showSpecialLeavePicker,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFC4B5FD)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.stars_rounded, color: Color(0xFF7C3AED), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _specialLeaveType,
                                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                                      ),
                                    ),
                                    const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF7C3AED)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Section Title: Tanggal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TANGGAL PENGAJUAN',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.5),
                        ),
                        if (_selectedDurationDays > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (_leaveType == 'cuti' && _selectedDurationDays > _sisaCuti)
                                  ? const Color(0xFFFEF2F2)
                                  : const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (_leaveType == 'cuti' && _selectedDurationDays > _sisaCuti)
                                    ? const Color(0xFFFCA5A5)
                                    : const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: Text(
                              'Durasi: $_selectedDurationDays Hari',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: (_leaveType == 'cuti' && _selectedDurationDays > _sisaCuti)
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF059669),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, true),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _startDate != null ? AppColors.primary : const Color(0xFFCBD5E1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Tanggal Mulai', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _startDate != null ? DateFormat('d MMM yyyy', 'id_ID').format(_startDate!) : 'Pilih Tanggal',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: _startDate != null ? FontWeight.w600 : FontWeight.normal,
                                            color: _startDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, false),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _endDate != null ? AppColors.primary : const Color(0xFFCBD5E1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Tanggal Selesai', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _endDate != null ? DateFormat('d MMM yyyy', 'id_ID').format(_endDate!) : 'Pilih Tanggal',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: _endDate != null ? FontWeight.w600 : FontWeight.normal,
                                            color: _endDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_leaveType == 'cuti' && _selectedDurationDays > _sisaCuti) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Durasi ($_selectedDurationDays hari) melebihi sisa cuti Anda ($_sisaCuti hari).',
                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFDC2626), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Section Title: Alasan
                    Text(
                      'ALASAN PENGAJUAN',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 3,
                      style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: _leaveType == 'cuti_khusus' 
                            ? 'Jelaskan keperluan cuti khusus secara jelas...' 
                            : 'Tuliskan alasan lengkap pengajuan Anda...',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Alasan pengajuan wajib diisi' : null,
                    ),

                    const SizedBox(height: 20),

                    // Section Title: Bukti Lampiran
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'BUKTI FOTO / SURAT LAMPIRAN',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.5),
                        ),
                        Text(
                          '(Opsional / Wajib Sakit)',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_photoBytes != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                _photoBytes!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _photoName ?? 'Foto Terlampir',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${(_photoBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB',
                                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                              onPressed: _removePhoto,
                              tooltip: 'Hapus Foto',
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.add_a_photo_outlined, size: 24, color: AppColors.primary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Unggah Bukti Foto / Surat Dokter',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'JPG, PNG maksimal 5MB',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        child: _isLoading 
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Kirim Pengajuan Cuti / Izin',
                                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveTypeCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color activeColor,
    required Color activeBg,
    required String tagText,
  }) {
    final isSelected = _leaveType == value;

    return InkWell(
      onTap: () => setState(() => _leaveType = value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? activeColor : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? activeColor.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tagText,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? activeColor : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? activeColor : const Color(0xFFCBD5E1),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

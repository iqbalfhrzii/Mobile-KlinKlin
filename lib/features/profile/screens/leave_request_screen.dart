import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../services/leave_service.dart';

class LeaveRequestScreen extends StatefulWidget {
  final int initialTabIndex; // 0: Pengajuan, 1: Riwayat
  const LeaveRequestScreen({super.key, this.initialTabIndex = 0});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final LeaveService _service = LeaveService();

  // Tab State: 0 = Pengajuan, 1 = Riwayat
  late int _currentTab;

  // Form Fields
  // 'cuti' = Cuti Bulanan/Tahunan, 'cuti_khusus' = Cuti Khusus, 'izin' = Izin
  String _leaveType = 'cuti';
  String _specialLeaveType = 'Melahirkan / Bersalin';
  DateTime? _startDate;
  DateTime? _endDate;
  Uint8List? _photoBytes;
  String? _photoName;
  bool _isLoadingSubmit = false;

  // History State
  bool _isLoadingHistory = true;
  List<dynamic> _history = [];
  String _activeFilter = 'semua'; // 'semua', 'pending', 'disetujui', 'ditolak'

  // Quota Info
  int _jatahCuti = 0;
  int _sisaCuti = 0;
  bool _hasQuota = false;
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
      'title': 'Cuti Khusus Lainnya',
      'icon': Icons.more_horiz_rounded,
      'duration_info': 'Sesuai Kebijakan HRD',
      'desc': 'Cuti khusus di luar ketentuan di atas',
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTabIndex;
    _loadAllData();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        _isLoadingHistory = true;
        _isLoadingQuota = true;
      });
    }

    try {
      final results = await Future.wait([
        _service.getLeaveHistory(),
        _service.getLeaveQuota(),
      ]);

      final historyRes = results[0];
      final quotaRes = results[1];

      if (mounted) {
        setState(() {
          _history = historyRes['data'] ?? [];
          if (quotaRes['data'] != null) {
            _jatahCuti = quotaRes['data']['jatah_cuti'] ?? 0;
            _sisaCuti = quotaRes['data']['sisa_cuti'] ?? 0;
            _hasQuota = true;
          }
          _isLoadingHistory = false;
          _isLoadingQuota = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
          _isLoadingQuota = false;
        });
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

    setState(() => _isLoadingSubmit = true);

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
        SnackbarUtils.showSuccess(context, 'Pengajuan cuti berhasil dikirim');
        _reasonController.clear();
        setState(() {
          _startDate = null;
          _endDate = null;
          _photoBytes = null;
          _photoName = null;
          _currentTab = 1; // Otomatis beralih ke tab Riwayat
        });
        _loadAllData(isRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoadingSubmit = false);
    }
  }

  void _showSpecialLeavePicker() {
    showModalBottomSheet(
      useSafeArea: true,
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
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                        ),
                        Text(
                          'Cuti khusus tidak memotong jatah cuti tahunan',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
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
                itemBuilder: (ctx, index) {
                  final opt = _specialLeaveOptions[index];
                  final isSelected = _specialLeaveType == opt['title'];

                  return InkWell(
                    onTap: () {
                      setState(() => _specialLeaveType = opt['title'] as String);
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
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              opt['icon'] as IconData,
                              color: isSelected ? Colors.white : const Color(0xFF64748B),
                              size: 18,
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
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEDE9FE),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        opt['duration_info'] as String,
                                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF6D28D9)),
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

  // --- HISTORY HELPERS ---
  Color _getStatusColor(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s == 'disetujui' || s == 'diterima' || s == 'approved') {
      return const Color(0xFF059669);
    } else if (s == 'ditolak' || s == 'rejected') {
      return const Color(0xFFDC2626);
    }
    return const Color(0xFFD97706); // pending / menunggu
  }

  Color _getStatusBgColor(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s == 'disetujui' || s == 'diterima' || s == 'approved') {
      return const Color(0xFFECFDF5);
    } else if (s == 'ditolak' || s == 'rejected') {
      return const Color(0xFFFEF2F2);
    }
    return const Color(0xFFFFFBEB); // pending
  }

  String _getStatusLabel(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s == 'disetujui' || s == 'diterima' || s == 'approved') {
      return 'DISETUJUI';
    } else if (s == 'ditolak' || s == 'rejected') {
      return 'DITOLAK';
    }
    return 'MENUNGGU';
  }

  IconData _getTypeIcon(String? type) {
    final t = (type ?? '').toLowerCase();
    if (t.contains('khusus')) return Icons.star_rounded;
    if (t.contains('sakit')) return Icons.medical_services_rounded;
    if (t.contains('cuti')) return Icons.beach_access_rounded;
    if (t.contains('tukar')) return Icons.event_repeat_rounded;
    return Icons.event_note_rounded;
  }

  Color _getTypeColor(String? type) {
    final t = (type ?? '').toLowerCase();
    if (t.contains('khusus')) return const Color(0xFF7C3AED);
    if (t.contains('sakit')) return const Color(0xFFEA580C);
    if (t.contains('cuti')) return const Color(0xFF0284C7);
    if (t.contains('tukar')) return const Color(0xFF9333EA);
    return const Color(0xFF0D9488);
  }

  String _getTypeLabel(String? type, {String? subType, String? alasan}) {
    final t = (type ?? '').toLowerCase();
    if (t.contains('khusus')) {
      if (subType != null && subType.isNotEmpty) return 'CUTI KHUSUS ($subType)';
      if (alasan != null && alasan.contains('[Cuti Khusus:')) {
        final match = RegExp(r'\[Cuti Khusus:\s*([^\]]+)\]').firstMatch(alasan);
        if (match != null) return 'CUTI KHUSUS (${match.group(1)})';
      }
      return 'CUTI KHUSUS';
    }
    if (t == 'cuti') return 'CUTI TAHUNAN (POTONG KUOTA)';
    if (t == 'izin' || t.contains('sakit')) return 'IZIN (POTONG GAJI)';
    if (t.contains('tukar')) return 'TUKAR LIBUR';
    return t.toUpperCase();
  }

  int _calculateDays(String? start, String? end) {
    if (start == null || end == null) return 1;
    try {
      final s = DateTime.parse(start);
      final e = DateTime.parse(end);
      final diff = e.difference(s).inDays + 1;
      return diff > 0 ? diff : 1;
    } catch (_) {
      return 1;
    }
  }

  String _formatDateRange(String? start, String? end) {
    if (start == null) return '-';
    try {
      final s = DateTime.parse(start);
      if (end == null || start == end) {
        return DateFormat('dd MMM yyyy', 'id_ID').format(s);
      }
      final e = DateTime.parse(end);
      return '${DateFormat('dd MMM', 'id_ID').format(s)} - ${DateFormat('dd MMM yyyy', 'id_ID').format(e)}';
    } catch (_) {
      return '$start - ${end ?? ''}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Gradient Header
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
                          'Cuti & Izin',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    HeaderIconButton(
                      icon: Icons.refresh_rounded,
                      onTap: () => _loadAllData(isRefresh: true),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _currentTab == 0
                      ? 'Ajukan permohonan cuti tahunan, khusus, atau izin'
                      : 'Daftar dan status persetujuan permohonan cuti Anda',
                  style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.88)),
                ),
              ],
            ),
          ),

          // Filter Segment Kanan Kiri (Pengajuan vs Riwayat)
          _buildSegmentedTabFilter(),

          // Body Content: Tab 0 (Pengajuan) or Tab 1 (Riwayat)
          Expanded(
            child: _currentTab == 0 ? _buildFormTab() : _buildHistoryTab(),
          ),
        ],
      ),
      floatingActionButton: _currentTab == 1
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _currentTab = 0),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                'Ajukan Cuti / Izin',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13.5),
              ),
            )
          : null,
    );
  }

  // --- FILTER KANAN KIRI ---
  Widget _buildSegmentedTabFilter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Tab Kiri: Pengajuan
          Expanded(
            child: InkWell(
              onTap: () {
                if (_currentTab != 0) setState(() => _currentTab = 0);
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _currentTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _currentTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_calendar_rounded,
                      size: 17,
                      color: _currentTab == 0 ? AppColors.primary : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pengajuan',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: _currentTab == 0 ? FontWeight.bold : FontWeight.w600,
                        color: _currentTab == 0 ? AppColors.primary : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Tab Kanan: Riwayat
          Expanded(
            child: InkWell(
              onTap: () {
                if (_currentTab != 1) {
                  setState(() => _currentTab = 1);
                  _loadAllData(isRefresh: true);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _currentTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _currentTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 18,
                      color: _currentTab == 1 ? AppColors.primary : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Riwayat',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: _currentTab == 1 ? FontWeight.bold : FontWeight.w600,
                        color: _currentTab == 1 ? AppColors.primary : const Color(0xFF64748B),
                      ),
                    ),
                    if (_history.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _currentTab == 1 ? AppColors.primary.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_history.length}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _currentTab == 1 ? AppColors.primary : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: FORMULIR PENGAJUAN ---
  Widget _buildFormTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quota Card jika Cuti Tahunan
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
                            'Sisa Jatah Cuti Tahunan',
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
                        'Jatah: $_jatahCuti Hari/Tahun',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Section: Jenis Pengajuan
            Text(
              'PILIH JENIS PENGAJUAN',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),

            _buildLeaveTypeCard(
              value: 'cuti',
              title: 'Cuti Tahunan (Memotong jatah cuti)',
              subtitle: 'Memotong sisa kuota cuti tahunan Anda',
              icon: Icons.beach_access_rounded,
              activeColor: const Color(0xFF0284C7),
              activeBg: const Color(0xFFF0F9FF),
              tagText: 'Potong Jatah Cuti',
            ),
            const SizedBox(height: 10),

            _buildLeaveTypeCard(
              value: 'izin',
              title: 'Izin Sakit / Keperluan Pribadi (Tidak memotong jatah cuti)',
              subtitle: 'Tidak memotong cuti, berlaku potong gaji harian',
              icon: Icons.medical_services_rounded,
              activeColor: const Color(0xFFEA580C),
              activeBg: const Color(0xFFFFF7ED),
              tagText: 'Tidak Potong Cuti (Potong Gaji)',
            ),
            const SizedBox(height: 10),

            _buildLeaveTypeCard(
              value: 'cuti_khusus',
              title: 'Cuti Khusus (Melahirkan, Menikah, dll)',
              subtitle: 'Melahirkan, Menikah, Khitanan, dll',
              icon: Icons.star_rounded,
              activeColor: const Color(0xFF7C3AED),
              activeBg: const Color(0xFFFAF5FF),
              tagText: 'Tidak Potong Cuti (Berbayar) ✨',
            ),

            // Contextual Information Banner
            if (_leaveType == 'cuti') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pengajuan Cuti Tahunan akan mengurangi kuota sisa cuti tahunan Anda ($_sisaCuti Hari tersisa). Pastikan kuota mencukupi.',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0369A1), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_leaveType == 'izin') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9A3412), height: 1.4),
                          children: const [
                            TextSpan(
                              text: 'Izin Sakit / Keperluan Pribadi ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: 'TIDAK memotong jatah kuota cuti tahunan Anda. Namun hari izin yang diambil akan berlaku ',
                            ),
                            TextSpan(
                              text: 'potong gaji harian (unpaid). ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: 'Wajib lampirkan surat dokter / bukti pendukung jika sakit.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Special Leave Subtype Selector
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

            // Section: Tanggal Pengajuan
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

            // Section: Alasan Pengajuan
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

            // Section: Bukti Foto / Surat Lampiran
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

            const SizedBox(height: 30),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoadingSubmit ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: _isLoadingSubmit
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
    );
  }

  // --- TAB 2: RIWAYAT PENGAJUAN ---
  Widget _buildHistoryTab() {
    if (_isLoadingHistory && _history.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final countPending = _history.where((item) {
      final s = (item['status'] ?? '').toString().toLowerCase();
      return s == 'pending' || s == 'menunggu';
    }).length;

    final countApproved = _history.where((item) {
      final s = (item['status'] ?? '').toString().toLowerCase();
      return s == 'disetujui' || s == 'diterima' || s == 'approved';
    }).length;

    final countRejected = _history.where((item) {
      final s = (item['status'] ?? '').toString().toLowerCase();
      return s == 'ditolak' || s == 'rejected';
    }).length;

    final filtered = _history.where((item) {
      final s = (item['status'] ?? '').toString().toLowerCase();
      if (_activeFilter == 'pending') return s == 'pending' || s == 'menunggu';
      if (_activeFilter == 'disetujui') return s == 'disetujui' || s == 'diterima' || s == 'approved';
      if (_activeFilter == 'ditolak') return s == 'ditolak' || s == 'rejected';
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () => _loadAllData(isRefresh: true),
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_hasQuota) _buildQuotaCard(),
            const SizedBox(height: 14),
            _buildFilterTabs(countPending, countApproved, countRejected),
            const SizedBox(height: 14),
            if (filtered.isEmpty)
              _buildEmptyState()
            else
              ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return _buildLeaveCard(item);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotaCard() {
    final cutiTerpakai = (_jatahCuti - _sisaCuti).clamp(0, _jatahCuti);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.beach_access_rounded, color: Color(0xFF0284C7), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Informasi Kuota Cuti',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Tahun ${DateTime.now().year}',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Jatah', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      Text('$_jatahCuti Hari', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Terpakai', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFDC2626))),
                      const SizedBox(height: 4),
                      Text('$cutiTerpakai Hari', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sisa Cuti', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF059669))),
                      const SizedBox(height: 4),
                      Text('$_sisaCuti Hari', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF059669))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(int pending, int approved, int rejected) {
    final tabs = [
      {'key': 'semua', 'label': 'Semua', 'count': _history.length, 'color': AppColors.textDark},
      {'key': 'pending', 'label': 'Menunggu', 'count': pending, 'color': const Color(0xFFD97706)},
      {'key': 'disetujui', 'label': 'Disetujui', 'count': approved, 'color': const Color(0xFF059669)},
      {'key': 'ditolak', 'label': 'Ditolak', 'count': rejected, 'color': const Color(0xFFDC2626)},
    ];

    return Row(
      children: tabs.map((t) {
        final isSelected = _activeFilter == t['key'];
        final color = t['color'] as Color;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () => setState(() => _activeFilter = t['key'] as String),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? color : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? color : AppColors.border,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      t['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${t['count']}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLeaveCard(dynamic item) {
    final jenis = (item['jenis_pengajuan'] ?? item['jenis'] ?? 'Cuti').toString();
    final status = (item['status'] ?? 'Pending').toString();
    final startStr = item['tanggal_mulai']?.toString();
    final endStr = item['tanggal_selesai']?.toString();
    final alasan = item['alasan']?.toString() ?? '-';
    final adminNote = item['catatan_admin']?.toString();
    final hasPhoto = item['bukti_foto'] != null || item['bukti_foto_url'] != null;

    final statusColor = _getStatusColor(status);
    final statusBgColor = _getStatusBgColor(status);
    final statusLabel = _getStatusLabel(status);

    final typeColor = _getTypeColor(jenis);
    final typeIcon = _getTypeIcon(jenis);
    final days = _calculateDays(startStr, endStr);
    final dateRange = _formatDateRange(startStr, endStr);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetailBottomSheet(item),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Type Pill & Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 13, color: typeColor),
                          const SizedBox(width: 5),
                          Text(
                            _getTypeLabel(jenis, subType: item['tipe_cuti_khusus']?.toString(), alasan: alasan),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: typeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            statusLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Date Range & Duration Badge
                Row(
                  children: [
                    const Icon(Icons.event_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        dateRange,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$days Hari',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Reason Preview
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.format_quote_rounded, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          alasan,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textDark,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Rejection Reason Box if Rejected
                if (status.toLowerCase().contains('tolak') && adminNote != null && adminNote.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Alasan Ditolak: $adminNote',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF7F1D1D),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (hasPhoto)
                      Row(
                        children: [
                          const Icon(Icons.attachment_rounded, size: 14, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(
                            'Ada Bukti Foto',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      children: [
                        Text(
                          'Lihat Detail',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event_available_rounded, size: 40, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 14),
            Text(
              'Belum ada pengajuan pada kategori ini.',
              style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Ajukan cuti tahunan, izin sakit, atau cuti khusus dengan mudah sekarang.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentTab = 0),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Ajukan Cuti Baru', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DETAIL BOTTOM SHEET ---
  void _showDetailBottomSheet(dynamic item) {
    final jenis = (item['jenis_pengajuan'] ?? item['jenis'] ?? 'Cuti').toString();
    final status = (item['status'] ?? 'Pending').toString();
    final startStr = item['tanggal_mulai']?.toString();
    final endStr = item['tanggal_selesai']?.toString();
    final alasan = item['alasan']?.toString() ?? '-';
    final adminNote = item['catatan_admin']?.toString();
    final photoUrl = item['bukti_foto_url'] ?? item['bukti_foto'];

    String? formattedCreatedAt;
    if (item['created_at'] != null) {
      try {
        final dt = DateTime.parse(item['created_at'].toString()).toLocal();
        formattedCreatedAt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
      } catch (_) {
        formattedCreatedAt = item['created_at'].toString();
      }
    }

    final statusColor = _getStatusColor(status);
    final statusBgColor = _getStatusBgColor(status);
    final statusLabel = _getStatusLabel(status);
    final typeColor = _getTypeColor(jenis);
    final typeIcon = _getTypeIcon(jenis);
    final days = _calculateDays(startStr, endStr);
    final dateRange = _formatDateRange(startStr, endStr);

    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pull bar
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
              const SizedBox(height: 16),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(typeIcon, color: typeColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detail Pengajuan',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            jenis.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: typeColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 16),

              // Status Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      statusLabel == 'DISETUJUI'
                          ? Icons.check_circle_rounded
                          : (statusLabel == 'DITOLAK' ? Icons.cancel_rounded : Icons.pending_rounded),
                      color: statusColor,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status: $statusLabel',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                          if (statusLabel == 'MENUNGGU')
                            Text(
                              'Permohonan sedang ditinjau oleh HRD/Admin.',
                              style: GoogleFonts.inter(fontSize: 11, color: statusColor),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Detail Info Pillars
              _buildDetailRow('Periode Izin / Cuti', dateRange),
              const SizedBox(height: 10),
              _buildDetailRow('Total Durasi', '$days Hari Kerja'),
              const SizedBox(height: 10),
              _buildDetailRow('Alasan Lengkap', alasan),

              if (adminNote != null && adminNote.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildDetailRow('Catatan Admin / HRD', adminNote, isWarning: true),
              ],

              if (formattedCreatedAt != null) ...[
                const SizedBox(height: 10),
                _buildDetailRow('Waktu Pengajuan', formattedCreatedAt),
              ],

              if (photoUrl != null && photoUrl.toString().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Lampiran Bukti Foto',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    photoUrl.toString(),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 80,
                      color: const Color(0xFFF1F5F9),
                      alignment: Alignment.center,
                      child: Text('Foto tidak dapat dimuat', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isWarning = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWarning ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isWarning ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isWarning ? const Color(0xFFDC2626) : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isWarning ? const Color(0xFF7F1D1D) : AppColors.textDark,
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

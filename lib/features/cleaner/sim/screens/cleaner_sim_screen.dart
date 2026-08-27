import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/api/api_client.dart';
import '../../../operasional/services/operasional_sim_service.dart';

class CleanerSimScreen extends StatefulWidget {
  const CleanerSimScreen({super.key});

  @override
  State<CleanerSimScreen> createState() => _CleanerSimScreenState();
}

class _CleanerSimScreenState extends State<CleanerSimScreen> {
  final _service = OperasionalSimService();
  final _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _mySimData;

  // Cleaner profile info
  String _userName = '';
  String _userRole = 'Cleaner';
  String _userBranch = '-';
  int _cabangId = 0;

  // Form Controllers
  final _nomorSimController = TextEditingController();
  final _tanggalTerbitController = TextEditingController();
  final _masaBerlakuController = TextEditingController();
  final _kendaraanController = TextEditingController();
  final _keteranganController = TextEditingController();

  String? _selectedJenisSim;
  File? _selectedPhotoFile;

  final List<String> _jenisSimList = [
    'SIM A',
    'SIM B I',
    'SIM B II',
    'SIM C',
    'SIM D',
    'SIM Internasional',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileAndSim();
  }

  @override
  void dispose() {
    _nomorSimController.dispose();
    _tanggalTerbitController.dispose();
    _masaBerlakuController.dispose();
    _kendaraanController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileAndSim() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('user_name') ?? '';
      _userRole = prefs.getString('user_role') ?? 'Cleaner';
      _userBranch = prefs.getString('user_branch') ?? '-';
      _cabangId = prefs.getInt('user_cabang_id') ?? prefs.getInt('user_branch_id') ?? 0;

      // Refresh from API /me
      try {
        final me = await AuthService.getMe();
        final data = me['data'] ?? me;
        if (data != null) {
          if (data['nama'] != null) _userName = data['nama'];
          if (data['cabang'] is Map) {
            _userBranch = data['cabang']['nama_cabang'] ?? _userBranch;
            _cabangId = data['cabang']['id'] ?? _cabangId;
          } else if (data['cabang_id'] != null) {
            _cabangId = int.tryParse(data['cabang_id'].toString()) ?? _cabangId;
          }
          if (data['jabatan'] is Map) {
            _userRole = data['jabatan']['nama_jabatan'] ?? _userRole;
          }
        }
      } catch (_) {}

      // Fetch SIM data to check if this cleaner already has a record
      await _fetchMySim();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchMySim() async {
    try {
      final res = await _service.getSimData(
        search: _userName.isNotEmpty ? _userName : null,
        cabangId: _cabangId > 0 ? _cabangId.toString() : null,
      );

      List<dynamic> list = [];
      if (res['data'] != null) {
        if (res['data'] is List) {
          list = res['data'];
        } else if (res['data']['data'] is List) {
          list = res['data']['data'];
        }
      }

      // If specific search didn't match, fallback to fetch all SIMs and match by name
      if (list.isEmpty) {
        final allRes = await _service.getSimData();
        if (allRes['data'] != null) {
          if (allRes['data'] is List) {
            list = allRes['data'];
          } else if (allRes['data']['data'] is List) {
            list = allRes['data']['data'];
          }
        }
      }

      // Match cleaner's name
      Map<String, dynamic>? match;
      if (_userName.isNotEmpty) {
        for (var item in list) {
          final itemNama = (item['nama_karyawan'] ?? '').toString().trim().toLowerCase();
          if (itemNama == _userName.trim().toLowerCase()) {
            match = Map<String, dynamic>.from(item as Map);
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _mySimData = match;
          if (match != null) {
            _populateFormWithData(match);
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetchMySim: $e");
    }
  }

  void _populateFormWithData(Map<String, dynamic> data) {
    _selectedJenisSim = data['jenis_sim'];
    _nomorSimController.text = data['nomor_sim'] ?? '';
    _tanggalTerbitController.text = (data['tanggal_terbit'] ?? '').toString().split(' ')[0];
    _masaBerlakuController.text = (data['masa_berlaku'] ?? '').toString().split(' ')[0];
    _kendaraanController.text = data['kendaraan_dioperasikan'] ?? '';
    _keteranganController.text = data['keterangan'] ?? '';
    _selectedPhotoFile = null;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1400,
      );
      if (picked != null) {
        setState(() {
          _selectedPhotoFile = File(picked.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih foto: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime initial = DateTime.now();
    if (controller.text.isNotEmpty) {
      initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveSim({BuildContext? modalContext}) async {
    if (_selectedJenisSim == null || _selectedJenisSim!.isEmpty) {
      _showToast('Harap pilih Jenis SIM', isError: true);
      return;
    }
    if (_nomorSimController.text.trim().isEmpty) {
      _showToast('Nomor SIM wajib diisi', isError: true);
      return;
    }
    if (_masaBerlakuController.text.trim().isEmpty) {
      _showToast('Masa berlaku SIM wajib diisi', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> payload = {
        'cabang_id': _cabangId > 0 ? _cabangId : 1,
        'nama_karyawan': _userName.isNotEmpty ? _userName : 'Cleaner',
        'jabatan': _userRole.isNotEmpty ? _userRole : 'Cleaner',
        'jenis_sim': _selectedJenisSim,
        'nomor_sim': _nomorSimController.text.trim(),
        'tanggal_terbit': _tanggalTerbitController.text.trim(),
        'masa_berlaku': _masaBerlakuController.text.trim(),
        'kendaraan_dioperasikan': _kendaraanController.text.trim(),
        'keterangan': _keteranganController.text.trim(),
      };

      Map<String, dynamic> res;
      final isEdit = _mySimData != null && _mySimData!['id'] != null;

      if (isEdit) {
        final id = int.parse(_mySimData!['id'].toString());
        res = await _service.updateSimData(
          id,
          payload,
          filePath: _selectedPhotoFile?.path,
        );
      } else {
        res = await _service.storeSimData(
          payload,
          filePath: _selectedPhotoFile?.path,
        );
      }

      if (res['status'] == true || res['data'] != null) {
        if (modalContext != null && modalContext.mounted) {
          Navigator.of(modalContext).pop();
        }
        _showToast(isEdit ? 'Data SIM berhasil diperbarui!' : 'Data SIM berhasil disimpan!');
        await _fetchMySim();
      } else {
        _showToast(res['message'] ?? 'Gagal menyimpan data SIM', isError: true);
      }
    } catch (e) {
      _showToast('Terjadi kesalahan: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _isExpired(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    try {
      final dt = DateTime.parse(dateStr);
      return dt.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  String _formatDisplayDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            child: Row(
              children: [
                const AppBackButton(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Surat Izin Mengemudi',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Data SIM Karyawan & Masa Berlaku',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : RefreshIndicator(
                    onRefresh: _loadProfileAndSim,
                    color: const Color(0xFF2563EB),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      child: _mySimData != null ? _buildSimDetailView() : _buildSimFormView(isEdit: false),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ==================== VIEW 1: DIGITAL CARD & DETAILS (IF HAS DATA) ====================

  Widget _buildSimDetailView() {
    final data = _mySimData!;
    final jenis = data['jenis_sim'] ?? 'SIM';
    final nomor = data['nomor_sim'] ?? '-';
    final tglTerbit = data['tanggal_terbit'];
    final masaBerlaku = data['masa_berlaku'];
    final kendaraan = data['kendaraan_dioperasikan'] ?? '-';
    final keterangan = data['keterangan'] ?? '-';
    final expired = _isExpired(masaBerlaku);
    final fotoUrl = data['foto_sim'] ?? data['file_foto_sim'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Digital SIM Card Widget
        _buildDigitalSimCard(
          jenisSim: jenis,
          nomorSim: nomor,
          nama: _userName,
          cabang: _userBranch,
          masaBerlaku: masaBerlaku,
          isExpired: expired,
        ),
        const SizedBox(height: 18),

        // 2. Info Detail Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Informasi Lengkap SIM',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: expired ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: expired ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          expired ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                          size: 13,
                          color: expired ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          expired ? 'Kedaluwarsa' : 'Aktif',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: expired ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),

              _buildDetailRow(Icons.calendar_today_outlined, 'Tanggal Terbit', _formatDisplayDate(tglTerbit)),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.event_available_outlined, 'Masa Berlaku', _formatDisplayDate(masaBerlaku)),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.directions_car_outlined, 'Kendaraan Dioperasikan', kendaraan),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.notes_rounded, 'Keterangan', keterangan),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 3. Foto SIM Preview
        if (fotoUrl != null && fotoUrl.toString().isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Foto Fisik SIM',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildNetworkOrFileImage(fotoUrl.toString()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // 4. Edit Button
        ElevatedButton.icon(
          onPressed: () => _openEditModal(),
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: const Text('Edit Data SIM'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildDigitalSimCard({
    required String jenisSim,
    required String nomorSim,
    required String nama,
    required String cabang,
    required dynamic masaBerlaku,
    required bool isExpired,
  }) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Watermark Logo
          Positioned(
            right: -20,
            bottom: -20,
            child: Opacity(
              opacity: 0.08,
              child: Image.asset('assets/images/logo.png', width: 180, errorBuilder: (_, __, ___) => const Icon(Icons.badge, size: 150, color: Colors.white)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.drive_eta_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KLINKLIN INDONESIA',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.85),
                              letterSpacing: 1.1,
                            ),
                          ),
                          Text(
                            'SURAT IZIN MENGEMUDI',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Jenis SIM Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      jenisSim,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                ],
              ),

              // Middle: Nomor SIM & Chip
              Row(
                children: [
                  // SIM Chip Icon
                  Container(
                    width: 32,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE047),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFCA8A04), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Container(width: 1, color: const Color(0xFFCA8A04)),
                        Container(width: 1, color: const Color(0xFFCA8A04)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    nomorSim,
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),

              // Bottom Info: Nama, Cabang & Masa Berlaku
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nama.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Cabang: $cabang',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'BERLAKU HINGGA',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      Text(
                        _formatDisplayDate(masaBerlaku),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isExpired ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkOrFileImage(String path) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
      );
    }
    final baseDomain = ApiClient.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    final fullUrl = '$baseDomain/storage/$path';
    return Image.network(
      fullUrl,
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
    );
  }

  // ==================== VIEW 2: FORM VIEW (FOR CREATE / FIRST TIME / EDIT) ====================

  Widget _buildSimFormView({
    required bool isEdit,
    BuildContext? modalCtx,
    StateSetter? setModalState,
  }) {
    void updateUI(VoidCallback fn) {
      setState(fn);
      if (setModalState != null) {
        setModalState(fn);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Readonly Profile Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName.isNotEmpty ? _userName : 'Cleaner',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cabang: $_userBranch • Jabatan: $_userRole',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  'Otomatis',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Form Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data Surat Izin Mengemudi (SIM)',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),

              // Jenis SIM Dropdown
              _buildDropdownField(
                label: 'Jenis SIM *',
                value: _selectedJenisSim,
                hint: 'Pilih Jenis SIM',
                items: _jenisSimList,
                onChanged: (val) => updateUI(() => _selectedJenisSim = val),
              ),
              const SizedBox(height: 14),

              // Nomor SIM
              _buildTextField(
                controller: _nomorSimController,
                label: 'Nomor SIM *',
                hint: 'Contoh: 1234-5678-901234',
                icon: Icons.badge_outlined,
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 14),

              // Tanggal Terbit & Masa Berlaku
              Row(
                children: [
                  Expanded(
                    child: _buildPickerButton(
                      label: 'Tanggal Terbit',
                      controller: _tanggalTerbitController,
                      hint: 'Pilih Tanggal',
                      icon: Icons.calendar_today_rounded,
                      onTap: () async {
                        await _selectDate(_tanggalTerbitController);
                        updateUI(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPickerButton(
                      label: 'Masa Berlaku *',
                      controller: _masaBerlakuController,
                      hint: 'Pilih Tanggal',
                      icon: Icons.event_available_rounded,
                      onTap: () async {
                        await _selectDate(_masaBerlakuController);
                        updateUI(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Kendaraan Dioperasikan
              _buildTextField(
                controller: _kendaraanController,
                label: 'Kendaraan yang Dioperasikan',
                hint: 'Contoh: Mobil Operasional Innova, Motor Matic...',
                icon: Icons.directions_car_outlined,
              ),
              const SizedBox(height: 14),

              // Keterangan Tambahan
              _buildTextField(
                controller: _keteranganController,
                label: 'Keterangan Tambahan',
                hint: 'Misal: Proses perpanjangan, hilang, dll...',
                icon: Icons.notes_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Foto SIM Upload
              _buildFotoSimPicker(onChanged: () => updateUI(() {})),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Submit Button
        ElevatedButton(
          onPressed: _isSaving ? null : () => _saveSim(modalContext: modalCtx),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  isEdit ? 'Simpan Perubahan' : 'Simpan Data SIM',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  void _openEditModal() {
    if (_mySimData != null) {
      _populateFormWithData(_mySimData!);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Data SIM',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _buildSimFormView(
                        isEdit: true,
                        modalCtx: ctx,
                        setModalState: setModalState,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : null,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
          dropdownColor: Colors.white,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.card_membership_rounded, size: 18, color: Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.inter(fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
            prefixIcon: maxLines == 1 ? Icon(icon, size: 18, color: const Color(0xFF64748B)) : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPickerButton({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final hasVal = controller.text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: hasVal ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasVal ? _formatDisplayDate(controller.text) : hint,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: hasVal ? FontWeight.w600 : FontWeight.normal,
                      color: hasVal ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFotoSimPicker({VoidCallback? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foto Fisik SIM (Opsional)',
          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
        ),
        const SizedBox(height: 8),
        if (_selectedPhotoFile != null) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedPhotoFile!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedPhotoFile = null);
                    if (onChanged != null) onChanged();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await _pickImage(ImageSource.camera);
                  if (onChanged != null) onChanged();
                },
                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                label: const Text('Kamera'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await _pickImage(ImageSource.gallery);
                  if (onChanged != null) onChanged();
                },
                icon: const Icon(Icons.photo_library_outlined, size: 16),
                label: const Text('Galeri'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

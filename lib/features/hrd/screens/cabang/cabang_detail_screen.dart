import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/gradient_header.dart';
import '../../../../../core/data/hrd_models.dart';
import '../../services/hrd_service.dart';
import 'cabang_form_sheet.dart';
import '../karyawan/karyawan_detail_sheet.dart';

class CabangDetailScreen extends StatefulWidget {
  final CabangModel cabang;
  const CabangDetailScreen({super.key, required this.cabang});

  @override
  State<CabangDetailScreen> createState() => _CabangDetailScreenState();
}

class _CabangDetailScreenState extends State<CabangDetailScreen> with SingleTickerProviderStateMixin {
  final HrdService _hrdService = HrdService();
  late TabController _tabController;
  late CabangModel _cabang;

  bool _isLoading = true;
  String _error = '';
  bool _hasChanges = false;

  List<JenisBonusModel> _jenisBonusList = [];
  List<TarifBonusCabangModel> _tarifBonusList = [];
  List<KaryawanModel> _karyawanCabangList = [];
  String _bonusSearchQuery = '';
  String _karyawanSearchQuery = '';

  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _cabang = widget.cabang;
    _tabController = TabController(length: 3, vsync: this);
    _fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final futures = await Future.wait([
        _hrdService.fetchJenisBonus(),
        _hrdService.fetchTarifBonus(_cabang.id),
        _hrdService.fetchKaryawan(all: true),
        _hrdService.fetchCabang(),
      ]);

      final jenisBonus = futures[0] as List<JenisBonusModel>;
      final tarifBonus = futures[1] as List<TarifBonusCabangModel>;
      final allKaryawan = futures[2] as List<KaryawanModel>;
      final allCabang = futures[3] as List<CabangModel>;

      // Update current cabang model if updated
      final updatedCabang = allCabang.firstWhere(
        (c) => c.id == _cabang.id,
        orElse: () => _cabang,
      );

      final cabangEmployees = allKaryawan.where((k) {
        return k.cabangId == _cabang.id || (k.cabang?.id == _cabang.id);
      }).toList();

      if (mounted) {
        setState(() {
          _cabang = updatedCabang;
          _jenisBonusList = jenisBonus;
          _tarifBonusList = tarifBonus;
          _karyawanCabangList = cabangEmployees;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is DioException && e.response?.statusCode == 404) {
            _error = 'Fitur ini belum tersedia di server (404).';
          } else {
            _error = e.toString().replaceFirst('Exception: ', '');
          }
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openEditCabang() async {
    final res = await CabangFormSheet.show(context, cabang: _cabang);
    if (res == true) {
      _hasChanges = true;
      _fetchAllData();
    }
  }

  Future<void> _openGoogleMaps() async {
    if (_cabang.latitude == null || _cabang.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koordinat GPS belum diisi untuk cabang ini')),
      );
      return;
    }
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${_cabang.latitude},${_cabang.longitude}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak dapat membuka Google Maps')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka peta: $e')),
        );
      }
    }
  }

  void _copyText(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label berhasil disalin ke clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatCurrency(num value) {
    return currencyFormatter.format(value);
  }

  String _calculateBatasTelat() {
    final jamMasukStr = _cabang.jamMasuk ?? '08:00';
    final toleransi = _cabang.toleransiTelatMenit ?? 15;
    try {
      final parts = jamMasukStr.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);

      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, hour, minute).add(Duration(minutes: toleransi));
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} WIB';
    } catch (_) {
      return '$jamMasukStr (+$toleransi mnt)';
    }
  }

  // Helper styling category icon & colors for each bonus type
  Map<String, dynamic> _getBonusVisual(String namaBonus) {
    final lower = namaBonus.toLowerCase();
    if (lower.contains('kilo') || lower.contains('jarak')) {
      return {
        'icon': Icons.directions_car_rounded,
        'color': const Color(0xFFF59E0B),
        'bgColor': const Color(0xFFFEF3C7),
      };
    } else if (lower.contains('deep') || lower.contains('bersih')) {
      return {
        'icon': Icons.auto_awesome_rounded,
        'color': const Color(0xFF0284C7),
        'bgColor': const Color(0xFFE0F2FE),
      };
    } else if (lower.contains('salon') || lower.contains('sofa') || lower.contains('kasur')) {
      return {
        'icon': Icons.chair_rounded,
        'color': const Color(0xFF6366F1),
        'bgColor': const Color(0xFFEEF2FF),
      };
    } else if (lower.contains('tip')) {
      return {
        'icon': Icons.paid_rounded,
        'color': const Color(0xFF10B981),
        'bgColor': const Color(0xFFD1FAE5),
      };
    } else if (lower.contains('parkir')) {
      return {
        'icon': Icons.local_parking_rounded,
        'color': const Color(0xFF3B82F6),
        'bgColor': const Color(0xFFDBEAFE),
      };
    } else if (lower.contains('lembur') || lower.contains('waktu')) {
      return {
        'icon': Icons.alarm_on_rounded,
        'color': const Color(0xFF8B5CF6),
        'bgColor': const Color(0xFFEDE9FE),
      };
    } else if (lower.contains('layanan')) {
      return {
        'icon': Icons.handyman_rounded,
        'color': const Color(0xFFEC4899),
        'bgColor': const Color(0xFFFCE7F3),
      };
    }
    return {
      'icon': Icons.card_giftcard_rounded,
      'color': const Color(0xFF0F766E),
      'bgColor': const Color(0xFFCCFBF1),
    };
  }

  // --- SHOW ATUR TARIF BONUS MODAL ---
  Future<void> _showAturTarifSheet(JenisBonusModel jenisBonus, int existingId, int currentNominal) async {
    final visual = _getBonusVisual(jenisBonus.namaBonus);
    final textController = TextEditingController(text: currentNominal > 0 ? currentNominal.toString() : '');
    int selectedAmount = currentNominal;
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle pill
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Header Info
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: visual['bgColor'],
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(visual['icon'], color: visual['color'], size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Atur Tarif Bonus',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                jenisBonus.namaBonus,
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _cabang.kodeCabang != null ? _cabang.kodeCabang!.toUpperCase() : 'CABANG',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 20),

                    Text(
                      'Nominal Tarif (Rp)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // TextField Input
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: TextField(
                        controller: textController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 16, right: 8, top: 12, bottom: 12),
                            child: Text(
                              'Rp',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                          hintText: '0',
                          hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          suffixIcon: textController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 20),
                                  onPressed: () {
                                    textController.clear();
                                    setModalState(() => selectedAmount = 0);
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            selectedAmount = int.tryParse(val) ?? 0;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Quick Nominal Presets
                    Text(
                      'Pilihan Cepat Nominal:',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPresetChip('+ Rp 5.000', 5000, () {
                          final cur = int.tryParse(textController.text) ?? 0;
                          final next = cur + 5000;
                          textController.text = next.toString();
                          setModalState(() => selectedAmount = next);
                        }),
                        _buildPresetChip('+ Rp 10.000', 10000, () {
                          final cur = int.tryParse(textController.text) ?? 0;
                          final next = cur + 10000;
                          textController.text = next.toString();
                          setModalState(() => selectedAmount = next);
                        }),
                        _buildPresetChip('+ Rp 25.000', 25000, () {
                          final cur = int.tryParse(textController.text) ?? 0;
                          final next = cur + 25000;
                          textController.text = next.toString();
                          setModalState(() => selectedAmount = next);
                        }),
                        _buildPresetChip('+ Rp 50.000', 50000, () {
                          final cur = int.tryParse(textController.text) ?? 0;
                          final next = cur + 50000;
                          textController.text = next.toString();
                          setModalState(() => selectedAmount = next);
                        }),
                        ActionChip(
                          avatar: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF64748B)),
                          label: Text(
                            'Reset (Rp 0)',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                          ),
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          onPressed: () {
                            textController.text = '0';
                            setModalState(() => selectedAmount = 0);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF16A34A)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tarif ini berlaku khusus untuk transaksi cleaner di cabang "${_cabang.namaCabang}".',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFF15803D),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSubmitting ? null : () => Navigator.pop(modalCtx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Batal',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    setModalState(() => isSubmitting = true);
                                    try {
                                      final nominalToSave = int.tryParse(textController.text) ?? 0;
                                      await _hrdService.setTarifBonus(
                                        existingId,
                                        _cabang.id,
                                        jenisBonus.id,
                                        nominalToSave,
                                      );
                                      _hasChanges = true;
                                      if (mounted) {
                                        Navigator.pop(modalCtx);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Tarif "${jenisBonus.namaBonus}" berhasil diperbarui!'),
                                            backgroundColor: const Color(0xFF15803D),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        );
                                      }
                                      await _fetchAllData();
                                    } catch (e) {
                                      setModalState(() => isSubmitting = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Gagal menyimpan tarif: $e'),
                                            backgroundColor: const Color(0xFFDC2626),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.check_rounded, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Simpan Tarif',
                                        style: GoogleFonts.inter(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip(String label, int amount, VoidCallback onTap) {
    return ActionChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1E293B),
        ),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onPressed: onTap,
    );
  }

  // --- MODAL TAMBAH JENIS BONUS BARU ---
  Future<void> _showTambahJenisBonusDialog() async {
    final namaCtrl = TextEditingController();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'Jenis Bonus Baru',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tambahkan kategori jenis bonus baru ke sistem.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: namaCtrl,
                autofocus: true,
                style: GoogleFonts.inter(fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: 'Nama Jenis Bonus',
                  hintText: 'Contoh: Bonus Tangga / Area Luar',
                  labelStyle: GoogleFonts.inter(fontSize: 13),
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: Text('Batal', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final nama = namaCtrl.text.trim();
                      if (nama.isEmpty) return;
                      setDialogState(() => isSaving = true);
                      try {
                        await _hrdService.createJenisBonus({'nama_bonus': nama});
                        _hasChanges = true;
                        if (mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Jenis bonus "$nama" berhasil ditambahkan!'),
                              backgroundColor: const Color(0xFF15803D),
                            ),
                          );
                        }
                        await _fetchAllData();
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal menambah bonus: $e'),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Simpan', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAktif = _cabang.status.toLowerCase() == 'aktif';
    final hasKode = _cabang.kodeCabang != null && _cabang.kodeCabang!.trim().isNotEmpty;
    final int configuredBonusCount = _tarifBonusList.where((t) => t.nominal > 0).length;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _hasChanges) {
          // Returning true to refresh parent list
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            // Top Gradient Header
            GradientHeader(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context, _hasChanges),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detail Cabang Operasional',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _cabang.namaCabang,
                              style: GoogleFonts.inter(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Action Buttons: Edit & Refresh
                      IconButton(
                        tooltip: 'Edit Cabang',
                        onPressed: _openEditCabang,
                        icon: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Muat Ulang',
                        onPressed: _fetchAllData,
                        icon: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main Body
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
                                const SizedBox(height: 12),
                                Text(
                                  _error,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 13.5),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _fetchAllData,
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  label: const Text('Coba Lagi'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : NestedScrollView(
                          headerSliverBuilder: (context, innerBoxIsScrolled) {
                            return [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                                  child: Column(
                                    children: [
                                      _buildHeroCard(isAktif, hasKode, configuredBonusCount),
                                      const SizedBox(height: 14),
                                    ],
                                  ),
                                ),
                              ),
                              SliverPersistentHeader(
                                pinned: true,
                                delegate: _SliverTabHeaderDelegate(
                                  TabBar(
                                    controller: _tabController,
                                    isScrollable: true,
                                    tabAlignment: TabAlignment.start,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                                    labelColor: const Color(0xFF0F172A),
                                    unselectedLabelColor: const Color(0xFF64748B),
                                    labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                                    unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                    indicatorColor: const Color(0xFF0F172A),
                                    indicatorWeight: 3,
                                    dividerColor: const Color(0xFFE2E8F0),
                                    tabs: [
                                      Tab(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.card_giftcard_rounded, size: 16),
                                            const SizedBox(width: 6),
                                            const Text('Tarif Bonus'),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '$configuredBonusCount',
                                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Tab(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.business_rounded, size: 16),
                                            SizedBox(width: 6),
                                            Text('Info & Lokasi'),
                                          ],
                                        ),
                                      ),
                                      Tab(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.people_alt_rounded, size: 16),
                                            const SizedBox(width: 6),
                                            const Text('Karyawan'),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '${_karyawanCabangList.length}',
                                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ];
                          },
                          body: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildTabTarifBonus(),
                              _buildTabInfoLokasi(),
                              _buildTabKaryawan(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HERO OVERVIEW CARD ---
  Widget _buildHeroCard(bool isAktif, bool hasKode, int configuredBonusCount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Code Badge + Branch Name + Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    hasKode
                        ? _cabang.kodeCabang!.toUpperCase()
                        : _cabang.namaCabang.substring(0, _cabang.namaCabang.length >= 3 ? 3 : _cabang.namaCabang.length).toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cabang.namaCabang,
                        style: GoogleFonts.inter(
                          fontSize: 17.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFFEF4444)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _cabang.alamat != null && _cabang.alamat!.trim().isNotEmpty
                                  ? _cabang.alamat!
                                  : 'Belum ada alamat kantor',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isAktif ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isAktif ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isAktif ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isAktif ? 'Aktif' : 'Nonaktif',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isAktif ? const Color(0xFF059669) : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (_cabang.targetOmzet != null && _cabang.targetOmzet! > 0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.track_changes_rounded, size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Text(
                      'Target Omzet: ',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
                    ),
                    Text(
                      _formatCurrency(_cabang.targetOmzet!),
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
                    ),
                    const Spacer(),
                    Text('/ bln', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB45309))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 14),

            // 4 Mini KPIs
            Row(
              children: [
                Expanded(
                  child: _buildMiniKpi(
                    icon: Icons.people_outline_rounded,
                    label: 'Karyawan',
                    value: '${_karyawanCabangList.length} Orang',
                    color: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMiniKpi(
                    icon: Icons.card_giftcard_rounded,
                    label: 'Tarif Bonus',
                    value: '$configuredBonusCount / ${_jenisBonusList.length}',
                    color: const Color(0xFF059669),
                    bgColor: const Color(0xFFECFDF5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMiniKpi(
                    icon: Icons.access_time_rounded,
                    label: 'Jam Masuk',
                    value: _cabang.jamMasuk ?? '08:00',
                    color: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFF5F3FF),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniKpi({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: KELOLA TARIF BONUS CLEANER
  // ==========================================
  Widget _buildTabTarifBonus() {
    final filtered = _jenisBonusList.where((jb) {
      if (_bonusSearchQuery.isEmpty) return true;
      return jb.namaBonus.toLowerCase().contains(_bonusSearchQuery.toLowerCase());
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // Section Header Info & Add Category Button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFAF5FF), Color(0xFFF3E8FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9D5FF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade600,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kelola Tarif Bonus Cleaner',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF581C87),
                          ),
                        ),
                        Text(
                          'Khusus diterapkan pada order di ${_cabang.namaCabang}',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF7E22CE),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Atur nominal insentif/bonus per jenis pekerjaan (Kilometer, Salon, Deepclean, Tips, Lembur, dll.) yang otomatis dihitung saat cleaner menyelesaikan order.',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: const Color(0xFF6B21A8),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showTambahJenisBonusDialog,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  label: Text('Tambah Kategori Jenis Bonus', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF7E22CE),
                    side: const BorderSide(color: Color(0xFFD8B4FE)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Search Bar for bonus
        if (_jenisBonusList.length > 5) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Cari kategori bonus...',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12.5),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              ),
              onChanged: (v) => setState(() => _bonusSearchQuery = v),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Bonus list cards
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.card_giftcard_rounded, size: 40, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text(
                  _bonusSearchQuery.isNotEmpty ? 'Kategori bonus tidak ditemukan' : 'Belum ada data jenis bonus',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          )
        else
          ...filtered.map((jb) {
            final tarif = _tarifBonusList.firstWhere(
              (t) => t.jenisBonusId == jb.id,
              orElse: () => TarifBonusCabangModel(id: 0, cabangId: _cabang.id, jenisBonusId: jb.id, nominal: 0),
            );
            return _buildBonusItemCard(jb, tarif);
          }),
      ],
    );
  }

  Widget _buildBonusItemCard(JenisBonusModel jb, TarifBonusCabangModel tarif) {
    final visual = _getBonusVisual(jb.namaBonus);
    final hasNominal = tarif.nominal > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasNominal ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showAturTarifSheet(jb, tarif.id, tarif.nominal),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Category Icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: visual['bgColor'],
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(visual['icon'], color: visual['color'], size: 22),
                ),
                const SizedBox(width: 14),

                // Name & Nominal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        jb.namaBonus,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            hasNominal ? _formatCurrency(tarif.nominal) : 'Belum Diatur (Rp 0)',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: hasNominal ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (hasNominal)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Aktif',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF059669),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Atur Button
                ElevatedButton(
                  onPressed: () => _showAturTarifSheet(jb, tarif.id, tarif.nominal),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasNominal ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                    foregroundColor: hasNominal ? const Color(0xFF1E293B) : Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 14, color: hasNominal ? const Color(0xFF1E293B) : Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        'Atur',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: INFORMASI & LOKASI
  // ==========================================
  Widget _buildTabInfoLokasi() {
    final hasAlamat = _cabang.alamat != null && _cabang.alamat!.trim().isNotEmpty;
    final hasCoordinates = _cabang.latitude != null && _cabang.longitude != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // CARD 1: Alamat Operasional
        _buildSectionContainer(
          icon: Icons.storefront_rounded,
          iconColor: const Color(0xFF0284C7),
          title: 'Alamat Operasional',
          trailing: hasAlamat
              ? TextButton.icon(
                  onPressed: () => _copyText(_cabang.alamat!, 'Alamat'),
                  icon: const Icon(Icons.copy_rounded, size: 13),
                  label: const Text('Salin', style: TextStyle(fontSize: 11.5)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasAlamat ? _cabang.alamat! : 'Belum ada alamat kantor yang dicatat.',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: hasAlamat ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // CARD 2: Jam Kerja & Presensi
        _buildSectionContainer(
          icon: Icons.schedule_rounded,
          iconColor: const Color(0xFF7C3AED),
          title: 'Jadwal Kerja & Presensi',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildScheduleBox(
                      icon: Icons.login_rounded,
                      label: 'Jam Masuk',
                      value: _cabang.jamMasuk ?? '08:00',
                      subtext: 'WIB',
                      color: const Color(0xFF16A34A),
                      bgColor: const Color(0xFFF0FDF4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildScheduleBox(
                      icon: Icons.timer_outlined,
                      label: 'Batas Toleransi',
                      value: '+${_cabang.toleransiTelatMenit ?? 15} Menit',
                      subtext: 'Batas: ${_calculateBatasTelat()}',
                      color: const Color(0xFFD97706),
                      bgColor: const Color(0xFFFFFBEB),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildScheduleBox(
                      icon: Icons.logout_rounded,
                      label: 'Jam Pulang',
                      value: _cabang.jamPulang ?? '17:00',
                      subtext: 'WIB',
                      color: const Color(0xFFDC2626),
                      bgColor: const Color(0xFFFEF2F2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Karyawan yang presensi masuk setelah pukul ${_calculateBatasTelat()} akan tercatat terlambat oleh sistem.',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // CARD 3: Lokasi & Geofence GPS Absensi
        _buildSectionContainer(
          icon: Icons.radar_rounded,
          iconColor: const Color(0xFF059669),
          title: 'Lokasi & Geofence Absensi',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: hasCoordinates ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              hasCoordinates ? 'GPS Terkonfigurasi' : 'Belum Diatur',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: hasCoordinates ? const Color(0xFF059669) : const Color(0xFF64748B),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasCoordinates) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildGpsField(
                        label: 'Latitude',
                        value: _cabang.latitude.toString(),
                        onCopy: () => _copyText(_cabang.latitude.toString(), 'Latitude'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildGpsField(
                        label: 'Longitude',
                        value: _cabang.longitude.toString(),
                        onCopy: () => _copyText(_cabang.longitude.toString(), 'Longitude'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.share_location_rounded, size: 16, color: Color(0xFF334155)),
                      const SizedBox(width: 8),
                      Text(
                        'Radius Valid Absensi: ',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                      ),
                      Text(
                        '${_cabang.radiusAbsensiMeter ?? 100} meter',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openGoogleMaps,
                    icon: const Icon(Icons.map_rounded, size: 16),
                    label: Text('Buka Titik Lokasi di Google Maps', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const Icon(Icons.location_off_rounded, size: 32, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 6),
                      Text(
                        'Titik koordinat GPS kantor belum ditentukan.',
                        style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _openEditCabang,
                        icon: const Icon(Icons.add_location_alt_rounded, size: 15),
                        label: Text('Atur Lokasi Sekarang', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionContainer({
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildScheduleBox({
    required IconData icon,
    required String label,
    required String value,
    required String subtext,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(subtext, style: GoogleFonts.inter(fontSize: 9.5, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildGpsField({required String label, required String value, required VoidCallback onCopy}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onCopy,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy_rounded, size: 14, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: DAFTAR KARYAWAN CABANG
  // ==========================================
  Widget _buildTabKaryawan() {
    final filtered = _karyawanCabangList.where((k) {
      if (_karyawanSearchQuery.isEmpty) return true;
      final q = _karyawanSearchQuery.toLowerCase();
      return k.nama.toLowerCase().contains(q) || (k.jabatan?.namaJabatan.toLowerCase().contains(q) ?? false);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // Summary & Search
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Cari staf / cleaner cabang...',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  ),
                  onChanged: (v) => setState(() => _karyawanSearchQuery = v),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.people_outline_rounded, size: 40, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text(
                  _karyawanSearchQuery.isNotEmpty
                      ? 'Tidak ada staf sesuai pencarian'
                      : 'Belum ada karyawan yang terdaftar di cabang ini',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          )
        else
          ...filtered.map((karyawan) => _buildKaryawanCard(karyawan)),
      ],
    );
  }

  Widget _buildKaryawanCard(KaryawanModel karyawan) {
    final jabatanName = karyawan.jabatan?.namaJabatan ?? 'Staf';
    final isCleaner = jabatanName.toLowerCase().contains('cleaner');
    final isAktif = karyawan.status.toLowerCase() == 'aktif';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        onTap: () {
          KaryawanDetailSheet.show(context, karyawan: karyawan);
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: isCleaner ? const Color(0xFFEFF6FF) : const Color(0xFFF5F3FF),
          child: Text(
            karyawan.nama.isNotEmpty ? karyawan.nama[0].toUpperCase() : '?',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: isCleaner ? const Color(0xFF2563EB) : const Color(0xFF7C3AED),
            ),
          ),
        ),
        title: Text(
          karyawan.nama,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isCleaner ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                jabatanName,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isCleaner ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: isAktif ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              isAktif ? 'Aktif' : 'Nonaktif',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                color: isAktif ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
      ),
    );
  }
}

class _SliverTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabHeaderDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabHeaderDelegate oldDelegate) {
    return false;
  }
}

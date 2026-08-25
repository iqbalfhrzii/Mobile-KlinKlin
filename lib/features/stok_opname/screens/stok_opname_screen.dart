import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/api/api_client.dart';
import '../services/stok_opname_service.dart';

class StokOpnameScreen extends StatefulWidget {
  const StokOpnameScreen({super.key});

  @override
  State<StokOpnameScreen> createState() => _StokOpnameScreenState();
}

class _StokOpnameScreenState extends State<StokOpnameScreen> {
  DateTime _selectedDate = DateTime.now();
  String _filterBulan = DateFormat('MM').format(DateTime.now());
  String _filterTahun = DateFormat('yyyy').format(DateTime.now());

  String _activePeriode = 'tengah_bulan'; // 'tengah_bulan', 'akhir_bulan'
  String _activeKategori = 'MSN'; // MSN, CLA, BHP, INV

  Map<String, dynamic>? _activeSession;
  List<dynamic> _allMonthSessions = [];
  bool _isLoading = false;
  List<dynamic> _details = [];
  List<dynamic> _pembelianBhps = [];
  String? _authToken;
  String _userRole = '';
  bool _isOperasional = false;

  final List<Map<String, dynamic>> _categories = [
    {
      'code': 'MSN',
      'label': 'Mesin Alat',
      'short': 'MSN',
      'icon': Icons.precision_manufacturing_rounded,
      'color': Color(0xFF2563EB),
    },
    {
      'code': 'CLA',
      'label': 'Cleaning Alat',
      'short': 'CLA',
      'icon': Icons.cleaning_services_rounded,
      'color': Color(0xFF0D9488),
    },
    {
      'code': 'BHP',
      'label': 'Habis Pakai',
      'short': 'BHP',
      'icon': Icons.inventory_2_rounded,
      'color': Color(0xFFEA580C),
    },
    {
      'code': 'INV',
      'label': 'Inventaris',
      'short': 'INV',
      'icon': Icons.home_repair_service_rounded,
      'color': Color(0xFF7C3AED),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAuthToken();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSession();
    });
  }

  Future<void> _loadAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('auth_token');
      _userRole = prefs.getString('user_role') ?? '';
      _isOperasional = _userRole.toLowerCase().contains('operasional');
      if (mounted) setState(() {});
    } catch (_) {}
  }

  String _getImageUrl(dynamic rawPath) {
    if (rawPath == null) return '';
    String p = rawPath.toString().trim().replaceAll(r'\', '/');
    if (p.isEmpty || p == 'null') return '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;

    final baseDomain = ApiClient.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    if (p.startsWith('public/')) {
      p = p.substring(7);
    }
    if (p.startsWith('storage/')) {
      return '$baseDomain/$p';
    }
    return '$baseDomain/storage/$p';
  }

  String _formatBulanTahun(DateTime dt) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April',
      'Mei', 'Juni', 'Juli', 'Agustus',
      'September', 'Oktober', 'November', 'Desember'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _fetchSession() async {
    if (_activePeriode.isEmpty) return;

    setState(() {
      _isLoading = true;
      _activeSession = null;
      _details = [];
      _pembelianBhps = [];
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final cabangId = prefs.getInt('user_cabang_id') ?? 1;

      // 1. Fetch BHP purchases for this month & branch
      final bhps = await StokOpnameService.getBhps(
        bulan: int.tryParse(_filterBulan),
        tahun: int.tryParse(_filterTahun),
        cabangId: cabangId,
      );

      // 2. Fetch Sessions
      final sessions = await StokOpnameService.getSessions(cabangId: cabangId);
      _allMonthSessions = sessions;

      final targetPeriode = '$_filterTahun-$_filterBulan';
      var session = sessions.firstWhere(
        (s) => s['periode_bulan'] == targetPeriode && s['tipe_sesi'] == _activePeriode,
        orElse: () => null,
      );

      // Auto start draft session if not yet started (only for CS/Branch, not Operasional)
      if (session == null && !_isOperasional) {
        final req = {
          'cabang_id': cabangId,
          'periode_bulan': targetPeriode,
          'tipe_sesi': _activePeriode,
          'tanggal_checklist': DateTime.now().toIso8601String().split('T')[0],
        };
        final newSession = await StokOpnameService.startSession(req);
        if (newSession != null) {
          session = newSession;
        }
      }

      if (session != null && session['id'] != null) {
        final sessionDetails = await StokOpnameService.getSessionDetails(session['id']);
        if (mounted) {
          setState(() {
            _activeSession = sessionDetails ?? session;
            _details = sessionDetails?['details'] ?? [];
            _pembelianBhps = bhps;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _activeSession = null;
            _details = [];
            _pembelianBhps = bhps;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data stok opname: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _getSessionStatus(String tipeSesi) {
    final targetPeriode = '$_filterTahun-$_filterBulan';
    final s = _allMonthSessions.firstWhere(
      (session) => session['periode_bulan'] == targetPeriode && session['tipe_sesi'] == tipeSesi,
      orElse: () => null,
    );
    if (s == null) {
      return {'label': 'Belum Ada', 'isSelesai': false, 'exists': false};
    }
    final isSelesai = (s['status'] ?? '').toString().toLowerCase() == 'selesai';
    return {
      'label': isSelesai ? 'Selesai' : 'Sedang Berjalan',
      'isSelesai': isSelesai,
      'exists': true,
    };
  }

  Map<String, dynamic>? _getBhpDetail(dynamic bhp) {
    if (bhp == null) return null;
    final int? bhpId = bhp['id'];
    if (bhpId == null) return null;

    for (var d in _details) {
      if (d['pembelian_bhp_id'] == bhpId || d['pembelian_bhp']?['id'] == bhpId) {
        return d;
      }
    }

    if (bhp['stok_opname_details'] is List && (bhp['stok_opname_details'] as List).isNotEmpty) {
      return (bhp['stok_opname_details'] as List).first as Map<String, dynamic>;
    }
    return null;
  }

  List<dynamic> _getItemsForCategory(String kategoriKode) {
    if (kategoriKode == 'BHP') {
      return _pembelianBhps;
    }

    return _details.where((detail) {
      final kodeItemFisik = detail['item_fisik']?['barang']?['kategori']?['kode_kategori'] ?? '';
      final kodeBarang = detail['barang']?['kategori']?['kode_kategori'] ?? '';
      return kodeItemFisik == kategoriKode || kodeBarang == kategoriKode;
    }).toList();
  }

  Future<void> _selesaikanSesi() async {
    if (_activeSession == null) return;

    final confirm = await AppConfirmationDialog.show(
      context,
      title: 'Selesaikan Sesi Opname?',
      message: 'Setelah sesi opname diselesaikan, seluruh data checklist pada periode ini akan terkunci dan tidak dapat diubah.',
      type: ConfirmationDialogType.success,
      confirmText: 'Selesaikan',
      cancelText: 'Batal',
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await StokOpnameService.finishSession(_activeSession!['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesi opname berhasil diselesaikan'),
              backgroundColor: Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _fetchSession();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menyelesaikan sesi: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _hapusDetail(int detailId, String confirmMessage) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 22),
            const SizedBox(width: 8),
            Text('Konfirmasi Hapus', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: Text(
          confirmMessage,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Ya, Hapus', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final success = await StokOpnameService.deleteDetail(detailId);
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Item berhasil dihapus dari checklist'),
                backgroundColor: Color(0xFF059669),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          _fetchSession();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus item: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _openInputModal({dynamic detailItem, dynamic bhpItem, String? initialQr}) {
    final bool isBhpMode = _activeKategori == 'BHP' || bhpItem != null;
    final isSelesai = (_activeSession?['status'] ?? '').toString().toLowerCase() == 'selesai';

    if (isSelesai) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi opname ini sudah selesai dan terkunci'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final qrController = TextEditingController(
      text: initialQr ?? detailItem?['item_fisik']?['kode_qr'] ?? detailItem?['barang']?['kode_barang'] ?? '',
    );
    final sisaController = TextEditingController(
      text: detailItem?['sisa_akhir']?.toString() ??
          detailItem?['jumlah_fisik']?.toString() ??
          bhpItem?['qty']?.toString() ??
          '0',
    );
    final catatanController = TextEditingController(
      text: detailItem?['keterangan']?.toString() ?? detailItem?['catatan']?.toString() ?? '',
    );

    String selectedKondisi = detailItem?['kondisi']?.toString() ?? 'Baik';
    File? selectedFoto;
    String? currentFotoUrl = detailItem?['foto_path'] ?? detailItem?['foto_item'] ?? detailItem?['foto'];
    final picker = ImagePicker();
    bool isSaving = false;

    dynamic activeBhp = bhpItem ?? (isBhpMode ? (detailItem?['pembelian_bhp'] ?? detailItem?['barang']) : null);
    dynamic detectedItem = detailItem?['item_fisik'];
    bool isSearchingQr = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            Future<void> lookupQr(String k) async {
              if (k.trim().isEmpty) return;
              setStateModal(() => isSearchingQr = true);
              try {
                final matchBhp = _pembelianBhps.firstWhere(
                  (b) =>
                      b['kode_pembelian']?.toString().toUpperCase() == k.trim().toUpperCase() ||
                      b['nama_barang']?.toString().toUpperCase() == k.trim().toUpperCase(),
                  orElse: () => null,
                );

                if (matchBhp != null) {
                  setStateModal(() {
                    isSearchingQr = false;
                    activeBhp = matchBhp;
                  });
                  return;
                }

                final item = await StokOpnameService.scanQr(k);
                setStateModal(() {
                  isSearchingQr = false;
                  detectedItem = item;
                });
              } catch (_) {
                setStateModal(() => isSearchingQr = false);
              }
            }

            if (initialQr != null && initialQr.isNotEmpty && detectedItem == null && activeBhp == null && !isSearchingQr) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                lookupQr(initialQr);
              });
            }

            Future<void> pickImage(ImageSource source) async {
              try {
                final picked = await picker.pickImage(source: source, imageQuality: 80);
                if (picked != null) {
                  setStateModal(() {
                    selectedFoto = File(picked.path);
                    currentFotoUrl = null;
                  });
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal mengambil foto: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isBhpMode ? Icons.inventory_2_rounded : (detailItem != null ? Icons.edit_note_rounded : Icons.qr_code_scanner_rounded),
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  isBhpMode
                                      ? (detailItem != null ? 'Edit Sisa Opname BHP' : 'Input Sisa Opname BHP')
                                      : (detailItem != null ? 'Edit Checklist Opname' : 'Scan & Input Item Opname'),
                                  style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. BHP ITEM INFO
                              if (isBhpMode && activeBhp != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            activeBhp['kode_pembelian'] ?? '-',
                                            style: GoogleFonts.firaCode(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0284C7)),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Qty Beli: ${activeBhp['qty']} ${activeBhp['satuan'] ?? 'pcs'}',
                                              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${activeBhp['nama_barang']} ${activeBhp['merk_barang'] != null && activeBhp['merk_barang'] != '' ? '(${activeBhp['merk_barang']})' : ''}',
                                        style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Toko: ${activeBhp['toko_pembelian'] ?? '-'} • Tgl: ${activeBhp['tanggal_pembelian'] ?? '-'}',
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // 2. QR Search / Input Field (MSN, CLA, INV)
                              if (!isBhpMode) ...[
                                Text('KODE QR / SCAN ITEM', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: qrController,
                                        style: GoogleFonts.firaCode(fontSize: 13, fontWeight: FontWeight.w700),
                                        decoration: InputDecoration(
                                          hintText: 'Contoh: MSN/SBY/0826/A/001',
                                          prefixIcon: const Icon(Icons.qr_code_2_rounded, size: 20, color: Color(0xFF64748B)),
                                          isDense: true,
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        ),
                                        onFieldSubmitted: (v) => lookupQr(v),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: isSearchingQr ? null : () => lookupQr(qrController.text),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                      child: isSearchingQr
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : const Icon(Icons.search_rounded, size: 20),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Detected Item Name
                                if (detectedItem != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFDBEAFE)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            detectedItem['barang']?['nama_barang'] ?? detectedItem['nama_item'] ?? 'Item Terdeteksi',
                                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E40AF)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Condition Selector (100% Web Parity: 5 Options with exact descriptions)
                                Text('KONDISI ITEM *', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: [
                                        'Baik',
                                        'Rusak',
                                        'Lagi di service',
                                        'Hilang',
                                        'Baik (Pernah diservice)'
                                      ].contains(selectedKondisi)
                                          ? selectedKondisi
                                          : 'Baik',
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'Baik',
                                          child: Row(
                                            children: [
                                              Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text('Baik - Berfungsi Normal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                              ),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Rusak',
                                          child: Row(
                                            children: [
                                              Icon(Icons.error_rounded, color: Color(0xFFDC2626), size: 16),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text('Rusak - Perlu Perbaikan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                              ),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Lagi di service',
                                          child: Row(
                                            children: [
                                              Icon(Icons.build_circle_rounded, color: Color(0xFFD97706), size: 16),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text('Lagi di service - Sedang diperbaiki', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                              ),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Hilang',
                                          child: Row(
                                            children: [
                                              Icon(Icons.help_rounded, color: Color(0xFF475569), size: 16),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text('Hilang - Tidak Ditemukan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                              ),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Baik (Pernah diservice)',
                                          child: Row(
                                            children: [
                                              Icon(Icons.verified_rounded, color: Color(0xFF0D9488), size: 16),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text('Baik (Pernah diservice) - Normal bekas servis', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setStateModal(() => selectedKondisi = val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ] else ...[
                                // Sisa Akhir Input (BHP)
                                Text('SISA AKHIR FISIK DIOPNAME', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: sisaController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    hintText: 'Masukkan sisa stok aktual',
                                    suffixText: activeBhp?['satuan'] ?? 'pcs',
                                    suffixStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primary),
                                    prefixIcon: const Icon(Icons.pin_rounded, size: 20, color: Color(0xFF64748B)),
                                    isDense: true,
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Catatan Field
                              Text('CATATAN / KETERANGAN', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: catatanController,
                                maxLines: 2,
                                style: GoogleFonts.inter(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Tulis keterangan kondisi atau catatan opname...',
                                  isDense: true,
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Foto Section
                              Text('FOTO BUKTI FISIK AKTUAL', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                              const SizedBox(height: 8),
                              if (selectedFoto != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(selectedFoto!, height: 160, width: double.infinity, fit: BoxFit.cover),
                                ),
                                const SizedBox(height: 8),
                              ] else if (currentFotoUrl != null && currentFotoUrl!.isNotEmpty) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(_getImageUrl(currentFotoUrl), height: 160, width: double.infinity, fit: BoxFit.cover),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => pickImage(ImageSource.camera),
                                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                                      label: const Text('Kamera'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => pickImage(ImageSource.gallery),
                                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                                      label: const Text('Galeri'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF64748B),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Action Submit
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (_activeSession == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesi opname belum aktif')));
                                      return;
                                    }
                                    setStateModal(() => isSaving = true);
                                    try {
                                      final formData = dio.FormData.fromMap({
                                        'stok_opname_id': _activeSession!['id'],
                                        'kondisi': selectedKondisi,
                                        'keterangan': catatanController.text,
                                        'sisa_akhir': double.tryParse(sisaController.text) ?? 0,
                                        'jumlah_fisik': double.tryParse(sisaController.text) ?? 0,
                                        if (detailItem?['id'] != null) 'detail_id': detailItem['id'],
                                        if (detectedItem?['id'] != null) 'item_fisik_id': detectedItem['id'],
                                        if (qrController.text.isNotEmpty) 'kode_qr': qrController.text,
                                        if (activeBhp?['id'] != null) 'pembelian_bhp_id': activeBhp['id'],
                                        if (selectedFoto != null)
                                          'foto': await dio.MultipartFile.fromFile(
                                            selectedFoto!.path,
                                            filename: 'opname_${DateTime.now().millisecondsSinceEpoch}.jpg',
                                          ),
                                      });

                                      if (isBhpMode) {
                                        await StokOpnameService.submitBhpOpname(formData);
                                      } else {
                                        await StokOpnameService.submitItem(formData);
                                      }

                                      if (ctx.mounted) Navigator.pop(ctx);
                                      _fetchSession();
                                    } catch (e) {
                                      setStateModal(() => isSaving = false);
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text('Gagal menyimpan opname: $e'), backgroundColor: Colors.red),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: isSaving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text('Simpan Data Opname', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final isSelesai = (_activeSession?['status'] ?? '').toString().toLowerCase() == 'selesai';
    final isReadOnly = isSelesai || _isOperasional;
    final hasItems = _details.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // 1. Sleek Gradient Header with Integrated Month Picker
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    if (Navigator.canPop(context)) ...[
                      const AppBackButton(),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isOperasional ? 'Monitoring Stok Opname' : 'Stok Opname Cabang',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isOperasional ? 'Monitoring pengecekan fisik aset & bahan operasional' : 'Pengecekan fisik aset & bahan operasional',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                          helpText: 'PILIH PERIODE OPNAME',
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                            _filterBulan = DateFormat('MM').format(picked);
                            _filterTahun = DateFormat('yyyy').format(picked);
                          });
                          _fetchSession();
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 5),
                            Text(
                              _formatBulanTahun(_selectedDate),
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Integrated Hero Overview & Session Switcher Card
          _buildHeroOverviewCard(isReadOnly),

          // 3. Category Horizontal Pills Selector
          _buildCategoryPillsBar(),

          // 4. Main Scrollable List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: _fetchSession,
                    color: AppColors.primary,
                    child: _buildItemListView(_activeKategori, isReadOnly),
                  ),
          ),
        ],
      ),

      // 5. Fixed Bottom Action Bar (Only for non-operasional and when session is active & not finished)
      bottomNavigationBar: (!isReadOnly && _activeSession != null)
          ? Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 6 : 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -3)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final String? scannedCode = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const QrScannerScreen()),
                        );
                        if (scannedCode != null && scannedCode.isNotEmpty) {
                          final qUpper = scannedCode.trim().toUpperCase();
                          final matchBhp = _pembelianBhps.firstWhere(
                            (b) => b['kode_pembelian']?.toString().toUpperCase() == qUpper || b['nama_barang']?.toString().toUpperCase() == qUpper,
                            orElse: () => null,
                          );
                          if (matchBhp != null || qUpper.startsWith('BHP')) {
                            setState(() => _activeKategori = 'BHP');
                            _openInputModal(bhpItem: matchBhp, initialQr: scannedCode);
                          } else {
                            _openInputModal(initialQr: scannedCode);
                          }
                        } else {
                          _openInputModal();
                        }
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: Text('Scan / Input', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (hasItems) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _selesaikanSesi,
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text('Selesaikan Sesi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            )
          : null,
    );
  }

  // --- HERO OVERVIEW & SESSION SWITCHER ---
  Widget _buildHeroOverviewCard(bool isSelesai) {
    final statusAwal = _getSessionStatus('tengah_bulan');
    final statusAkhir = _getSessionStatus('akhir_bulan');

    final totalItems = _details.length;
    final int baikCount = _details.where((d) => (d['kondisi'] ?? '').toString().toLowerCase() == 'baik').length;
    final int rusakCount = _details.where((d) => (d['kondisi'] ?? '').toString().toLowerCase().contains('rusak') || (d['kondisi'] ?? '').toString().toLowerCase().contains('service')).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Switcher Sesi
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSessionTab(
                    value: 'tengah_bulan',
                    title: 'Awal Bulan',
                    sub: 'Tgl 15',
                    status: statusAwal,
                  ),
                ),
                Expanded(
                  child: _buildSessionTab(
                    value: 'akhir_bulan',
                    title: 'Akhir Bulan',
                    sub: 'Tgl 30',
                    status: statusAkhir,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Mini Stats Row
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  label: 'Total Data',
                  value: '$totalItems Item',
                  icon: Icons.checklist_rounded,
                  color: const Color(0xFF0284C7),
                  bg: const Color(0xFFF0F9FF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricItem(
                  label: 'Kondisi Baik',
                  value: '$baikCount Item',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF16A34A),
                  bg: const Color(0xFFF0FDF4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricItem(
                  label: 'Perlu Servis',
                  value: '$rusakCount Item',
                  icon: Icons.build_circle_outlined,
                  color: rusakCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                  bg: rusakCount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTab({
    required String value,
    required String title,
    required String sub,
    required Map<String, dynamic> status,
  }) {
    final isSelected = _activePeriode == value;
    final bool isSelesai = status['isSelesai'] == true;
    final bool exists = status['exists'] == true;

    return InkWell(
      onTap: () {
        if (_activePeriode != value) {
          setState(() => _activePeriode = value);
          _fetchSession();
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                ]
              : [],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '($sub)',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isSelesai ? const Color(0xFF16A34A) : (exists ? const Color(0xFFEAB308) : const Color(0xFFCBD5E1)),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  status['label'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isSelesai ? const Color(0xFF15803D) : (exists ? const Color(0xFFB45309) : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  // --- CATEGORY PILLS BAR (Non-Scrollable 4-Segment Bar) ---
  Widget _buildCategoryPillsBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: _categories.map((cat) {
            final code = cat['code'] as String;
            final short = cat['short'] as String;
            final icon = cat['icon'] as IconData;
            final isSelected = _activeKategori == code;
            final count = _getItemsForCategory(code).length;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => setState(() => _activeKategori = code),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 14,
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          short,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                            color: isSelected ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : (count > 0 ? const Color(0xFFE2E8F0) : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // --- ITEM LIST VIEW ---
  Widget _buildItemListView(String kategoriKode, bool isSelesai) {
    final filtered = _getItemsForCategory(kategoriKode);
    final catMap = _categories.firstWhere((c) => c['code'] == kategoriKode, orElse: () => _categories.first);
    final fullName = '${catMap['label']} ($kategoriKode)';
    final catIcon = catMap['icon'] as IconData;

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(catIcon, size: 40, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 14),
              Text(
                kategoriKode == 'BHP' ? 'Belum Ada Pembelian BHP' : 'Belum Ada Data $fullName',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 5),
              Text(
                kategoriKode == 'BHP'
                    ? 'Belum ada data pembelian barang habis pakai pada bulan ini.'
                    : 'Gunakan tombol Scan QR atau Input Manual di bawah untuk menambahkan item checklist.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = filtered[index];
        final bool isBhp = kategoriKode == 'BHP';
        return isBhp ? _buildBhpCard(item, isSelesai) : _buildAlatCard(item, isSelesai);
      },
    );
  }

  // --- ALAT CARD (MSN, CLA, INV) ---
  Widget _buildAlatCard(dynamic item, bool isSelesai) {
    final itemFisik = item['item_fisik'] ?? {};
    final barang = itemFisik['barang'] ?? item['barang'] ?? {};
    final waktu = item['created_at'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(item['created_at']))
        : '-';
    final kodeQr = itemFisik['kode_qr'] ?? '-';
    final namaAlat = barang['nama_barang'] ?? itemFisik['nama_item'] ?? '-';
    final kondisi = (item['kondisi'] ?? 'Baik').toString();

    final String fotoAktual = _getImageUrl(
      item['foto_path'] ?? item['foto_item'] ?? item['foto'] ?? item['foto_url'],
    );
    final String fotoAwal = _getImageUrl(
      itemFisik['foto_path'] ?? itemFisik['foto'] ?? barang['foto'] ?? barang['foto_path'],
    );

    final keterangan = item['keterangan'] ?? '-';

    Color kondisiColor = const Color(0xFF059669);
    Color kondisiBg = const Color(0xFFDCFCE7);

    if (kondisi.toLowerCase().contains('service') || kondisi.toLowerCase().contains('diservice')) {
      kondisiColor = const Color(0xFF0D9488);
      kondisiBg = const Color(0xFFCCFBF1);
    } else if (kondisi.toLowerCase() == 'rusak') {
      kondisiColor = const Color(0xFFDC2626);
      kondisiBg = const Color(0xFFFEE2E2);
    } else if (kondisi.toLowerCase() == 'hilang') {
      kondisiColor = const Color(0xFFD97706);
      kondisiBg = const Color(0xFFFEF3C7);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1E293B).withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: QR Code & Kondisi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 13, color: Color(0xFF475569)),
                    const SizedBox(width: 4),
                    Text(
                      kodeQr,
                      style: GoogleFonts.firaCode(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: kondisiBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  kondisi.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: kondisiColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Name & Checklist Time
          Text(
            namaAlat,
            style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                'Waktu Checklist: $waktu',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
              ),
            ],
          ),

          // Photos Comparison
          if (fotoAktual.isNotEmpty || fotoAwal.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (fotoAktual.isNotEmpty)
                  Expanded(child: _buildPhotoThumbnail(url: fotoAktual, title: 'Foto Bukti Aktual', label: 'AKTUAL', isAktual: true)),
                if (fotoAktual.isNotEmpty && fotoAwal.isNotEmpty) const SizedBox(width: 8),
                if (fotoAwal.isNotEmpty)
                  Expanded(child: _buildPhotoThumbnail(url: fotoAwal, title: 'Foto Master Barang', label: 'MASTER', isAktual: false)),
              ],
            ),
          ],

          if (keterangan.isNotEmpty && keterangan != '-') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Catatan: $keterangan',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569), fontStyle: FontStyle.italic),
              ),
            ),
          ],          if (!isSelesai) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (item['id'] != null)
                  IconButton(
                    onPressed: () => _hapusDetail(item['id'], 'Yakin ingin menghapus item $namaAlat dari checklist opname ini?'),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                    tooltip: 'Hapus dari Checklist',
                    visualDensity: VisualDensity.compact,
                  ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _openInputModal(detailItem: item),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF0284C7)),
                        const SizedBox(width: 4),
                        Text(
                          'Edit Opname',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0284C7)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- BHP CARD (100% Web Parity) ---
  Widget _buildBhpCard(dynamic bhp, bool isSelesai) {
    final detail = _getBhpDetail(bhp);
    final String kodeBhp = bhp['kode_pembelian'] ?? '-';
    final String namaBarang = bhp['nama_barang'] ?? 'BHP Item';
    final String merkBarang = bhp['merk_barang'] ?? '';
    final String toko = bhp['toko_pembelian'] ?? '-';
    final String tglBeli = bhp['tanggal_pembelian'] != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.tryParse(bhp['tanggal_pembelian'].toString()) ?? DateTime.now())
        : '-';
    final String satuan = bhp['satuan'] ?? 'pcs';
    final dynamic qtyBeli = bhp['qty'] ?? 0;

    final bool sudahDiopname = detail != null;
    final dynamic sisaAkhir = detail != null
        ? (detail['sisa_akhir'] ?? detail['jumlah_fisik'] ?? detail['jumlah'] ?? 0)
        : null;

    final String fotoAktual = detail != null
        ? _getImageUrl(detail['foto_path'] ?? detail['foto_item'] ?? detail['foto'])
        : '';
    final String catatan = detail?['keterangan'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sudahDiopname ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
          width: sudahDiopname ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1E293B).withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Kode & Qty Beli Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  kodeBhp,
                  style: GoogleFonts.firaCode(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'Qty Beli: $qtyBeli $satuan',
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Name & Merk
          Text(
            '$namaBarang ${merkBarang.isNotEmpty ? '($merkBarang)' : ''}',
            style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 3),

          // Store & Purchase Date
          Row(
            children: [
              const Icon(Icons.storefront_rounded, size: 12, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text('Toko: $toko', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
              const SizedBox(width: 8),
              const Icon(Icons.calendar_today_rounded, size: 10, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(tglBeli, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
            ],
          ),

          const SizedBox(height: 10),

          // Sisa Akhir Highlight Card Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: sudahDiopname ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sudahDiopname ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SISA FISIK DIOPNAME',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: sudahDiopname ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sudahDiopname ? '$sisaAkhir $satuan' : 'Belum diinput',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: sudahDiopname ? const Color(0xFF0369A1) : const Color(0xFF94A3B8),
                        fontStyle: sudahDiopname ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                if (fotoAktual.isNotEmpty) ...[
                  _buildSmallThumbnail(fotoAktual),
                ],
              ],
            ),
          ),

          if (catatan.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Catatan: $catatan', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontStyle: FontStyle.italic)),
          ],

          if (!isSelesai) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (sudahDiopname && detail['id'] != null) ...[
                  IconButton(
                    onPressed: () => _hapusDetail(detail['id'], 'Yakin ingin mereset/menghapus input sisa opname untuk $namaBarang?'),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                    tooltip: 'Reset / Hapus Sisa',
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _openInputModal(detailItem: detail, bhpItem: bhp),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF0284C7)),
                          const SizedBox(width: 4),
                          Text('Edit Sisa', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0284C7))),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: () => _openInputModal(bhpItem: bhp),
                    icon: const Icon(Icons.add_rounded, size: 15),
                    label: const Text('Input Sisa Sekarang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail({
    required String url,
    required String title,
    required String label,
    required bool isAktual,
  }) {
    return InkWell(
      onTap: () => _showPhotoDialog(url),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isAktual ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                headers: _authToken != null ? {'Authorization': 'Bearer $_authToken'} : null,
                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 20)),
              ),
              Positioned(
                bottom: 3,
                left: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isAktual ? const Color(0xFF0284C7) : Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(label, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallThumbnail(String url) {
    return InkWell(
      onTap: () => _showPhotoDialog(url),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 18, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  void _showPhotoDialog(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(url, fit: BoxFit.contain),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}

// Scanner Helper Widget
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Scan QR Code Barang', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on_rounded),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_isScanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                  _isScanned = true;
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
          ),
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 2.5),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ],
      ),
    );
  }
}

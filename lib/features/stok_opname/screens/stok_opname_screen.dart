import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
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
  String _filterBulan = DateFormat('MM').format(DateTime.now());
  String _filterTahun = DateFormat('yyyy').format(DateTime.now());

  String _activePeriode = 'tengah_bulan'; // 'tengah_bulan', 'akhir_bulan', 'inventaris'
  String _activeKategori = 'MSN'; // MSN, CLA, BHP, INV

  Map<String, dynamic>? _activeSession;
  bool _isLoading = false;
  List<dynamic> _details = [];
  List<dynamic> _pembelianBhps = [];
  String? _authToken;

  final Map<String, String> _bulanNames = {
    '01': 'Januari',
    '02': 'Februari',
    '03': 'Maret',
    '04': 'April',
    '05': 'Mei',
    '06': 'Juni',
    '07': 'Juli',
    '08': 'Agustus',
    '09': 'September',
    '10': 'Oktober',
    '11': 'November',
    '12': 'Desember'
  };

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
    } catch (_) {}
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

      // Fetch BHP purchases for this period & branch
      final bhps = await StokOpnameService.getBhps(
        bulan: int.tryParse(_filterBulan),
        tahun: int.tryParse(_filterTahun),
        cabangId: cabangId,
      );

      final sessions = await StokOpnameService.getSessions(cabangId: cabangId);

      final targetPeriode = '$_filterTahun-$_filterBulan';
      var session = sessions.firstWhere(
        (s) => s['periode_bulan'] == targetPeriode && s['tipe_sesi'] == _activePeriode,
        orElse: () => null,
      );

      if (session == null) {
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

      if (session != null) {
        final sessionDetails = await StokOpnameService.getSessionDetails(session['id']);
        if (mounted) {
          setState(() {
            _activeSession = session;
            _details = sessionDetails?['details'] ?? [];
            _pembelianBhps = bhps;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _pembelianBhps = bhps;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('Error fetching session: $e');
    }
  }

  void _setPeriode(String periode) {
    setState(() {
      _activePeriode = periode;
    });
    _fetchSession();
  }

  void _setKategori(String kategori) {
    setState(() {
      _activeKategori = kategori;
    });
  }

  String _formatDateTime(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().trim().isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr.toString());
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }

  String _getFileUrl(dynamic rawPath) {
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

  void _showImageZoom(String path, String title) {
    final fullUrl = _getFileUrl(path);
    if (fullUrl.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(14),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SmartNetworkImage(
                  url: fullUrl,
                  token: _authToken,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.white,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 48),
                        const SizedBox(height: 12),
                        Text('Gagal memuat foto', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openInputModal({
    String? initialQr,
    String? initialKondisi,
    String? initialCatatan,
    String? initialFotoUrl,
    String? initialSisa,
    dynamic detailItem,
    dynamic bhpItem,
  }) {
    final qrController = TextEditingController(text: initialQr ?? '');
    final catatanController = TextEditingController(text: initialCatatan ?? '');
    final sisaBhpController = TextEditingController(text: initialSisa ?? (detailItem?['sisa_akhir']?.toString() ?? ''));
    final picker = ImagePicker();

    String selectedKondisi = initialKondisi ?? 'Baik';
    final List<String> kondisiOptions = [
      'Baik',
      'Rusak',
      'Hilang',
      'Lagi di service',
      'Baik (Pernah diservice)',
    ];

    File? selectedFoto;
    String? currentFotoUrl = initialFotoUrl ?? detailItem?['foto_path'];
    Map<String, dynamic>? detectedItem = detailItem?['item_fisik'] ?? detailItem?['itemFisik'];
    Map<String, dynamic>? activeBhp = bhpItem ?? detailItem?['pembelian_bhp'] ?? detailItem?['pembelianBhp'];
    
    // Auto-match activeBhp if initialQr is given and activeBhp is null
    if (activeBhp == null && initialQr != null && initialQr.isNotEmpty) {
      final qUpper = initialQr.trim().toUpperCase();
      final match = _pembelianBhps.firstWhere(
        (b) => b['kode_pembelian']?.toString().toUpperCase() == qUpper || b['nama_barang']?.toString().toUpperCase() == qUpper,
        orElse: () => null,
      );
      if (match != null) {
        activeBhp = match;
      }
    }

    final bool isBhpMode = _activeKategori == 'BHP' || activeBhp != null;
    bool isSearchingQr = false;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            Future<void> lookupQr(String kode) async {
              final k = kode.trim();
              if (k.isEmpty) return;

              setStateModal(() {
                isSearchingQr = true;
                detectedItem = null;
              });

              try {
                // Check if it matches a BHP item first
                final qUpper = k.toUpperCase();
                final matchBhp = _pembelianBhps.firstWhere(
                  (b) => b['kode_pembelian']?.toString().toUpperCase() == qUpper || b['nama_barang']?.toString().toUpperCase() == qUpper,
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
                setStateModal(() {
                  isSearchingQr = false;
                });
              }
            }

            // Auto lookup initialQr on first load if detectedItem is still null
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

            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
                                isBhpMode ? Icons.sanitizer_rounded : (detailItem != null ? Icons.edit_note_rounded : Icons.qr_code_scanner_rounded),
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isBhpMode
                                  ? (detailItem != null ? 'Edit Opname BHP' : 'Input Opname Stok BHP')
                                  : (detailItem != null ? 'Edit Checklist Opname' : 'Scan & Input Item Opname'),
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. BHP ITEM INFO / SELECTOR (IF BHP MODE)
                          if (isBhpMode) ...[
                            if (activeBhp != null) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFDCFCE7)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.sanitizer_rounded, color: Color(0xFF16A34A), size: 18),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Item Habis Pakai (BHP)',
                                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF15803D)),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            activeBhp?['kode_pembelian'] ?? '-',
                                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF15803D)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      activeBhp?['nama_barang'] ?? 'BHP Item',
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                                    ),
                                    if (activeBhp?['merk'] != null && activeBhp?['merk'].toString().isNotEmpty == true) ...[
                                      const SizedBox(height: 2),
                                      Text('Merk: ${activeBhp?['merk']}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                    ],
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.storefront_rounded, size: 13, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text('Toko: ${activeBhp?['toko_pembelian'] ?? '-'}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                        const Spacer(),
                                        Text(
                                          'Qty Beli: ${activeBhp?['qty_dibeli'] ?? activeBhp?['qty'] ?? 1} ${activeBhp?['satuan'] ?? 'pcs'}',
                                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ] else ...[
                              // Dropdown to pick from _pembelianBhps or scan QR
                              Text('Pilih Item BHP / Scan QR *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<dynamic>(
                                          value: activeBhp,
                                          hint: Text('Pilih barang BHP...', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
                                          isExpanded: true,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                                          items: _pembelianBhps.map((b) {
                                            return DropdownMenuItem<dynamic>(
                                              value: b,
                                              child: Text('${b['nama_barang']} (${b['kode_pembelian'] ?? '-'})', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            setStateModal(() => activeBhp = val);
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () async {
                                      final String? scanned = await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const QrScannerScreen()),
                                      );
                                      if (scanned != null && scanned.isNotEmpty) {
                                        lookupQr(scanned);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Sisa Stok Akhir BHP
                            Text('Sisa Stok Akhir Bulan (BHP) *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: sisaBhpController,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                hintText: 'Masukkan jumlah sisa barang (mis. 1)',
                                hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.pie_chart_outline_rounded, color: AppColors.primary, size: 20),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ] else ...[
                            // 1. KODE QR / CARI ITEM FISIK (MSN / CLA / INV)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Kode QR / Aset *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                                if (isSearchingQr)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: qrController,
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                                    onChanged: (val) {
                                      if (val.length >= 4) {
                                        lookupQr(val);
                                      }
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'mis. MSN/SBY/0826/A/001',
                                      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                                      prefixIcon: const Icon(Icons.qr_code_rounded, color: AppColors.primary, size: 20),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () async {
                                    final String? scanned = await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
                                    );
                                    if (scanned != null && scanned.isNotEmpty) {
                                      qrController.text = scanned;
                                      lookupQr(scanned);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18),
                                        const SizedBox(width: 6),
                                        Text('Scan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Info Deteksi Barang
                            if (detectedItem != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFDCFCE7)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            detectedItem!['barang']?['nama_barang'] ?? 'Barang Terdaftar',
                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF15803D)),
                                          ),
                                          Text(
                                            'Kategori: ${detectedItem!['barang']?['kategori']?['nama_kategori'] ?? '-'}',
                                            style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF16A34A)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),

                            // 2. KONDISI ITEM FISIK
                            Text('Kondisi Item Fisik *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedKondisi,
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                                  items: kondisiOptions.map((k) {
                                    return DropdownMenuItem(value: k, child: Text(k));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setStateModal(() => selectedKondisi = val);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // 3. UPLOAD / AMBIL FOTO AKTUAL
                          Text('Foto Aktual Barang *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                          const SizedBox(height: 6),
                          if (selectedFoto == null && (currentFotoUrl == null || currentFotoUrl!.isEmpty)) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => pickImage(ImageSource.camera),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: Column(
                                        children: [
                                          const Icon(Icons.camera_alt_rounded, color: Color(0xFF1D4ED8), size: 26),
                                          const SizedBox(height: 6),
                                          Text('Buka Kamera', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF1D4ED8))),
                                          Text('Ambil foto langsung', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF3B82F6))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => pickImage(ImageSource.gallery),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Column(
                                        children: [
                                          const Icon(Icons.photo_library_rounded, color: Color(0xFF64748B), size: 26),
                                          const SizedBox(height: 6),
                                          Text('Pilih Galeri', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                                          Text('Upload foto HP', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (selectedFoto != null) ...[
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                children: [
                                  Image.file(
                                    selectedFoto!,
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Row(
                                      children: [
                                        InkWell(
                                          onTap: () => pickImage(ImageSource.camera),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () => setStateModal(() => selectedFoto = null),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.8), shape: BoxShape.circle),
                                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (currentFotoUrl != null && currentFotoUrl!.isNotEmpty) ...[
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                children: [
                                  SizedBox(
                                    height: 160,
                                    width: double.infinity,
                                    child: SmartNetworkImage(
                                      url: _getFileUrl(currentFotoUrl),
                                      token: _authToken,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Row(
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () => pickImage(ImageSource.camera),
                                          icon: const Icon(Icons.camera_alt_rounded, size: 14),
                                          label: const Text('Ganti Foto'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // 4. CATATAN TAMBAHAN
                          Text('Catatan Tambahan (Opsional)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: catatanController,
                            maxLines: 3,
                            style: GoogleFonts.inter(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Tuliskan catatan kondisi atau posisi item...',
                              hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -3))],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (_activeSession == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesi opname belum aktif')));
                                  return;
                                }

                                if (!isBhpMode) {
                                  if (qrController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kode QR wajib diisi / discan')));
                                    return;
                                  }
                                } else {
                                  if (activeBhp == null && detailItem == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih item BHP yang diopname')));
                                    return;
                                  }
                                  if (sisaBhpController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sisa stok BHP wajib diisi')));
                                    return;
                                  }
                                }

                                if (selectedFoto == null && (currentFotoUrl == null || currentFotoUrl!.isEmpty)) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto aktual barang wajib diambil/diupload')));
                                  return;
                                }

                                setStateModal(() => isSubmitting = true);

                                try {
                                  dio.MultipartFile? fotoMultipart;
                                  if (selectedFoto != null) {
                                    fotoMultipart = await dio.MultipartFile.fromFile(
                                      selectedFoto!.path,
                                      filename: 'opname_${DateTime.now().millisecondsSinceEpoch}.jpg',
                                    );
                                  }

                                  if (!isBhpMode) {
                                    final itemFisikId = detectedItem?['id'] ?? detailItem?['item_fisik_id'] ?? detailItem?['itemFisik']?['id'];
                                    final formData = dio.FormData.fromMap({
                                      'stok_opname_id': _activeSession!['id'],
                                      'item_fisik_id': itemFisikId ?? 1,
                                      'kondisi': selectedKondisi.split(' - ')[0],
                                      if (fotoMultipart != null) 'foto': fotoMultipart,
                                      'keterangan': catatanController.text.trim(),
                                    });

                                    final res = await StokOpnameService.submitItem(formData);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res['message'] ?? 'Berhasil merekam item'),
                                          backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : Colors.red,
                                        ),
                                      );
                                      _fetchSession();
                                    }
                                  } else {
                                    final pembelianBhpId = activeBhp?['id'] ?? detailItem?['pembelian_bhp_id'] ?? detailItem?['pembelian_bhp']?['id'] ?? detailItem?['pembelianBhp']?['id'];
                                    final formData = dio.FormData.fromMap({
                                      'stok_opname_id': _activeSession!['id'],
                                      'pembelian_bhp_id': pembelianBhpId,
                                      'barang_id': activeBhp?['barang_id'] ?? detailItem?['barang_id'],
                                      'sisa_akhir': double.tryParse(sisaBhpController.text.trim()) ?? 0,
                                      if (fotoMultipart != null) 'foto': fotoMultipart,
                                      'keterangan': catatanController.text.trim(),
                                    });

                                    final res = await StokOpnameService.submitBhpOpname(formData);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res['message'] ?? 'Berhasil merekam BHP'),
                                          backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : Colors.red,
                                        ),
                                      );
                                      _fetchSession();
                                    }
                                  }
                                } catch (e) {
                                  setStateModal(() => isSubmitting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                detailItem != null ? 'Perbarui Checklist' : 'Simpan Checklist',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                              ),
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

  void _confirmSelesaikanSesi() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Selesaikan Sesi Opname?', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(
          'Apakah Anda yakin ingin menyelesaikan sesi opname ini? Setelah diselesaikan, data checklist akan terkunci.',
          style: GoogleFonts.inter(color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                if (_activeSession != null) {
                  _activeSession!['status'] = 'Selesai';
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sesi opname berhasil diselesaikan'),
                  backgroundColor: Color(0xFF16A34A),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Selesaikan', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // --- STATS CALCULATIONS ---
  int get _countBaik {
    int count = 0;
    for (final d in _details) {
      final kondisi = d['kondisi']?.toString().toLowerCase() ?? '';
      if (kondisi.contains('baik')) count++;
    }
    return count;
  }

  int get _countRusak {
    int count = 0;
    for (final d in _details) {
      final kondisi = d['kondisi']?.toString().toLowerCase() ?? '';
      if (kondisi.contains('rusak') || kondisi.contains('hilang') || kondisi.contains('service')) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(currentYear - 2024 + 1, (index) => (2024 + index).toString()).reversed.toList();
    final bool isSelesai = _activeSession != null && _activeSession!['status'] == 'Selesai';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Enhanced Gradient Header
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 18),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stok Opname Cabang',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pengecekan fisik aset & stok cabang',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchSession,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filter Bulan & Tahun
                    _buildMonthYearSelector(years),
                    const SizedBox(height: 14),

                    // Periode Tabs (Awal Bulan, Akhir Bulan, Bebas)
                    _buildPeriodeSelector(),
                    const SizedBox(height: 14),

                    // Active Session Summary & Stats Banner
                    if (_activeSession != null) ...[
                      _buildSessionSummaryCard(isSelesai),
                      const SizedBox(height: 14),
                    ],

                    // Level 2 Category Tabs (Mesin, Cleaning, BHP, Inventaris)
                    _buildCategoryPills(),
                    const SizedBox(height: 12),

                    // Items List Section
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    else
                      _buildItemsList(isSelesai),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: (!isSelesai && _activeSession != null)
          ? FloatingActionButton.extended(
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
              backgroundColor: AppColors.primary,
              elevation: 4,
              icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
              label: Text(
                'Scan QR Item',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            )
          : null,
    );
  }

  // --- MONTH & YEAR SELECTOR ---
  Widget _buildMonthYearSelector(List<String> years) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          // Bulan
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BULAN OPNAME', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
                const SizedBox(height: 2),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterBulan,
                    isDense: true,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 18),
                    items: _bulanNames.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _filterBulan = val);
                        _fetchSession();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Container(height: 32, width: 1, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 12)),
          // Tahun
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TAHUN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
                const SizedBox(height: 2),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterTahun,
                    isDense: true,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 18),
                    items: years.map((y) => DropdownMenuItem(value: y, child: Text(y, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _filterTahun = val);
                        _fetchSession();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- PERIODE SELECTOR CARDS (AWAL BULAN & AKHIR BULAN) ---
  Widget _buildPeriodeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildPeriodeCard(
            value: 'tengah_bulan',
            title: 'Opname Awal Bulan',
            subtitle: 'Tgl 15',
            icon: Icons.event_available_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildPeriodeCard(
            value: 'akhir_bulan',
            title: 'Opname Akhir Bulan',
            subtitle: 'Tgl 30',
            icon: Icons.event_busy_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodeCard({required String value, required String title, required String subtitle, required IconData icon}) {
    final bool isActive = _activePeriode == value;

    return InkWell(
      onTap: () => _setPeriode(value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 4)),
                ]
              : [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? Colors.white : const Color(0xFF64748B), size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isActive ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isActive ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- SESSION SUMMARY & STATS CARD ---
  Widget _buildSessionSummaryCard(bool isSelesai) {
    final statusText = _activeSession?['status'] ?? 'Draft';
    final periodeName = _activePeriode == 'tengah_bulan' ? 'Awal Bulan' : 'Akhir Bulan';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sesi: $periodeName',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Checklist ${_bulanNames[_filterBulan]} $_filterTahun',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelesai ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isSelesai ? const Color(0xFF15803D) : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                  if (!isSelesai) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _confirmSelesaikanSesi,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Selesaikan',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Mini Stats (Total Item, Baik, Rusak/Hilang)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Total: ${_details.length}',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDCFCE7)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      Text(
                        'Baik: $_countBaik',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFEE2E2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                      const SizedBox(width: 6),
                      Text(
                        'Rusak: $_countRusak',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFB91C1C)),
                      ),
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

  // --- CATEGORY PILLS (2x2 GRID - NO HORIZONTAL SCROLL) ---
  Widget _buildCategoryPills() {
    final categories = [
      {'code': 'MSN', 'label': 'Mesin Alat', 'sub': 'MSN', 'icon': Icons.precision_manufacturing_rounded},
      {'code': 'CLA', 'label': 'Cleaning Alat', 'sub': 'CLA', 'icon': Icons.cleaning_services_rounded},
      {'code': 'BHP', 'label': 'Habis Pakai', 'sub': 'BHP', 'icon': Icons.sanitizer_rounded},
      {'code': 'INV', 'label': 'Inventaris', 'sub': 'INV', 'icon': Icons.chair_rounded},
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildCategoryItem(categories[0])),
            const SizedBox(width: 8),
            Expanded(child: _buildCategoryItem(categories[1])),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildCategoryItem(categories[2])),
            const SizedBox(width: 8),
            Expanded(child: _buildCategoryItem(categories[3])),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> cat) {
    final isSelected = _activeKategori == cat['code'];
    final IconData icon = cat['icon'] as IconData;

    return InkWell(
      onTap: () => _setKategori(cat['code'] as String),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cat['label'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                      color: isSelected ? Colors.white : const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    cat['sub'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ITEMS LIST ---
  Widget _buildItemsList(bool isSelesai) {
    if (_activeKategori == 'BHP') {
      if (_pembelianBhps.isEmpty && _details.where((d) => d['pembelian_bhp_id'] != null || d['pembelian_bhp'] != null || d['pembelianBhp'] != null).isEmpty) {
        return _buildEmptyState(
          title: 'Belum Ada Item BHP',
          subtitle: 'Belum ada data pembelian barang habis pakai pada periode ${_bulanNames[_filterBulan]} $_filterTahun.',
        );
      }

      if (_pembelianBhps.isNotEmpty) {
        return Column(
          children: _pembelianBhps.map((bhp) {
            final matchingDetail = _details.firstWhere(
              (d) => d['pembelian_bhp_id'] == bhp['id'] || d['pembelian_bhp']?['id'] == bhp['id'] || d['pembelianBhp']?['id'] == bhp['id'],
              orElse: () => null,
            );
            return _buildBhpPurchaseCard(bhp, matchingDetail, isSelesai);
          }).toList(),
        );
      }

      // Fallback to details if _pembelianBhps is somehow empty but details exist
      final bhpDetails = _details.where((d) => d['pembelian_bhp_id'] != null || d['pembelian_bhp'] != null || d['pembelianBhp'] != null).toList();
      return Column(
        children: bhpDetails.map((detail) => _buildBhpCard(detail, isSelesai)).toList(),
      );
    }

    List<dynamic> filtered = _details.where((d) {
      final itemFisik = d['item_fisik'] ?? d['itemFisik'];
      final barang = d['barang'] ?? itemFisik?['barang'];
      final kategori = barang?['kategori']?['nama_kategori']?.toString().toUpperCase() ?? '';
      final kode = itemFisik?['kode_qr']?.toString().toUpperCase() ?? '';

      if (_activeKategori == 'MSN') {
        return kode.contains('MSN') || kategori.contains('MESIN');
      } else if (_activeKategori == 'CLA') {
        return kode.contains('CLA') || kategori.contains('CLEANING');
      } else if (_activeKategori == 'INV') {
        return kode.contains('INV') || kategori.contains('INVENTARIS');
      }
      return false;
    }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(
        title: 'Belum Ada Item Checklist',
        subtitle: 'Belum ada data checklist untuk kategori ini pada periode terpilih.',
      );
    }

    return Column(
      children: filtered.map((detail) {
        return _buildNormalItemCard(detail, isSelesai);
      }).toList(),
    );
  }

  Widget _buildEmptyState({required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  // --- DETAIL MODAL SHEET ---
  void _showDetailModal(dynamic detail, bool isSelesai, {bool isBhp = false}) {
    final itemFisik = detail['item_fisik'] ?? detail['itemFisik'] ?? {};
    final barang = itemFisik['barang'] ?? detail['barang'] ?? {};
    final pembelianBhp = detail['pembelian_bhp'] ?? detail['pembelianBhp'];

    final String namaBarang = isBhp
        ? (pembelianBhp != null ? (pembelianBhp['nama_barang'] ?? 'BHP Item') : 'Barang BHP')
        : (barang['nama_barang'] ?? 'Alat / Item');

    final String kodeQr = isBhp ? (pembelianBhp?['kode_pembelian'] ?? '-') : (itemFisik['kode_qr'] ?? '-');
    final String kondisi = detail['kondisi']?.toString() ?? (isBhp ? 'BHP' : 'Baik');
    final String sisaAkhir = detail['sisa_akhir']?.toString() ?? '-';
    final String? fotoPath = detail['foto_path'];
    final String? fotoAwal = isBhp ? null : (itemFisik['foto_path'] ?? itemFisik['foto_awal'] ?? itemFisik['foto'] ?? barang['foto'] ?? barang['foto_path']);
    final String? keterangan = detail['keterangan'];
    final String waktu = _formatDateTime(detail['created_at'] ?? detail['updated_at']);

    Color kondisiColor = const Color(0xFF16A34A);
    Color kondisiBg = const Color(0xFFDCFCE7);

    if (kondisi.toLowerCase().contains('rusak') || kondisi.toLowerCase().contains('hilang')) {
      kondisiColor = const Color(0xFFDC2626);
      kondisiBg = const Color(0xFFFEE2E2);
    } else if (kondisi.toLowerCase().contains('service')) {
      kondisiColor = const Color(0xFFD97706);
      kondisiBg = const Color(0xFFFEF3C7);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(3)),
                  ),
                ),

                // Modal Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isBhp ? Icons.sanitizer_rounded : Icons.inventory_2_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              namaBarang,
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isBhp ? 'Barang Habis Pakai' : 'Pengecekan Fisik Alat & Aset',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),

                // Modal Body Information Grid
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Grid 2 Columns
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildDetailTile(
                              label: isBhp ? 'KODE PEMBELIAN' : 'KODE QR / ASET',
                              value: kodeQr,
                              icon: Icons.qr_code_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: isBhp
                                ? _buildDetailTile(
                                    label: 'SISA STOK AKHIR',
                                    value: sisaAkhir,
                                    icon: Icons.pie_chart_outline_rounded,
                                    valueColor: const Color(0xFF1D4ED8),
                                  )
                                : Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('KONDISI ITEM', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: kondisiBg,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            kondisi,
                                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: kondisiColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Waktu Checklist & Status Sesi
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailTile(
                              label: 'WAKTU CHECKLIST',
                              value: waktu,
                              icon: Icons.access_time_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailTile(
                              label: 'STATUS SESI',
                              value: isSelesai ? 'Terkunci (Selesai)' : 'Draft (Bisa diedit)',
                              icon: isSelesai ? Icons.lock_rounded : Icons.edit_note_rounded,
                              valueColor: isSelesai ? const Color(0xFF15803D) : const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),

                      // Catatan
                      if (keterangan != null && keterangan.toString().trim().isNotEmpty && keterangan != '-') ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CATATAN KETERANGAN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
                              const SizedBox(height: 4),
                              Text(
                                keterangan.toString(),
                                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Foto Previews Section with ACTUAL SmartNetworkImage
                      if ((fotoAwal != null && fotoAwal.isNotEmpty) || (fotoPath != null && fotoPath.isNotEmpty)) ...[
                        const SizedBox(height: 18),
                        Text('FOTO BUKTI / AKTUAL', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B), letterSpacing: 0.5)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (fotoAwal != null && fotoAwal.isNotEmpty)
                              Expanded(
                                child: InkWell(
                                  onTap: () => _showImageZoom(fotoAwal, 'Foto Awal $namaBarang'),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        SizedBox(
                                          height: 130,
                                          child: SmartNetworkImage(
                                            url: _getFileUrl(fotoAwal),
                                            token: _authToken,
                                            fit: BoxFit.cover,
                                            placeholder: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                                            errorBuilder: (_, __, ___) => Container(
                                              color: const Color(0xFFF1F5F9),
                                              child: const Center(child: Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 32)),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Foto Master Awal', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                                              const Icon(Icons.fullscreen_rounded, size: 16, color: Color(0xFF64748B)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (fotoAwal != null && fotoAwal.isNotEmpty && fotoPath != null && fotoPath.isNotEmpty)
                              const SizedBox(width: 10),
                            if (fotoPath != null && fotoPath.isNotEmpty)
                              Expanded(
                                child: InkWell(
                                  onTap: () => _showImageZoom(fotoPath, 'Foto Aktual $namaBarang'),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        SizedBox(
                                          height: 130,
                                          child: SmartNetworkImage(
                                            url: _getFileUrl(fotoPath),
                                            token: _authToken,
                                            fit: BoxFit.cover,
                                            placeholder: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                                            errorBuilder: (_, __, ___) => Container(
                                              color: const Color(0xFFEFF6FF),
                                              child: const Center(child: Icon(Icons.broken_image_rounded, color: Color(0xFF93C5FD), size: 32)),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Foto Aktual Opname', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF1D4ED8))),
                                              const Icon(Icons.fullscreen_rounded, size: 16, color: Color(0xFF1D4ED8)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),
                      if (!isSelesai) ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                ),
                                child: Text('Tutup', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _openInputModal(
                                    initialQr: kodeQr != '-' ? kodeQr : null,
                                    initialKondisi: kondisi,
                                    initialCatatan: (keterangan != null && keterangan != '-') ? keterangan : '',
                                    initialFotoUrl: fotoPath,
                                    initialSisa: isBhp ? sisaAkhir : null,
                                    detailItem: detail,
                                  );
                                },
                                icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
                                label: Text('Edit Checklist', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text('Tutup', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailTile({required String label, required String value, required IconData icon, Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: valueColor ?? const Color(0xFF1E293B)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- ITEM CARD (MESIN / CLA / INV) - COMPACT & USER FRIENDLY ---
  Widget _buildNormalItemCard(dynamic detail, bool isSelesai) {
    final itemFisik = detail['item_fisik'] ?? detail['itemFisik'] ?? {};
    final barang = itemFisik['barang'] ?? detail['barang'] ?? {};
    final kodeQr = itemFisik['kode_qr'] ?? '-';
    final namaBarang = barang['nama_barang'] ?? 'Alat / Item';
    final kondisi = detail['kondisi']?.toString() ?? 'Baik';
    final fotoPath = detail['foto_path'];

    Color kondisiColor = const Color(0xFF16A34A);
    Color kondisiBg = const Color(0xFFDCFCE7);

    if (kondisi.toLowerCase().contains('rusak') || kondisi.toLowerCase().contains('hilang')) {
      kondisiColor = const Color(0xFFDC2626);
      kondisiBg = const Color(0xFFFEE2E2);
    } else if (kondisi.toLowerCase().contains('service')) {
      kondisiColor = const Color(0xFFD97706);
      kondisiBg = const Color(0xFFFEF3C7);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: () => _showDetailModal(detail, isSelesai),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Icon Box or Photo Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: fotoPath != null && fotoPath.toString().isNotEmpty
                    ? SizedBox(
                        width: 42,
                        height: 42,
                        child: SmartNetworkImage(
                          url: _getFileUrl(fotoPath),
                          token: _authToken,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            child: const Icon(Icons.precision_manufacturing_rounded, color: AppColors.primary, size: 20),
                          ),
                        ),
                      )
                    : Container(
                        width: 42,
                        height: 42,
                        color: AppColors.primary.withValues(alpha: 0.08),
                        child: const Icon(Icons.precision_manufacturing_rounded, color: AppColors.primary, size: 20),
                      ),
              ),
              const SizedBox(width: 12),

              // Main Info (Nama Barang + QR Code)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      namaBarang,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            kodeQr,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (fotoPath != null && fotoPath.toString().isNotEmpty) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.camera_alt_rounded, size: 12, color: Color(0xFF3B82F6)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Kondisi Badge & Arrow
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kondisiBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      kondisi,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: kondisiColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Detail', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF64748B)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateOnly(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().trim().isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr.toString());
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }

  // --- ITEM CARD (BHP FROM PURCHASES) - RICH, MODERN & ACTIONABLE ---
  Widget _buildBhpPurchaseCard(Map<String, dynamic> bhp, dynamic detail, bool isSelesai) {
    final String namaBhp = bhp['nama_barang'] ?? 'BHP Item';
    final String? merk = bhp['merk'];
    final String kodePembelian = bhp['kode_pembelian'] ?? '-';
    final String tglPembelian = _formatDateOnly(bhp['tanggal_pembelian']);
    final String toko = bhp['toko_pembelian'] ?? '-';
    final dynamic qtyBeli = bhp['qty_dibeli'] ?? bhp['qty'] ?? 1;
    final String satuan = bhp['satuan'] ?? 'pcs';
    final bool sudahDiopname = detail != null;
    final dynamic sisaAkhir = detail?['sisa_akhir'];
    final String? fotoAktual = detail?['foto_path'];
    final String? fotoBarang = bhp['foto_barang'] ?? bhp['foto'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sudahDiopname ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0),
          width: sudahDiopname ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: sudahDiopname ? const Color(0xFF16A34A).withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (sudahDiopname) {
            _showDetailModal(detail, isSelesai, isBhp: true);
          } else if (!isSelesai) {
            _openInputModal(bhpItem: bhp);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Tgl Pembelian + Badge Kode QR Pembelian
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        'Beli: $tglPembelian',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code_rounded, size: 11, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 4),
                        Text(
                          kodePembelian,
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF1D4ED8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Center Row: Photo Thumbnail + Nama & Toko + Qty
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: (fotoAktual != null && fotoAktual.isNotEmpty) || (fotoBarang != null && fotoBarang.isNotEmpty)
                        ? SizedBox(
                            width: 50,
                            height: 50,
                            child: SmartNetworkImage(
                              url: _getFileUrl(fotoAktual ?? fotoBarang),
                              token: _authToken,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                child: const Icon(Icons.sanitizer_rounded, color: Color(0xFF10B981), size: 24),
                              ),
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.sanitizer_rounded, color: Color(0xFF10B981), size: 24),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          namaBhp,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (merk != null && merk.toString().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Merk: $merk',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.storefront_rounded, size: 12, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                toko,
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              'Beli: $qtyBeli $satuan',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),

              // Bottom Row: Opname Status & Action Button
              if (sudahDiopname) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
                          const SizedBox(width: 4),
                          Text(
                            'Sudah Diopname',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF15803D)),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Sisa: $sisaAkhir $satuan',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF1D4ED8)),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF64748B)),
                      ],
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFFD97706)),
                          const SizedBox(width: 4),
                          Text(
                            'Belum Diinput',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ),
                    if (!isSelesai)
                      InkWell(
                        onTap: () => _openInputModal(bhpItem: bhp),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'Input Opname',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
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
        ),
      ),
    );
  }

  // --- ITEM CARD (BHP FALLBACK FROM DETAIL) ---
  Widget _buildBhpCard(dynamic detail, bool isSelesai) {
    final pembelianBhp = detail['pembelian_bhp'] ?? detail['pembelianBhp'];
    final namaBhp = pembelianBhp != null ? (pembelianBhp['nama_barang'] ?? 'BHP Item') : 'Barang BHP';
    final sisa = detail['sisa_akhir'] ?? '-';
    final fotoPath = detail['foto_path'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: () => _showDetailModal(detail, isSelesai, isBhp: true),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: fotoPath != null && fotoPath.toString().isNotEmpty
                    ? SizedBox(
                        width: 42,
                        height: 42,
                        child: SmartNetworkImage(
                          url: _getFileUrl(fotoPath),
                          token: _authToken,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            child: const Icon(Icons.sanitizer_rounded, color: Color(0xFF10B981), size: 20),
                          ),
                        ),
                      )
                    : Container(
                        width: 42,
                        height: 42,
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        child: const Icon(Icons.sanitizer_rounded, color: Color(0xFF10B981), size: 20),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      namaBhp,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Sisa: $sisa',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                        ),
                        if (fotoPath != null && fotoPath.toString().isNotEmpty) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.camera_alt_rounded, size: 12, color: Color(0xFF3B82F6)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Detail', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF64748B)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// SMART NETWORK IMAGE WITH AUTO HTTP/HTTPS FALLBACK
// ---------------------------------------------------------
class SmartNetworkImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final String? token;
  final Widget? placeholder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const SmartNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.token,
    this.placeholder,
    this.errorBuilder,
  });

  @override
  State<SmartNetworkImage> createState() => _SmartNetworkImageState();
}

class _SmartNetworkImageState extends State<SmartNetworkImage> {
  late String _activeUrl;
  bool _triedFallback = false;

  @override
  void initState() {
    super.initState();
    _activeUrl = widget.url;
  }

  @override
  void didUpdateWidget(covariant SmartNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _activeUrl = widget.url;
      _triedFallback = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeUrl.isEmpty) {
      return widget.errorBuilder?.call(context, 'Empty URL', null) ??
          const Center(child: Icon(Icons.image_not_supported_rounded, color: Color(0xFF94A3B8), size: 20));
    }

    final headers = widget.token != null && widget.token!.isNotEmpty
        ? {
            'Authorization': 'Bearer ${widget.token}',
            'Accept': 'image/*,*/*',
          }
        : const {'Accept': 'image/*,*/*'};

    return Image.network(
      _activeUrl,
      fit: widget.fit,
      headers: headers,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return widget.placeholder ??
            Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Image load error on $_activeUrl: $error');
        if (!_triedFallback) {
          _triedFallback = true;
          if (_activeUrl.startsWith('http://')) {
            final fallback = _activeUrl.replaceFirst('http://', 'https://');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _activeUrl = fallback);
            });
            return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
          } else if (_activeUrl.startsWith('https://')) {
            final fallback = _activeUrl.replaceFirst('https://', 'http://');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _activeUrl = fallback);
            });
            return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
          }
        }
        return widget.errorBuilder?.call(context, error, stackTrace) ??
            const Center(child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 20));
      },
    );
  }
}

// --- LIVE CAMERA QR SCANNER SCREEN ---
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _hasScanned = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_outlined, color: Colors.amber, size: 48),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Kamera Perlu Izin / Restart Aplikasi',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Karena paket scanner baru ditambahkan, silakan restart (Re-run) aplikasi Anda agar library native kamera terpasang sempurna.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Kembali & Input Manual'),
                      ),
                    ],
                  ),
                ),
              );
            },
            onDetect: (capture) {
              if (_hasScanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? rawValue = barcode.rawValue;
                if (rawValue != null && rawValue.trim().isNotEmpty) {
                  _hasScanned = true;
                  Navigator.pop(context, rawValue.trim());
                  break;
                }
              }
            },
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      Text(
                        'Pindai QR Code Item',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () => _scannerController.toggleTorch(),
                          icon: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Viewfinder Target Frame
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 3),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(21),
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 230,
                            height: 2,
                            color: AppColors.primary.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Arahkan kamera ke kode QR barang',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.keyboard_rounded, color: Colors.white70),
                    label: Text(
                      'Input Manual Saja',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
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

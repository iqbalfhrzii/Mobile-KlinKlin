import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/weekly_date_picker.dart';
import '../../../core/data/order_model.dart';
import '../../../core/data/hrd_models.dart';
import '../../orders/services/order_service.dart';
import '../../hrd/services/hrd_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/data/customer_model.dart';
class FinanceAuditScreen extends StatefulWidget {
  const FinanceAuditScreen({super.key});

  @override
  State<FinanceAuditScreen> createState() => _FinanceAuditScreenState();
}

class _FinanceAuditScreenState extends State<FinanceAuditScreen> {
  final OrderService _orderService = OrderService();
  final HrdService _hrdService = HrdService();

  List<OrderModel> _orders = [];
  List<CabangModel> _cabangs = [];
  List<KaryawanModel> _karyawans = [];
  List<CustomerModel> _customers = [];
  List<LayananModel> _layanans = [];
  bool _isLoading = true;
  String _error = '';

  // Main Audit Sub-Tab ('audit-order', 'approve-edit', 'edit-order', 'hasil-audit')
  String _auditTab = 'audit-order';

  // Toggle Table in Audit Order ('pending' vs 'done')
  String _approvalTableMode = 'pending';

  // Filter
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  String? _selectedCabangName;
  String? _selectedStatusUtama;
  String _periodFilter = 'semua'; // 'semua', 'hari_ini', 'kemarin', 'besok', 'bulan_ini', 'custom'
  DateTimeRange? _customRange;
  DateTime? _filterStart;
  DateTime? _filterEnd;

  // Pagination limits matching Absensi/Audit design
  int _limitAuditPending = 5;
  int _limitAuditDone = 5;
  int _limitApproveEdit = 5;
  int _limitEditOrderBebas = 5;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final ordersData = await _orderService.fetchOrders();
      List<CabangModel> cabangsData = [];
      List<KaryawanModel> karyawansData = [];
      List<CustomerModel> customersData = [];
      List<LayananModel> layanansData = [];
      try {
        cabangsData = await _hrdService.fetchCabang();
      } catch (e) {
        print("Error fetching cabangs: $e");
      }
      try {
        karyawansData = await _hrdService.fetchKaryawan();
      } catch (e) {
        print("Error fetching karyawans: $e");
      }
      try {
        customersData = await CustomerService.getCustomers(ignoreCabang: true);
      } catch (e) {
        print("Error fetching customers: $e");
      }
      try {
        layanansData = await _hrdService.fetchLayanan();
      } catch (e) {
        print("Error fetching layanans: $e");
      }

      if (mounted) {
        setState(() {
          // Sort by ID sequence descending to fix unstable API created_at sorting for imported data
          ordersData.sort((a, b) {
            final idA = int.tryParse(a.id.split('-').last) ?? 0;
            final idB = int.tryParse(b.id.split('-').last) ?? 0;
            return idB.compareTo(idA);
          });
          _orders = ordersData;
          _cabangs = cabangsData;
          _karyawans = karyawansData;
          _customers = customersData;
          _layanans = layanansData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Audit Sub-Tabs Bar (Audit Order | Approve Edit | Edit Order | Hasil Audit)
                    _buildAuditTabBar(),
                    const SizedBox(height: 14),

                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error.isNotEmpty)
                      _buildErrorWidget()
                    else if (_auditTab == 'audit-order')
                      _buildAuditOrderContent()
                    else if (_auditTab == 'approve-edit')
                      _buildApproveEditContent()
                    else if (_auditTab == 'edit-order')
                      _buildEditOrderBebasContent()
                    else if (_auditTab == 'hasil-audit')
                      _buildHasilAuditContent()
                    else
                      _buildComingSoonTab(_auditTab),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Header ---
  Widget _buildHeader() {
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manajemen Audit',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Audit & Persetujuan',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fact_check_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Finance Audit',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Format Helpers ---
  String _formatTanggal(String dateStr) {
    if (dateStr.isEmpty) return '-';
    try {
      String cleanStr = dateStr.replaceAll(' - ', ' ').replaceAll(' · ', ' ');
      final dt = DateTime.parse(cleanStr);
      return DateFormat('EEEE, dd MMMM yyyy, HH:mm', 'id_ID').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildSafeImage(String url, {BoxFit fit = BoxFit.contain}) {
    if (url.startsWith('file://')) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('Gambar lokal tidak ditemukan', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    
    String finalUrl = url;
    if (!url.startsWith('http')) {
      final domain = ApiClient.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
      if (!url.startsWith('storage/') && !url.startsWith('/storage/')) {
        finalUrl = '$domain/storage/${url.startsWith('/') ? url.substring(1) : url}';
      } else {
        finalUrl = '$domain/${url.startsWith('/') ? url.substring(1) : url}';
      }
    }

    return Image.network(
      finalUrl,
      fit: fit,
      errorBuilder: (ctx, err, stack) => const Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('Gagal memuat gambar', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection(String title, Color color, IconData icon, List<CleanerFoto> photos) {
    if (photos.isEmpty) return const SizedBox();

    String formattedDate = '';
    if (photos.first.createdAt != null) {
      formattedDate = DateFormat('dd MMM yyyy HH:mm').format(photos.first.createdAt!);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  border: Border.all(color: color.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: color),
                    const SizedBox(width: 4),
                    Text(
                      title, 
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                    ),
                  ],
                ),
              ),
              if (formattedDate.isNotEmpty)
                Text(
                  formattedDate, 
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final f = photos[index];
              return InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(16),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _buildSafeImage(f.url, fit: BoxFit.contain),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black.withOpacity(0.5),
                                padding: const EdgeInsets.all(8),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: Colors.grey.shade200,
                    child: _buildSafeImage(f.url, fit: BoxFit.cover),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCleanerPhotos(OrderCleaner cleaner) {
    if (cleaner.fotosStart.isEmpty && cleaner.fotosFinish.isEmpty) return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFD1FAE5),
                child: Text(
                  cleaner.name.substring(0, cleaner.name.length >= 2 ? 2 : cleaner.name.length).toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF166534)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cleaner.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    Text('Status: ${cleaner.statusPengerjaan.name.toUpperCase()}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cleaner.fotosStart.isNotEmpty) ...[
                _buildPhotoSection(
                  'Foto Mulai (Sebelum)',
                  Colors.blue.shade700,
                  Icons.arrow_circle_down_rounded,
                  cleaner.fotosStart,
                ),
              ],
              if (cleaner.fotosStart.isNotEmpty && cleaner.fotosFinish.isNotEmpty)
                const SizedBox(height: 12),
              if (cleaner.fotosFinish.isNotEmpty) ...[
                _buildPhotoSection(
                  'Foto Selesai (Sesudah)',
                  Colors.green.shade700,
                  Icons.check_circle_outline_rounded,
                  cleaner.fotosFinish,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // --- ERROR WIDGET ---
  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 40),
            const SizedBox(height: 10),
            Text(_error, style: GoogleFonts.inter(color: AppColors.error)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Main Audit Sub-Tabs Bar ---
  Widget _buildAuditTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildAuditTabButton('Audit Order', 'audit-order', isPrimary: true),
            _buildAuditTabButton('Approve Edit', 'approve-edit'),
            _buildAuditTabButton('Edit Order', 'edit-order'),
            _buildAuditTabButton('Hasil Audit', 'hasil-audit'),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditTabButton(String label, String tabKey, {bool isPrimary = false}) {
    final bool isActive = _auditTab == tabKey;
    return GestureDetector(
      onTap: () => setState(() => _auditTab = tabKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            color: isActive ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  // --- Coming Soon View for other Audit Tabs ---
  Widget _buildComingSoonTab(String tabName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fact_check_outlined, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            'Menu $tabName',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          Text(
            'Fitur ini sedang disinkronkan dengan sistem audit web.',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // AUDIT ORDER CONTENT
  // ===========================================================================
  Widget _buildAuditOrderContent() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Calculate Summary Stats
    final ordersToday = _orders.where((o) =>
      !o.tanggalInput.isBefore(todayStart) && !o.tanggalInput.isAfter(todayEnd)
    ).toList();

    // Omzet = sum of pembayaran.total_akhir for approved payments today
    // (matches web: Pemasukan::whereDate('tanggal_pemasukan', now())->sum('nominal'))
    // pembayaran.total in mobile == total_akhir from API == Pemasukan.nominal on web
    final omzetToday = ordersToday
        .where((o) =>
          o.pembayaran?.statusPembayaran == 'approved' ||
          o.paymentStatus == 'approved')
        .fold<int>(0, (sum, o) {
          // Use pembayaran.total (= total_akhir) if available, else fallback to order.total
          final nominal = o.pembayaran?.total ?? o.total;
          return sum + nominal;
        });

    // Done count = pesanan berstatus utama Done hari ini
    // (matches web: Pesanan::where('status_order_utama', 'done')->whereDate('tanggal_input', now())->count())
    final doneCountToday = ordersToday
        .where((o) => o.statusUtamaRaw?.toLowerCase() == 'done')
        .length;

    final pendingAuditList = _orders.where((o) =>
      o.status == OrderStatus.waitingPaymentApproval ||
      o.paymentStatus == 'pending' ||
      (o.pembayaran?.statusPembayaran == 'pending')
    ).toList();

    final approvedDoneList = _orders.where((o) =>
      o.status == OrderStatus.completed ||
      o.paymentStatus == 'approved' ||
      (o.pembayaran?.statusPembayaran == 'approved')
    ).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Unified 1-Row Summary Bar (Omzet Hari Ini | Disetujui | Menunggu)
        _buildUnifiedAuditSummaryBar(omzetToday, doneCountToday, pendingAuditList.length),
        const SizedBox(height: 14),

        // Mode Switcher for Tables (Pending vs Done/Approved)
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _approvalTableMode = 'pending'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                    decoration: BoxDecoration(
                      color: _approvalTableMode == 'pending' ? const Color(0xFFD97706) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: _approvalTableMode == 'pending' ? Colors.white : AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Menunggu Approval (${pendingAuditList.length})',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: _approvalTableMode == 'pending' ? FontWeight.bold : FontWeight.w600,
                            color: _approvalTableMode == 'pending' ? Colors.white : AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _approvalTableMode = 'done'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                    decoration: BoxDecoration(
                      color: _approvalTableMode == 'done' ? const Color(0xFF059669) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.task_alt_rounded,
                          size: 16,
                          color: _approvalTableMode == 'done' ? Colors.white : AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Disetujui / Selesai (${approvedDoneList.length})',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: _approvalTableMode == 'done' ? FontWeight.bold : FontWeight.w600,
                            color: _approvalTableMode == 'done' ? Colors.white : AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Search & Filter Bar (Row 1: Search + Pilih Tanggal, Row 2: Semua Cabang + Semua Waktu)
        _buildProMaxSearchAndFilterBar(),
        const SizedBox(height: 14),

        if (_approvalTableMode == 'pending')
          _buildPendingOrdersList(pendingAuditList)
        else
          _buildDoneOrdersList(approvedDoneList),
      ],
    );
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _customRange ?? DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _periodFilter = 'custom';
        _customRange = picked;
      });
    }
  }

  bool _matchesDateFilter(DateTime dt) {
    if (_periodFilter == 'semua') {
      return true;
    }
    if (_periodFilter == 'weekly_date' && _filterStart != null && _filterEnd != null) {
      final start = DateTime(_filterStart!.year, _filterStart!.month, _filterStart!.day);
      final end = DateTime(_filterEnd!.year, _filterEnd!.month, _filterEnd!.day, 23, 59, 59);
      return !dt.isBefore(start) && !dt.isAfter(end);
    }
    final now = DateTime.now();

    if (_periodFilter == 'hari_ini') {
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      return !dt.isBefore(todayStart) && !dt.isAfter(todayEnd);
    } else if (_periodFilter == 'kemarin') {
      final yest = now.subtract(const Duration(days: 1));
      final yStart = DateTime(yest.year, yest.month, yest.day);
      final yEnd = DateTime(yest.year, yest.month, yest.day, 23, 59, 59);
      return !dt.isBefore(yStart) && !dt.isAfter(yEnd);
    } else if (_periodFilter == 'besok') {
      final tom = now.add(const Duration(days: 1));
      final tStart = DateTime(tom.year, tom.month, tom.day);
      final tEnd = DateTime(tom.year, tom.month, tom.day, 23, 59, 59);
      return !dt.isBefore(tStart) && !dt.isAfter(tEnd);
    } else if (_periodFilter == 'bulan_ini') {
      final mStart = DateTime(now.year, now.month, 1);
      final mEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      return !dt.isBefore(mStart) && !dt.isAfter(mEnd);
    } else if (_periodFilter == 'custom' && _customRange != null) {
      final cStart = DateTime(_customRange!.start.year, _customRange!.start.month, _customRange!.start.day);
      final cEnd = DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day, 23, 59, 59);
      return !dt.isBefore(cStart) && !dt.isAfter(cEnd);
    }

    return true;
  }

  Widget _buildUnifiedAuditSummaryBar(num omzetToday, int doneCountToday, int pendingCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // 1. Omzet Hari Ini
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.monetization_on_rounded, size: 12, color: Color(0xFF059669)),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'OMZET HARI INI',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _currencyFormat.format(omzetToday),
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF065F46)),
                    ),
                  ),
                ],
              ),
            ),
            VerticalDivider(width: 14, thickness: 1, color: Colors.grey.withOpacity(0.15)),

            // 2. Disetujui
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF0284C7)),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'DISETUJUI',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$doneCountToday Order',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0369A1)),
                    ),
                  ),
                ],
              ),
            ),
            VerticalDivider(width: 14, thickness: 1, color: Colors.grey.withOpacity(0.15)),

            // 3. Menunggu Audit
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.pending_actions_rounded, size: 12, color: Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'MENUNGGU',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$pendingCount Order',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
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

  Widget _buildUnifiedCancelSummaryBar(num totalCancelToday, num totalCancelThisMonth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.cancel_outlined, size: 14, color: Color(0xFFDC2626)),
                      ),
                      const SizedBox(width: 6),
                      Text('CANCEL HARI INI', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('$totalCancelToday Order', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF991B1B))),
                ],
              ),
            ),
            VerticalDivider(width: 20, thickness: 1, color: Colors.grey.withOpacity(0.15)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.calendar_month_outlined, size: 14, color: Color(0xFFE11D48)),
                      ),
                      const SizedBox(width: 6),
                      Text('CANCEL BULAN INI', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFE11D48))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('$totalCancelThisMonth Order', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF9F1239))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProMaxSearchAndFilterBar({bool showStatusFilter = false}) {
    final int activeFilterCount = (_selectedCabangName != null ? 1 : 0) +
        (_periodFilter != 'semua' ? 1 : 0) +
        (showStatusFilter && _selectedStatusUtama != null ? 1 : 0);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: _searchQuery.isNotEmpty ? const Color(0xFF3B82F6) : Colors.grey.withOpacity(0.25),
                width: _searchQuery.isNotEmpty ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _searchQuery.isNotEmpty ? const Color(0xFF3B82F6).withOpacity(0.12) : Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: _searchQuery.isNotEmpty ? const Color(0xFF2563EB) : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Cari pelanggan, no. pesanan, atau cleaner...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, size: 14, color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _showFilterBottomSheet(showStatusFilter: showStatusFilter),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: activeFilterCount > 0
                  ? const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF4F46E5)])
                  : null,
              color: activeFilterCount > 0 ? null : Colors.white,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: activeFilterCount > 0 ? Colors.transparent : Colors.grey.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                if (activeFilterCount > 0)
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: activeFilterCount > 0 ? Colors.white : AppColors.textDark,
                ),
                const SizedBox(width: 6),
                Text(
                  'Filter',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: activeFilterCount > 0 ? Colors.white : AppColors.textDark,
                  ),
                ),
                if (activeFilterCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$activeFilterCount',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showFilterBottomSheet({required bool showStatusFilter}) {
    List<String> sortedCabangNames = [];
    if (_cabangs.isNotEmpty) {
      sortedCabangNames = _cabangs
          .where((c) => !c.namaCabang.toLowerCase().contains('kantor pusat'))
          .map((c) => c.namaCabang.toUpperCase())
          .toList()..sort();
    }
    if (sortedCabangNames.isEmpty) {
      sortedCabangNames = ['BALIKPAPAN', 'DENPASAR', 'MAKASSAR', 'MALANG', 'SURABAYA'];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Filter Transaksi', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // 1. Pilih Cabang
                  Text('Pilih Cabang', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Semua Cabang'),
                        selected: _selectedCabangName == null,
                        onSelected: (val) {
                          setModalState(() => _selectedCabangName = null);
                          setState(() => _selectedCabangName = null);
                        },
                        selectedColor: const Color(0xFFEFF6FF),
                        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: _selectedCabangName == null ? FontWeight.bold : FontWeight.w500, color: _selectedCabangName == null ? const Color(0xFF1D4ED8) : AppColors.textDark),
                        side: BorderSide(color: _selectedCabangName == null ? const Color(0xFF3B82F6) : Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        showCheckmark: false,
                      ),
                      ...sortedCabangNames.map((name) {
                        final isSel = _selectedCabangName == name;
                        return ChoiceChip(
                          label: Text(name),
                          selected: isSel,
                          onSelected: (val) {
                            setModalState(() => _selectedCabangName = val ? name : null);
                            setState(() => _selectedCabangName = val ? name : null);
                          },
                          selectedColor: const Color(0xFFEFF6FF),
                          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? const Color(0xFF1D4ED8) : AppColors.textDark),
                          side: BorderSide(color: isSel ? const Color(0xFF3B82F6) : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          showCheckmark: false,
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. Rentang Waktu
                  Text('Rentang Waktu', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...[
                        {'key': 'semua', 'label': 'Semua Waktu'},
                        {'key': 'hari_ini', 'label': 'Hari Ini'},
                        {'key': 'kemarin', 'label': 'Kemarin'},
                        {'key': 'besok', 'label': 'Besok'},
                        {'key': 'bulan_ini', 'label': 'Bulan Ini'},
                      ].map((item) {
                        final isSel = _periodFilter == item['key'];
                        return ChoiceChip(
                          label: Text(item['label']!),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                _periodFilter = item['key']!;
                                _customRange = null;
                                if (_periodFilter == 'semua') {
                                  _filterStart = null;
                                  _filterEnd = null;
                                }
                              });
                              setState(() {
                                _periodFilter = item['key']!;
                                _customRange = null;
                                if (_periodFilter == 'semua') {
                                  _filterStart = null;
                                  _filterEnd = null;
                                }
                              });
                            }
                          },
                          selectedColor: const Color(0xFFECFDF5),
                          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? const Color(0xFF047857) : AppColors.textDark),
                          side: BorderSide(color: isSel ? const Color(0xFF10B981) : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          showCheckmark: false,
                        );
                      }),
                      ActionChip(
                        avatar: const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF4F46E5)),
                        label: Text(
                          _periodFilter == 'custom' && _customRange != null
                              ? '${DateFormat('dd/MM').format(_customRange!.start)} - ${DateFormat('dd/MM').format(_customRange!.end)}'
                              : 'Pilih Tanggal',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: _periodFilter == 'custom' ? FontWeight.bold : FontWeight.w500, color: _periodFilter == 'custom' ? const Color(0xFF4F46E5) : AppColors.textDark),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _pickCustomRange();
                        },
                        backgroundColor: _periodFilter == 'custom' ? const Color(0xFFEEF2FF) : Colors.white,
                        side: BorderSide(color: _periodFilter == 'custom' ? const Color(0xFF6366F1) : Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ],
                  ),

                  // 3. Status Utama (for Tab 3)
                  if (showStatusFilter) ...[
                    const SizedBox(height: 20),
                    Text('Status Order', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Semua Status'),
                          selected: _selectedStatusUtama == null,
                          onSelected: (val) {
                            setModalState(() => _selectedStatusUtama = null);
                            setState(() => _selectedStatusUtama = null);
                          },
                          selectedColor: const Color(0xFFFFFBEB),
                          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: _selectedStatusUtama == null ? FontWeight.bold : FontWeight.w500, color: _selectedStatusUtama == null ? const Color(0xFFD97706) : AppColors.textDark),
                          side: BorderSide(color: _selectedStatusUtama == null ? const Color(0xFFF59E0B) : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          showCheckmark: false,
                        ),
                        ...['Draft', 'Process', 'Done', 'Dibatalkan'].map((st) {
                          final isSel = _selectedStatusUtama == st;
                          return ChoiceChip(
                            label: Text(st),
                            selected: isSel,
                            onSelected: (val) {
                              setModalState(() => _selectedStatusUtama = val ? st : null);
                              setState(() => _selectedStatusUtama = val ? st : null);
                            },
                            selectedColor: const Color(0xFFFFFBEB),
                            labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? const Color(0xFFD97706) : AppColors.textDark),
                            side: BorderSide(color: isSel ? const Color(0xFFF59E0B) : Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            showCheckmark: false,
                          );
                        }),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedCabangName = null;
                              _periodFilter = 'semua';
                              _customRange = null;
                              _filterStart = null;
                              _filterEnd = null;
                              if (showStatusFilter) _selectedStatusUtama = null;
                            });
                            setState(() {
                              _selectedCabangName = null;
                              _periodFilter = 'semua';
                              _customRange = null;
                              _filterStart = null;
                              _filterEnd = null;
                              if (showStatusFilter) _selectedStatusUtama = null;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Reset', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Terapkan Filter', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  // --- Summary Card ---
  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 10, color: color.withOpacity(0.85)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCabangFilterChip(String label, String? value) {
    final bool isSelected = _selectedCabangName == value;
    return InkWell(
      onTap: () => setState(() => _selectedCabangName = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  // --- Pending Orders List ---
  Widget _buildPendingOrdersList(List<OrderModel> pendingList) {
    final filtered = pendingList.where((o) {
      if (!_matchesDateFilter(o.tanggalInput)) {
        return false;
      }
      if (_selectedCabangName != null) {
        final matchCabang = o.customer.area.toUpperCase().contains(_selectedCabangName!) ||
            (_cabangs.any((c) => c.namaCabang.toUpperCase() == _selectedCabangName && o.cabangId == c.id.toString()));
        if (!matchCabang) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchCust = o.customer.name.toLowerCase().contains(q);
        final matchId = o.id.toLowerCase().contains(q);
        final matchCleaners = o.cleaners.any((c) => c.name.toLowerCase().contains(q));
        if (!matchCust && !matchId && !matchCleaners) return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            const Icon(Icons.verified_rounded, size: 36, color: Color(0xFF059669)),
            const SizedBox(height: 10),
            Text(
              'Tidak ada pesanan menunggu approval',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              'Semua pembayaran pesanan telah diaudit.',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    final totalCount = filtered.length;
    final displayedList = filtered.take(_limitAuditPending).toList();

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayedList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = displayedList[index];
            final orderNo = order.id.startsWith('SUR') || order.id.startsWith('BAL') || order.id.startsWith('DEN') || order.id.startsWith('MAL')
                ? order.id
                : 'Order #${order.id}';
            return _buildProMaxOrderCard(order, isPending: true);
          },
        ),
        _buildLoadMoreButton(
          currentCount: displayedList.length,
          totalCount: totalCount,
          onTap: () => setState(() => _limitAuditPending += 5),
        ),
      ],
    );
  }

  // --- Done Orders List ---
  Widget _buildDoneOrdersList(List<OrderModel> doneList) {
    final filtered = doneList.where((o) {
      if (!_matchesDateFilter(o.tanggalInput)) {
        return false;
      }
      if (_selectedCabangName != null) {
        final matchCabang = o.customer.area.toUpperCase().contains(_selectedCabangName!) ||
            (_cabangs.any((c) => c.namaCabang.toUpperCase() == _selectedCabangName && o.cabangId == c.id.toString()));
        if (!matchCabang) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchCust = o.customer.name.toLowerCase().contains(q);
        final matchId = o.id.toLowerCase().contains(q);
        if (!matchCust && !matchId) return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            const Icon(Icons.history_rounded, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(
              'Belum ada data pesanan disetujui',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
          ],
        ),
      );
    }

    final totalCount = filtered.length;
    final displayedList = filtered.take(_limitAuditDone).toList();

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayedList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final order = displayedList[index];
            final orderNo = order.id.startsWith('SUR') || order.id.startsWith('BAL') || order.id.startsWith('DEN') || order.id.startsWith('MAL')
                ? order.id
                : 'Order #${order.id}';

            return _buildProMaxOrderCard(order, isPending: false);
          },
        ),
        _buildLoadMoreButton(
          currentCount: displayedList.length,
          totalCount: totalCount,
          onTap: () => setState(() => _limitAuditDone += 5),
        ),
      ],
    );
  }

  Widget _buildProMaxOrderCard(OrderModel order, {required bool isPending}) {
    final orderNo = order.id.startsWith('SUR') || order.id.startsWith('BAL') || order.id.startsWith('DEN') || order.id.startsWith('MAL')
        ? order.id
        : 'Order #${order.id}';

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Compact
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isPending ? const Color(0xFFFEF3C7).withOpacity(0.4) : const Color(0xFFF0FDF4).withOpacity(0.5),
                border: Border(
                  bottom: BorderSide(
                    color: isPending ? const Color(0xFFFDE68A).withOpacity(0.5) : const Color(0xFFBBF7D0).withOpacity(0.5),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isPending ? Icons.pending_actions_rounded : Icons.check_circle_rounded,
                        size: 15,
                        color: isPending ? const Color(0xFFD97706) : const Color(0xFF059669),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        orderNo,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isPending ? const Color(0xFFB45309) : const Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPending ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isPending ? 'Menunggu Approval' : 'Disetujui',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isPending ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Body Compact
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Info Row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(
                          order.customer.name.isNotEmpty ? order.customer.name[0].toUpperCase() : 'C',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customer.name,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 11, color: Color(0xFFDC2626)),
                                const SizedBox(width: 2),
                                Text(
                                  order.customer.area.toUpperCase(),
                                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                                ),
                                const SizedBox(width: 5),
                                Text('•', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted)),
                                const SizedBox(width: 5),
                                const Icon(Icons.access_time_rounded, size: 11, color: AppColors.textMuted),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(order.tanggalInput),
                                    style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Price & Payment Method Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.payment_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Metode: ${order.paymentMethod.toUpperCase()}',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                            ),
                          ],
                        ),
                        Text(
                          _currencyFormat.format(order.total),
                          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Safe Actions Bar (Space Efficient)
                  if (isPending) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: OutlinedButton.icon(
                            onPressed: () => _showDetailModal(order),
                            icon: const Icon(Icons.description_outlined, size: 14),
                            label: const Text('Periksa'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 4,
                          child: ElevatedButton.icon(
                            onPressed: () => _showApproveConfirm(order),
                            icon: const Icon(Icons.check_circle_rounded, size: 14),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                              textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            onPressed: () => _showRejectModal(order),
                            icon: const Icon(Icons.cancel_outlined, size: 14),
                            label: const Text('Tolak'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFEF2F2),
                              foregroundColor: const Color(0xFFDC2626),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Color(0xFFFECACA)),
                              ),
                              elevation: 0,
                              textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showDetailModal(order),
                          icon: const Icon(Icons.description_outlined, size: 14),
                          label: const Text('Lihat Rincian Audit'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: text)),
    );
  }

  // --- Modal Detail Bottom Sheet Matching Web ERP ---
  void _showDetailModal(OrderModel order) {
    final csName = order.createdByName.isNotEmpty ? order.createdByName : 'Joko';
    final int totalBonus = order.cleaners.fold(0, (sum, c) => sum + c.totalBonus);
    final hasProof = order.paymentProof != null && order.paymentProof!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),

            // Title & Tutup Button (Persis Web Screenshot)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Pembayaran ${order.id}',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.customer.name.toLowerCase(),
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text('Tutup', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 14),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Informasi Pelanggan
                    _buildSectionHeader('Informasi Pelanggan'),
                    _buildDetailRow('Nama:', order.customer.name),
                    _buildDetailRow('No. WA:', order.customer.phone),
                    _buildDetailRow('Alamat:', order.customer.address),
                    const SizedBox(height: 16),

                    // 2. Informasi Pesanan
                    _buildSectionHeader('Informasi Pesanan'),
                    _buildDetailRow('Cabang:', order.customer.area),
                    _buildDetailRow('CS:', csName),
                    _buildDetailRow('Tanggal:', _formatTanggal(order.schedule)),
                    _buildDetailRow('Metode:', order.paymentMethod.toUpperCase()),
                    const SizedBox(height: 16),

                    // 3. Rincian Pembayaran Card (Persis Web Screenshot)
                    _buildSectionHeader('Rincian Pembayaran'),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          if (order.services.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Layanan Utama', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark)),
                                  Text(_currencyFormat.format(order.total), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                ],
                              ),
                            )
                          else
                            ...order.services.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${s.name} (x${s.qty})',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark),
                                    ),
                                  ),
                                  Text(
                                    _currencyFormat.format(s.price * (int.tryParse(s.qty) ?? 1)),
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            )),
                          const Divider(height: 16, color: Color(0xFFCBD5E1)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal Pesanan', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                              Text(_currencyFormat.format(order.subtotal), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                            ],
                          ),
                          if (order.ppn != null && order.ppn! > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('PPN (${order.ppn}%)', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                  Text('+${_currencyFormat.format(order.subtotal * (order.ppn! / 100))}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Akhir', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7))),
                              Text(_currencyFormat.format(order.total), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Cleaner & Bonus Card (Persis Web Screenshot)
                    _buildSectionHeader('Cleaner & Bonus'),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          if (order.cleaners.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Belum ada cleaner ditugaskan', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                  Text('Rp 0', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                ],
                              ),
                            )
                          else
                            ...order.cleaners.map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(c.name, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark)),
                                  Text(_currencyFormat.format(c.totalBonus), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                ],
                              ),
                            )),
                          const Divider(height: 16, color: Color(0xFFCBD5E1)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Keseluruhan Bonus', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                              Text(_currencyFormat.format(totalBonus), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5. Bukti Transfer Section (Persis Web Screenshot)
                    _buildSectionHeader('Bukti transfer'),
                    hasProof
                        ? OutlinedButton.icon(
                            onPressed: () {
                              // Show proof image dialog
                              showDialog(
                                context: context,
                                builder: (ctx) => Dialog(
                                  child: _buildSafeImage(order.paymentProof!),
                                ),
                              );
                            },
                            icon: const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF0284C7)),
                            label: Text('Buka bukti', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0284C7))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF0284C7)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          )
                        : Text('Tidak ada bukti transfer.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 16),

                    // 6. Foto Pengerjaan Cleaner Section (Persis Web Screenshot)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('Foto Pengerjaan Cleaner'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Text(
                            'Total ${order.cleaners.fold(0, (sum, c) => sum + c.fotosStart.length + c.fotosFinish.length)} Foto',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (order.cleaners.isEmpty || order.cleaners.every((c) => c.fotosStart.isEmpty && c.fotosFinish.isEmpty))
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.image_outlined, size: 42, color: Colors.grey.shade300),
                            const SizedBox(height: 10),
                            Text(
                              'Belum ada foto pengerjaan',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cleaner wajib mengunggah foto minimal 2 saat mulai dan 2 saat selesai pengerjaan melalui aplikasi mobile.',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ...order.cleaners.map((c) => _buildCleanerPhotos(c)),
                    if (_approvalTableMode == 'pending') ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showApproveConfirm(order);
                              },
                              icon: const Icon(Icons.check_circle_rounded, size: 16),
                              label: const Text('Approve & Selesai'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showRejectModal(order);
                              },
                              icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFDC2626)),
                              label: const Text('Tolak', style: TextStyle(color: Color(0xFFDC2626))),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: Color(0xFFFECACA)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
    );
  }

  Widget _buildDetailRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted))),
          Expanded(child: Text(val, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark))),
        ],
      ),
    );
  }

  // --- Confirm Approve Dialog ---
  void _showApproveConfirm(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Konfirmasi Approval', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menyetujui pembayaran ${order.id} sebesar ${_currencyFormat.format(order.total)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                order.paymentStatus = 'approved';
                order.status = OrderStatus.completed;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pembayaran berhasil disetujui!'), backgroundColor: Color(0xFF059669)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            child: const Text('Ya, Approve'),
          ),
        ],
      ),
    );
  }

  // --- Reject Modal Dialog ---
  void _showRejectModal(OrderModel order) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Tolak Pembayaran', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Masukkan alasan penolakan pembayaran ${order.id}:', style: GoogleFonts.inter(fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Alasan penolakan...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                order.paymentStatus = 'rejected';
                order.status = OrderStatus.cancelled;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pembayaran berhasil ditolak.'), backgroundColor: Color(0xFFDC2626)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // APPROVE EDIT CONTENT (Matching Web tab=approve-edit)
  // ===========================================================================
  Widget _buildApproveEditContent() {
    List<OrderModel> editRequestsList = _orders.where((o) => o.hasPendingEditRequest).toList();

    // removed fallback dummy data

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProMaxSearchAndFilterBar(),
        const SizedBox(height: 14),

        _buildApproveEditList(editRequestsList),
      ],
    );
  }

  Widget _buildApproveEditList(List<OrderModel> editList) {
    final filtered = editList.where((o) {
      if (!_matchesDateFilter(o.tanggalInput)) return false;
      if (_selectedCabangName != null) {
        final matchCabang = o.customer.area.toUpperCase().contains(_selectedCabangName!) ||
            (_cabangs.any((c) => c.namaCabang.toUpperCase() == _selectedCabangName && o.cabangId == c.id.toString()));
        if (!matchCabang) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchCust = o.customer.name.toLowerCase().contains(q);
        final matchId = o.id.toLowerCase().contains(q);
        if (!matchCust && !matchId) return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            const Icon(Icons.edit_note_rounded, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(
              'Belum ada pengajuan edit pesanan',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              'Pengajuan edit dari CS yang membutuhkan persetujuan akan muncul di sini.',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final totalCount = filtered.length;
    final displayedList = filtered.take(_limitApproveEdit).toList();

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayedList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = displayedList[index];
            final orderNo = order.id.isNotEmpty ? order.id : 'Order #${order.id}';
            final csName = order.createdByName.isNotEmpty ? order.createdByName : 'CS';
            final alasanStr = order.alasanPengajuanEdit.isNotEmpty
                ? order.alasanPengajuanEdit
                : 'Pengajuan edit layanan';

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
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
                        orderNo,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          'Pengajuan Edit',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        order.customer.name,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.support_agent_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        'CS: $csName',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.storefront_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        order.customer.area.toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Alasan Banner matching Web UI Screenshot
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alasan Pengajuan Edit (Oleh CS: $csName):',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alasanStr,
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                      ),
                      Text(
                        _currencyFormat.format(order.total),
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showEditDetailModal(order, csName, alasanStr),
                          icon: const Icon(Icons.visibility_rounded, size: 14),
                          label: const Text('Detail'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showApproveEditConfirm(order),
                          icon: const Icon(Icons.check_rounded, size: 14),
                          label: const Text('Setujui'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showRejectEditModal(order),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        _buildLoadMoreButton(
          currentCount: displayedList.length,
          totalCount: totalCount,
          onTap: () => setState(() => _limitApproveEdit += 5),
        ),
      ],
    );
  }

  // --- Modal Detail Pengajuan Edit Bottom Sheet (Matching Screenshot 2) ---
  void _showEditDetailModal(OrderModel order, String csName, String alasanStr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Detail Pengajuan Edit ${order.id}',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amber Banner for Alasan (Persis Screenshot 2)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alasan Pengajuan Edit (Oleh CS: $csName)',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFB45309)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            alasanStr,
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _buildDetailRow('Pelanggan', order.customer.name),
                    _buildDetailRow('No. WA', order.customer.phone),
                    _buildDetailRow('Alamat', order.customer.address),
                    _buildDetailRow('Tanggal (Jadwal)', _formatTanggal(order.schedule)),
                    const SizedBox(height: 14),

                    _buildSectionHeader('Rincian Layanan'),
                    ...order.services.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${s.name} (x${s.qty})', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark)),
                          Text(_currencyFormat.format(s.price * (int.tryParse(s.qty) ?? 1)), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal Pesanan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        Text(_currencyFormat.format(order.subtotal), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('Foto Pengerjaan Cleaner'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Text(
                            'Total ${order.cleaners.fold(0, (sum, c) => sum + c.fotosStart.length + c.fotosFinish.length)} Foto',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (order.cleaners.isEmpty || order.cleaners.every((c) => c.fotosStart.isEmpty && c.fotosFinish.isEmpty))
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.image_outlined, size: 42, color: Colors.grey.shade300),
                            const SizedBox(height: 10),
                            Text(
                              'Belum ada foto pengerjaan',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cleaner wajib mengunggah foto minimal 2 saat mulai dan 2 saat selesai pengerjaan melalui aplikasi mobile.',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ...order.cleaners.map((c) => _buildCleanerPhotos(c)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showApproveEditConfirm(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Setujui Pengajuan Edit', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menyetujui pengajuan edit pesanan ${order.id}? Pesanan akan diizinkan untuk diedit ulang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                order.hasPendingEditRequest = false;
                order.status = OrderStatus.finishedByCleaner;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pengajuan edit berhasil disetujui! CS sekarang dapat mengedit pesanan.'), backgroundColor: Color(0xFF059669)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            child: const Text('Ya, Setujui'),
          ),
        ],
      ),
    );
  }

  void _showRejectEditModal(OrderModel order) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Tolak Pengajuan Edit', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Masukkan alasan penolakan pengajuan edit ${order.id}:', style: GoogleFonts.inter(fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Alasan penolakan...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                order.hasPendingEditRequest = false;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pengajuan edit ditolak.'), backgroundColor: Color(0xFFDC2626)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EDIT ORDER BEBAS CONTENT (Finance Full Authority - Matching Screenshot 1 & 2)
  // ===========================================================================
  Widget _buildEditOrderBebasContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProMaxSearchAndFilterBar(showStatusFilter: true),
        const SizedBox(height: 14),

        _buildEditOrderBebasList(),
      ],
    );
  }

  Widget _buildEditOrderBebasList() {
    List<OrderModel> displayOrders = List.from(_orders);



    final filtered = displayOrders.where((o) {
      if (!_matchesDateFilter(o.tanggalInput)) return false;
      if (_selectedCabangName != null) {
        final matchCabang = o.customer.area.toUpperCase().contains(_selectedCabangName!) ||
            (_cabangs.any((c) => c.namaCabang.toUpperCase() == _selectedCabangName && o.cabangId == c.id.toString()));
        if (!matchCabang) return false;
      }
      if (_selectedStatusUtama != null) {
        if (o.statusUtamaLabel.toLowerCase() != _selectedStatusUtama!.toLowerCase()) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchCust = o.customer.name.toLowerCase().contains(q);
        final matchId = o.id.toLowerCase().contains(q);
        final matchPhone = o.customer.phone.contains(q);
        if (!matchCust && !matchId && !matchPhone) return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            const Icon(Icons.edit_note_rounded, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(
              'Tidak ada pesanan ditemukan',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              'Coba sesuaikan kata kunci pencarian atau filter di atas.',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final totalCount = filtered.length;
    final displayedList = filtered.take(_limitEditOrderBebas).toList();

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayedList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = displayedList[index];
            final orderNo = order.id;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: ID & Subtotal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        orderNo,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      Text(
                        _currencyFormat.format(order.total),
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Customer & Schedule
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${order.customer.name} · ${order.customer.phone}',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          order.customer.area.toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        _formatTanggal(order.schedule),
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 4 STATUS BADGES (Persis Screenshot 1)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      // 1. Status Utama
                      _buildStatusBadgeItem(
                        label: 'Utama: ${order.statusUtamaLabel}',
                        bgColor: order.statusUtamaLabel == 'Done'
                            ? const Color(0xFFDCFCE7)
                            : order.statusUtamaLabel == 'Dibatalkan'
                                ? const Color(0xFFFEE2E2)
                                : order.statusUtamaLabel == 'Draft'
                                    ? Colors.grey.shade200
                                    : const Color(0xFFEFF6FF),
                        textColor: order.statusUtamaLabel == 'Done'
                            ? const Color(0xFF15803D)
                            : order.statusUtamaLabel == 'Dibatalkan'
                                ? const Color(0xFFB91C1C)
                                : order.statusUtamaLabel == 'Draft'
                                    ? Colors.grey.shade700
                                    : const Color(0xFF1D4ED8),
                      ),
                      // 2. Pengerjaan
                      _buildStatusBadgeItem(
                        label: 'Pengerjaan: ${order.statusPengerjaanLabel}',
                        bgColor: order.statusPengerjaanLabel == 'Selesai'
                            ? const Color(0xFFDCFCE7)
                            : order.statusPengerjaanLabel == 'Selesai Cleaner'
                                ? const Color(0xFFFEF3C7)
                                : order.statusPengerjaanLabel == 'Dibatalkan'
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFE0F2FE),
                        textColor: order.statusPengerjaanLabel == 'Selesai'
                            ? const Color(0xFF15803D)
                            : order.statusPengerjaanLabel == 'Selesai Cleaner'
                                ? const Color(0xFFB45309)
                                : order.statusPengerjaanLabel == 'Dibatalkan'
                                    ? const Color(0xFFB91C1C)
                                    : const Color(0xFF0369A1),
                      ),
                      // 3. Pembayaran
                      _buildStatusBadgeItem(
                        label: 'Pembayaran: ${order.statusPembayaranLabel}',
                        bgColor: order.statusPembayaranLabel == 'Disetujui'
                            ? const Color(0xFFDCFCE7)
                            : order.statusPembayaranLabel == 'Menunggu Approval'
                                ? const Color(0xFFFEF3C7)
                                : order.statusPembayaranLabel == 'Ditolak' || order.statusPembayaranLabel == 'Dibatalkan'
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFEFF6FF),
                        textColor: order.statusPembayaranLabel == 'Disetujui'
                            ? const Color(0xFF15803D)
                            : order.statusPembayaranLabel == 'Menunggu Approval'
                                ? const Color(0xFFD97706)
                                : order.statusPembayaranLabel == 'Ditolak' || order.statusPembayaranLabel == 'Dibatalkan'
                                    ? const Color(0xFFB91C1C)
                                    : const Color(0xFF2563EB),
                      ),
                      // 4. Bonus
                      _buildStatusBadgeItem(
                        label: 'Bonus: ${order.statusBonusLabel}',
                        bgColor: order.statusBonusLabel == 'Selesai'
                            ? const Color(0xFFDCFCE7)
                            : order.statusBonusLabel == 'Disetujui'
                                ? const Color(0xFFE0F2FE)
                                : const Color(0xFFFEF3C7),
                        textColor: order.statusBonusLabel == 'Selesai'
                            ? const Color(0xFF15803D)
                            : order.statusBonusLabel == 'Disetujui'
                                ? const Color(0xFF0369A1)
                                : const Color(0xFFD97706),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Action Button: Edit Bebas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _openFinanceEditOrderBebasModal(order),
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: const Text('Edit Bebas'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        _buildLoadMoreButton(
          currentCount: displayedList.length,
          totalCount: totalCount,
          onTap: () => setState(() => _limitEditOrderBebas += 5),
        ),
      ],
    );
  }

  // ===========================================================================
  // HASIL AUDIT CONTENT (Pembatalan - Matching Web tab=hasil-audit)
  // ===========================================================================
  Widget _buildHasilAuditContent() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final cancelledOrders = _orders.where((o) => o.status == OrderStatus.cancelled || o.status == OrderStatus.waitingCancelApproval).toList();

    // Removed sample fallback items

    final totalCancelToday = cancelledOrders.where((o) {
      final dt = o.waktuBatal ?? o.tanggalInput;
      return !dt.isBefore(todayStart) && !dt.isAfter(todayEnd);
    }).length;

    final totalCancelThisMonth = cancelledOrders.where((o) {
      final dt = o.waktuBatal ?? o.tanggalInput;
      return dt.year == now.year && dt.month == now.month;
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUnifiedCancelSummaryBar(totalCancelToday, totalCancelThisMonth),
        const SizedBox(height: 14),
        _buildProMaxSearchAndFilterBar(),
        const SizedBox(height: 14),

        _buildHasilAuditList(cancelledOrders),
      ],
    );
  }

  Widget _buildHasilAuditList(List<OrderModel> cancelledList) {
    final filtered = cancelledList.where((o) {
      if (!_matchesDateFilter(o.waktuBatal ?? o.tanggalInput)) return false;
      if (_selectedCabangName != null) {
        final matchCabang = o.customer.area.toUpperCase().contains(_selectedCabangName!) ||
            (_cabangs.any((c) => c.namaCabang.toUpperCase() == _selectedCabangName && o.cabangId == c.id.toString()));
        if (!matchCabang) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchCust = o.customer.name.toLowerCase().contains(q);
        final matchId = o.id.toLowerCase().contains(q);
        if (!matchCust && !matchId) return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            const Icon(Icons.cancel_outlined, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(
              'Belum ada riwayat pembatalan pesanan',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              'Pesanan yang dibatalkan akan muncul di daftar ini.',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = filtered[index];
            final orderNo = order.id.isNotEmpty ? order.id : 'Order #${order.id}';

            final csName = order.createdByName.isNotEmpty ? order.createdByName : 'Joko';
            final dateStr = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(order.waktuBatal ?? order.tanggalInput);

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
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
                        orderNo,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          'Dibatalkan',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pelanggan: ${order.customer.name}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                          const SizedBox(height: 2),
                          Text('Cabang: ${order.customer.area}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Dibatalkan oleh: $csName', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text(dateStr, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () => _showCancelDetailModal(order, csName, dateStr),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Detail',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF0284C7)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // --- Modal Detail Pembatalan Bottom Sheet (Matching Screenshot 2) ---
  void _showCancelDetailModal(OrderModel order, String csName, String dateStr) {
    final subtotal = order.services.fold<int>(0, (sum, s) => sum + s.subtotal);
    final cancelReason = order.cancelReason?.isNotEmpty == true ? order.cancelReason! : 'customer cancel';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Pembatalan ${order.id}',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      Text(
                        order.customer.name,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Tutup', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Red Box for Informasi Pembatalan (Persis Screenshot 2)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Informasi Pembatalan',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFB91C1C)),
                          ),
                          const SizedBox(height: 6),
                          Text('Dibatalkan Oleh: $csName', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFB91C1C))),
                          Text('Waktu Batal: $dateStr', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFB91C1C))),
                          Text('Alasan: $cancelReason', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFB91C1C))),
                          const SizedBox(height: 4),
                          Text(
                            'Tidak ada bukti gambar pembatalan.',
                            style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFFB91C1C)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('Informasi Pelanggan'),
                              _buildDetailRow('Nama', order.customer.name),
                              _buildDetailRow('No. WA', order.customer.phone),
                              _buildDetailRow('Alamat', order.customer.address),
                              const SizedBox(height: 12),
                              _buildSectionHeader('Informasi Pesanan'),
                              _buildDetailRow('Cabang', order.customer.area),
                              _buildDetailRow('CS Pembuat', csName),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 _buildSectionHeader('Rincian Layanan'),
                                ...order.services.map((s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(s.name, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark))),
                                      Text(_currencyFormat.format(s.price), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                    ],
                                  ),
                                )),
                                 const Divider(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Subtotal', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                    Text(_currencyFormat.format(subtotal), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total Akhir', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                    Text('Rp 0', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Foto Pengerjaan Cleaner Section (Persis Screenshot 2)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('Foto Pengerjaan Cleaner'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Text(
                            'Total ${order.cleaners.fold(0, (sum, c) => sum + c.fotosStart.length + c.fotosFinish.length)} Foto',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (order.cleaners.isEmpty || order.cleaners.every((c) => c.fotosStart.isEmpty && c.fotosFinish.isEmpty))
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.image_outlined, size: 42, color: Colors.grey.shade300),
                            const SizedBox(height: 10),
                            Text(
                              'Belum ada foto pengerjaan',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cleaner wajib mengunggah foto minimal 2 saat mulai dan 2 saat selesai pengerjaan melalui aplikasi mobile.',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ...order.cleaners.map((c) => _buildCleanerPhotos(c)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton({
    required int currentCount,
    required int totalCount,
    required VoidCallback onTap,
  }) {
    if (currentCount >= totalCount) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF0284C7), width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF0284C7)),
              const SizedBox(width: 6),
              Text(
                'Tampilkan Lebih Banyak ($currentCount dari $totalCount)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0284C7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadgeItem({required String label, required Color bgColor, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  // --- Modal Edit Order Bebas (Finance Full Authority - Matching Screenshot 2) ---
  void _openFinanceEditOrderBebasModal(OrderModel order) {
    String selectedCabang = order.customer.area.isNotEmpty ? order.customer.area.toUpperCase() : 'SURABAYA';
    String csName = order.createdByName.isNotEmpty ? order.createdByName : 'Joko';
    String statusPengerjaan = order.statusPengerjaanLabel;
    String statusPembayaran = order.statusPembayaranLabel;
    String statusBonus = order.statusBonusLabel;

    final customerNameCtrl = TextEditingController(text: order.customer.name);
    final customerPhoneCtrl = TextEditingController(text: order.customer.phone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Compute Status Utama Live
          String liveStatusUtama = 'Process';
          if (statusPengerjaan == 'Dibatalkan' || statusPembayaran == 'Dibatalkan' || order.status == OrderStatus.cancelled) {
            liveStatusUtama = 'Dibatalkan';
          } else if ((statusPengerjaan == 'Selesai' || statusPengerjaan == 'Selesai Cleaner') && statusPembayaran == 'Disetujui' && statusBonus == 'Selesai') {
            liveStatusUtama = 'Done';
          } else if (statusPengerjaan == 'Draft') {
            liveStatusUtama = 'Draft';
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Pesanan #${order.id}',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                          Text(
                            'Finance memiliki wewenang penuh untuk mengubah detail pesanan, pelanggan, cleaner, status, bonus, dan pembayaran.',
                            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) {
                            final matchCabang = _cabangs.firstWhere(
                              (c) => c.namaCabang.toUpperCase() == selectedCabang.toUpperCase(),
                              orElse: () => _cabangs.firstWhere(
                                (c) => c.id.toString() == order.cabangId,
                                orElse: () => CabangModel(id: 0, namaCabang: selectedCabang),
                              ),
                            );
                            final int? selectedCabangId = matchCabang.id != 0 ? matchCabang.id : int.tryParse(order.cabangId);

                            final availableKaryawans = _karyawans;
                            final availableCustomers = _customers;

                            final filteredCleaners = _karyawans.where((k) => 
                              (selectedCabangId == null || k.cabangId == selectedCabangId) &&
                              (k.jabatan?.namaJabatan ?? '').toLowerCase() == 'cleaner'
                            ).toList();
                            final availableCleaners = filteredCleaners.isNotEmpty 
                                ? filteredCleaners 
                                : _karyawans.where((k) => (k.jabatan?.namaJabatan ?? '').toLowerCase() == 'cleaner').toList();

                            final filteredLayanans = _layanans.where((l) => selectedCabangId == null || l.cabangId == selectedCabangId).toList();
                            final availableLayanans = filteredLayanans.isNotEmpty ? filteredLayanans : _layanans;

                            String currentCustomerVal = '${order.customer.name} - ${order.customer.phone}';

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Card 1: Informasi Administrasi (Persis Screenshot 2)
                                _buildFormCard(
                                  title: 'Informasi Administrasi',
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildFormDropdown(
                                              label: 'Cabang',
                                              value: selectedCabang,
                                              items: {
                                                ...(_cabangs.isEmpty
                                                    ? [selectedCabang]
                                                    : _cabangs.map((c) => c.namaCabang)),
                                                if (_cabangs.isNotEmpty && !_cabangs.any((c) => c.namaCabang == selectedCabang))
                                                  selectedCabang
                                              }.toList(),
                                              onChanged: (v) => setModalState(() => selectedCabang = v!),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _buildFormDropdown(
                                              label: 'CS Penginput',
                                              value: csName,
                                              items: {
                                                ...(availableKaryawans.isEmpty
                                                    ? [csName]
                                                    : availableKaryawans.map((k) => k.nama)),
                                                if (availableKaryawans.isNotEmpty && !availableKaryawans.any((k) => k.nama == csName))
                                                  csName
                                              }.toList(),
                                              onChanged: (v) => setModalState(() => csName = v!),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      _buildFormReadOnlyField(
                                        label: 'Tanggal & Waktu Input Order',
                                        value: DateFormat('MM/dd/yyyy hh:mm a').format(order.tanggalInput),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Card 2: Pelanggan (Persis Screenshot 1)
                                _buildFormCard(
                                  title: 'Pelanggan',
                                  child: _buildFormDropdown(
                                    label: 'Pelanggan',
                                    value: currentCustomerVal,
                                    items: {
                                      ...(availableCustomers.isEmpty
                                          ? [currentCustomerVal]
                                          : availableCustomers.map((c) => '${c.name} - ${c.phone}')),
                                      if (availableCustomers.isNotEmpty && !availableCustomers.any((c) => '${c.name} - ${c.phone}' == currentCustomerVal))
                                        currentCustomerVal
                                    }.toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setModalState(() {
                                          final parts = v.split(' - ');
                                          if (parts.isNotEmpty) order.customer.name = parts[0];
                                          if (parts.length > 1) order.customer.phone = parts[1];
                                          currentCustomerVal = v;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Card 3: Status Administratif (Persis Screenshot 1)
                                _buildFormCard(
                                  title: 'Status Administratif',
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _buildFormDropdown(
                                          label: 'Status Pengerjaan',
                                          value: statusPengerjaan,
                                          items: {
                                            'Draft',
                                            'Assigned (Ditugaskan)',
                                            'In Progress (Dikerjakan)',
                                            'Finished by Cleaner',
                                            'Waiting Payment Approval',
                                            'Waiting Cancel Approval',
                                            'Completed (Selesai)',
                                            'Cancelled (Batal)',
                                            statusPengerjaan
                                          }.toList(),
                                          onChanged: (v) => setModalState(() => statusPengerjaan = v!),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildFormDropdown(
                                          label: 'Status Pembayaran',
                                          value: statusPembayaran,
                                          items: {
                                            'Belum Dibayar',
                                            'Pending (Menunggu Persetujuan)',
                                            'Approved (Disetujui)',
                                            'Rejected (Ditolak)',
                                            'Cancelled (Batal)',
                                            statusPembayaran
                                          }.toList(),
                                          onChanged: (v) => setModalState(() => statusPembayaran = v!),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildFormDropdown(
                                          label: 'Status Bonus',
                                          value: statusBonus,
                                          items: {
                                            'Pending',
                                            'Input',
                                            'Selesai',
                                            'Cancelled (Batal)',
                                            statusBonus
                                          }.toList(),
                                          onChanged: (v) => setModalState(() => statusBonus = v!),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Card 4: Penugasan Cleaner (Persis Screenshot 2)
                                _buildFormCard(
                                  title: 'Penugasan Cleaner',
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pilih cleaner yang ditugaskan untuk pesanan ini pada cabang terpilih.',
                                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: {
                                          ...(availableCleaners.isEmpty
                                              ? order.cleaners.map((c) => c.name).toList()
                                              : availableCleaners.map((k) => k.nama).toList())
                                        }.map((cleanerName) {
                                  final isSelected = order.cleaners.any((c) => c.name == cleanerName);
                                  return FilterChip(
                                    selected: isSelected,
                                    label: Text(cleanerName, style: GoogleFonts.inter(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                    selectedColor: AppColors.primary.withOpacity(0.2),
                                    onSelected: (sel) {
                                      setModalState(() {
                                        if (sel) {
                                          order.cleaners.add(OrderCleaner(id: '1', pesananCleanerId: '1', name: cleanerName, rating: 5.0, statusPengerjaan: CleanerWorkStatus.finished, bonuses: []));
                                        } else {
                                          order.cleaners.removeWhere((c) => c.name == cleanerName);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Card 5: Informasi Order (Persis Screenshot 2)
                        _buildFormCard(
                          title: 'Informasi Order',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Chat dari', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: ['Organik', 'Ads', 'Lama'].map((opt) {
                                            final isSel = (opt.toLowerCase() == 'organik' && order.chatDari == ChatSource.organik) ||
                                                (opt.toLowerCase() == 'ads' && order.chatDari == ChatSource.ads) ||
                                                (opt.toLowerCase() == 'lama' && order.chatDari != ChatSource.organik && order.chatDari != ChatSource.ads);
                                            return Expanded(
                                              child: InkWell(
                                                onTap: () => setModalState(() {
                                                  if (opt.toLowerCase() == 'organik') order.chatDari = ChatSource.organik;
                                                  else if (opt.toLowerCase() == 'ads') order.chatDari = ChatSource.ads;
                                                }),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                  margin: const EdgeInsets.only(right: 4),
                                                  decoration: BoxDecoration(
                                                    color: isSel ? AppColors.primary : Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Center(
                                                    child: Text(opt, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: isSel ? Colors.white : AppColors.textDark)),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Tipe customer', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: ['Lama', 'Baru'].map((opt) {
                                            final isSel = opt == 'Lama';
                                            return Expanded(
                                              child: InkWell(
                                                onTap: () => setModalState(() {}),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                  margin: const EdgeInsets.only(right: 4),
                                                  decoration: BoxDecoration(
                                                    color: isSel ? AppColors.primary : Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Center(
                                                    child: Text(opt, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: isSel ? Colors.white : AppColors.textDark)),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildFormReadOnlyField(
                                      label: 'Tanggal Pengerjaan',
                                      value: order.services.isNotEmpty ? order.services.first.tanggalPengerjaan : DateFormat('MM/dd/yyyy').format(DateTime.now()),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildFormReadOnlyField(
                                      label: 'Waktu Pengerjaan',
                                      value: order.services.isNotEmpty ? order.services.first.waktuPengerjaan : '07:00 PM',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: TextEditingController(text: order.notes),
                                maxLines: 2,
                                onChanged: (val) => order.notes = val,
                                decoration: InputDecoration(
                                  labelText: 'Keterangan Order',
                                  hintText: 'Catatan tambahan mengenai order...',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Card 6: Rincian Keuangan & Pembayaran (Persis Screenshot 2)
                        _buildFormCard(
                          title: 'Rincian Keuangan & Pembayaran',
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildFormDropdown(
                                      label: 'Metode Pembayaran',
                                      value: order.paymentMethod.isNotEmpty ? order.paymentMethod : 'Belum Dibayar (None)',
                                      items: ['Belum Dibayar (None)', 'Transfer BCA', 'Transfer Mandiri', 'Cash', 'transfer', 'qris', 'cash'],
                                      onChanged: (v) => setModalState(() => order.paymentMethod = v!),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Diskon (%)', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                        const SizedBox(height: 4),
                                        SizedBox(
                                          height: 38,
                                          child: TextField(
                                            controller: TextEditingController(text: '${order.discount ?? 0}'),
                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                            keyboardType: TextInputType.number,
                                            onChanged: (val) => order.discount = int.tryParse(val) ?? 0,
                                            decoration: InputDecoration(
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildFormDropdown(
                                      label: 'PPN (%)',
                                      value: (order.ppn ?? 0) > 0 ? 'PPN 11%' : 'Tanpa PPN (0%)',
                                      items: ['Tanpa PPN (0%)', 'PPN 11%'],
                                      onChanged: (v) => setModalState(() => order.ppn = v!.contains('11') ? 11 : 0),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildFormDropdown(
                                      label: 'PPH (%)',
                                      value: (order.pph ?? 0) > 0 ? 'PPH 2%' : 'Tanpa PPH (0%)',
                                      items: ['Tanpa PPH (0%)', 'PPH 2%'],
                                      onChanged: (v) => setModalState(() => order.pph = v!.contains('2') ? 2 : 0),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Card 7: Detail Layanan (Persis Screenshot 5)
                        _buildFormCard(
                          title: 'Detail Layanan',
                          action: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                final defaultLayananName = availableLayanans.isNotEmpty ? availableLayanans.first.namaLayanan : 'General Cleaning';
                                order.services.add(ServiceItem(
                                  name: defaultLayananName,
                                  qty: '1',
                                  price: 50000,
                                ));
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              minimumSize: const Size(0, 26),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: Text('Tambah Baris', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textDark)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...order.services.map((svc) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Container(
                                          height: 32,
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.shade300),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: svc.name,
                                              isExpanded: true,
                                              icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textMuted),
                                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDark),
                                              items: {
                                                ...(availableLayanans.isEmpty
                                                    ? [svc.name]
                                                    : availableLayanans.map((l) => l.namaLayanan)),
                                                if (availableLayanans.isNotEmpty && !availableLayanans.any((l) => l.namaLayanan == svc.name))
                                                  svc.name
                                              }.map((name) => DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis))).toList(),
                                              onChanged: (v) {
                                                if (v != null) {
                                                  setModalState(() => svc.name = v);
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: SizedBox(
                                          height: 32,
                                          child: TextField(
                                            controller: TextEditingController(text: '${svc.qty}'),
                                            style: GoogleFonts.inter(fontSize: 11),
                                            keyboardType: TextInputType.number,
                                            onChanged: (val) => svc.qty = val,
                                            decoration: InputDecoration(
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
                                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
                                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.primary)),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: SizedBox(
                                          height: 32,
                                          child: TextField(
                                            controller: TextEditingController(text: NumberFormat('#,###', 'id_ID').format(svc.price)),
                                            style: GoogleFonts.inter(fontSize: 11),
                                            keyboardType: TextInputType.number,
                                            onChanged: (val) {
                                              final parsed = int.tryParse(val.replaceAll('.', '').replaceAll(',', '')) ?? 0;
                                              svc.price = parsed;
                                            },
                                            decoration: InputDecoration(
                                              prefixText: 'Rp ',
                                              prefixStyle: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
                                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
                                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.primary)),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: order.services.length <= 1
                                            ? null
                                            : () => setModalState(() => order.services.remove(svc)),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Text(
                                            'Hapus',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: order.services.length <= 1 ? Colors.grey : Colors.red.shade400,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Card 8: Rincian Bonus Cleaner (Persis Screenshot 3)
                        _buildFormCard(
                          title: 'Rincian Bonus Cleaner',
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                            child: Text(
                              order.cleaners.isEmpty ? 'Belum ada cleaner yang ditugaskan.' : 'Bonus teralokasikan untuk ${order.cleaners.length} cleaner.',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Card 9: Foto Pengerjaan Cleaner (Persis Screenshot 3)
                        _buildFormCard(
                          title: 'Foto Pengerjaan Cleaner',
                          action: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Text(
                              'Total ${order.cleaners.fold(0, (sum, c) => sum + c.fotosStart.length + c.fotosFinish.length)} Foto',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (order.cleaners.isEmpty || order.cleaners.every((c) => c.fotosStart.isEmpty && c.fotosFinish.isEmpty))
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.image_outlined, size: 48, color: AppColors.textMuted),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Belum ada foto pengerjaan',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Cleaner wajib mengunggah foto minimal 2 saat mulai dan 2 saat selesai pengerjaan melalui aplikasi mobile.',
                                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ...order.cleaners.map((c) => _buildCleanerPhotos(c)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons: Batal & Simpan Seluruh Perubahan (Persis Screenshot 3)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('Batal', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    order.customer.name = customerNameCtrl.text.trim();
                                    order.customer.phone = customerPhoneCtrl.text.trim();
                                    order.customer.area = selectedCabang;
                                    order.createdByName = csName;
                                    order.statusPengerjaan = statusPengerjaan;
                                    order.statusBonus = statusBonus;

                                    if (statusPembayaran == 'Disetujui') {
                                      order.paymentStatus = 'approved';
                                    } else if (statusPembayaran == 'Menunggu Approval') {
                                      order.paymentStatus = 'pending';
                                    } else if (statusPembayaran == 'Ditolak') {
                                      order.paymentStatus = 'rejected';
                                    }

                                    if (liveStatusUtama == 'Done') {
                                      order.status = OrderStatus.completed;
                                    } else if (liveStatusUtama == 'Dibatalkan') {
                                      order.status = OrderStatus.cancelled;
                                    } else if (liveStatusUtama == 'Draft') {
                                      order.status = OrderStatus.draft;
                                    } else {
                                      order.status = OrderStatus.waitingPaymentApproval;
                                    }
                                  });
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Perubahan order berhasil disimpan oleh Finance!'),
                                      backgroundColor: Color(0xFF059669),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('Simpan Seluruh Perubahan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormCard({required String title, Widget? action, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildFormDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final cleanValue = items.contains(value) ? value : items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: cleanValue,
              isExpanded: true,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600),
              items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormReadOnlyField({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(value, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

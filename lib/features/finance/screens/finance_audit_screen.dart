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
import '../../../core/widgets/app_confirmation_dialog.dart';
import '../services/finance_service.dart';
class FinanceAuditScreen extends StatefulWidget {
  const FinanceAuditScreen({super.key});

  @override
  State<FinanceAuditScreen> createState() => _FinanceAuditScreenState();
}

class _FinanceAuditScreenState extends State<FinanceAuditScreen> {
  final OrderService _orderService = OrderService();
  final HrdService _hrdService = HrdService();
  final FinanceService _financeService = FinanceService();

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
  String? _selectedStatusPembayaran; // 'Disetujui', 'Ditolak', 'Pending', 'Belum Dibayar'

  // Pagination limits matching Absensi/Audit design
  int _limitAuditPending = 5;
  int _limitAuditDone = 5;
  int _limitApproveEdit = 5;
  int _limitEditOrderBebas = 5;
  int _limitTotalPesanan = 10;

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
                    else if (_auditTab == 'total-pesanan')
                      _buildTotalPesananContent()
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
                      color: Colors.white.withValues(alpha: 0.85),
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
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
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
                  color: color.withValues(alpha: 0.1),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
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
                                backgroundColor: Colors.black.withValues(alpha: 0.5),
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

  // --- Main Audit Sub-Tabs Bar (2 Baris Rapi Tanpa Geser ke Kanan) ---
  Widget _buildAuditTabBar() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Baris 1: 3 Tab Utama
          Row(
            children: [
              Expanded(child: _buildAuditTabButton('Audit Order', 'audit-order')),
              const SizedBox(width: 4),
              Expanded(child: _buildAuditTabButton('Approve Edit', 'approve-edit')),
              const SizedBox(width: 4),
              Expanded(child: _buildAuditTabButton('Hasil Audit', 'hasil-audit')),
            ],
          ),
          const SizedBox(height: 5),
          // Baris 2: Edit Order & Total Pesanan
          Row(
            children: [
              Expanded(child: _buildAuditTabButton('Edit Order', 'edit-order')),
              const SizedBox(width: 4),
              Expanded(child: _buildAuditTabButton('Total Pesanan', 'total-pesanan')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTabButton(String label, String tabKey) {
    final bool isActive = _auditTab == tabKey;
    return GestureDetector(
      onTap: () => setState(() => _auditTab = tabKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.grey.shade200,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 11.5,
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
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
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

    // Omzet = sum pembayaran.total_akhir where approved_at is today
    // (matches web: Pemasukan::whereDate('tanggal_pemasukan', now())->sum('nominal'))
    // Pemasukan is created with tanggal_pemasukan = now() at the moment finance clicks Approve
    final omzetToday = _orders
        .where((o) {
          final approvedAt = o.pembayaran?.approvedAt;
          if (approvedAt == null) return false;
          if (o.pembayaran?.statusPembayaran != 'approved' && o.paymentStatus != 'approved') return false;
          return !approvedAt.isBefore(todayStart) && !approvedAt.isAfter(todayEnd);
        })
        .fold<int>(0, (sum, o) {
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
        const SizedBox(height: 8),

        // Mode Switcher for Tables (Pending vs Done/Approved)
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
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
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Menunggu (${pendingAuditList.length})',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: _approvalTableMode == 'pending' ? FontWeight.bold : FontWeight.w600,
                              color: _approvalTableMode == 'pending' ? Colors.white : AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Selesai (${approvedDoneList.length})',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: _approvalTableMode == 'done' ? FontWeight.bold : FontWeight.w600,
                              color: _approvalTableMode == 'done' ? Colors.white : AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
        const SizedBox(height: 8),

        // Search & Filter Bar
        _buildProMaxSearchAndFilterBar(),
        const SizedBox(height: 4),

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
        border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
            VerticalDivider(width: 14, thickness: 1, color: Colors.grey.withValues(alpha: 0.15)),

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
            VerticalDivider(width: 14, thickness: 1, color: Colors.grey.withValues(alpha: 0.15)),

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
        border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
            VerticalDivider(width: 20, thickness: 1, color: Colors.grey.withValues(alpha: 0.15)),
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
        (showStatusFilter && _selectedStatusUtama != null ? 1 : 0) +
        (_selectedStatusPembayaran != null ? 1 : 0);

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
                color: _searchQuery.isNotEmpty ? const Color(0xFF3B82F6) : Colors.grey.withValues(alpha: 0.25),
                width: _searchQuery.isNotEmpty ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _searchQuery.isNotEmpty ? const Color(0xFF3B82F6).withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.03),
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
                color: activeFilterCount > 0 ? Colors.transparent : Colors.grey.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                if (activeFilterCount > 0)
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
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
                      color: Colors.white.withValues(alpha: 0.25),
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
                  const SizedBox(height: 20),

                  // 3. Status Pembayaran
                  Text('Status Pembayaran', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Semua'),
                        selected: _selectedStatusPembayaran == null,
                        onSelected: (val) {
                          setModalState(() => _selectedStatusPembayaran = null);
                          setState(() => _selectedStatusPembayaran = null);
                        },
                        selectedColor: const Color(0xFFEFF6FF),
                        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: _selectedStatusPembayaran == null ? FontWeight.bold : FontWeight.w500, color: _selectedStatusPembayaran == null ? const Color(0xFF1D4ED8) : AppColors.textDark),
                        side: BorderSide(color: _selectedStatusPembayaran == null ? const Color(0xFF3B82F6) : Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        showCheckmark: false,
                      ),
                      ...['Disetujui', 'Ditolak', 'Pending', 'Belum Dibayar'].map((st) {
                        final isSel = _selectedStatusPembayaran == st;
                        Color chipColor;
                        Color chipBg;
                        switch (st) {
                          case 'Disetujui':
                            chipColor = const Color(0xFF059669);
                            chipBg = const Color(0xFFECFDF5);
                            break;
                          case 'Ditolak':
                            chipColor = const Color(0xFFDC2626);
                            chipBg = const Color(0xFFFEF2F2);
                            break;
                          case 'Pending':
                            chipColor = const Color(0xFFD97706);
                            chipBg = const Color(0xFFFFFBEB);
                            break;
                          default:
                            chipColor = const Color(0xFF6B7280);
                            chipBg = const Color(0xFFF9FAFB);
                        }
                        return ChoiceChip(
                          label: Text(st),
                          selected: isSel,
                          onSelected: (val) {
                            setModalState(() => _selectedStatusPembayaran = val ? st : null);
                            setState(() => _selectedStatusPembayaran = val ? st : null);
                          },
                          selectedColor: chipBg,
                          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? chipColor : AppColors.textDark),
                          side: BorderSide(color: isSel ? chipColor : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          showCheckmark: false,
                        );
                      }),
                    ],
                  ),

                  // 4. Status Utama (for Tab 3)
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
                              _selectedStatusPembayaran = null;
                              if (showStatusFilter) _selectedStatusUtama = null;
                            });
                            setState(() {
                              _selectedCabangName = null;
                              _periodFilter = 'semua';
                              _customRange = null;
                              _filterStart = null;
                              _filterEnd = null;
                              _selectedStatusPembayaran = null;
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
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                  color: color.withValues(alpha: 0.12),
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
            style: GoogleFonts.inter(fontSize: 10, color: color.withValues(alpha: 0.85)),
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
      if (_selectedStatusPembayaran != null) {
        if (o.statusPembayaranLabel != _selectedStatusPembayaran) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchCust = o.customer.name.toLowerCase().contains(q);
        final matchId = o.nomorPesanan.toLowerCase().contains(q);
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
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
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
        ...displayedList.map((order) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildProMaxOrderCard(order, isPending: true),
        )),
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
      if (_selectedStatusPembayaran != null) {
        if (o.statusPembayaranLabel != _selectedStatusPembayaran) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchCust = o.customer.name.toLowerCase().contains(q);
        final matchId = o.nomorPesanan.toLowerCase().contains(q);
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
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
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
        ...displayedList.map((order) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildProMaxOrderCard(order, isPending: false),
        )),
        _buildLoadMoreButton(
          currentCount: displayedList.length,
          totalCount: totalCount,
          onTap: () => setState(() => _limitAuditDone += 5),
        ),
      ],
    );
  }

  Widget _buildProMaxOrderCard(OrderModel order, {bool isPending = false, Widget? customAction}) {
    final orderNo = order.nomorPesanan.isNotEmpty ? order.nomorPesanan : 'Order #${order.id}';

    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
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
                color: order.statusUtamaLabel == 'Dibatalkan'
                    ? const Color(0xFFFEE2E2).withValues(alpha: 0.4)
                    : order.statusUtamaLabel == 'Done'
                        ? const Color(0xFFF0FDF4).withValues(alpha: 0.5)
                        : const Color(0xFFFEF3C7).withValues(alpha: 0.4),
                border: Border(
                  bottom: BorderSide(
                    color: order.statusUtamaLabel == 'Dibatalkan'
                        ? const Color(0xFFFCA5A5).withValues(alpha: 0.5)
                        : order.statusUtamaLabel == 'Done'
                            ? const Color(0xFFBBF7D0).withValues(alpha: 0.5)
                            : const Color(0xFFFDE68A).withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        order.statusUtamaLabel == 'Dibatalkan'
                            ? Icons.cancel_rounded
                            : order.statusUtamaLabel == 'Done'
                                ? Icons.check_circle_rounded
                                : Icons.pending_actions_rounded,
                        size: 15,
                        color: order.statusUtamaLabel == 'Dibatalkan'
                            ? const Color(0xFFDC2626)
                            : order.statusUtamaLabel == 'Done'
                                ? const Color(0xFF059669)
                                : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        orderNo,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: order.statusUtamaLabel == 'Dibatalkan'
                              ? const Color(0xFF991B1B)
                              : order.statusUtamaLabel == 'Done'
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: order.statusUtamaLabel == 'Done'
                          ? const Color(0xFFDCFCE7)
                          : order.statusUtamaLabel == 'Dibatalkan'
                              ? const Color(0xFFFEE2E2)
                              : order.statusUtamaLabel == 'Draft'
                                  ? Colors.grey.shade200
                                  : isPending ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order.statusUtamaLabel.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: order.statusUtamaLabel == 'Done'
                            ? const Color(0xFF16A34A)
                            : order.statusUtamaLabel == 'Dibatalkan'
                                ? const Color(0xFFDC2626)
                                : order.statusUtamaLabel == 'Draft'
                                    ? Colors.grey.shade700
                                    : isPending ? const Color(0xFFD97706) : const Color(0xFF2563EB),
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
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
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
                  if (customAction != null)
                    customAction
                  else if (isPending) ...[
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
                              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
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
                            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
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
  // --- Modal Detail Bottom Sheet UI UX Pro Max ---
  void _showDetailModal(OrderModel order) {
    final csName = order.createdByName.isNotEmpty ? order.createdByName : 'CS';
    final int totalBonus = order.cleaners.fold(0, (sum, c) => sum + c.totalBonus);
    final hasProof = order.paymentProof != null && order.paymentProof!.isNotEmpty;

    Color badgeBg = const Color(0xFFFEF3C7);
    Color badgeBorder = const Color(0xFFFDE68A);
    Color badgeText = const Color(0xFFD97706);
    String badgeLabel = 'Pending';

    if (order.paymentStatus.toLowerCase() == 'approved' || order.paymentStatus.toLowerCase() == 'disetujui' || order.paymentStatus.toLowerCase() == 'paid') {
      badgeBg = const Color(0xFFDCFCE7);
      badgeBorder = const Color(0xFF86EFAC);
      badgeText = const Color(0xFF15803D);
      badgeLabel = 'Pembayaran Disetujui';
    } else if (order.paymentStatus.toLowerCase() == 'rejected' || order.paymentStatus.toLowerCase() == 'ditolak') {
      badgeBg = const Color(0xFFFEE2E2);
      badgeBorder = const Color(0xFFFCA5A5);
      badgeText = const Color(0xFFB91C1C);
      badgeLabel = 'Pembayaran Ditolak';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4)),
          ],
        ),
        child: Column(
          children: [
            // Header Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Handle Bar
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Title Row with ID, Badge, and Close Button (Persis Image 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            Text(
                              order.nomorPesanan.isNotEmpty ? order.nomorPesanan : 'Order #${order.id}',
                              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: badgeBorder),
                              ),
                              child: Text(
                                badgeLabel,
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: badgeText),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textMuted),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.customer.name.toLowerCase(),
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),

                  // Blue Gradient Hero Card (TOTAL AKHIR PEMBAYARAN - Persis Image 1)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D52BA), Color(0xFF053E94)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF0D52BA).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL AKHIR PEMBAYARAN',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85), letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currencyFormat.format(order.total),
                          style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined, size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                'Metode: ${order.paymentMethod.toUpperCase()}',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('•', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              ),
                              const Icon(Icons.storefront_outlined, size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                order.customer.area.toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Scrollable Section Cards
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Informasi Pelanggan Card (Persis Image 1)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Informasi Pelanggan', icon: Icons.person_rounded, accentColor: const Color(0xFF0D52BA)),
                          const SizedBox(height: 6),
                          _buildDetailRow('Nama', order.customer.name),
                          _buildDetailRow('No. WhatsApp', order.customer.phone),
                          _buildDetailRow('Alamat', order.customer.address),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Informasi Pesanan Card (Persis Image 1)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Informasi Pesanan', icon: Icons.assignment_rounded, accentColor: const Color(0xFF0D52BA)),
                          const SizedBox(height: 6),
                          _buildDetailRow('Cabang / Area', order.customer.area),
                          _buildDetailRow('CS Pembuat', csName),
                          _buildDetailRow('Tanggal Jadwal', _formatTanggal(order.schedule)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Rincian Layanan Card (Persis Image 1)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Rincian Layanan', icon: Icons.build_rounded, accentColor: const Color(0xFF0D52BA)),
                          const SizedBox(height: 8),
                          if (order.services.isEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Layanan Utama', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark)),
                                Text(_currencyFormat.format(order.total), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                              ],
                            )
                          else
                            ...order.services.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                        child: Text('x${s.qty}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(s.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                    ],
                                  ),
                                  Text(_currencyFormat.format(s.price * (int.tryParse(s.qty) ?? 1)), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                                ],
                              ),
                            )),
                          const Divider(height: 20, color: Color(0xFFE2E8F0), thickness: 1.5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal Pesanan', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                              Text(_currencyFormat.format(order.subtotal), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (order.ppn != null && order.ppn! > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('PPN (${order.ppn}%)', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                                  Text('+${_currencyFormat.format(order.subtotal * (order.ppn! / 100))}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                                ],
                              ),
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Akhir', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                              Text(_currencyFormat.format(order.total), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF059669))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Cleaner & Bonus Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Cleaner & Bonus', icon: Icons.cleaning_services_rounded, accentColor: const Color(0xFF0D52BA)),
                          const SizedBox(height: 8),
                          if (order.cleaners.isEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Belum ada cleaner ditugaskan', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                                Text('Rp 0', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                              ],
                            )
                          else
                            ...order.cleaners.map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(c.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                  Text(_currencyFormat.format(c.totalBonus), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                ],
                              ),
                            )),
                          const Divider(height: 18, color: Color(0xFFE2E8F0), thickness: 1.5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Keseluruhan Bonus', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                              Text(_currencyFormat.format(totalBonus), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5. Bukti Transfer Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Bukti transfer', icon: Icons.receipt_long_rounded, accentColor: const Color(0xFF0D52BA)),
                          const SizedBox(height: 6),
                          hasProof
                              ? OutlinedButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => Dialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: _buildSafeImage(order.paymentProof!),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF0D52BA)),
                                  label: Text('Buka bukti foto', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0D52BA))),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF0D52BA)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                )
                              : Text('Tidak ada bukti transfer.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 6. Foto Pengerjaan Cleaner Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionHeader('Foto Pengerjaan Cleaner', icon: Icons.photo_camera_rounded, accentColor: const Color(0xFF0D52BA)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: Text(
                                  'Total ${order.cleaners.fold(0, (sum, c) => sum + c.fotosStart.length + c.fotosFinish.length)} Foto',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (order.cleaners.isEmpty || order.cleaners.every((c) => c.fotosStart.isEmpty && c.fotosFinish.isEmpty))
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.photo_library_outlined, size: 36, color: Colors.grey.shade300),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Belum ada foto pengerjaan',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Cleaner wajib mengunggah foto saat mulai dan selesai pengerjaan melalui aplikasi mobile.',
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
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Sticky Bottom Action Bar (Persis Image 1)
            if (_approvalTableMode == 'pending')
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, -4)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showRejectModal(order);
                        },
                        icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFDC2626)),
                        label: Text('Tolak', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showApproveConfirm(order);
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                        label: Text('Approve Pembayaran', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                          shadowColor: const Color(0xFF059669).withValues(alpha: 0.4),
                        ),
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

  Widget _buildSectionHeader(String title, {IconData? icon, Color? accentColor}) {
    final color = accentColor ?? const Color(0xFF0D52BA);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          if (icon != null) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String val, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(
              val,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  // --- Confirm Approve Dialog (Modern & Mobile Friendly) ---
  void _showApproveConfirm(OrderModel order) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: Colors.white,
        elevation: 10,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon Badge
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF86EFAC), width: 2),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 30),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Konfirmasi Approval',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),

              // Subtitle / Prompt
              Text(
                'Apakah Anda yakin ingin menyetujui pembayaran untuk pesanan ini?',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Highlighted Order Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              order.nomorPesanan.isNotEmpty ? order.nomorPesanan : 'Order #${order.id}',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            order.statusUtamaLabel,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Pelanggan:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        Text(
                          order.customer.name,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Nominal:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        Text(
                          _currencyFormat.format(order.total),
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF059669)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Actions Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.white,
                      ),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                        );
                        try {
                          final int pId = order.pembayaran?.id ??
                              int.tryParse(order.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                          if (pId == 0) throw Exception('Data pembayaran tidak ditemukan');
                          await _financeService.approvePembayaran(pId, 'approved');
                          if (mounted) Navigator.pop(context);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Pembayaran berhasil disetujui!'), backgroundColor: Color(0xFF059669)),
                            );
                            _fetchData();
                          }
                        } catch (e) {
                          if (mounted) Navigator.pop(context);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                      label: Text(
                        'Ya, Approve',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        shadowColor: const Color(0xFF059669).withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Reject Modal Dialog (Modern & Mobile Friendly) ---
  void _showRejectModal(OrderModel order) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: Colors.white,
        elevation: 10,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon Badge
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFCA5A5), width: 2),
                ),
                child: const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 30),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Tolak Pembayaran',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),

              // Subtitle / Prompt
              Text(
                'Pesanan akan ditolak dan status pembayaran dikembalikan.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // Highlighted Order Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          order.nomorPesanan.isNotEmpty ? order.nomorPesanan : 'Order #${order.id}',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    Text(
                      _currencyFormat.format(order.total),
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Reason Input
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Alasan Penolakan:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Tuliskan alasan penolakan pembayaran...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400),
                  contentPadding: const EdgeInsets.all(12),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
                ),
              ),
              const SizedBox(height: 20),

              // Actions Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.white,
                      ),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final reason = reasonCtrl.text.trim();
                        if (reason.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Alasan penolakan wajib diisi!'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        Navigator.pop(dialogContext);
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                        );
                        try {
                          final int pId = order.pembayaran?.id ??
                              int.tryParse(order.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                          if (pId == 0) throw Exception('Data pembayaran tidak ditemukan');
                          await _financeService.approvePembayaran(pId, 'rejected', alasan: reason);
                          if (mounted) Navigator.pop(context);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Pembayaran berhasil ditolak.'), backgroundColor: Color(0xFFDC2626)),
                            );
                            _fetchData();
                          }
                        } catch (e) {
                          if (mounted) Navigator.pop(context);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                      label: Text(
                        'Tolak',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        shadowColor: const Color(0xFFDC2626).withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        const SizedBox(height: 4),

        _buildApproveEditList(editRequestsList),
      ],
    );
  }

  Widget _buildApproveEditList(List<OrderModel> editList) {
    final filtered = editList.where((o) {
      if (!_matchesDateFilter(o.waktuPengajuanEdit ?? o.tanggalInput)) return false;
      if (_selectedCabangName != null) {
        final matchCabang = o.customer.area.toUpperCase().contains(_selectedCabangName!) ||
            (_cabangs.any((c) => c.namaCabang.toUpperCase() == _selectedCabangName && o.cabangId == c.id.toString()));
        if (!matchCabang) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchCust = o.customer.name.toLowerCase().contains(q);
        final matchId = o.nomorPesanan.toLowerCase().contains(q);
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
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
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
        ...displayedList.map((order) {
          final csName = order.createdByName.isNotEmpty ? order.createdByName : 'CS';
          final alasanStr = order.alasanPengajuanEdit.isNotEmpty
              ? order.alasanPengajuanEdit
              : 'Pengajuan edit layanan';

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildProMaxOrderCard(
              order,
              customAction: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Alasan Banner
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
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showEditDetailModal(order, csName, alasanStr),
                          icon: const Icon(Icons.visibility_rounded, size: 14),
                          label: const Text('Detail', style: TextStyle(fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: GoogleFonts.inter(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showApproveEditConfirm(order),
                          icon: const Icon(Icons.check_rounded, size: 14),
                          label: const Text('Setujui', style: TextStyle(fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: GoogleFonts.inter(fontSize: 12),
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
            ),
          );
        }),
        _buildLoadMoreButton(
          currentCount: displayedList.length,
          totalCount: totalCount,
          onTap: () => setState(() => _limitApproveEdit += 5),
        ),
      ],
    );
  }

  // --- Modal Detail Pengajuan Edit Bottom Sheet (Matching Screenshot 2) ---
  // --- Modal Detail Pengajuan Edit Bottom Sheet UI UX Pro Max ---
  void _showEditDetailModal(OrderModel order, String csName, String alasanStr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4)),
          ],
        ),
        child: Column(
          children: [
            // Header Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Handle Bar
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Title Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            Text(
                              order.nomorPesanan.isNotEmpty ? order.nomorPesanan : 'Order #${order.id}',
                              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Text(
                                'Pengajuan Edit',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textMuted),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Diajukan oleh CS: $csName',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),

                  // Amber Gradient Hero Card (ALASAN PENGAJUAN EDIT)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD97706), Color(0xFFB45309)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFD97706).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              'ALASAN PENGAJUAN EDIT',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9), letterSpacing: 0.8),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          alasanStr.isNotEmpty ? alasanStr : 'Tidak ada keterangan alasan.',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, height: 1.3),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_outline_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                'CS: $csName',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('•', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              ),
                              const Icon(Icons.storefront_outlined, size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                order.customer.area.toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Scrollable Section Cards
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Informasi Pelanggan Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Informasi Pelanggan', icon: Icons.person_rounded, accentColor: const Color(0xFFD97706)),
                          const SizedBox(height: 6),
                          _buildDetailRow('Nama', order.customer.name),
                          _buildDetailRow('No. WhatsApp', order.customer.phone),
                          _buildDetailRow('Alamat', order.customer.address),
                          _buildDetailRow('Jadwal', _formatTanggal(order.schedule)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Rincian Layanan Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Rincian Layanan & Tagihan', icon: Icons.build_rounded, accentColor: const Color(0xFFD97706)),
                          const SizedBox(height: 8),
                          ...order.services.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                      child: Text('x${s.qty}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(s.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                  ],
                                ),
                                Text(_currencyFormat.format(s.price * (int.tryParse(s.qty) ?? 1)), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                              ],
                            ),
                          )),
                          const Divider(height: 20, color: Color(0xFFE2E8F0), thickness: 1.5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal Pesanan', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                              Text(_currencyFormat.format(order.subtotal), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Akhir', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                              Text(_currencyFormat.format(order.total), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF059669))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Foto Pengerjaan Cleaner Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionHeader('Foto Pengerjaan Cleaner', icon: Icons.photo_camera_rounded, accentColor: const Color(0xFFD97706)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: Text(
                                  'Total ${order.cleaners.fold(0, (sum, c) => sum + c.fotosStart.length + c.fotosFinish.length)} Foto',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (order.cleaners.isEmpty || order.cleaners.every((c) => c.fotosStart.isEmpty && c.fotosFinish.isEmpty))
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.photo_library_outlined, size: 36, color: Colors.grey.shade300),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Belum ada foto pengerjaan',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Cleaner wajib mengunggah foto pengerjaan melalui aplikasi mobile.',
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
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Sticky Bottom Action Bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, -4)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showRejectEditModal(order);
                      },
                      icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFDC2626)),
                      label: Text('Tolak', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showApproveEditConfirm(order);
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                      label: Text('Setujui Pengajuan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                        shadowColor: const Color(0xFF059669).withValues(alpha: 0.4),
                      ),
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


  void _showApproveEditConfirm(OrderModel order) {
    bool isSubmitting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: Colors.white,
          elevation: 10,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Icon Badge
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFC7D2FE), width: 2),
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: Color(0xFF4F46E5), size: 32),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Setujui Pengajuan Edit',
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),

                // Subtitle
                Text(
                  'Status pesanan akan dikembalikan agar CS dapat mengedit rincian pesanan ulang.',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Order Info Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text(
                                order.nomorPesanan.isNotEmpty ? order.nomorPesanan : 'Order #${order.id}',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          Text(
                            _currencyFormat.format(order.total),
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                          ),
                        ],
                      ),
                      if (order.alasanPengajuanEdit.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            'Alasan: ${order.alasanPengajuanEdit}',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB45309)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Colors.white,
                        ),
                        child: Text(
                          'Batal',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setDialogState(() => isSubmitting = true);
                                try {
                                  final identifier =
                                      order.pengajuanEditId?.toString() ?? order.id;
                                  await _financeService.approvePengajuanEdit(
                                    identifier,
                                    'approved',
                                  );
                                  if (!mounted) return;
                                  Navigator.pop(dialogCtx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Pengajuan edit berhasil disetujui! Status pesanan dikembalikan agar CS dapat mengedit ulang.',
                                      ),
                                      backgroundColor: Color(0xFF059669),
                                    ),
                                  );
                                  _fetchData();
                                } catch (e) {
                                  setDialogState(() => isSubmitting = false);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.toString().replaceAll('Exception: ', ''),
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                        label: Text(
                          isSubmitting ? 'Memproses...' : 'Ya, Setujui',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          shadowColor: const Color(0xFF059669).withValues(alpha: 0.3),
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
    );
  }

  void _showRejectEditModal(OrderModel order) {
    final reasonCtrl = TextEditingController();
    bool isSubmitting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: Colors.white,
          elevation: 10,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Icon Badge
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFCA5A5), width: 2),
                  ),
                  child: const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 30),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Tolak Pengajuan Edit',
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),

                // Subtitle
                Text(
                  'Pengajuan edit dari CS akan ditolak.',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),

                // Reason Input
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Alasan Penolakan:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  enabled: !isSubmitting,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Tuliskan alasan penolakan...',
                    hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400),
                    contentPadding: const EdgeInsets.all(12),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Colors.white,
                        ),
                        child: Text(
                          'Batal',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final reason = reasonCtrl.text.trim();
                                if (reason.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Alasan penolakan wajib diisi!'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                setDialogState(() => isSubmitting = true);
                                try {
                                  final identifier =
                                      order.pengajuanEditId?.toString() ?? order.id;
                                  await _financeService.approvePengajuanEdit(
                                    identifier,
                                    'rejected',
                                    alasan: reason,
                                  );
                                  if (!mounted) return;
                                  Navigator.pop(dialogCtx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Pengajuan edit berhasil ditolak.'),
                                      backgroundColor: Color(0xFFDC2626),
                                    ),
                                  );
                                  _fetchData();
                                } catch (e) {
                                  setDialogState(() => isSubmitting = false);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.toString().replaceAll('Exception: ', ''),
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                        label: Text(
                          isSubmitting ? 'Memproses...' : 'Tolak',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          shadowColor: const Color(0xFFDC2626).withValues(alpha: 0.3),
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
        const SizedBox(height: 4),

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
        final matchId = o.nomorPesanan.toLowerCase().contains(q);
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
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
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
        ...displayedList.map((order) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildProMaxOrderCard(
            order,
            customAction: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _openFinanceEditOrderBebasModal(order),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Edit Bebas'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F52BA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                    textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _confirmDeleteOrder(order),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                  label: Text('Hapus', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    backgroundColor: const Color(0xFFFEF2F2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        )),
        _buildLoadMoreButton(
          currentCount: displayedList.length,
          totalCount: totalCount,
          onTap: () => setState(() => _limitEditOrderBebas += 5),
        ),
      ],
    );
  }

  // ===========================================================================
  // TOTAL PESANAN CONTENT (Matching Web tab=total-pesanan)
  // ===========================================================================
  Widget _buildTotalPesananContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF16A34A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Daftar semua pesanan dari seluruh cabang. Anda dapat mengedit atau menghapus pesanan.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF15803D), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildProMaxSearchAndFilterBar(showStatusFilter: true),
        const SizedBox(height: 4),
        _buildTotalPesananList(),
      ],
    );
  }

  Widget _buildTotalPesananList() {
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
        final matchId = o.nomorPesanan.toLowerCase().contains(q);
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
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            const Icon(Icons.inventory_2_outlined, size: 36, color: AppColors.textMuted),
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
    final displayedList = filtered.take(_limitTotalPesanan).toList();

    return Column(
      children: [
        ...displayedList.map((order) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildProMaxOrderCard(
            order,
            customAction: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _openFinanceEditOrderBebasModal(order),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F52BA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                    textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _confirmDeleteOrder(order),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                  label: Text('Hapus', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    backgroundColor: const Color(0xFFFEF2F2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        )),
        _buildLoadMoreButton(
          currentCount: displayedList.length,
          totalCount: totalCount,
          onTap: () => setState(() => _limitTotalPesanan += 10),
        ),
      ],
    );
  }

  // --- Confirm Delete Order Action ---
  Future<void> _confirmDeleteOrder(OrderModel order) async {
    final orderDisplay = order.nomorPesanan.isNotEmpty ? order.nomorPesanan : '#${order.id}';
    final confirmed = await AppConfirmationDialog.show(
      context,
      title: 'Hapus Pesanan?',
      message: 'Apakah Anda yakin ingin menghapus pesanan $orderDisplay (${order.customer.name}) secara permanen? Data yang dihapus tidak dapat dikembalikan.',
      type: ConfirmationDialogType.danger,
      confirmText: 'Ya, Hapus',
      cancelText: 'Batal',
      isDestructive: true,
    );

    if (confirmed != true) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text('Sedang menghapus pesanan $orderDisplay...', style: GoogleFonts.inter(color: Colors.white)),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      await _orderService.deleteOrder(order.id);
      if (!mounted) return;
      setState(() {
        _orders.removeWhere((o) => o.id == order.id);
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pesanan $orderDisplay berhasil dihapus.', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', ''), style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

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
        const SizedBox(height: 10),
        _buildProMaxSearchAndFilterBar(),
        const SizedBox(height: 4),

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
        final matchId = o.nomorPesanan.toLowerCase().contains(q);
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
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
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
        ...filtered.map((order) {
          final csName = order.createdByName.isNotEmpty ? order.createdByName : 'Joko';
          final dateStr = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(order.waktuBatal ?? order.tanggalInput);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildProMaxOrderCard(
              order,
              customAction: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showCancelDetailModal(order, csName, dateStr),
                    icon: const Icon(Icons.description_outlined, size: 14),
                    label: const Text('Lihat Rincian Audit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      foregroundColor: AppColors.primary,
                      textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- Modal Detail Pembatalan Bottom Sheet UI UX Pro Max ---
  void _showCancelDetailModal(OrderModel order, String csName, String dateStr) {
    final subtotal = order.services.fold<int>(0, (sum, s) => sum + s.subtotal);
    final cancelReason = order.cancelReason?.isNotEmpty == true ? order.cancelReason! : 'Dibatalkan atas permintaan pelanggan / operasional.';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4)),
          ],
        ),
        child: Column(
          children: [
            // Header Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Handle Bar
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Title Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            Text(
                              order.nomorPesanan.isNotEmpty ? order.nomorPesanan : 'Order #${order.id}',
                              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Text(
                                'Dibatalkan',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textMuted),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pelanggan: ${order.customer.name}',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),

                  // Red/Rose Gradient Hero Card (INFORMASI PEMBATALAN)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFE11D48).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cancel_outlined, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              'ALASAN PEMBATALAN',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9), letterSpacing: 0.8),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cancelReason,
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, height: 1.3),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_outline_rounded, size: 14, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Oleh: $csName',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 14, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    dateStr,
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Scrollable Section Cards
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Informasi Pelanggan & Pesanan Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Informasi Pelanggan & Pesanan', icon: Icons.person_rounded, accentColor: const Color(0xFFE11D48)),
                          const SizedBox(height: 6),
                          _buildDetailRow('Nama', order.customer.name),
                          _buildDetailRow('No. WhatsApp', order.customer.phone),
                          _buildDetailRow('Alamat', order.customer.address),
                          _buildDetailRow('Area / Cabang', order.customer.area),
                          _buildDetailRow('CS Pembuat', csName),
                          _buildDetailRow('Jadwal', _formatTanggal(order.schedule)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Rincian Layanan Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Rincian Layanan & Tagihan', icon: Icons.receipt_long_rounded, accentColor: const Color(0xFFE11D48)),
                          const SizedBox(height: 8),
                          ...order.services.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                      child: Text('x${s.qty}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(s.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                  ],
                                ),
                                Text(_currencyFormat.format(s.price * (int.tryParse(s.qty) ?? 1)), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                              ],
                            ),
                          )),
                          const Divider(height: 20, color: Color(0xFFE2E8F0), thickness: 1.5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal Layanan', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                              Text(_currencyFormat.format(subtotal), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Status Tagihan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                              Text('Dibatalkan (Rp 0)', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Foto Pengerjaan Cleaner Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionHeader('Foto Pengerjaan Cleaner', icon: Icons.photo_camera_rounded, accentColor: const Color(0xFFE11D48)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: Text(
                                  'Total ${order.cleaners.fold(0, (sum, c) => sum + c.fotosStart.length + c.fotosFinish.length)} Foto',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (order.cleaners.isEmpty || order.cleaners.every((c) => c.fotosStart.isEmpty && c.fotosFinish.isEmpty))
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.photo_library_outlined, size: 36, color: Colors.grey.shade300),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Belum ada foto pengerjaan',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tidak ada unggahan foto untuk pesanan yang dibatalkan ini.',
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
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Sticky Bottom Action Bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, -4)),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
                  label: Text('Kembali ke Daftar Pembatalan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                    shadowColor: const Color(0xFF334155).withValues(alpha: 0.4),
                  ),
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

  // --- Modal Edit Order Bebas (Finance Full Authority - Mobile & User Friendly) ---
  void _openFinanceEditOrderBebasModal(OrderModel order) {
    String selectedCabang = order.customer.area.isNotEmpty ? order.customer.area.toUpperCase() : 'SURABAYA';
    String csName = order.createdByName.isNotEmpty ? order.createdByName : 'Joko';

    String pengerjaanDisplay(String raw) {
      final s = raw.toLowerCase().trim();
      if (s == 'completed' || s == 'selesai') return 'Completed (Selesai)';
      if (s == 'finished_by_cleaner' || s == 'selesai cleaner') return 'Finished by Cleaner';
      if (s == 'in_progress' || s == 'dikerjakan') return 'In Progress (Dikerjakan)';
      if (s == 'assigned' || s == 'ditugaskan') return 'Assigned (Ditugaskan)';
      if (s == 'draft') return 'Draft';
      if (s == 'cancelled' || s == 'dibatalkan' || s == 'batal') return 'Cancelled (Batal)';
      if (s == 'waiting_payment_approval') return 'Waiting Payment Approval';
      if (s == 'waiting_cancel_approval') return 'Waiting Cancel Approval';
      return 'Assigned (Ditugaskan)';
    }

    String statusPengerjaan = pengerjaanDisplay(order.statusPesananRaw.isNotEmpty ? order.statusPesananRaw : order.statusPengerjaanLabel);
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
          Color statusUtamaColor = const Color(0xFF2563EB);
          Color statusUtamaBg = const Color(0xFFEFF6FF);
          IconData statusUtamaIcon = Icons.sync_rounded;

          final isPengerjaanDone = statusPengerjaan == 'Completed (Selesai)' || statusPengerjaan == 'Finished by Cleaner';
          final isPembayaranApproved = statusPembayaran == 'Disetujui' || statusPembayaran == 'Approved' || statusPembayaran == 'Approved (Disetujui)';
          final isBonusSelesai = statusBonus.toLowerCase() == 'selesai';

          if (statusPengerjaan == 'Cancelled (Batal)' || statusPembayaran == 'Dibatalkan' || statusPembayaran == 'Ditolak' || statusPembayaran == 'Batal' || order.status == OrderStatus.cancelled) {
            liveStatusUtama = 'Dibatalkan';
            statusUtamaColor = const Color(0xFFDC2626);
            statusUtamaBg = const Color(0xFFFEE2E2);
            statusUtamaIcon = Icons.cancel_rounded;
          } else if (statusPengerjaan == 'Completed (Selesai)' && isPembayaranApproved && isBonusSelesai) {
            liveStatusUtama = 'Done';
            statusUtamaColor = const Color(0xFF059669);
            statusUtamaBg = const Color(0xFFDCFCE7);
            statusUtamaIcon = Icons.check_circle_rounded;
          } else if (isPengerjaanDone) {
            liveStatusUtama = 'Pending';
            statusUtamaColor = const Color(0xFFD97706);
            statusUtamaBg = const Color(0xFFFEF3C7);
            statusUtamaIcon = Icons.hourglass_top_rounded;
          } else if (statusPengerjaan == 'Draft') {
            liveStatusUtama = 'Draft';
            statusUtamaColor = const Color(0xFF64748B);
            statusUtamaBg = const Color(0xFFF1F5F9);
            statusUtamaIcon = Icons.edit_note_rounded;
          } else {
            liveStatusUtama = 'Process';
            statusUtamaColor = const Color(0xFF2563EB);
            statusUtamaBg = const Color(0xFFEFF6FF);
            statusUtamaIcon = Icons.sync_rounded;
          }

          final orderDisplayId = order.nomorPesanan.isNotEmpty ? order.nomorPesanan : 'Order #${order.id}';

          return Container(
            height: MediaQuery.of(context).size.height * 0.90,
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 25, offset: Offset(0, -5)),
              ],
            ),
            child: Column(
              children: [
                // Header Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Edit $orderDisplayId',
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFC7D2FE)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.security_rounded, size: 12, color: Color(0xFF4F46E5)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Full Authority',
                                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF475569)),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Sleek Compact Notice Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF1D4ED8).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.admin_panel_settings_rounded, size: 16, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'WEWENANG PENUH FINANCE',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Ubah data administrasi, status pengerjaan, pembayaran, rincian layanan, dan bonus pesanan secara instan.',
                                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.95), height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),

                // Scrollable Form Cards
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                // Card 1: Informasi Administrasi
                                _buildFormCard(
                                  title: 'Informasi Administrasi',
                                  icon: Icons.domain_rounded,
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildFormDropdown(
                                              label: 'Cabang',
                                              value: selectedCabang,
                                              icon: Icons.storefront_rounded,
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
                                              icon: Icons.support_agent_rounded,
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
                                        value: DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(order.tanggalInput),
                                        icon: Icons.calendar_today_rounded,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Card 2: Pelanggan
                                _buildFormCard(
                                  title: 'Pelanggan',
                                  icon: Icons.person_rounded,
                                  child: _buildFormDropdown(
                                    label: 'Pilih Data Pelanggan',
                                    value: currentCustomerVal,
                                    icon: Icons.badge_outlined,
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
                                const SizedBox(height: 12),

                                // Card 3: Status Administratif
                                _buildFormCard(
                                  title: 'Status Administratif',
                                  icon: Icons.tune_rounded,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Row 1: Status Pengerjaan (Full Width)
                                      _buildFormDropdown(
                                        label: 'Status Pengerjaan Layanan',
                                        value: statusPengerjaan,
                                        icon: Icons.engineering_rounded,
                                        items: const [
                                          'Draft',
                                          'Assigned (Ditugaskan)',
                                          'In Progress (Dikerjakan)',
                                          'Finished by Cleaner',
                                          'Waiting Payment Approval',
                                          'Waiting Cancel Approval',
                                          'Completed (Selesai)',
                                          'Cancelled (Batal)',
                                        ],
                                        onChanged: (v) => setModalState(() => statusPengerjaan = v!),
                                      ),
                                      const SizedBox(height: 10),

                                      // Row 2: Status Pembayaran (50%) & Status Bonus (50%)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildFormDropdown(
                                              label: 'Status Pembayaran',
                                              value: statusPembayaran,
                                              icon: Icons.payments_outlined,
                                              items: {
                                                'Belum Dibayar',
                                                'Pending',
                                                'Disetujui',
                                                'Ditolak',
                                                'Batal',
                                                statusPembayaran
                                              }.toList(),
                                              onChanged: (v) => setModalState(() => statusPembayaran = v!),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _buildFormDropdown(
                                              label: 'Status Bonus',
                                              value: statusBonus,
                                              icon: Icons.card_giftcard_rounded,
                                              items: {
                                                'Pending',
                                                'Input',
                                                'Selesai',
                                                'Batal',
                                                statusBonus
                                              }.toList(),
                                              onChanged: (v) => setModalState(() => statusBonus = v!),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // Live Status Utama Preview Badge
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: statusUtamaBg,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: statusUtamaColor.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(statusUtamaIcon, size: 16, color: statusUtamaColor),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Kalkulasi Status Utama: ',
                                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                            ),
                                            Text(
                                              liveStatusUtama.toUpperCase(),
                                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: statusUtamaColor),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Card 4: Penugasan Cleaner
                                _buildFormCard(
                                  title: 'Penugasan Cleaner',
                                  icon: Icons.cleaning_services_rounded,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormDropdown(
                                        label: 'Tambah Cleaner Cabang Ini',
                                        value: 'Pilih Cleaner...',
                                        icon: Icons.person_add_alt_1_rounded,
                                        items: [
                                          'Pilih Cleaner...',
                                          ...(availableCleaners.isEmpty
                                              ? order.cleaners.map((c) => c.name).toList()
                                              : availableCleaners.map((k) => k.nama).toList())
                                        ],
                                        onChanged: (val) {
                                          if (val != null && val != 'Pilih Cleaner...') {
                                            setModalState(() {
                                              if (!order.cleaners.any((c) => c.name == val)) {
                                                order.cleaners.add(OrderCleaner(id: DateTime.now().millisecondsSinceEpoch.toString(), pesananCleanerId: '1', name: val, rating: 5.0, statusPengerjaan: CleanerWorkStatus.finished, bonuses: []));
                                              }
                                            });
                                          }
                                        },
                                      ),
                                      if (order.cleaners.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Text('Cleaner Ditugaskan (${order.cleaners.length}):', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: order.cleaners.map((c) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: const Color(0xFFBFDBFE)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.person_rounded, size: 14, color: Color(0xFF2563EB)),
                                                  const SizedBox(width: 4),
                                                  Text(c.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8))),
                                                  const SizedBox(width: 6),
                                                  InkWell(
                                                    onTap: () {
                                                      setModalState(() {
                                                        order.cleaners.remove(c);
                                                      });
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.all(2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red.shade100,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(Icons.close_rounded, size: 12, color: Color(0xFFDC2626)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Card 5: Informasi Order
                                _buildFormCard(
                                  title: 'Informasi Order',
                                  icon: Icons.info_outline_rounded,
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
                                                          if (opt.toLowerCase() == 'organik') {
                                                            order.chatDari = ChatSource.organik;
                                                          } else if (opt.toLowerCase() == 'ads') {
                                                            order.chatDari = ChatSource.ads;
                                                          }
                                                        }),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                                          margin: const EdgeInsets.only(right: 4),
                                                          decoration: BoxDecoration(
                                                            color: isSel ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                                                            borderRadius: BorderRadius.circular(8),
                                                            border: Border.all(color: isSel ? const Color(0xFF1D4ED8) : Colors.transparent),
                                                          ),
                                                          child: Center(
                                                            child: Text(opt, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : AppColors.textDark)),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
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
                                                            color: isSel ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                                                            borderRadius: BorderRadius.circular(8),
                                                            border: Border.all(color: isSel ? const Color(0xFF1D4ED8) : Colors.transparent),
                                                          ),
                                                          child: Center(
                                                            child: Text(opt, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : AppColors.textDark)),
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
                                              icon: Icons.event_rounded,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _buildFormReadOnlyField(
                                              label: 'Waktu Pengerjaan',
                                              value: order.services.isNotEmpty ? order.services.first.waktuPengerjaan : '07:00 PM',
                                              icon: Icons.access_time_rounded,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text('Keterangan Order', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                      const SizedBox(height: 4),
                                      TextField(
                                        controller: TextEditingController(text: order.notes),
                                        maxLines: 2,
                                        onChanged: (val) => order.notes = val,
                                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark),
                                        decoration: InputDecoration(
                                          hintText: 'Catatan tambahan mengenai order...',
                                          hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400),
                                          contentPadding: const EdgeInsets.all(10),
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Card 6: Rincian Keuangan & Pembayaran
                                _buildFormCard(
                                  title: 'Rincian Keuangan & Pajak',
                                  icon: Icons.account_balance_wallet_rounded,
                                  child: Column(
                                    children: [
                                      _buildFormDropdown(
                                        label: 'Metode Pembayaran',
                                        value: order.paymentMethod.isNotEmpty && order.paymentMethod != 'Belum Dibayar (None)' ? order.paymentMethod : 'Belum Dibayar',
                                        icon: Icons.payment_rounded,
                                        items: ['Belum Dibayar', 'Transfer BCA', 'Transfer Mandiri', 'Cash', 'transfer', 'qris', 'cash'],
                                        onChanged: (v) => setModalState(() => order.paymentMethod = v == 'Belum Dibayar' ? '' : v!),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Diskon (%)', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                                const SizedBox(height: 4),
                                                Container(
                                                  height: 42,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF8FAFC),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                                  ),
                                                  child: TextField(
                                                    controller: TextEditingController(text: '${order.discount ?? 0}'),
                                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                                                    keyboardType: TextInputType.number,
                                                    onChanged: (val) => order.discount = int.tryParse(val) ?? 0,
                                                    decoration: const InputDecoration(
                                                      suffixText: '%',
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                      border: InputBorder.none,
                                                      isDense: true,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _buildFormDropdown(
                                              label: 'PPN',
                                              value: (order.ppn ?? 0) > 0 ? '11%' : '0%',
                                              items: ['0%', '11%'],
                                              onChanged: (v) => setModalState(() => order.ppn = v!.contains('11') ? 11 : 0),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _buildFormDropdown(
                                              label: 'PPH',
                                              value: (order.pph ?? 0) > 0 ? '2%' : '0%',
                                              items: ['0%', '2%'],
                                              onChanged: (v) => setModalState(() => order.pph = v!.contains('2') ? 2 : 0),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Card 7: Detail Layanan
                                _buildFormCard(
                                  title: 'Detail Layanan',
                                  icon: Icons.inventory_2_rounded,
                                  action: InkWell(
                                    onTap: () {
                                      setModalState(() {
                                        final defaultLayananName = availableLayanans.isNotEmpty ? availableLayanans.first.namaLayanan : 'General Cleaning';
                                        order.services.add(ServiceItem(
                                          name: defaultLayananName,
                                          qty: '1',
                                          price: 50000,
                                        ));
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFC7D2FE)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.add_rounded, size: 14, color: Color(0xFF4F46E5)),
                                          const SizedBox(width: 4),
                                          Text('Tambah Baris', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5))),
                                        ],
                                      ),
                                    ),
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
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Column(
                                            children: [
                                              // Row 1: Dropdown full width
                                              Container(
                                                height: 40,
                                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF8FAFC),
                                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: DropdownButtonHideUnderline(
                                                  child: DropdownButton<String>(
                                                    value: svc.name,
                                                    isExpanded: true,
                                                    icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textMuted),
                                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
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
                                              const SizedBox(height: 8),
                                              // Row 2: Qty, Price, Hapus
                                              Row(
                                                children: [
                                                  SizedBox(
                                                    width: 65,
                                                    height: 38,
                                                    child: TextField(
                                                      controller: TextEditingController(text: '${svc.qty}'),
                                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                                      keyboardType: TextInputType.number,
                                                      textAlign: TextAlign.center,
                                                      onChanged: (val) => svc.qty = val,
                                                      decoration: InputDecoration(
                                                        prefixText: 'x',
                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: SizedBox(
                                                      height: 38,
                                                      child: TextField(
                                                        controller: TextEditingController(text: NumberFormat('#,###', 'id_ID').format(svc.price)),
                                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                                        keyboardType: TextInputType.number,
                                                        onChanged: (val) {
                                                          final parsed = int.tryParse(val.replaceAll('.', '').replaceAll(',', '')) ?? 0;
                                                          svc.price = parsed;
                                                        },
                                                        decoration: InputDecoration(
                                                          prefixText: 'Rp ',
                                                          prefixStyle: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  InkWell(
                                                    onTap: order.services.length <= 1
                                                        ? null
                                                        : () => setModalState(() => order.services.remove(svc)),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: order.services.length <= 1 ? Colors.grey.shade100 : const Color(0xFFFEE2E2),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Icon(
                                                        Icons.delete_outline_rounded,
                                                        size: 18,
                                                        color: order.services.length <= 1 ? Colors.grey : const Color(0xFFDC2626),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      )),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Card 8: Rincian Bonus Cleaner
                                _buildFormCard(
                                  title: 'Rincian Bonus Cleaner',
                                  icon: Icons.stars_rounded,
                                  action: InkWell(
                                    onTap: order.cleaners.isEmpty ? null : () => _showTambahBonusManualModal(order, setModalState),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: order.cleaners.isEmpty ? Colors.grey.shade100 : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: order.cleaners.isEmpty ? Colors.grey.shade300 : const Color(0xFFBFDBFE)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add_circle_outline_rounded, size: 14, color: order.cleaners.isEmpty ? Colors.grey : const Color(0xFF2563EB)),
                                          const SizedBox(width: 4),
                                          Text('+ Bonus Manual', style: GoogleFonts.inter(fontSize: 11, color: order.cleaners.isEmpty ? Colors.grey : const Color(0xFF1D4ED8), fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: order.cleaners.isEmpty
                                        ? [
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                                              child: Text(
                                                'Belum ada cleaner yang ditugaskan.',
                                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                              ),
                                            )
                                          ]
                                        : order.cleaners.map((cleaner) {
                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        cleaner.name,
                                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                                      ),
                                                      InkWell(
                                                        onTap: () => _showTambahBonusManualModal(order, setModalState, initialCleanerId: cleaner.id),
                                                        child: Text(
                                                          '+ Tambah Bonus',
                                                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF2563EB), fontWeight: FontWeight.bold),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (cleaner.bonuses.isEmpty) ...[
                                                    const SizedBox(height: 6),
                                                    Text('Belum ada bonus tercatat.', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
                                                  ] else ...[
                                                    const SizedBox(height: 8),
                                                    ...cleaner.bonuses.map((bonus) => Padding(
                                                      padding: const EdgeInsets.only(bottom: 6),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(bonus.jenisBonus, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                                              if (bonus.keterangan.isNotEmpty && bonus.keterangan != '-')
                                                                Text(bonus.keterangan, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                                                            ],
                                                          ),
                                                          Row(
                                                            children: [
                                                              Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(bonus.nominal), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                                                              const SizedBox(width: 8),
                                                              InkWell(
                                                                onTap: () {
                                                                  setModalState(() {
                                                                    cleaner.bonuses.remove(bonus);
                                                                  });
                                                                },
                                                                child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    )),
                                                  ],
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Card 9: Foto Pengerjaan Cleaner
                                _buildFormCard(
                                  title: 'Foto Pengerjaan Cleaner',
                                  icon: Icons.photo_library_rounded,
                                  action: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(10),
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
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Column(
                                            children: [
                                              const Icon(Icons.image_outlined, size: 36, color: AppColors.textMuted),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Belum ada foto pengerjaan',
                                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Cleaner wajib mengunggah foto mulai dan selesai pengerjaan melalui aplikasi mobile.',
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
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Sticky Bottom Action Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, -4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: Colors.white,
                          ),
                          child: Text('Batal', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                            );

                            String backendStatusPesanan = 'assigned';
                            if (statusPengerjaan == 'Completed (Selesai)') {
                              backendStatusPesanan = 'completed';
                            } else if (statusPengerjaan == 'Finished by Cleaner') {
                              backendStatusPesanan = 'finished_by_cleaner';
                            } else if (statusPengerjaan == 'In Progress (Dikerjakan)') {
                              backendStatusPesanan = 'in_progress';
                            } else if (statusPengerjaan == 'Draft') {
                              backendStatusPesanan = 'draft';
                            } else if (statusPengerjaan == 'Cancelled (Batal)') {
                              backendStatusPesanan = 'cancelled';
                            } else if (statusPengerjaan == 'Waiting Payment Approval') {
                              backendStatusPesanan = 'waiting_payment_approval';
                            } else if (statusPengerjaan == 'Waiting Cancel Approval') {
                              backendStatusPesanan = 'waiting_cancel_approval';
                            } else {
                              backendStatusPesanan = 'assigned';
                            }

                            String backendStatusPembayaran = 'pending';
                            if (statusPembayaran == 'Approved (Disetujui)' || statusPembayaran == 'Disetujui') {
                              backendStatusPembayaran = 'approved';
                            } else if (statusPembayaran == 'Rejected (Ditolak)' || statusPembayaran == 'Ditolak') {
                              backendStatusPembayaran = 'rejected';
                            } else if (statusPembayaran == 'Cancelled (Batal)' || statusPembayaran == 'Dibatalkan') {
                              backendStatusPembayaran = 'cancelled';
                            } else if (statusPembayaran == 'Belum Dibayar') {
                              backendStatusPembayaran = 'belum_dibayar';
                            }

                            String backendStatusBonus = 'pending';
                            if (statusBonus == 'Input') {
                              backendStatusBonus = 'input';
                            } else if (statusBonus == 'Selesai') {
                              backendStatusBonus = 'selesai';
                            } else if (statusBonus == 'Cancelled (Batal)') {
                              backendStatusBonus = 'cancelled';
                            }

                            final data = {
                              'pelanggan_name': customerNameCtrl.text.trim(),
                              'pelanggan_phone': customerPhoneCtrl.text.trim(),
                              'cabang_name': selectedCabang,
                              'cs_name': csName,
                              'status_pesanan': backendStatusPesanan,
                              'status_pembayaran': backendStatusPembayaran,
                              'status_bonus': backendStatusBonus,
                              'metode_pembayaran': ['cash', 'transfer', 'qris'].contains(order.paymentMethod) ? order.paymentMethod : 'transfer',
                              'diskon_persen': order.discount ?? 0,
                              'ppn': order.ppn ?? 0,
                              'pph': order.pph ?? 0,
                              'keterangan_order': order.notes,
                              'chat_dari': order.chatDari == ChatSource.organik ? 'organik' : (order.chatDari == ChatSource.ads ? 'ads' : 'lama'),
                              'details': order.services.map((s) => {
                                'name': s.name,
                                'qty': s.qty.toString(),
                                'harga': s.price,
                                'tanggal_pengerjaan': s.tanggalPengerjaan.isNotEmpty ? s.tanggalPengerjaan : null,
                                'waktu_pengerjaan': s.waktuPengerjaan.isNotEmpty ? s.waktuPengerjaan : null,
                              }).toList(),
                              'cleaner_names': order.cleaners.map((c) => c.name).toList(),
                              'cleaners_with_bonus': order.cleaners.map((c) => {
                                'name': c.name,
                                'bonuses': c.bonuses.map((b) => {
                                  'jenis_bonus': b.jenisBonus,
                                  'nominal': b.nominal,
                                  'keterangan': b.keterangan,
                                }).toList(),
                              }).toList(),
                            };

                            try {
                              await _financeService.updatePesanan(order.id, data);
                              if (mounted) Navigator.pop(context); // close loading
                              if (mounted) Navigator.pop(context); // close edit modal
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Perubahan order berhasil disimpan ke server oleh Finance!'),
                                    backgroundColor: Color(0xFF059669),
                                  ),
                                );
                                _fetchData();
                              }
                            } catch (e) {
                              if (mounted) Navigator.pop(context); // close loading
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString().replaceAll('Exception: ', '')),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                          label: Text('Simpan Perubahan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTambahBonusManualModal(OrderModel order, StateSetter parentState, {String? initialCleanerId}) {
    String? selectedCleanerId = initialCleanerId ?? (order.cleaners.isNotEmpty ? order.cleaners.first.id : null);
    String selectedJenisBonus = 'Bonus Deepclean';
    final nominalCtrl = TextEditingController();
    final keteranganCtrl = TextEditingController();

    final jenisBonusList = [
      'Bonus Deepclean',
      'Bonus Kasur/Sofa',
      'Bonus General Cleaning',
      'Bonus Lembur',
      'Bonus Kinerja',
      'Bonus Lainnya',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tambah Bonus Manual Cleaner', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 16),
                  
                  // Pilih Cleaner
                  Text('Pilih Cleaner', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCleanerId,
                        isExpanded: true,
                        hint: Text('Pilih Cleaner', style: GoogleFonts.inter(fontSize: 12)),
                        items: order.cleaners.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: GoogleFonts.inter(fontSize: 12)))).toList(),
                        onChanged: (v) => setDialogState(() => selectedCleanerId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Jenis Bonus
                  Text('Jenis Bonus', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedJenisBonus,
                        isExpanded: true,
                        items: jenisBonusList.map((j) => DropdownMenuItem(value: j, child: Text(j, style: GoogleFonts.inter(fontSize: 12)))).toList(),
                        onChanged: (v) => setDialogState(() => selectedJenisBonus = v!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Nominal
                  Text('Nominal (Rp)', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 40,
                    child: TextField(
                      controller: nominalCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Keterangan
                  Text('Keterangan (Opsional)', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 40,
                    child: TextField(
                      controller: keteranganCtrl,
                      style: GoogleFonts.inter(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Alasan pemberian bonus...',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        child: Text('Batal', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (selectedCleanerId == null) return;
                          final nominal = int.tryParse(nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                          if (nominal <= 0) return;

                          final targetCleaner = order.cleaners.firstWhere((c) => c.id == selectedCleanerId);
                          
                          parentState(() {
                            targetCleaner.bonuses.add(CleanerBonus(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              jenisBonus: selectedJenisBonus,
                              nominal: nominal,
                              keterangan: keteranganCtrl.text.isNotEmpty ? keteranganCtrl.text : '-',
                            ));
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('Simpan Bonus', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormCard({required String title, IconData? icon, Widget? action, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 14, color: const Color(0xFF4F46E5)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildFormDropdown({
    required String label,
    required String value,
    IconData? icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final cleanValue = items.contains(value) ? value : items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: cleanValue,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
              items: items.map((i) {
                return DropdownMenuItem(
                  value: i,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 14, color: const Color(0xFF64748B)),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          i,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormReadOnlyField({required String label, required String value, IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: const Color(0xFF64748B)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

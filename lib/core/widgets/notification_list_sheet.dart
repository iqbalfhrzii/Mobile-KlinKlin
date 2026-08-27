import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/notification_model.dart';
import '../services/notification_service.dart';
import '../../features/hrd/screens/karyawan/karyawan_list_screen.dart';
import '../../features/operasional/screens/operasional_pengumuman_screen.dart';
import '../../features/operasional/screens/operasional_approval_pengajuan_screen.dart';
import '../../features/operasional/screens/operasional_permintaan_design_screen.dart';
import '../../features/operasional/screens/operasional_data_kecelakaan_screen.dart';
import '../../features/operasional/screens/monitoring_stok_opname_screen.dart';
import '../../features/operasional/screens/operasional_quotation_screen.dart';
import '../../features/operasional/screens/operasional_purchase_order_screen.dart';
import '../../features/operasional/screens/tagihan_bulanan_screen.dart';
import '../../features/operasional/screens/operasional_sim_screen.dart';
import '../../features/hrd/screens/cuti/hrd_cuti_screen.dart';
import '../../features/hrd/screens/tukar_libur/hrd_tukar_libur_screen.dart';
import '../../features/hrd/screens/jadwal_libur/hrd_jadwal_libur_screen.dart';
import '../../features/uang_kas/screens/uang_kas_screen.dart';
import '../../features/konten_marketing/screens/konten_marketing_screen.dart';
import '../../features/orders/screens/order_detail_screen.dart';
import '../../features/orders/services/order_service.dart';
import '../../features/cleaner/jobs/cleaner_job_detail_screen.dart';

class NotificationListSheet extends StatefulWidget {
  const NotificationListSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationListSheet(),
    );
  }

  @override
  State<NotificationListSheet> createState() => _NotificationListSheetState();
}

class _NotificationListSheetState extends State<NotificationListSheet> {
  final NotificationService _service = NotificationService.instance;

  bool _isLoading = true;
  List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final list = await _service.fetchNotifications();
    if (mounted) {
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final success = await _service.markAllAsRead();
    if (success && mounted) {
      setState(() {
        _notifications = _notifications
            .map((n) => n.copyWith(readAt: DateTime.now()))
            .toList();
      });
    }
  }

  void _onNotificationTap(NotificationItem notification) async {
    // 1. Mark as read in background
    if (!notification.isRead) {
      _service.markAsRead(notification.id);
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = notification.copyWith(readAt: DateTime.now());
        }
      });
    }

    // 2. Dismiss modal
    Navigator.pop(context);

    // 3. Navigate to target
    final type = notification.type.toLowerCase();
    final screen = (notification.screen ?? '').toLowerCase();
    final title = notification.title.toLowerCase();
    final message = notification.message.toLowerCase();
    final data = notification.data;

    // A. Karyawan Baru / Acc Karyawan
    if (type.contains('karyawan') ||
        screen.contains('karyawan') ||
        title.contains('karyawan baru') ||
        message.contains('karyawan baru') ||
        data['action'] == 'acc') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const KaryawanListScreen(initialTabIndex: 1),
        ),
      );
      return;
    }

    // B. Pengumuman
    if (type.contains('pengumuman') || screen.contains('pengumuman')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OperasionalPengumumanScreen(),
        ),
      );
      return;
    }

    // C. Uang Kas / Cashflow
    if (type.contains('kas') || type.contains('cashflow') || screen.contains('uang_kas')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const UangKasScreen(),
        ),
      );
      return;
    }

    // D. Approval Pengajuan / BHP
    if (type.contains('approval') || type.contains('pengajuan') || type.contains('bhp')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OperasionalApprovalPengajuanScreen(),
        ),
      );
      return;
    }

    // E. Permintaan Design
    if (type.contains('design')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OperasionalPermintaanDesignScreen(),
        ),
      );
      return;
    }

    // F. Data Kecelakaan / Insiden
    if (type.contains('kecelakaan') || type.contains('insiden') || screen.contains('kecelakaan')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OperasionalDataKecelakaanScreen(),
        ),
      );
      return;
    }

    // G. Stok Opname
    if (type.contains('stok') || screen.contains('stok')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const MonitoringStokOpnameScreen(),
        ),
      );
      return;
    }

    // H. Quotation / Penawaran
    if (type.contains('quotation') || screen.contains('quotation')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OperasionalQuotationScreen(),
        ),
      );
      return;
    }

    // I. Purchase Order
    if (type.contains('purchase_order') || type.contains('po')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OperasionalPurchaseOrderScreen(),
        ),
      );
      return;
    }

    // J. Tagihan Bulanan
    if (type.contains('tagihan')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const TagihanBulananScreen(),
        ),
      );
      return;
    }

    // K. SIM
    if (type.contains('sim')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OperasionalSimScreen(),
        ),
      );
      return;
    }

    // L. Cuti & Izin
    if (type.contains('cuti') || type.contains('izin')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const HrdCutiScreen(),
        ),
      );
      return;
    }

    // M. Tukar Libur
    if (type.contains('tukar_libur')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const HrdTukarLiburScreen(),
        ),
      );
      return;
    }

    // N. Jadwal Libur
    if (type.contains('jadwal_libur')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const HrdJadwalLiburScreen(),
        ),
      );
      return;
    }

    // O. Marketing
    if (type.contains('marketing') || type.contains('konten')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const KontenMarketingScreen(),
        ),
      );
      return;
    }

    // P. Order Detail
    if (type.contains('order') || screen.contains('order')) {
      final pesananId = data['pesanan_id'] ?? data['id'];
      if (pesananId != null) {
        final id = int.tryParse(pesananId.toString()) ?? 0;
        if (id > 0) {
          try {
            final order = await OrderService().fetchOrderDetail(id.toString());
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(order: order),
                ),
              );
            }
          } catch (_) {}
          return;
        }
      }
    }

    // Q. Cleaner Job Detail
    if (type.contains('cleaner') || type.contains('job')) {
      final cleanerJobId = data['cleaner_job_id'] ?? data['pesanan_cleaner_id'] ?? data['id'];
      if (cleanerJobId != null) {
        final id = int.tryParse(cleanerJobId.toString()) ?? 0;
        if (id > 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CleanerJobDetailScreen(
                job: {'id': id, 'status_pengerjaan': 'notified'},
              ),
            ),
          );
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Row(
                  children: [
                    Text(
                      'Notifikasi',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$unreadCount baru',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                if (unreadCount > 0)
                  InkWell(
                    onTap: _markAllAsRead,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'Tandai semua dibaca',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Body List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                  )
                : _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_off_outlined,
                                size: 40,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Belum Ada Notifikasi',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Semua info dan update penting akan muncul di sini',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadNotifications,
                        color: const Color(0xFF2563EB),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _notifications.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            color: Color(0xFFF1F5F9),
                            indent: 72,
                          ),
                          itemBuilder: (context, index) {
                            final item = _notifications[index];
                            return _buildNotificationTile(item);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(NotificationItem item) {
    final isUnread = !item.isRead;
    final (iconData, iconColor, iconBg) = _getIconConfig(item);

    return Material(
      color: isUnread ? const Color(0xFFF8FAFC) : Colors.white,
      child: InkWell(
        onTap: () => _onNotificationTap(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Box
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),

              // Texts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: isUnread ? const Color(0xFF334155) : const Color(0xFF64748B),
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.timeAgo.isNotEmpty
                          ? item.timeAgo
                          : _formatDate(item.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color, Color) _getIconConfig(NotificationItem item) {
    final type = item.type.toLowerCase();
    final title = item.title.toLowerCase();

    if (type.contains('karyawan') || title.contains('karyawan')) {
      return (Icons.how_to_reg_rounded, const Color(0xFF16A34A), const Color(0xFFDCFCE7));
    }
    if (type.contains('pengumuman') || title.contains('pengumuman')) {
      return (Icons.campaign_rounded, const Color(0xFF0284C7), const Color(0xFFE0F2FE));
    }
    if (type.contains('kas') || type.contains('cashflow')) {
      return (Icons.account_balance_wallet_rounded, const Color(0xFFD97706), const Color(0xFFFEF3C7));
    }
    if (type.contains('order') || type.contains('pesanan')) {
      return (Icons.receipt_long_rounded, const Color(0xFF059669), const Color(0xFFD1FAE5));
    }
    if (type.contains('design') || type.contains('marketing')) {
      return (Icons.palette_rounded, const Color(0xFF7C3AED), const Color(0xFFF3E8FF));
    }
    if (type.contains('kecelakaan') || type.contains('insiden')) {
      return (Icons.warning_amber_rounded, const Color(0xFFDC2626), const Color(0xFFFEE2E2));
    }
    if (type.contains('stok') || type.contains('opname')) {
      return (Icons.inventory_2_rounded, const Color(0xFF4F46E5), const Color(0xFFEEF2FF));
    }
    if (type.contains('cuti') || type.contains('izin')) {
      return (Icons.beach_access_rounded, const Color(0xFFD97706), const Color(0xFFFEF3C7));
    }
    if (type.contains('cleaner') || type.contains('job')) {
      return (Icons.cleaning_services_rounded, const Color(0xFF0284C7), const Color(0xFFE0F2FE));
    }

    return (Icons.notifications_active_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF));
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

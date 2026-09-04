import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import '../../features/cleaner/jobs/cleaner_job_detail_screen.dart';
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
import '../../features/profile/screens/leave_history_screen.dart';
import '../../features/cleaner/tukar_libur/screens/tukar_libur_screen.dart';
import '../../features/hrd/screens/jadwal_libur/hrd_jadwal_libur_screen.dart';
import '../../features/hrd/screens/karyawan/karyawan_list_screen.dart';
import '../../features/designer/screens/designer_aset_sosmed_screen.dart';
import '../../features/uang_kas/screens/uang_kas_screen.dart';
import '../../features/konten_marketing/screens/konten_marketing_screen.dart';
import '../../features/orders/screens/order_detail_screen.dart';
import '../../features/orders/services/order_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/finance/screens/finance_audit_screen.dart';

// Top-level background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class FcmService {
  static final FcmService instance = FcmService._internal();
  FcmService._internal();

  FirebaseMessaging? _messaging;
  GlobalKey<NavigatorState>? navigatorKey;

  void init(GlobalKey<NavigatorState> navKey) {
    navigatorKey = navKey;
    _initFirebase();
  }

  Future<void> _initFirebase() async {
    try {
      _messaging = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permission for iOS/Android 13+
      NotificationSettings settings = await _messaging!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Enable foreground notification presentation on iOS (alert banner, badge, sound)
      await _messaging!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('User granted permission: ${settings.authorizationStatus}');

      // Handle token updates
      _messaging!.onTokenRefresh.listen((String token) {
        debugPrint("FCM Token refreshed: $token");
        _sendTokenToBackend(token);
      });

      // Handle foreground messages with rich floating SnackBar
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        // Get currently logged-in user details
        final prefs = await SharedPreferences.getInstance();
        final currentKaryawanId = (prefs.getString('karyawan_id') ?? '').trim();
        final currentUserName = (prefs.getString('user_name') ?? '').trim();
        final currentRole = (prefs.getString('user_role') ?? '').trim().toLowerCase();
        final isLoggedIn = prefs.getString('auth_token') != null;

        if (!isLoggedIn) {
          debugPrint('Ignoring FCM message: user not logged in');
          return;
        }

        final targetKaryawanId = (message.data['target_karyawan_id'] ?? '').toString().trim();
        final targetRole = (message.data['target_role'] ?? '').toString().trim().toLowerCase();
        final type = (message.data['type'] ?? '').toString().toLowerCase();
        final screen = (message.data['screen'] ?? '').toString().toLowerCase();

        // 1. Validasi Akun Spesifik: Hanya pengguna yang akunnya sedang login yang boleh menerima notifikasi!
        if (targetKaryawanId.isNotEmpty && currentKaryawanId.isNotEmpty) {
          if (targetKaryawanId != currentKaryawanId) {
            debugPrint('Silencing FCM notification: ditujukan untuk user ID $targetKaryawanId (${message.data['target_nama']}), sedangkan yang sedang login adalah $currentKaryawanId ($currentUserName)');
            return;
          }
        }

        // 2. Validasi Role: Role sesi aktif harus cocok
        if (targetRole.isNotEmpty) {
          if (!currentRole.contains(targetRole) && !currentRole.contains('admin') && !currentRole.contains('ceo')) {
            debugPrint('Silencing FCM notification: target role $targetRole tidak cocok dengan role aktif $currentRole');
            return;
          }
        }

        // 3. Isolasi jenis layar khusus
        if (type == 'pembayaran_pending' || screen == 'approval_pembayaran') {
          if (!currentRole.contains('finance') && !currentRole.contains('admin') && !currentRole.contains('ceo')) {
            debugPrint('Ignoring pembayaran_pending: user bukan finance');
            return;
          }
        }
        if (type == 'new_job' || type == 'cancel_job' || screen == 'detail_pesanan') {
          if (!currentRole.contains('cleaner') && !currentRole.contains('admin') && !currentRole.contains('ceo')) {
            debugPrint('Ignoring job notification: user bukan cleaner');
            return;
          }
        }

        // Realtime refresh bell badge and vibration
        NotificationService.instance.refreshUnreadCount();

        if (message.notification != null && navigatorKey?.currentContext != null) {
          final type = (message.data['type'] ?? '').toString();
          
          IconData iconData = Icons.notifications_active_rounded;
          Color iconColor = const Color(0xFF38BDF8);

          if (type.contains('batal') || type.contains('cancel') || screen.contains('audit') || (message.notification?.title ?? '').toLowerCase().contains('batal')) {
            iconData = Icons.cancel_rounded;
            iconColor = const Color(0xFFEF4444);
          } else if (type.contains('pengumuman')) {
            iconData = Icons.campaign_rounded;
            iconColor = const Color(0xFF10B981);
          } else if (type.contains('kas') || type.contains('cashflow')) {
            iconData = Icons.account_balance_wallet_rounded;
            iconColor = const Color(0xFFF59E0B);
          } else if (type.contains('order') || type.contains('pembayaran')) {
            iconData = Icons.receipt_long_rounded;
            iconColor = const Color(0xFF34D399);
          } else if (type.contains('marketing') || type.contains('konten') || type.contains('design')) {
            iconData = Icons.palette_rounded;
            iconColor = const Color(0xFFA78BFA);
          } else if (type.contains('approval') || type.contains('pengajuan') || type.contains('bhp')) {
            iconData = Icons.assignment_turned_in_rounded;
            iconColor = const Color(0xFF3B82F6);
          } else if (type.contains('kecelakaan') || type.contains('insiden')) {
            iconData = Icons.warning_amber_rounded;
            iconColor = const Color(0xFFEF4444);
          } else if (type.contains('stok') || type.contains('opname')) {
            iconData = Icons.inventory_2_rounded;
            iconColor = const Color(0xFF8B5CF6);
          } else if (type.contains('laporan')) {
            iconData = Icons.description_rounded;
            iconColor = const Color(0xFF06B6D4);
          } else if (type.contains('cleaner') || type.contains('job')) {
            iconData = Icons.cleaning_services_rounded;
            iconColor = const Color(0xFF38BDF8);
          } else if (type.contains('cuti') || type.contains('izin')) {
            iconData = Icons.beach_access_rounded;
            iconColor = const Color(0xFFF59E0B);
          } else if (type.contains('schedule') || type.contains('jadwal')) {
            iconData = Icons.event_note_rounded;
            iconColor = const Color(0xFF38BDF8);
          } else if (type.contains('quotation') || type.contains('penawaran')) {
            iconData = Icons.request_quote_rounded;
            iconColor = const Color(0xFF0284C7);
          } else if (type.contains('purchase_order') || type.contains('po')) {
            iconData = Icons.shopping_bag_rounded;
            iconColor = const Color(0xFFF97316);
          } else if (type.contains('tagihan')) {
            iconData = Icons.receipt_long_rounded;
            iconColor = const Color(0xFFEF4444);
          } else if (type.contains('sim')) {
            iconData = Icons.badge_rounded;
            iconColor = const Color(0xFF10B981);
          }

          _showTopBanner(
            title: message.notification!.title ?? 'Notifikasi Baru',
            body: message.notification!.body,
            iconData: iconData,
            iconColor: iconColor,
            onTap: () => _handleMessage(message),
          );
        }
      });

      // Handle message open (app in background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleMessage(message);
      });

      // Check if the app was opened from a terminated state via a notification
      RemoteMessage? initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleMessage(initialMessage);
        });
      }

    } catch (e) {
      debugPrint('Failed to initialize Firebase FCM: $e');
    }
  }

  Future<void> updateTokenToServer() async {
    try {
      if (!await AuthService.isLoggedIn()) return;
      if (_messaging == null) return;
      
      String? token = await _messaging!.getToken();
      if (token != null) {
        debugPrint("Got FCM Token: $token");
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      if (await AuthService.isLoggedIn()) {
        await AuthService.updateFcmToken(token);
        debugPrint("FCM token successfully sent to backend.");
      }
    } catch (e) {
      debugPrint("Failed to send token to backend: $e");
    }
  }

  void _handleMessage(RemoteMessage message) async {
    debugPrint("Handling notification click: ${message.data}");
    final prefs = await SharedPreferences.getInstance();
    final currentKaryawanId = (prefs.getString('karyawan_id') ?? '').trim();
    final currentUserName = (prefs.getString('user_name') ?? '').trim();
    final currentRole = (prefs.getString('user_role') ?? '').trim().toLowerCase();
    final isLoggedIn = prefs.getString('auth_token') != null;

    final navContext = navigatorKey?.currentContext;
    final navState = navigatorKey?.currentState;
    if (navContext == null || navState == null) return;

    if (!isLoggedIn) {
      if (navContext.mounted) {
        ScaffoldMessenger.of(navContext).showSnackBar(
          const SnackBar(content: Text('Silakan login terlebih dahulu.')),
        );
      }
      return;
    }

    final targetKaryawanId = (message.data['target_karyawan_id'] ?? '').toString().trim();
    final targetRole = (message.data['target_role'] ?? '').toString().trim().toLowerCase();
    final targetNama = (message.data['target_nama'] ?? 'pengguna lain').toString();

    // 1. Validasi Akun Pengguna: Tolak jika notifikasi ini dikirimkan untuk akun karyawan lain
    if (targetKaryawanId.isNotEmpty && currentKaryawanId.isNotEmpty && targetKaryawanId != currentKaryawanId) {
      if (navContext.mounted) {
        ScaffoldMessenger.of(navContext).showSnackBar(
          SnackBar(
            content: Text('Notifikasi ini ditujukan untuk $targetNama. Anda saat ini sedang login sebagai $currentUserName.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return;
    }

    // 2. Validasi Role Pengguna
    if (targetRole.isNotEmpty && !currentRole.contains(targetRole) && !currentRole.contains('admin') && !currentRole.contains('ceo')) {
      if (navContext.mounted) {
        ScaffoldMessenger.of(navContext).showSnackBar(
          SnackBar(
            content: Text('Notifikasi ini untuk role $targetRole. Anda saat ini login sebagai ${prefs.getString('user_role')}.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return;
    }

    final type = (message.data['type'] ?? '').toString();
    final screen = (message.data['screen'] ?? '').toString();
    final title = (message.notification?.title ?? message.data['title'] ?? '').toString();
    final body = (message.notification?.body ?? message.data['body'] ?? message.data['message'] ?? '').toString();

    // 0. Pembatalan Pesanan / Hasil Audit (Khusus Finance)
    if (type == 'pembatalan' || type == 'cancel_order' || screen == 'hasil_audit' || screen == 'audit_pesanan' || type == 'approval_edit' || title.toLowerCase().contains('batal') || body.toLowerCase().contains('batal')) {
      if (currentRole.contains('finance') || currentRole.contains('admin finance')) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => const FinanceAuditScreen(initialTab: 'hasil-audit'),
          ),
        );
        return;
      } else {
        if (navContext.mounted) {
          ScaffoldMessenger.of(navContext).showSnackBar(
            SnackBar(
              content: Text('Notifikasi pembatalan/audit ini khusus untuk bagian Finance. Anda saat ini login sebagai ${prefs.getString('user_role')}.'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
        return;
      }
    }

    // 0b. Approval Pembayaran (Khusus Finance)
    if (type == 'pembayaran_pending' || screen == 'approval_pembayaran') {
      if (currentRole.contains('finance') || currentRole.contains('admin finance')) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => const FinanceAuditScreen(),
          ),
        );
        return;
      } else {
        if (navContext.mounted) {
          ScaffoldMessenger.of(navContext).showSnackBar(
            SnackBar(
              content: Text('Notifikasi verifikasi pembayaran ini khusus untuk Finance. Anda saat ini login sebagai ${prefs.getString('user_role')}.'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
        return;
      }
    }

    // 1. Pengumuman
    if (type == 'pengumuman' || screen == 'pengumuman') {
      navState.push(
        MaterialPageRoute(
          builder: (_) => const OperasionalPengumumanScreen(),
        ),
      );
      return;
    }

    // 2. Uang Kas Cabang / Pengajuan Kas
    if (type == 'pengajuan_kas' || type == 'cashflow' || screen == 'uang_kas') {
      navState.push(
        MaterialPageRoute(
          builder: (_) => const UangKasScreen(),
        ),
      );
      return;
    }

    // 3. Approval Pengajuan / Pembelian BHP / Pengadaan Alat
    if (type == 'approval_pengajuan' || type == 'pembelian_bhp' || screen == 'approval_pengajuan' || screen == 'pembelian_bhp') {
      final isCeo = currentRole == 'ceo';
      navState.push(
        MaterialPageRoute(
          builder: (_) => OperasionalApprovalPengajuanScreen(isReadOnly: isCeo),
        ),
      );
      return;
    }

    // 4. Permintaan Desain Promo
    if (type == 'permintaan_design' || screen == 'permintaan_design') {
      navState.push(
        MaterialPageRoute(
          builder: (_) => const OperasionalPermintaanDesignScreen(),
        ),
      );
      return;
    }

    // 5. Data Kecelakaan / Insiden Kerja
    if (type.contains('kecelakaan') || screen.contains('kecelakaan') || type.contains('insiden') || screen.contains('insiden')) {
      navState.push(
        MaterialPageRoute(
          builder: (_) => const OperasionalDataKecelakaanScreen(),
        ),
      );
      return;
    }

    // 6. Stok Opname
    if (type == 'stok_opname' || screen == 'stok_opname') {
      navState.push(
        MaterialPageRoute(
          builder: (_) => const MonitoringStokOpnameScreen(),
        ),
      );
      return;
    }

    // 7. Laporan Lapangan
    if (type == 'laporan_lapangan' || screen == 'laporan_lapangan') {
      navState.push(
        MaterialPageRoute(
          builder: (_) => const OperasionalDataKecelakaanScreen(),
        ),
      );
      return;
    }

    // 8. Konten Marketing
    if (type == 'konten_marketing' || screen == 'konten_marketing') {
      navState.push(
        MaterialPageRoute(
          builder: (_) => const KontenMarketingScreen(),
        ),
      );
      return;
    }

    // 9. Quotation / Penawaran
    if (type == 'quotation' || screen == 'quotation') {
      navState.push(
        MaterialPageRoute(
          builder: (_) => const OperasionalQuotationScreen(),
        ),
      );
      return;
    }

    // 10. Purchase Order
    if (type == 'purchase_order' || screen == 'purchase_order') {
      navState.push(
        MaterialPageRoute(
          builder: (_) => const OperasionalPurchaseOrderScreen(),
        ),
      );
      return;
    }

    // 11. Tagihan Bulanan Kantor
    if (type == 'tagihan_bulanan' || screen == 'tagihan_bulanan') {
      navState.push(
        MaterialPageRoute(
          builder: (_) => const TagihanBulananScreen(),
        ),
      );
      return;
    }

    // 12. SIM Driver / Cleaner / Karyawan
    if (type.contains('sim') || screen.contains('sim')) {
      navState.push(
        MaterialPageRoute(
          builder: (_) => const OperasionalSimScreen(),
        ),
      );
      return;
    }

    // 13. Cuti & Izin
    if (type == 'cuti_hrd' || screen == 'hrd_cuti' || type == 'cuti' || screen == 'cuti' || type.contains('cuti') || type.contains('izin')) {
      final isHrd = currentRole.contains('hrd') || currentRole.contains('admin') || currentRole.contains('ceo');
      final isApprovalResult = title.toLowerCase().contains('disetujui') ||
          title.toLowerCase().contains('ditolak') ||
          body.toLowerCase().contains('disetujui') ||
          body.toLowerCase().contains('ditolak');

      if (isHrd && !isApprovalResult && (type == 'cuti_hrd' || screen == 'hrd_cuti')) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => const HrdCutiScreen(),
          ),
        );
      } else {
        navState.push(
          MaterialPageRoute(
            builder: (_) => const LeaveHistoryScreen(),
          ),
        );
      }
      return;
    }

    // 14. Tukar Libur
    if (type == 'tukar_libur_hrd' || screen == 'hrd_tukar_libur' || type == 'tukar_libur' || screen == 'tukar_libur' || type.contains('tukar_libur')) {
      final isHrd = currentRole.contains('hrd') || currentRole.contains('admin') || currentRole.contains('ceo');
      final isApprovalResult = title.toLowerCase().contains('disetujui') ||
          title.toLowerCase().contains('ditolak') ||
          body.toLowerCase().contains('disetujui') ||
          body.toLowerCase().contains('ditolak');

      if (isHrd && !isApprovalResult && (type == 'tukar_libur_hrd' || screen == 'hrd_tukar_libur')) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => const HrdTukarLiburScreen(),
          ),
        );
      } else {
        navState.push(
          MaterialPageRoute(
            builder: (_) => const TukarLiburScreen(),
          ),
        );
      }
      return;
    }

    // 15. HRD Jadwal Libur
    if (type == 'jadwal_libur' || screen == 'jadwal_libur') {
      if (currentRole.contains('hrd') || currentRole.contains('admin') || currentRole.contains('ceo')) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => const HrdJadwalLiburScreen(),
          ),
        );
      }
      return;
    }

    // 16. HRD Data Karyawan & Acc Karyawan Baru
    if (type.contains('karyawan') || screen.contains('karyawan') || type == 'karyawan_baru') {
      if (currentRole.contains('hrd') || currentRole.contains('admin') || currentRole.contains('ceo')) {
        final isAcc = message.data['action'] == 'acc' || type == 'karyawan_baru';
        navState.push(
          MaterialPageRoute(
            builder: (_) => KaryawanListScreen(initialTabIndex: isAcc ? 1 : 0),
          ),
        );
      }
      return;
    }

    // 17. Designer Aset Sosmed
    if (type == 'aset_sosmed' || screen == 'aset_sosmed') {
      navState.push(
        MaterialPageRoute(
          builder: (_) => const DesignerAsetSosmedScreen(),
        ),
      );
      return;
    }

    // 9. Order Detail (Cleaner Start/Finish, Payment Verified, Cancellation/Edit Approval)
    if (type == 'order_detail' || screen == 'order_detail') {
      // Jika yang login adalah Finance, arahkan ke layar persetujuan Finance, BUKAN ke detail CS!
      if (currentRole.contains('finance')) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => const FinanceAuditScreen(),
          ),
        );
        return;
      }

      // Jika yang login adalah CS / Admin / CEO
      if (currentRole.contains('cs') || currentRole.contains('customer service') || currentRole.contains('admin') || currentRole.contains('ceo')) {
        final pesananId = message.data['pesanan_id'];
        if (pesananId != null && pesananId.toString().isNotEmpty) {
          try {
            final order = await OrderService().fetchOrderDetail(pesananId.toString());
            if (navigatorKey?.currentContext != null) {
              Navigator.of(navigatorKey!.currentContext!).push(
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(order: order),
                ),
              );
            }
          } catch (e) {
            debugPrint('Error fetching order detail from notification: $e');
          }
        }
        return;
      }

      if (navContext.mounted) {
        ScaffoldMessenger.of(navContext).showSnackBar(
          SnackBar(
            content: Text('Notifikasi ini untuk Customer Service. Anda saat ini login sebagai ${prefs.getString('user_role')}.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return;
    }

    // 10. Cleaner New Job & Cancel Job
    if ((type == 'new_job' && screen == 'detail_pesanan') || type == 'cancel_job' || type == 'job_cancelled') {
      if (!currentRole.contains('cleaner') && !currentRole.contains('admin') && !currentRole.contains('ceo')) {
        if (navContext.mounted) {
          ScaffoldMessenger.of(navContext).showSnackBar(
            SnackBar(
              content: Text('Notifikasi tugas ini ditujukan untuk Cleaner ($targetNama). Anda saat ini login sebagai $currentUserName (${prefs.getString('user_role')}).'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
        return;
      }
      final String? cleanerIdStr = message.data['pesanan_cleaner_id'] ?? message.data['cleaner_job_id'];
      if (cleanerIdStr != null) {
        final int? cleanerId = int.tryParse(cleanerIdStr);
        if (cleanerId != null) {
          final isCancel = type == 'cancel_job' || type == 'job_cancelled';
          navState.push(
            MaterialPageRoute(
              builder: (_) => CleanerJobDetailScreen(
                job: {
                  'id': cleanerId,
                  'status_pengerjaan': isCancel ? 'cancelled' : 'notified',
                },
              ),
            ),
          );
        }
      }
    }
  }

  OverlayEntry? _currentBannerEntry;

  void _showTopBanner({
    required String title,
    required String? body,
    required IconData iconData,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    _removeCurrentBanner();

    final overlay = navigatorKey?.currentState?.overlay;
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TopNotificationBanner(
        title: title,
        body: body,
        iconData: iconData,
        iconColor: iconColor,
        onTap: () {
          _removeCurrentBanner();
          onTap();
        },
        onDismissed: () {
          _removeCurrentBanner();
        },
      ),
    );

    _currentBannerEntry = entry;
    overlay.insert(entry);
  }

  void _removeCurrentBanner() {
    if (_currentBannerEntry != null) {
      try {
        _currentBannerEntry?.remove();
      } catch (_) {}
      _currentBannerEntry = null;
    }
  }
}

class _TopNotificationBanner extends StatefulWidget {
  final String title;
  final String? body;
  final IconData iconData;
  final Color iconColor;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _TopNotificationBanner({
    required this.title,
    required this.body,
    required this.iconData,
    required this.iconColor,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  State<_TopNotificationBanner> createState() => _TopNotificationBannerState();
}

class _TopNotificationBannerState extends State<_TopNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    _animController.forward();

    // Otomatis hilang setelah 4 detik
    _autoDismissTimer = Timer(const Duration(seconds: 4), () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    _autoDismissTimer?.cancel();
    _animController.reverse().then((_) {
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.up,
            onDismissed: (_) {
              _autoDismissTimer?.cancel();
              widget.onDismissed();
            },
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {
                  _dismiss();
                  widget.onTap();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF334155).withValues(alpha: 0.8),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.iconColor.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(widget.iconData, color: widget.iconColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.body != null && widget.body!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.body!,
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tombol Buka
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Buka',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF34D399),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 10,
                              color: Color(0xFF34D399),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Tombol Close
                      GestureDetector(
                        onTap: _dismiss,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

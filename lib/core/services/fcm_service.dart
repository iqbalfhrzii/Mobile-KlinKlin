import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'auth_service.dart';
import '../../features/cleaner/jobs/cleaner_job_detail_screen.dart';
import '../../features/operasional/screens/operasional_pengumuman_screen.dart';
import '../../features/operasional/screens/operasional_approval_pengajuan_screen.dart';
import '../../features/operasional/screens/operasional_permintaan_design_screen.dart';
import '../../features/operasional/screens/operasional_data_kecelakaan_screen.dart';
import '../../features/operasional/screens/monitoring_stok_opname_screen.dart';
import '../../features/operasional/screens/operasional_laporan_lapangan_screen.dart';
import '../../features/uang_kas/screens/uang_kas_screen.dart';
import '../../features/konten_marketing/screens/konten_marketing_screen.dart';
import '../../features/orders/screens/order_detail_screen.dart';
import '../../features/orders/services/order_service.dart';

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

      debugPrint('User granted permission: ${settings.authorizationStatus}');

      // Handle token updates
      _messaging!.onTokenRefresh.listen((String token) {
        debugPrint("FCM Token refreshed: $token");
        _sendTokenToBackend(token);
      });

      // Handle foreground messages with rich floating SnackBar
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null && navigatorKey?.currentContext != null) {
          final type = (message.data['type'] ?? '').toString();
          
          IconData iconData = Icons.notifications_active_rounded;
          Color iconColor = const Color(0xFF38BDF8);

          if (type.contains('pengumuman')) {
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
          }

          ScaffoldMessenger.of(navigatorKey!.currentContext!).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconData, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.notification!.title ?? 'Notifikasi Baru',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                        ),
                        if (message.notification!.body != null)
                          Text(
                            message.notification!.body!,
                            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'Buka',
                textColor: const Color(0xFF34D399),
                onPressed: () => _handleMessage(message),
              ),
            ),
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
    final context = navigatorKey?.currentContext;
    if (context == null) return;

    final type = (message.data['type'] ?? '').toString();
    final screen = (message.data['screen'] ?? '').toString();

    // 1. Pengumuman
    if (type == 'pengumuman' || screen == 'pengumuman') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const OperasionalPengumumanScreen(),
        ),
      );
      return;
    }

    // 2. Uang Kas Cabang / Pengajuan Kas
    if (type == 'pengajuan_kas' || type == 'cashflow' || screen == 'uang_kas') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const UangKasScreen(),
        ),
      );
      return;
    }

    // 3. Approval Pengajuan / Pembelian BHP / Pengadaan Alat
    if (type == 'approval_pengajuan' || type == 'pembelian_bhp' || screen == 'approval_pengajuan' || screen == 'pembelian_bhp') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const OperasionalApprovalPengajuanScreen(),
        ),
      );
      return;
    }

    // 4. Permintaan Desain Promo
    if (type == 'permintaan_design' || screen == 'permintaan_design') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const OperasionalPermintaanDesignScreen(),
        ),
      );
      return;
    }

    // 5. Data Kecelakaan / Insiden Kerja
    if (type == 'data_kecelakaan' || screen == 'data_kecelakaan') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const OperasionalDataKecelakaanScreen(),
        ),
      );
      return;
    }

    // 6. Stok Opname
    if (type == 'stok_opname' || screen == 'stok_opname') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const MonitoringStokOpnameScreen(),
        ),
      );
      return;
    }

    // 7. Laporan Lapangan
    if (type == 'laporan_lapangan' || screen == 'laporan_lapangan') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const OperasionalLaporanLapanganScreen(),
        ),
      );
      return;
    }

    // 8. Konten Marketing
    if (type == 'konten_marketing' || screen == 'konten_marketing') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const KontenMarketingScreen(),
        ),
      );
      return;
    }

    // 9. Order Detail (Cleaner Start/Finish, Payment Verified, Cancellation/Edit Approval)
    if (type == 'order_detail' || screen == 'order_detail') {
      final pesananId = message.data['pesanan_id'];
      if (pesananId != null && pesananId.toString().isNotEmpty) {
        try {
          // Show quick loading or directly navigate
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

    // 10. Cleaner New Job
    if (type == 'new_job' && screen == 'detail_pesanan') {
      final String? cleanerIdStr = message.data['pesanan_cleaner_id'];
      if (cleanerIdStr != null) {
        final int? cleanerId = int.tryParse(cleanerIdStr);
        if (cleanerId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CleanerJobDetailScreen(
                job: {'id': cleanerId, 'status_pengerjaan': 'notified'},
              ),
            ),
          );
        }
      }
    }
  }
}

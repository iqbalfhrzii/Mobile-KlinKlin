import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/cleaner/shell/cleaner_main_shell.dart';
import '../features/finance/shell/finance_main_shell.dart';
import '../features/hrd/shell/hrd_main_shell.dart';
import '../features/operasional/shell/operasional_main_shell.dart';
import '../features/designer/shell/designer_main_shell.dart';
import '../features/marketing/shell/marketing_main_shell.dart';
import '../features/ceo/shell/ceo_main_shell.dart';
import '../core/services/fcm_service.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

class KlinklinApp extends StatefulWidget {
  final bool isLoggedIn;
  final String userRole;
  
  const KlinklinApp({super.key, required this.isLoggedIn, required this.userRole});

  @override
  State<KlinklinApp> createState() => _KlinklinAppState();
}

class _KlinklinAppState extends State<KlinklinApp> {
  @override
  void initState() {
    super.initState();
    FcmService.instance.init(globalNavigatorKey);
  }

  Widget _getInitialShell(String role) {
    role = role.toLowerCase();
    if (role.contains('cleaner')) {
      return const CleanerMainShell();
    } else if (role.contains('finance') || role.contains('keuangan')) {
      return const FinanceMainShell();
    } else if (role.contains('hrd')) {
      return const HrdMainShell();
    } else if (role.contains('operasional')) {
      return const OperasionalMainShell();
    } else if (role.contains('designer') || role.contains('desain')) {
      return const DesignerMainShell();
    } else if (role.contains('marketing')) {
      return const MarketingMainShell();
    } else if (role.contains('ceo') || role.contains('owner')) {
      return const CeoMainShell();
    } else {
      return const MainShell();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KlinKlin CS App',
      navigatorKey: globalNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Route based on role if logged in
      home: widget.isLoggedIn ? _getInitialShell(widget.userRole) : const LoginScreen(),
    );
  }
}

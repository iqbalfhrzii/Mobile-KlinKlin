import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/theme/app_theme.dart';
//import '../features/auth/screens/login_dummy_screen.dart';
import '../features/auth/screens/login_screen.dart';

import '../core/services/auth_service.dart';
import '../features/shell/main_shell.dart';
import '../core/services/fcm_service.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

class KlinklinApp extends StatefulWidget {
  const KlinklinApp({super.key});

  @override
  State<KlinklinApp> createState() => _KlinklinAppState();
}

class _KlinklinAppState extends State<KlinklinApp> {
  @override
  void initState() {
    super.initState();
    FcmService.instance.init(globalNavigatorKey);
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
      // Sengaja diarahkan ke LoginDummyScreen (demo login tanpa API)
      home: const LoginScreen(),
    );
  }
}

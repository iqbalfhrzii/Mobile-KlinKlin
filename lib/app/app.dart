import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/screens/login_screen.dart';

import '../core/services/auth_service.dart';
import '../features/shell/main_shell.dart';

class KlinklinApp extends StatelessWidget {
  const KlinklinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KlinKlin CS App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Sengaja diarahkan ke LoginScreen terus sesuai permintaan
      home: const LoginScreen(),
    );
  }
}

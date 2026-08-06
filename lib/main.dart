import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/network/dio_client.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  DioClient.instance.init();

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getString('auth_token') != null;
  final userRole = prefs.getString('user_role') ?? '';

  runApp(KlinklinApp(isLoggedIn: isLoggedIn, userRole: userRole));
}

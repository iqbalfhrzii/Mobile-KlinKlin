import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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
  runApp(const KlinklinApp());
}

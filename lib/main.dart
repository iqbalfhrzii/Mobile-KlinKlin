import 'package:flutter/material.dart';
import 'core/network/dio_client.dart';
import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  DioClient.instance.init();
  runApp(const KlinklinApp());
}

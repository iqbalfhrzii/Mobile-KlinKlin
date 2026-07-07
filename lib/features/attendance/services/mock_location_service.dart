import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

class MockLocationService {
  static const MethodChannel _channel = MethodChannel('com.example.klinklin/location');

  static Future<bool> isMockLocation(Position position) async {
    // Geolocator built-in check for Android & iOS
    if (position.isMocked) return true;

    // Additional Native Check for Android
    if (Platform.isAndroid) {
      try {
        final bool isMock = await _channel.invokeMethod('isMockLocation', {
          'latitude': position.latitude,
          'longitude': position.longitude,
        });
        return isMock;
      } on PlatformException {
        return false;
      }
    }
    
    return false; // For iOS fallback
  }
}

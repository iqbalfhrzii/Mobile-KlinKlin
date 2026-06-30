import 'dart:convert';
import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  try {
    final res = await dio.get(
      'http://127.0.0.1:8000/api/pesanan',
      queryParameters: {'status_pesanan': 'waiting_payment_approval'}
    );
    final data = res.data['data']['data'] as List; // Pagination
    if (data.isEmpty) {
      print('NO ORDERS FOUND');
      return;
    }
    
    final order = data.first;
    print('Order ID: ${order['id']}');
    print('Pembayaran Keys: ${order['pembayaran']?.keys}');
    print('Pembayaran Data: ${order['pembayaran']}');
  } catch (e) {
    print('Error: $e');
  }
}

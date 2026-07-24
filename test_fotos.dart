import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  dio.options.baseUrl = 'http://127.0.0.1:8000/api'; // Assuming local laravel
  dio.options.headers['Accept'] = 'application/json';
  
  try {
    final response = await dio.get('/pesanan');
    final rawData = response.data['data']?['data'] ?? response.data['data'] ?? response.data;
    
    if (rawData is List) {
      final order69 = rawData.firstWhere((o) => o['nomor_pesanan']?.contains('000069') ?? false, orElse: () => null);
      if (order69 != null) {
        print('Found Order 69:');
        final cleaners = order69['cleaners'] ?? [];
        print('Cleaners count: ${cleaners.length}');
        for (var c in cleaners) {
          print('Cleaner ${c['id']}:');
          final fStart = c['fotos_start'] ?? [];
          final fFinish = c['fotos_finish'] ?? [];
          print(' fotos_start: ${fStart.length}');
          print(' fotos_finish: ${fFinish.length}');
        }
      } else {
        print('Order 69 not found in first page');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}

import 'package:dio/dio.dart';

void main() async {
  final dio = Dio(BaseOptions(baseUrl: 'http://192.168.1.25:8000/api'));
  try {
    print('Logging in...');
    final res = await dio.post('/login', data: {
      "email": "cs@klinklin.com",
      "pin": "123456"
    });
    final token = res.data['token'];
    print('Token: $token');
    
    print('Fetching /karyawans...');
    final res2 = await dio.get('/karyawans', options: Options(headers: {'Authorization': 'Bearer $token'}));
    
    final data = res2.data;
    if (data['data'] != null && data['data'] is List && (data['data'] as List).isNotEmpty) {
      print('First Karyawan:');
      print(data['data'].first);
    } else {
      print('Data: $data');
    }
  } catch (e) {
    print('Error: $e');
    if (e is DioException) {
      print('Response: ${e.response?.data}');
    }
  }
}

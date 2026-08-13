import 'package:dio/dio.dart';

void main() async {
  final _dio = Dio(BaseOptions(
    baseUrl: 'http://erp.klinklin.online/api',
  ));
  try {
    await _dio.get('/api/stok-opname');
  } catch (e) {
    if (e is DioException) {
      print('URL Requested: \${e.requestOptions.uri}');
    }
  }
}

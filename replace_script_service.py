import re

path = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\attendance\services\attendance_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

new_method = """
  Future<Map<String, dynamic>> getDetailBulanan({required int karyawanId, String? month}) async {
    try {
      final Map<String, dynamic> query = {};
      if (month != null && month.isNotEmpty) {
        if (month.contains('-')) {
          final parts = month.split('-');
          if (parts.length >= 2) {
            final y = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            if (y != null) query['tahun'] = y;
            if (m != null) query['bulan'] = m;
          }
        }
      }

      final response = await _dio.get(
        '/absensi/detail-bulanan/$karyawanId',
        queryParameters: query,
      );
      if (response.statusCode == 200) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      return {};
    }
  }
"""

if 'getDetailBulanan' not in content:
    content = content.replace('  Future<List<AttendanceHistoryItem>> getAllAbsensi', new_method + '\n  Future<List<AttendanceHistoryItem>> getAllAbsensi')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated attendance_service.dart")

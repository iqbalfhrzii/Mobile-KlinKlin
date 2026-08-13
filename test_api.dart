import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final loginUrl = Uri.parse('http://erp.klinklin.online/api/login');
  final loginResponse = await http.post(
    loginUrl,
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: jsonEncode({'email': 'cs.surabaya@klinklin.com', 'pin': '123456'})
  );

  print('Login status: \${loginResponse.statusCode}');
  
  if (loginResponse.statusCode == 200) {
    final loginData = jsonDecode(loginResponse.body);
    final token = loginData['token'];
    
    final stokOpnameUrl = Uri.parse('http://erp.klinklin.online/api/stok-opname?cabang_id=1');
    final stokOpnameResponse = await http.get(
      stokOpnameUrl,
      headers: {
        'Content-Type': 'application/json', 
        'Accept': 'application/json',
        'Authorization': 'Bearer \$token'
      }
    );
    
    print('Stok Opname List Status: \${stokOpnameResponse.statusCode}');
    print('Stok Opname List Body: \${stokOpnameResponse.body}');
    
    if (stokOpnameResponse.statusCode == 200) {
      final listData = jsonDecode(stokOpnameResponse.body);
      final sessions = listData['data'] as List;
      
      if (sessions.isNotEmpty) {
        final sessionId = sessions[0]['id'];
        final detailUrl = Uri.parse('http://erp.klinklin.online/api/stok-opname/\$sessionId');
        final detailResponse = await http.get(
          detailUrl,
          headers: {
            'Content-Type': 'application/json', 
            'Accept': 'application/json',
            'Authorization': 'Bearer \$token'
          }
        );
        
        print('Stok Opname Detail Status: \${detailResponse.statusCode}');
        print('Stok Opname Detail Body (first 1000 chars): \${detailResponse.body.length > 1000 ? detailResponse.body.substring(0, 1000) : detailResponse.body}');
      }
    }
  } else {
    print('Login Body: \${loginResponse.body}');
  }
}

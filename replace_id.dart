import 'dart:io';

void main() {
  final dir = Directory('lib/features');
  int filesModified = 0;
  for (var file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart') && !file.path.contains('service') && !file.path.contains('model')) {
      String content = file.readAsStringSync();
      bool modified = false;

      // Replace o.id with o.nomorPesanan where it's displayed
      final replacements = {
        'Text(o.id': 'Text(o.nomorPesanan',
        'Text(_o.id': 'Text(_o.nomorPesanan',
        'Text(order.id': 'Text(order.nomorPesanan',
        'Text(\'Order #\${o.id}\'': 'Text(\'Order #\${o.nomorPesanan}\'',
        'Text(\'Order #\${order.id}\'': 'Text(\'Order #\${order.nomorPesanan}\'',
        'Text(\'\${_o.id}': 'Text(\'\${_o.nomorPesanan}',
        'Text(\'Pembayaran \${_o.id}': 'Text(\'Pembayaran \${_o.nomorPesanan}',
        'Text(\'Pesanan \${_o.id}': 'Text(\'Pesanan \${_o.nomorPesanan}',
        'Text(id,': 'Text(id,', // Wait, this might be tricky, skip this
        'o.id.toLowerCase().contains': 'o.nomorPesanan.toLowerCase().contains',
      };

      for (var entry in replacements.entries) {
        if (content.contains(entry.key)) {
          content = content.replaceAll(entry.key, entry.value);
          modified = true;
        }
      }

      if (modified) {
        file.writeAsStringSync(content);
        filesModified++;
        print('Modified: ${file.path}');
      }
    }
  }
  print('Total files modified: $filesModified');
}

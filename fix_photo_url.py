import re

path = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\profile\screens\leave_history_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the URL generation logic
old_logic = """                                      final url = item['bukti_foto'].toString().startsWith('http') 
                                          ? item['bukti_foto'] 
                                          : '${AppConstants.baseUrl.replaceAll('/api', '')}/storage/${item['bukti_foto']}';"""
new_logic = """                                      final url = '${AppConstants.baseUrl}/pengajuan/${item['id']}/foto';"""
content = content.replace(old_logic, new_logic)

old_network = """                                          image: NetworkImage(
                                            item['bukti_foto'].toString().startsWith('http') 
                                                ? item['bukti_foto'] 
                                                : '${AppConstants.baseUrl.replaceAll('/api', '')}/storage/${item['bukti_foto']}'
                                          ),"""
new_network = """                                          image: NetworkImage(
                                            '${AppConstants.baseUrl}/pengajuan/${item['id']}/foto'
                                          ),"""
content = content.replace(old_network, new_network)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Updated Flutter to use Laravel API endpoint for photos')

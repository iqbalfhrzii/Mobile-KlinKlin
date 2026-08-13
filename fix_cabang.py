import re

path = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\master_barang\screens\master_barang_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('final items = await MasterBarangService.getItemFisik(cabangId: 1); // Mock cabang 1', 'final items = await MasterBarangService.getItemFisik(); // Fetch all cabangs')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated master_barang_screen.dart to remove mock cabangId')

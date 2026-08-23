path = r'c:\Users\HP VICTUS\Documents\Laravel\API_KLINKLIN\app\Jobs\ProcessPengumuman.php'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("ðŸ“¢ Pengumuman: ", "📢 Pengumuman: ")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("ProcessPengumuman.php updated successfully!")

import re

path = r'c:\Users\HP VICTUS\Documents\Mobile\lib\features\profile\screens\profile_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

pattern = re.compile(r"                    if \(_userRole\.toLowerCase\(\)\.contains\('cleaner'\)\) \.\.\.\[[\s\S]*?const SizedBox\(height: 12\),\n                    \],\n")
content = pattern.sub('', content)

content = content.replace("import '../../cleaner/tukar_libur/screens/tukar_libur_screen.dart';\n", '')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Removed from profile')

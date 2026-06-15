import re
with open('lib/core/data/mock_data.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace cleaner: 'Name' with cleaners: ['Name']
content = re.sub(r"cleaner:\s*'([^']+)'", r"cleaners: ['\1']", content)

# Replace cleaner: const OrderCleaner(...) with cleaners: const [OrderCleaner(...)]
content = re.sub(r"cleaner:\s*const\s*OrderCleaner\(([^)]+)\)", r"cleaners: const [OrderCleaner(\1)]", content)

# Replace cleaner: null with cleaners: const []
content = re.sub(r"cleaner:\s*null", r"cleaners: const []", content)

with open('lib/core/data/mock_data.dart', 'w', encoding='utf-8') as f:
    f.write(content)

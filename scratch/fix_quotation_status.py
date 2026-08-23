ctrl_path = r'c:\Users\HP VICTUS\Documents\Laravel\API_KLINKLIN\app\Http\Controllers\Api\QuotationApiController.php'

with open(ctrl_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("'status' => 'Pending'", "'status' => 'Dibuat'")

with open(ctrl_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated QuotationApiController.php: changed 'Pending' to 'Dibuat'!")

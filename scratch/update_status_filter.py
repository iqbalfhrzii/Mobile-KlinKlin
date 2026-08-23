ctrl_path = r'c:\Users\HP VICTUS\Documents\Laravel\API_KLINKLIN\app\Http\Controllers\Api\QuotationApiController.php'

with open(ctrl_path, 'r', encoding='utf-8') as f:
    content = f.read()

target = """        if ($request->has('status') && !empty($request->status) && $request->status !== 'Semua Status' && $request->status !== 'Semua') {
            $query->where('status', $request->status);
        }"""

replacement = """        if ($request->has('status') && !empty($request->status) && $request->status !== 'Semua Status' && $request->status !== 'Semua') {
            if ($request->status === 'Menunggu' || $request->status === 'Pending') {
                $query->whereIn('status', ['Dibuat', 'Menunggu', 'Pending']);
            } else {
                $query->where('status', $request->status);
            }
        }"""

content = content.replace(target, replacement)

with open(ctrl_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated status filter in QuotationApiController.php!")

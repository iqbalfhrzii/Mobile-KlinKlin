api_routes_path = r'c:\Users\HP VICTUS\Documents\Laravel\API_KLINKLIN\routes\api.php'

with open(api_routes_path, 'r', encoding='utf-8') as f:
    content = f.read()

target = "Route::post('/logout', [AuthController::class, 'logout']);"
replacement = """Route::post('/logout', [AuthController::class, 'logout']);
    Route::post('/fcm-token', [\\App\\Http\\Controllers\\Api\\CleanerDeviceController::class, 'updateFcmToken']);
    Route::post('/cleaner/fcm-token', [\\App\\Http\\Controllers\\Api\\CleanerDeviceController::class, 'updateFcmToken']);"""

if target in content:
    content = content.replace(target, replacement, 1)
    with open(api_routes_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("FCM routes added successfully to routes/api.php!")
else:
    print("Target not found in routes/api.php")

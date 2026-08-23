api_routes_path = r'c:\Users\HP VICTUS\Documents\Laravel\API_KLINKLIN\routes\api.php'

with open(api_routes_path, 'r', encoding='utf-8') as f:
    routes_code = f.read()

route_block = """
    /*
    |--------------------------------------------------------------------------
    | QUOTATION (DATA PENAWARAN) ROUTES
    |--------------------------------------------------------------------------
    */
    Route::prefix('operasional/quotation')->middleware('role:cs,operasional,admin,ceo,hrd,finance,customer service')->group(function () {
        Route::get('/', [\App\Http\Controllers\Api\QuotationApiController::class, 'index']);
        Route::get('/{id}', [\App\Http\Controllers\Api\QuotationApiController::class, 'show']);
        Route::post('/', [\App\Http\Controllers\Api\QuotationApiController::class, 'store']);
        Route::put('/{id}', [\App\Http\Controllers\Api\QuotationApiController::class, 'update']);
        Route::delete('/{id}', [\App\Http\Controllers\Api\QuotationApiController::class, 'destroy']);
        Route::post('/{id}/approve', [\App\Http\Controllers\Api\QuotationApiController::class, 'approve']);
        Route::post('/{id}/reject', [\App\Http\Controllers\Api\QuotationApiController::class, 'reject']);
    });
"""

pos = routes_code.rfind('});')
if pos != -1:
    new_code = routes_code[:pos] + route_block + "\n" + routes_code[pos:]
    with open(api_routes_path, 'w', encoding='utf-8') as f:
        f.write(new_code)
    print("Added quotation routes before last }); in routes/api.php!")
else:
    print("Error: Could not find });")

import os

controller_path = r'c:\Users\HP VICTUS\Documents\Laravel\API_KLINKLIN\app\Http\Controllers\Api\MarketingContentApiController.php'
api_routes_path = r'c:\Users\HP VICTUS\Documents\Laravel\API_KLINKLIN\routes\api.php'

controller_code = """<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\MarketingContent;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class MarketingContentApiController extends Controller
{
    /**
     * Get list of marketing contents by type (story, promo, follow_up).
     */
    public function index(Request $request)
    {
        $type = $request->input('type', 'story'); // story, promo, follow_up
        $search = $request->input('search');

        $query = MarketingContent::query();

        if (!empty($type) && $type !== 'all') {
            $query->where('type', $type);
        }

        if (!empty($search)) {
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%{$search}%")
                  ->orWhere('description', 'like', "%{$search}%");
            });
        }

        $contents = $query->latest()->paginate(15);

        return response()->json([
            'status' => true,
            'data' => $contents,
        ]);
    }

    /**
     * Get detail of a marketing content.
     */
    public function show($id)
    {
        $content = MarketingContent::findOrFail($id);

        return response()->json([
            'status' => true,
            'data' => $content,
        ]);
    }

    /**
     * Store new marketing content.
     */
    public function store(Request $request)
    {
        $request->validate([
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'type' => 'required|in:story,promo,follow_up',
            'file' => 'required|file|max:51200', // 50MB max
        ]);

        try {
            $file = $request->file('file');
            $filePath = $file->store('marketing-contents', 'public');

            $content = MarketingContent::create([
                'title' => $request->title,
                'description' => $request->description,
                'type' => $request->type,
                'file_path' => $filePath,
                'file_name' => $file->getClientOriginalName(),
                'file_type' => $file->getMimeType(),
                'file_size' => $file->getSize(),
            ]);

            return response()->json([
                'status' => true,
                'message' => 'Konten marketing berhasil diunggah.',
                'data' => $content,
            ], 201);
        } catch (\\Exception $e) {
            return response()->json([
                'status' => false,
                'message' => 'Gagal mengunggah konten marketing: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Delete marketing content.
     */
    public function destroy($id)
    {
        try {
            $content = MarketingContent::findOrFail($id);
            if (Storage::disk('public')->exists($content->file_path)) {
                Storage::disk('public')->delete($content->file_path);
            }
            $content->delete();

            return response()->json([
                'status' => true,
                'message' => 'Konten marketing berhasil dihapus.',
            ]);
        } catch (\\Exception $e) {
            return response()->json([
                'status' => false,
                'message' => 'Gagal menghapus konten marketing: ' . $e->getMessage(),
            ], 500);
        }
    }
}
"""

with open(controller_path, 'w', encoding='utf-8') as f:
    f.write(controller_code)
print("Created MarketingContentApiController.php successfully!")

# Update routes/api.php
with open(api_routes_path, 'r', encoding='utf-8') as f:
    api_content = f.read()

if 'konten-marketing' not in api_content:
    routes_to_add = """
    /*
    |--------------------------------------------------------------------------
    | KONTEN MARKETING (MARKETING CONTENT)
    |--------------------------------------------------------------------------
    */
    Route::prefix('konten-marketing')->middleware('role:cs,operasional,admin,ceo,finance,hrd,cleaner,designer')->group(function () {
        Route::get('/', [\\App\Http\Controllers\Api\MarketingContentApiController::class, 'index']);
        Route::get('/{id}', [\\App\Http\Controllers\Api\MarketingContentApiController::class, 'show']);
        Route::post('/', [\\App\Http\Controllers\Api\MarketingContentApiController::class, 'store']);
        Route::delete('/{id}', [\\App\Http\Controllers\Api\MarketingContentApiController::class, 'destroy']);
    });
});
"""
    # replace the last "});" with routes_to_add
    idx = api_content.rfind('});')
    if idx != -1:
        api_content = api_content[:idx] + routes_to_add
        with open(api_routes_path, 'w', encoding='utf-8') as f:
            f.write(api_content)
        print("Added konten-marketing routes to routes/api.php successfully!")
    else:
        print("Could not find ending of routes group in routes/api.php")
else:
    print("konten-marketing routes already exist in routes/api.php!")

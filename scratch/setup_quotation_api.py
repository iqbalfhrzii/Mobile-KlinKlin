import re

api_routes_path = r'c:\Users\HP VICTUS\Documents\Laravel\API_KLINKLIN\routes\api.php'
quotation_ctrl_path = r'c:\Users\HP VICTUS\Documents\Laravel\API_KLINKLIN\app\Http\Controllers\Api\QuotationApiController.php'

# 1. Update QuotationApiController.php
new_controller_code = """<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Quotation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class QuotationApiController extends Controller
{
    public function index(Request $request)
    {
        $query = Quotation::with(['cabang', 'pembuat', 'penyetuju']);
        
        if ($request->has('search') && !empty($request->search)) {
            $search = $request->search;
            $query->where(function($q) use ($search) {
                $q->where('no_quotation', 'like', "%{$search}%")
                  ->orWhere('nama_customer', 'like', "%{$search}%");
            });
        }

        if ($request->has('status') && !empty($request->status) && $request->status !== 'Semua Status' && $request->status !== 'Semua') {
            $query->where('status', $request->status);
        }

        if ($request->has('cabang_id') && !empty($request->cabang_id)) {
            $query->where('cabang_id', $request->cabang_id);
        }

        $quotations = $query->latest()->paginate(15);
        
        // Map data to include calculated attributes
        $quotations->getCollection()->transform(function($q) {
            $q->subtotal_calc = $q->subtotal;
            $q->ppn_nominal_calc = $q->ppn_nominal;
            $q->pph_nominal_calc = $q->pph_nominal;
            $q->grand_total_calc = $q->grand_total;
            return $q;
        });

        return response()->json([
            'status' => true,
            'data' => $quotations
        ]);
    }

    public function show($id)
    {
        $quotation = Quotation::with(['cabang', 'pembuat', 'penyetuju'])->findOrFail($id);
        
        $quotation->subtotal_calc = $quotation->subtotal;
        $quotation->ppn_nominal_calc = $quotation->ppn_nominal;
        $quotation->pph_nominal_calc = $quotation->pph_nominal;
        $quotation->grand_total_calc = $quotation->grand_total;

        return response()->json([
            'status' => true,
            'data' => $quotation
        ]);
    }

    public function store(Request $request)
    {
        $user = $request->user();
        $fallbackCabangId = $user ? ($user->cabang_id ?? ($user->karyawan ? $user->karyawan->cabang_id : null)) : null;

        $request->validate([
            'tanggal' => 'required|date',
            'exp_date' => 'required|date',
            'cabang_id' => 'nullable|exists:cabangs,id',
            'nama_customer' => 'required|string|max:255',
            'no_wa_customer' => 'required|string|max:20',
            'alamat' => 'required|string',
            'job_location' => 'nullable|string',
            'rincian' => 'required|array',
            'rincian.*.deskripsi' => 'required|string',
            'rincian.*.qty' => 'required|numeric',
            'rincian.*.harga' => 'required|numeric',
            'alat_chemical_klinklin' => 'boolean',
            'diskon' => 'nullable|numeric',
            'ppn' => 'nullable|numeric',
            'pph' => 'nullable|numeric',
        ]);

        try {
            DB::beginTransaction();

            $cabangId = $request->cabang_id ?? $fallbackCabangId ?? 1;
            $dibuatOlehId = $user ? ($user->karyawan_id ?? $user->id) : 1;

            $bulan = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII'];
            $currentMonth = $bulan[date('n') - 1];
            $year = date('Y');
            
            $lastQuotation = Quotation::whereYear('created_at', $year)->orderBy('id', 'desc')->first();
            $nextNumber = 1;
            if ($lastQuotation && preg_match('/\/(\d+)$/', $lastQuotation->no_quotation, $matches)) {
                $nextNumber = intval($matches[1]) + 1;
            }
            $no_quotation = "QUO/KLINKLIN/{$currentMonth}/{$year}/{$nextNumber}";

            $quotation = Quotation::create([
                'no_quotation' => $no_quotation,
                'tanggal' => $request->tanggal,
                'exp_date' => $request->exp_date,
                'cabang_id' => $cabangId,
                'nama_customer' => $request->nama_customer,
                'no_wa_customer' => $request->no_wa_customer,
                'alamat' => $request->alamat,
                'job_location' => $request->job_location,
                'rincian' => $request->rincian,
                'alat_chemical_klinklin' => $request->alat_chemical_klinklin ?? false,
                'diskon' => $request->diskon ?? 0,
                'ppn' => $request->ppn ?? 0,
                'pph' => $request->pph ?? 0,
                'status' => 'Pending',
                'dibuat_oleh_id' => $dibuatOlehId,
            ]);

            DB::commit();

            return response()->json([
                'status' => true,
                'message' => 'Quotation berhasil dibuat',
                'data' => $quotation
            ]);
        } catch (\\Exception $e) {
            DB::rollBack();
            return response()->json([
                'status' => false,
                'message' => 'Gagal membuat quotation: ' . $e->getMessage()
            ], 500);
        }
    }

    public function update(Request $request, $id)
    {
        $quotation = Quotation::findOrFail($id);

        $request->validate([
            'tanggal' => 'required|date',
            'exp_date' => 'required|date',
            'nama_customer' => 'required|string|max:255',
            'no_wa_customer' => 'required|string|max:20',
            'alamat' => 'required|string',
            'job_location' => 'nullable|string',
            'rincian' => 'required|array',
            'rincian.*.deskripsi' => 'required|string',
            'rincian.*.qty' => 'required|numeric',
            'rincian.*.harga' => 'required|numeric',
            'alat_chemical_klinklin' => 'boolean',
            'diskon' => 'nullable|numeric',
            'ppn' => 'nullable|numeric',
            'pph' => 'nullable|numeric',
        ]);

        try {
            DB::beginTransaction();

            $quotation->update([
                'tanggal' => $request->tanggal,
                'exp_date' => $request->exp_date,
                'nama_customer' => $request->nama_customer,
                'no_wa_customer' => $request->no_wa_customer,
                'alamat' => $request->alamat,
                'job_location' => $request->job_location,
                'rincian' => $request->rincian,
                'alat_chemical_klinklin' => $request->alat_chemical_klinklin ?? false,
                'diskon' => $request->diskon ?? 0,
                'ppn' => $request->ppn ?? 0,
                'pph' => $request->pph ?? 0,
            ]);

            DB::commit();

            return response()->json([
                'status' => true,
                'message' => 'Quotation berhasil diperbarui',
                'data' => $quotation
            ]);
        } catch (\\Exception $e) {
            DB::rollBack();
            return response()->json([
                'status' => false,
                'message' => 'Gagal memperbarui quotation: ' . $e->getMessage()
            ], 500);
        }
    }

    public function approve(Request $request, $id)
    {
        try {
            $quotation = Quotation::findOrFail($id);
            $userId = $request->user() ? ($request->user()->id) : 1;

            $quotation->update([
                'status' => 'Disetujui',
                'disetujui_oleh_id' => $userId,
                'tanggal_persetujuan' => now(),
                'catatan_persetujuan' => $request->catatan_persetujuan,
            ]);

            return response()->json([
                'status' => true,
                'message' => 'Quotation berhasil disetujui',
                'data' => $quotation
            ]);
        } catch (\\Exception $e) {
            return response()->json([
                'status' => false,
                'message' => 'Gagal menyetujui quotation: ' . $e->getMessage()
            ], 500);
        }
    }

    public function reject(Request $request, $id)
    {
        try {
            $quotation = Quotation::findOrFail($id);
            $userId = $request->user() ? ($request->user()->id) : 1;

            $quotation->update([
                'status' => 'Ditolak',
                'disetujui_oleh_id' => $userId,
                'tanggal_persetujuan' => now(),
                'catatan_persetujuan' => $request->catatan_persetujuan,
            ]);

            return response()->json([
                'status' => true,
                'message' => 'Quotation berhasil ditolak',
                'data' => $quotation
            ]);
        } catch (\\Exception $e) {
            return response()->json([
                'status' => false,
                'message' => 'Gagal menolak quotation: ' . $e->getMessage()
            ], 500);
        }
    }

    public function destroy($id)
    {
        try {
            $quotation = Quotation::findOrFail($id);
            $quotation->delete();

            return response()->json([
                'status' => true,
                'message' => 'Quotation berhasil dihapus'
            ]);
        } catch (\\Exception $e) {
            return response()->json([
                'status' => false,
                'message' => 'Gagal menghapus quotation: ' . $e->getMessage()
            ], 500);
        }
    }
}
"""

with open(quotation_ctrl_path, 'w', encoding='utf-8') as f:
    f.write(new_controller_code)
print("Updated QuotationApiController.php!")

# 2. Update routes/api.php
with open(api_routes_path, 'r', encoding='utf-8') as f:
    routes_code = f.read()

route_block = """
    /*
    |--------------------------------------------------------------------------
    | QUOTATION (DATA PENAWARAN) ROUTES
    |--------------------------------------------------------------------------
    */
    Route::prefix('operasional/quotation')->middleware('role:cs,operasional,admin,ceo,hrd,finance,customer service')->group(function () {
        Route::get('/', [\\App\\Http\\Controllers\\Api\\QuotationApiController::class, 'index']);
        Route::get('/{id}', [\\App\\Http\\Controllers\\Api\\QuotationApiController::class, 'show']);
        Route::post('/', [\\App\\Http\\Controllers\\Api\\QuotationApiController::class, 'store']);
        Route::put('/{id}', [\\App\\Http\\Controllers\\Api\\QuotationApiController::class, 'update']);
        Route::delete('/{id}', [\\App\\Http\\Controllers\\Api\\QuotationApiController::class, 'destroy']);
        Route::post('/{id}/approve', [\\App\\Http\\Controllers\\Api\\QuotationApiController::class, 'approve']);
        Route::post('/{id}/reject', [\\App\\Http\\Controllers\\Api\\QuotationApiController::class, 'reject']);
    });
"""

if 'QuotationApiController' not in routes_code:
    # Insert before the last closing }); in Route::middleware('auth:sanctum')
    # Find position before last '});'
    pos = routes_code.rfind('});')
    if pos != -1:
        routes_code = routes_code[:pos] + route_block + "\n" + routes_code[pos:]
        with open(api_routes_path, 'w', encoding='utf-8') as f:
            f.write(routes_code)
        print("Added quotation routes to routes/api.php!")
    else:
        print("Could not find closing }); in routes/api.php")
else:
    print("QuotationApiController already in routes/api.php!")

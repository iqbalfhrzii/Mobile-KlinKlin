import re

api_routes_path = r'c:\Users\HP VICTUS\Documents\Laravel\API_KLINKLIN\routes\api.php'
absensi_ctrl_path = r'c:\Users\HP VICTUS\Documents\Laravel\API_KLINKLIN\app\Http\Controllers\Api\AbsensiController.php'

# 1. Update routes/api.php
with open(api_routes_path, 'r', encoding='utf-8') as f:
    api_content = f.read()

target_route = """    Route::prefix('absensi')->group(function () {
        Route::middleware('role:cleaner,cs')->group(function () {
            Route::post('/check-in', [AbsensiController::class, 'checkIn']);
            Route::post('/check-out', [AbsensiController::class, 'checkOut']);
            Route::get('/saya', [AbsensiController::class, 'saya']);
        });

        Route::middleware('role:admin,hrd,finance')->group(function () {
            Route::get('/riwayat', [AbsensiController::class, 'riwayat']);
            Route::get('/detail-bulanan/{karyawan_id}', [AbsensiController::class, 'detailBulanan']);
            Route::get('/{absensi}/selfie', [AbsensiController::class, 'selfie']);
        });

        Route::get('/{absensi}', [AbsensiController::class, 'show']);
    });"""

replacement_route = """    Route::prefix('absensi')->group(function () {
        Route::middleware('role:cleaner,cs,customer service,admin,hrd,finance,operasional,ceo')->group(function () {
            Route::post('/check-in', [AbsensiController::class, 'checkIn']);
            Route::post('/check-out', [AbsensiController::class, 'checkOut']);
            Route::get('/saya', [AbsensiController::class, 'saya']);
            Route::get('/riwayat', [AbsensiController::class, 'riwayat']);
            Route::get('/detail-bulanan/{karyawan_id}', [AbsensiController::class, 'detailBulanan']);
            Route::get('/{absensi}/selfie', [AbsensiController::class, 'selfie']);
        });

        Route::get('/{absensi}', [AbsensiController::class, 'show']);
    });"""

if target_route in api_content:
    api_content = api_content.replace(target_route, replacement_route)
    with open(api_routes_path, 'w', encoding='utf-8') as f:
        f.write(api_content)
    print("Updated routes/api.php successfully!")
else:
    print("Could not find exact target block in routes/api.php, attempting regex replace...")
    api_content = re.sub(
        r"Route::middleware\('role:admin,hrd,finance'\)->group\(function \(\) \{\s*Route::get\('/riwayat'.*?Route::get\('/\{absensi\}/selfie'.*?\}\);",
        """Route::middleware('role:admin,hrd,finance,cs,cleaner,operasional,ceo')->group(function () {
            Route::get('/riwayat', [AbsensiController::class, 'riwayat']);
            Route::get('/detail-bulanan/{karyawan_id}', [AbsensiController::class, 'detailBulanan']);
            Route::get('/{absensi}/selfie', [AbsensiController::class, 'selfie']);
        });""",
        api_content,
        flags=re.DOTALL
    )
    with open(api_routes_path, 'w', encoding='utf-8') as f:
        f.write(api_content)
    print("Regex updated routes/api.php!")

# 2. Update AbsensiController.php
with open(absensi_ctrl_path, 'r', encoding='utf-8') as f:
    ctrl_content = f.read()

# Replace selfie method
target_selfie = """    public function selfie(Request $request, Absensi $absensi): StreamedResponse|JsonResponse
    {
        if (! Storage::disk('local')->exists($absensi->selfie_path)) {
            return $this->errorResponse('Selfie absensi tidak ditemukan', 404);
        }

        return Storage::disk('local')->download($absensi->selfie_path);
    }"""

replacement_selfie = """    public function selfie(Request $request, Absensi $absensi)
    {
        if (! $this->canViewAbsensi($request->user(), $absensi)) {
            return $this->errorResponse('Anda tidak boleh mengakses absensi ini', 403);
        }

        if (! Storage::disk('local')->exists($absensi->selfie_path)) {
            return $this->errorResponse('Selfie absensi tidak ditemukan', 404);
        }

        return Storage::disk('local')->response($absensi->selfie_path);
    }"""

if target_selfie in ctrl_content:
    ctrl_content = ctrl_content.replace(target_selfie, replacement_selfie)
    print("Updated selfie() in AbsensiController.php!")

# Replace hasRiwayatAccess and canViewAbsensi
target_can_view = """    private function hasRiwayatAccess(?Karyawan $karyawan): bool
    {
        $role = strtolower((string) $karyawan?->loadMissing('jabatan')->jabatan?->nama_jabatan);

        return in_array($role, ['admin', 'hrd', 'finance'], true);
    }

    private function canViewAbsensi(?Karyawan $karyawan, Absensi $absensi): bool
    {
        if (! $karyawan) {
            return false;
        }

        return $this->hasRiwayatAccess($karyawan)
            || ($this->isEligibleForAbsensi($karyawan) && $absensi->karyawan_id === $karyawan->id);
    }"""

replacement_can_view = """    private function hasRiwayatAccess(?Karyawan $karyawan): bool
    {
        $role = strtolower((string) $karyawan?->loadMissing('jabatan')->jabatan?->nama_jabatan);

        return in_array($role, ['admin', 'hrd', 'finance', 'operasional', 'ceo'], true);
    }

    private function canViewAbsensi(?Karyawan $karyawan, Absensi $absensi): bool
    {
        if (! $karyawan) {
            return false;
        }

        $role = strtolower((string) $karyawan->loadMissing('jabatan')->jabatan?->nama_jabatan);

        if ($this->hasRiwayatAccess($karyawan)) {
            return true;
        }

        // CS dapat melihat absensi staf/cleaner di cabangnya
        if (in_array($role, ['cs', 'customer service'], true) || str_contains($role, 'cs')) {
            return $absensi->cabang_id === $karyawan->cabang_id;
        }

        // Cleaner hanya melihat absensi miliknya sendiri
        return $absensi->karyawan_id === $karyawan->id;
    }"""

if target_can_view in ctrl_content:
    ctrl_content = ctrl_content.replace(target_can_view, replacement_can_view)
    print("Updated canViewAbsensi() in AbsensiController.php!")

with open(absensi_ctrl_path, 'w', encoding='utf-8') as f:
    f.write(ctrl_content)
print("AbsensiController.php written successfully!")

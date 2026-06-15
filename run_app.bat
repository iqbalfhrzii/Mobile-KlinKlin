@echo off
echo ==============================================
echo 🚀 Klinklin Flutter Auto-Fix Run Script
echo ==============================================

echo [1/3] Menghapus folder build lama (jika ada)...
rmdir /Q /S "C:\Users\HP VICTUS\Documents\Mobile\build" 2>nul

echo [2/3] Membuat junction path pendek untuk mencegah error Windows...
mklink /J "C:\Users\HP VICTUS\Documents\Mobile\build" "C:\KlinklinBuild"

echo [3/3] Menjalankan aplikasi ke device...
C:\flutter\bin\flutter.bat run -d 19301FDEE003AS --debug

echo Selesai!
pause

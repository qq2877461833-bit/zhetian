@echo off
title Zhetian - Fix Build & Export
echo ==========================================
echo   ZheTian - Fix Build (clean fonts + export)
echo ==========================================
cd /d "%~dp0"

echo [1/3] Cleaning font temp files (fix woff2 import hang)...
del /q "assets\fonts\*.tmp" 2>nul
del /q "assets\fonts\*.woff2" 2>nul
del /q "assets\fonts\*.woff2.import" 2>nul
echo   done.

echo [2/3] Removing broken .godot cache...
rmdir /s /q ".godot" 2>nul
echo   done.

echo [3/3] Exporting Web build...
"C:\Users\yanglimei\Desktop\Godot_v4.4-stable_win64.exe" --headless --path "%~dp0" --export-release "Web" "%~dp0build\web\index.html"
if errorlevel 1 ( echo EXPORT FAILED & pause & exit /b 1 )
echo   export OK: 
dir /b "build\web\index.pck" 2>nul | findstr pck && echo pck exists

echo.
echo ==========================================
echo   DONE! Start server: start_server.bat
echo   Then open: http://localhost:8137/index.html
echo ==========================================
pause

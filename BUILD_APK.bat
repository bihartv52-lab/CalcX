@echo off
echo ========================================
echo   Calcx Social App - APK Builder
echo ========================================
echo.

echo [1/5] Checking Flutter setup...
G:\flutter\bin\flutter.bat doctor

echo.
echo [2/5] Cleaning previous builds...
G:\flutter\bin\flutter.bat clean

echo.
echo [3/5] Getting dependencies...
G:\flutter\bin\flutter.bat pub get

echo.
echo [4/5] Building APK (Release mode)...
echo.
echo NOTE: This may take 5-10 minutes on first build.
echo Please be patient...
echo.

G:\flutter\bin\flutter.bat build apk --release

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo   ✅ APK BUILD SUCCESSFUL!
    echo ========================================
    echo.
    echo APK Location:
    echo %CD%\build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo File Size:
    for %%A in (build\app\outputs\flutter-apk\app-release.apk) do echo %%~zA bytes
    echo.
    echo You can now:
    echo 1. Copy APK to your phone
    echo 2. Install it
    echo 3. Enjoy your app!
    echo.
    
    REM Open folder with APK
    echo Opening APK folder...
    explorer build\app\outputs\flutter-apk
) else (
    echo.
    echo ========================================
    echo   ❌ BUILD FAILED!
    echo ========================================
    echo.
    echo Please check the error messages above.
    echo Common fixes:
    echo 1. Run: flutter clean
    echo 2. Run: flutter pub get
    echo 3. Try again
    echo.
)

echo.
pause

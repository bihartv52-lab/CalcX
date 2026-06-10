@echo off
echo ========================================
echo CalcX App Testing Script
echo ========================================
echo.

echo Checking Flutter installation...
where flutter >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter not found in PATH
    echo Please add G:\flutter\bin to your PATH
    pause
    exit /b 1
)

echo Flutter found!
echo.

echo Current directory: %CD%
cd /d G:\Calcx

echo.
echo ========================================
echo Step 1: Cleaning previous builds...
echo ========================================
G:\flutter\bin\flutter clean

echo.
echo ========================================
echo Step 2: Getting dependencies...
echo ========================================
G:\flutter\bin\flutter pub get

echo.
echo ========================================
echo Step 3: Checking for connected devices...
echo ========================================
G:\flutter\bin\flutter devices

echo.
echo ========================================
echo TESTING OPTIONS:
echo ========================================
echo 1. Run on connected device/emulator
echo 2. Build APK for testing
echo 3. Run diagnostics only
echo 4. Exit
echo.

set /p choice="Enter your choice (1-4): "

if "%choice%"=="1" (
    echo.
    echo Starting app on connected device...
    G:\flutter\bin\flutter run
) else if "%choice%"=="2" (
    echo.
    echo Building APK...
    G:\flutter\bin\flutter build apk --release
    echo.
    echo APK built successfully!
    echo Location: G:\Calcx\build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo Copy to G:\ drive?
    set /p copy="(Y/N): "
    if /i "%copy%"=="Y" (
        copy "G:\Calcx\build\app\outputs\flutter-apk\app-release.apk" "G:\calcx-release.apk"
        echo APK copied to G:\calcx-release.apk
    )
) else if "%choice%"=="3" (
    echo.
    echo Running diagnostics...
    G:\flutter\bin\flutter doctor -v
    echo.
    echo Analyzing code...
    G:\flutter\bin\flutter analyze
) else (
    echo Exiting...
    exit /b 0
)

echo.
echo ========================================
echo Test complete!
echo ========================================
pause

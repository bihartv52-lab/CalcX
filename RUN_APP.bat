@echo off
echo ========================================
echo   Calcx Social App - Launcher
echo ========================================
echo.

REM Check if Flutter is installed
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter is not installed or not in PATH!
    echo.
    echo Please install Flutter from: https://flutter.dev/docs/get-started/install/windows
    echo Or add Flutter to your PATH environment variable.
    echo.
    pause
    exit /b 1
)

echo [1/4] Checking Flutter setup...
flutter doctor -v

echo.
echo [2/4] Getting dependencies...
flutter pub get

echo.
echo [3/4] Checking for connected devices...
flutter devices

echo.
echo [4/4] Running app...
echo.
echo NOTE: First build may take 2-5 minutes.
echo.

flutter run

pause

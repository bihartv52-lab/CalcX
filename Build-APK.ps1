# Calcx APK Builder - PowerShell Script
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Calcx Social App - APK Builder" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to find Flutter
function Find-Flutter {
    $commonPaths = @(
        "C:\flutter\bin\flutter.bat",
        "C:\src\flutter\bin\flutter.bat",
        "$env:LOCALAPPDATA\flutter\bin\flutter.bat",
        "$env:USERPROFILE\flutter\bin\flutter.bat",
        "D:\flutter\bin\flutter.bat"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    # Try to find in PATH
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutterCmd) {
        return $flutterCmd.Source
    }
    
    return $null
}

# Find Flutter
Write-Host "[1/5] Searching for Flutter installation..." -ForegroundColor Yellow
$flutterPath = Find-Flutter

if (-not $flutterPath) {
    Write-Host ""
    Write-Host "ERROR: Flutter not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Flutter:" -ForegroundColor Yellow
    Write-Host "1. Download from: https://flutter.dev/docs/get-started/install/windows" -ForegroundColor White
    Write-Host "2. Extract to C:\flutter" -ForegroundColor White
    Write-Host "3. Add C:\flutter\bin to PATH" -ForegroundColor White
    Write-Host "4. Run this script again" -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "✓ Flutter found at: $flutterPath" -ForegroundColor Green
Write-Host ""

# Check Flutter
Write-Host "[2/5] Checking Flutter setup..." -ForegroundColor Yellow
& $flutterPath doctor

Write-Host ""
Write-Host "[3/5] Cleaning previous builds..." -ForegroundColor Yellow
& $flutterPath clean

Write-Host ""
Write-Host "[4/5] Getting dependencies..." -ForegroundColor Yellow
& $flutterPath pub get

Write-Host ""
Write-Host "[5/5] Building APK (Release mode)..." -ForegroundColor Yellow
Write-Host ""
Write-Host "NOTE: This may take 5-10 minutes on first build." -ForegroundColor Cyan
Write-Host "Please be patient..." -ForegroundColor Cyan
Write-Host ""

& $flutterPath build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  ✓ APK BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
        $apkSize = (Get-Item $apkPath).Length
        $apkSizeMB = [math]::Round($apkSize / 1MB, 2)
        
        Write-Host "APK Location:" -ForegroundColor Cyan
        Write-Host "  $PWD\$apkPath" -ForegroundColor White
        Write-Host ""
        Write-Host "File Size: $apkSizeMB MB" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "You can now:" -ForegroundColor Yellow
        Write-Host "  1. Copy APK to your phone" -ForegroundColor White
        Write-Host "  2. Install it" -ForegroundColor White
        Write-Host "  3. Enjoy your app!" -ForegroundColor White
        Write-Host ""
        
        # Open folder
        Write-Host "Opening APK folder..." -ForegroundColor Cyan
        Start-Process "build\app\outputs\flutter-apk"
    }
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  ✗ BUILD FAILED!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please check the error messages above." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Common fixes:" -ForegroundColor Cyan
    Write-Host "  1. Run: flutter clean" -ForegroundColor White
    Write-Host "  2. Run: flutter pub get" -ForegroundColor White
    Write-Host "  3. Try again" -ForegroundColor White
    Write-Host ""
}

Write-Host ""
Read-Host "Press Enter to exit"

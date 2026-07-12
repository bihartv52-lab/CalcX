@echo off
title CalcX APK Builder (F: Volume)
echo ==================================================
echo             CALCX APK BUILDER (F: DRIVE)
echo ==================================================
echo.

:: Detect Java Home from Android Studio if it exists
if exist "C:\Program Files\Android\Android Studio\jbr" (
    set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
    echo [INFO] Detected Java JDK at: C:\Program Files\Android\Android Studio\jbr
)

set "FLUTTER_BIN=F:\flutter\bin\flutter.bat"

echo.
echo Step 1: Cleaning previous build cache...
call "%FLUTTER_BIN%" clean
if %ERRORLEVEL% neq 0 (
    echo [WARNING] Flutter clean failed, continuing anyway...
)
echo.

echo Step 2: Fetching dependencies...
call "%FLUTTER_BIN%" pub get
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to fetch dependencies.
    goto fail
)
echo.

echo Step 3: Building Release APK...
echo (This may take several minutes on the first build...)
call "%FLUTTER_BIN%" build apk --release
if %ERRORLEVEL% neq 0 (
    goto fail
)
echo.

echo Step 4: Copying APK to F:\ volume...
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    copy /Y "build\app\outputs\flutter-apk\app-release.apk" "F:\CalcX.apk"
    echo.
    echo ==================================================
    echo ✅ SUCCESS! APK copied to: F:\CalcX.apk
    echo ==================================================
    goto end
) else (
    echo [ERROR] Release APK was not found in the output directory.
    goto fail
)

:fail
echo.
echo ==================================================
echo ❌ BUILD FAILED!
echo ==================================================
echo Please check the error messages above.
pause
exit /b 1

:end
echo.
pause
exit /b 0

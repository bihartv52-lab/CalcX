@echo off
title CalcX APK Build
echo ========================================
echo   Building CalcX APK (please wait)
echo ========================================

set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
set "FLUTTER_ROOT=C:\Users\avigu\Downloads\flutter_windows_3.41.9-stable\flutter"
set "PATH=%FLUTTER_ROOT%\bin;%PATH%"
set "GRADLE_USER_HOME=G:\dev\gradle"
set "PUB_CACHE=G:\dev\pub-cache"
set "TEMP=G:\dev\temp"
set "TMP=G:\dev\temp"

cd /d G:\Calcx

echo.
echo Step 1: flutter pub get
call flutter pub get
if errorlevel 1 goto fail

echo.
echo Step 2: build APK (arm64, debug = faster for testing)
call flutter build apk --debug --target-platform android-arm64
if errorlevel 1 goto fail

echo.
echo Step 3: copy APK to G:\CalcX.apk
if exist "build\app\outputs\flutter-apk\app-debug.apk" (
  copy /Y "build\app\outputs\flutter-apk\app-debug.apk" "G:\CalcX.apk"
  echo.
  echo SUCCESS! APK saved to: G:\CalcX.apk
  echo Install on phone: copy G:\CalcX.apk to phone and open it.
) else (
  echo APK not found in build folder.
  goto fail
)
goto end

:fail
echo.
echo BUILD FAILED. Open G:\dev\calcx-build.log if you ran with logging.
pause
exit /b 1

:end
pause
exit /b 0

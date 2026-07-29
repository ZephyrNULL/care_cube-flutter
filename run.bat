@echo off
title Care Cube - Flutter Run
color 0A

echo ============================================
echo   Care Cube - Smart Medicine Box
echo ============================================
echo.
echo Setting up environment...
echo.

set "PATH=C:\Windows\System32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0;C:\Windows\System32\OpenSSH;C:\Users\Chamindu\flutter\bin;C:\Program Files\Git\cmd"
set "ANDROID_HOME=C:\Users\Chamindu\AppData\Local\Android\Sdk"
set "ANDROID_SDK_ROOT=C:\Users\Chamindu\AppData\Local\Android\Sdk"

cd /d "C:\Users\Chamindu\Desktop\care_cube_flutter\care_cube_app"

echo [1/4] Checking flutter...
flutter --version
echo.

echo [2/4] Checking connected devices...
flutter devices
echo.

echo [3/4] Building and running app...
echo This may take a few minutes on first run...
echo.

flutter run

echo.
echo ============================================
echo   App stopped. Exit code: %ERRORLEVEL%
echo ============================================
pause

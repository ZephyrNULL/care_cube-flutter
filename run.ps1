$ErrorActionPreference = "Continue"
$env:PATH = "C:\Windows\System32;C:\Windows;C:\Users\Chamindu\flutter\bin;C:\Program Files\Git\cmd;" + $env:PATH
$env:ANDROID_HOME = "C:\Users\Chamindu\AppData\Local\Android\Sdk"
$env:ANDROID_SDK_ROOT = "C:\Users\Chamindu\AppData\Local\Android\Sdk"

Set-Location "C:\Users\Chamindu\Desktop\care_cube_flutter\care_cube_app"

Write-Host "========================================" -ForegroundColor Green
Write-Host "  Care Cube - Flutter Run" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Checking flutter..." -ForegroundColor Yellow
flutter --version
Write-Host ""

Write-Host "Running app..." -ForegroundColor Yellow
flutter run

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

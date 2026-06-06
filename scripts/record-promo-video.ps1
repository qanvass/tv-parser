# record-promo-video.ps1
# Locks orientation, forces TV layout, runs screenrecord, and automates navigation.

$ErrorActionPreference = "Stop"

$adb = "C:\Users\Qanva\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$outDir = "C:\Users\Qanva\Desktop\TV Parcer\store_release_package"

if (!(Test-Path $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

# ── Step 1: Force Rotation Lock to Landscape ─────────────────────────
Write-Host "Locking device orientation to Landscape..." -ForegroundColor Yellow
& $adb shell settings put system accelerometer_rotation 0
& $adb shell settings put system user_rotation 1
Start-Sleep -Seconds 2

# ── Step 2: Force Resolution & Density ────────────────────────────────
Write-Host "Setting device to 1920x1080 mode (density 240)..." -ForegroundColor Yellow
& $adb shell wm size 1920x1080
& $adb shell wm density 240
Start-Sleep -Seconds 3

# Force stop app to start clean
Write-Host "Resetting application..."
& $adb shell am force-stop com.quasar.tvparser
Start-Sleep -Seconds 1

# ── Step 3: Start Screen Recording ───────────────────────────────────
Write-Host "Starting screen recording (45 seconds limit)..." -ForegroundColor Green
$recProcess = Start-Process $adb -ArgumentList "shell screenrecord --size 1920x1080 --bit-rate 8000000 --time-limit 45 /sdcard/promo_video.mp4" -PassThru
Start-Sleep -Seconds 1

# Launch the app
& $adb shell am start -n com.quasar.tvparser/com.quasar.tvparser.MainActivity | Out-Null

try {
    # ── Walkthrough Navigation ───────────────────────────────────────
    Write-Host "1. Booting app and loading playlists..."
    Start-Sleep -Seconds 12 # Splash screen + dashboard load

    Write-Host "2. Focusing Live TV channel card..."
    & $adb shell input keyevent 22 # Right
    Start-Sleep -Seconds 2

    Write-Host "3. Returning to navigation rail..."
    & $adb shell input keyevent 21 # Left
    Start-Sleep -Seconds 1

    Write-Host "4. Navigating to Movies Catalog..."
    & $adb shell input keyevent 20 # Down to Movies
    Start-Sleep -Seconds 1
    & $adb shell input keyevent 23 # Enter to select
    Start-Sleep -Seconds 4 # Let content load

    Write-Host "5. Focusing a Movie card..."
    & $adb shell input keyevent 22 # Right
    Start-Sleep -Seconds 2

    Write-Host "6. Returning to navigation rail..."
    & $adb shell input keyevent 21 # Left
    Start-Sleep -Seconds 1

    Write-Host "7. Navigating to Series Catalog..."
    & $adb shell input keyevent 20 # Down to Series
    Start-Sleep -Seconds 1
    & $adb shell input keyevent 23 # Enter to select
    Start-Sleep -Seconds 4 # Let content load

    Write-Host "8. Returning to navigation rail..."
    & $adb shell input keyevent 21 # Left
    Start-Sleep -Seconds 1

    Write-Host "9. Navigating to Settings..."
    & $adb shell input keyevent 20 # Down to Settings
    Start-Sleep -Seconds 1
    & $adb shell input keyevent 23 # Enter to select
    Start-Sleep -Seconds 3 # Let Settings load

    Write-Host "10. Navigating to Connection Diagnostics..."
    & $adb shell input keyevent 20 # Down to Diagnostics
    Start-Sleep -Seconds 1
    & $adb shell input keyevent 23 # Enter to launch
    Start-Sleep -Seconds 5 # Run diagnostics

    Write-Host "Waiting for recording process to conclude..." -ForegroundColor Yellow
    $recProcess.WaitForExit()

    # Pull the recording
    Write-Host "Pulling video file from device..." -ForegroundColor Green
    & $adb pull /sdcard/promo_video.mp4 (Join-Path $outDir "promo_video.mp4")
    & $adb shell rm /sdcard/promo_video.mp4
    Write-Host "Saved promo video to: $(Join-Path $outDir 'promo_video.mp4')" -ForegroundColor Green

} finally {
    # ── Clean up device resolution & rotation ────────────────────────
    Write-Host "Restoring device size, density, and rotation..." -ForegroundColor Yellow
    & $adb shell wm size reset
    & $adb shell wm density reset
    & $adb shell settings put system accelerometer_rotation 1
    & $adb shell settings put system user_rotation 0
    & $adb shell am force-stop com.quasar.tvparser
    Write-Host "Restore complete." -ForegroundColor Green
}

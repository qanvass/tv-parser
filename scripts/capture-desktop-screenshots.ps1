# capture-desktop-screenshots.ps1
# Automates navigation and captures 8 Chromebook / Desktop screenshots in 16:9 aspect ratio (1920x1080)

$ErrorActionPreference = "Stop"

$adb = "C:\Users\Qanva\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$outDir = "C:\Users\Qanva\Desktop\TV Parcer\store_release_package"

if (!(Test-Path $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

function Take-Screenshot {
    param([string]$filename)
    $remotePath = "/sdcard/$filename"
    $localPath = Join-Path $outDir $filename

    Write-Host "Capturing $filename..." -ForegroundColor Cyan
    & $adb shell screencap -p $remotePath
    & $adb pull $remotePath $localPath
    & $adb shell rm $remotePath
    Write-Host "Saved to $localPath" -ForegroundColor Green
}

# ── Step 1: Force Rotation Lock to Landscape ─────────────────────────
Write-Host "Locking device orientation to Landscape..." -ForegroundColor Yellow
& $adb shell settings put system accelerometer_rotation 0
& $adb shell settings put system user_rotation 1
Start-Sleep -Seconds 2

# ── Step 2: Force Desktop Resolution & Density ────────────────────────
Write-Host "Setting device to 1920x1080 mode (density 240)..." -ForegroundColor Yellow
& $adb shell wm size 1920x1080
& $adb shell wm density 240
Start-Sleep -Seconds 3

# Force stop app to start clean
Write-Host "Restarting application..."
& $adb shell am force-stop com.quasar.tvparser
Start-Sleep -Seconds 1
& $adb shell am start -n com.quasar.tvparser/com.quasar.tvparser.MainActivity | Out-Null
Write-Host "Waiting for application to boot and load playlist data..." -ForegroundColor Yellow
Start-Sleep -Seconds 15  # Wait for splash video + playlists load

try {
    # ── Screen 1: desktop_live.png (Live TV Dashboard) ────────────────────
    Take-Screenshot "desktop_live.png"

    # ── Screen 2: desktop_live_focused.png (Live TV with Focused Card) ────
    Write-Host "Focusing first Live channel card..."
    & $adb shell input keyevent 22 # Right
    Start-Sleep -Seconds 2
    Take-Screenshot "desktop_live_focused.png"

    # ── Screen 3: desktop_movies.png (Movies Tab) ─────────────────────────
    Write-Host "Navigating back to rail..."
    & $adb shell input keyevent 21 # Left
    Start-Sleep -Seconds 1
    Write-Host "Focusing Movies rail item..."
    & $adb shell input keyevent 20 # Down
    Start-Sleep -Seconds 1
    Write-Host "Selecting Movies..."
    & $adb shell input keyevent 23 # Enter
    Start-Sleep -Seconds 5 # Wait for movies to load
    Take-Screenshot "desktop_movies.png"

    # ── Screen 4: desktop_movies_focused.png (Movies with Focused Card) ───
    Write-Host "Focusing first Movie card..."
    & $adb shell input keyevent 22 # Right
    Start-Sleep -Seconds 2
    Take-Screenshot "desktop_movies_focused.png"

    # ── Screen 5: desktop_series.png (Series Tab) ─────────────────────────
    Write-Host "Navigating back to rail..."
    & $adb shell input keyevent 21 # Left
    Start-Sleep -Seconds 1
    Write-Host "Focusing Series rail item..."
    & $adb shell input keyevent 20 # Down
    Start-Sleep -Seconds 1
    Write-Host "Selecting Series..."
    & $adb shell input keyevent 23 # Enter
    Start-Sleep -Seconds 5 # Wait for series to load
    Take-Screenshot "desktop_series.png"

    # ── Screen 6: desktop_series_focused.png (Series with Focused Card) ───
    Write-Host "Focusing first Series card..."
    & $adb shell input keyevent 22 # Right
    Start-Sleep -Seconds 2
    Take-Screenshot "desktop_series_focused.png"

    # ── Screen 7: desktop_settings.png (Settings Screen) ──────────────────
    Write-Host "Navigating back to rail..."
    & $adb shell input keyevent 21 # Left
    Start-Sleep -Seconds 1
    Write-Host "Focusing Settings rail item..."
    & $adb shell input keyevent 20 # Down
    Start-Sleep -Seconds 1
    Write-Host "Selecting Settings..."
    & $adb shell input keyevent 23 # Enter
    Start-Sleep -Seconds 4 # Wait for Settings to load
    Take-Screenshot "desktop_settings.png"

    # ── Screen 8: desktop_diagnostics.png (Diagnostics Screen) ────────────
    Write-Host "Focusing Connection Diagnostics..."
    & $adb shell input keyevent 20 # Down to Connection Diagnostics
    Start-Sleep -Seconds 1
    Write-Host "Selecting Connection Diagnostics..."
    & $adb shell input keyevent 23 # Enter to launch diagnostics
    Start-Sleep -Seconds 5 # Wait for diagnostics page to load
    Take-Screenshot "desktop_diagnostics.png"

    # Navigate back to reset state
    Write-Host "Resetting app state..."
    & $adb shell input keyevent 4 # Back from diagnostics
    Start-Sleep -Seconds 1
    & $adb shell input keyevent 4 # Back from settings
    Start-Sleep -Seconds 1

    Write-Host "Successfully captured all 8 Desktop screenshots!" -ForegroundColor Green

} finally {
    # ── Reset Resolution, Density & Rotation ─────────────────────────
    Write-Host "Restoring device size, density, and rotation..." -ForegroundColor Yellow
    & $adb shell wm size reset
    & $adb shell wm density reset
    & $adb shell settings put system accelerometer_rotation 1
    & $adb shell settings put system user_rotation 0
    & $adb shell am force-stop com.quasar.tvparser
    Write-Host "Restore complete." -ForegroundColor Green
}

# capture-tv-screenshots.ps1
# Automates navigation and captures 8 TV screenshots in 16:9 aspect ratio (1920x1080)

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

# ── Step 1: Force TV Resolution & Density ────────────────────────────
Write-Host "Setting device to 1920x1080 TV mode (density 240)..." -ForegroundColor Yellow
& $adb shell wm size 1920x1080
& $adb shell wm density 240
Start-Sleep -Seconds 4

# Ensure app is in foreground
& $adb shell am start -n com.quasar.tvparser/com.quasar.tvparser.MainActivity | Out-Null
Start-Sleep -Seconds 12  # Wait for splash video + playlists load

try {
    # ── Screen 1: tv_live.png (Live TV Dashboard) ────────────────────
    Take-Screenshot "tv_live.png"

    # ── Screen 2: tv_live_focused.png (Live TV with Focused Card) ────
    Write-Host "Focusing first Live channel card..."
    & $adb shell input keyevent 22 # Right
    Start-Sleep -Seconds 2
    Take-Screenshot "tv_live_focused.png"

    # ── Screen 3: tv_movies.png (Movies Tab) ─────────────────────────
    Write-Host "Navigating back to rail..."
    & $adb shell input keyevent 21 # Left
    Start-Sleep -Seconds 1
    Write-Host "Focusing Movies rail item..."
    & $adb shell input keyevent 20 # Down
    Start-Sleep -Seconds 1
    Write-Host "Selecting Movies..."
    & $adb shell input keyevent 23 # Enter
    Start-Sleep -Seconds 4 # Wait for movies to load
    Take-Screenshot "tv_movies.png"

    # ── Screen 4: tv_movies_focused.png (Movies with Focused Card) ───
    Write-Host "Focusing first Movie card..."
    & $adb shell input keyevent 22 # Right
    Start-Sleep -Seconds 2
    Take-Screenshot "tv_movies_focused.png"

    # ── Screen 5: tv_series.png (Series Tab) ─────────────────────────
    Write-Host "Navigating back to rail..."
    & $adb shell input keyevent 21 # Left
    Start-Sleep -Seconds 1
    Write-Host "Focusing Series rail item..."
    & $adb shell input keyevent 20 # Down
    Start-Sleep -Seconds 1
    Write-Host "Selecting Series..."
    & $adb shell input keyevent 23 # Enter
    Start-Sleep -Seconds 4 # Wait for series to load
    Take-Screenshot "tv_series.png"

    # ── Screen 6: tv_series_focused.png (Series with Focused Card) ───
    Write-Host "Focusing first Series card..."
    & $adb shell input keyevent 22 # Right
    Start-Sleep -Seconds 2
    Take-Screenshot "tv_series_focused.png"

    # ── Screen 7: tv_settings.png (Settings Screen) ──────────────────
    Write-Host "Navigating back to rail..."
    & $adb shell input keyevent 21 # Left
    Start-Sleep -Seconds 1
    Write-Host "Focusing Settings rail item..."
    & $adb shell input keyevent 20 # Down
    Start-Sleep -Seconds 1
    Write-Host "Selecting Settings..."
    & $adb shell input keyevent 23 # Enter
    Start-Sleep -Seconds 3 # Wait for Settings to load
    Take-Screenshot "tv_settings.png"

    # ── Screen 8: tv_diagnostics.png (Diagnostics Screen) ────────────
    Write-Host "Focusing Connection Diagnostics..."
    & $adb shell input keyevent 20 # Down to Connection Diagnostics
    Start-Sleep -Seconds 1
    Write-Host "Selecting Connection Diagnostics..."
    & $adb shell input keyevent 23 # Enter to launch diagnostics
    Start-Sleep -Seconds 4 # Wait for diagnostics page to load
    Take-Screenshot "tv_diagnostics.png"

    # Navigate back to reset state
    Write-Host "Going back..."
    & $adb shell input keyevent 4 # Back from diagnostics
    Start-Sleep -Seconds 1
    & $adb shell input keyevent 4 # Back from settings
    Start-Sleep -Seconds 1

    Write-Host "Successfully captured all 8 TV screenshots!" -ForegroundColor Green

} finally {
    # ── Reset Resolution and Density ─────────────────────────────────
    Write-Host "Resetting device resolution and density..." -ForegroundColor Yellow
    & $adb shell wm size reset
    & $adb shell wm density reset
    Write-Host "Reset complete." -ForegroundColor Green
}

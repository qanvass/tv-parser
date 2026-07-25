param(
    [string]$Serial = "emulator-5554"
)

# capture-tv-screenshots.ps1
# Automates navigation and captures 8 TV screenshots in 16:9 aspect ratio (1920x1080)

$ErrorActionPreference = "Stop"

$adb = "C:\Users\Qanva\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$outDir = "C:\Users\Qanva\Desktop\TV Parcer\store_release_package"

& $adb -s $Serial get-state | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "ADB target '$Serial' is not available. Start the screenshot emulator first."
}

$isEmulator = (& $adb -s $Serial shell getprop ro.kernel.qemu).Trim()
if ($isEmulator -ne "1") {
    throw "Refusing to change resolution on '$Serial': it is not an Android emulator."
}

if (!(Test-Path $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

function Take-Screenshot {
    param([string]$filename)
    $remotePath = "/sdcard/$filename"
    $localPath = Join-Path $outDir $filename

    Write-Host "Capturing $filename..." -ForegroundColor Cyan
    & $adb -s $Serial shell screencap -p $remotePath
    & $adb -s $Serial pull $remotePath $localPath
    & $adb -s $Serial shell rm $remotePath
    Write-Host "Saved to $localPath" -ForegroundColor Green
}

# ── Step 1: Force TV Resolution & Density ────────────────────────────
Write-Host "Setting device to 1920x1080 TV mode (density 240)..." -ForegroundColor Yellow
& $adb -s $Serial shell wm size 1920x1080
& $adb -s $Serial shell wm density 240
Start-Sleep -Seconds 4

# Ensure app is in foreground
& $adb -s $Serial shell am start -n com.quasar.tvparser/com.quasar.tvparser.MainActivity | Out-Null
Start-Sleep -Seconds 15  # Wait for splash video + playlists load

# Dismiss the Android system tutorial only when its button is present.
& $adb -s $Serial shell uiautomator dump /sdcard/tvparser_window.xml | Out-Null
$uiXml = & $adb -s $Serial shell cat /sdcard/tvparser_window.xml
if ($uiXml -match 'text="Got it"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"') {
    $tapX = [int](([int]$matches[1] + [int]$matches[3]) / 2)
    $tapY = [int](([int]$matches[2] + [int]$matches[4]) / 2)
    & $adb -s $Serial shell input tap $tapX $tapY
    Start-Sleep -Seconds 1
}
& $adb -s $Serial shell rm /sdcard/tvparser_window.xml

try {
    # ── Screen 1: tv_live.png (Live TV Dashboard) ────────────────────
    Take-Screenshot "tv_live.png"

    # ── Screen 2: tv_live_focused.png (Live TV with Focused Card) ────
    Write-Host "Focusing first Live channel card..."
    & $adb -s $Serial shell input keyevent 22 # Right
    Start-Sleep -Seconds 2
    Take-Screenshot "tv_live_focused.png"

    # ── Screen 3: tv_movies.png (Movies Tab) ─────────────────────────
    Write-Host "Navigating back to rail..."
    & $adb -s $Serial shell input keyevent 21 # Left
    Start-Sleep -Seconds 1
    Write-Host "Focusing Movies rail item..."
    & $adb -s $Serial shell input keyevent 20 # Down
    Start-Sleep -Seconds 1
    Write-Host "Selecting Movies..."
    & $adb -s $Serial shell input keyevent 23 # Enter
    Start-Sleep -Seconds 4 # Wait for movies to load
    Take-Screenshot "tv_movies.png"

    # ── Screen 4: tv_movies_focused.png (Movies with Focused Card) ───
    Write-Host "Focusing first Movie card..."
    & $adb -s $Serial shell input keyevent 22 # Right
    Start-Sleep -Seconds 2
    Take-Screenshot "tv_movies_focused.png"

    # ── Screen 5: tv_series.png (Series Tab) ─────────────────────────
    Write-Host "Navigating back to rail..."
    & $adb -s $Serial shell input keyevent 21 # Left
    Start-Sleep -Seconds 1
    Write-Host "Focusing Series rail item..."
    & $adb -s $Serial shell input keyevent 20 # Down
    Start-Sleep -Seconds 1
    Write-Host "Selecting Series..."
    & $adb -s $Serial shell input keyevent 23 # Enter
    Start-Sleep -Seconds 4 # Wait for series to load
    Take-Screenshot "tv_series.png"

    # ── Screen 6: tv_series_focused.png (Series with Focused Card) ───
    Write-Host "Focusing first Series card..."
    & $adb -s $Serial shell input keyevent 22 # Right
    Start-Sleep -Seconds 2
    Take-Screenshot "tv_series_focused.png"

    # ── Screen 7: tv_settings.png (Settings Screen) ──────────────────
    Write-Host "Navigating back to rail..."
    & $adb -s $Serial shell input keyevent 21 # Left
    Start-Sleep -Seconds 1
    Write-Host "Focusing Settings rail item..."
    & $adb -s $Serial shell input keyevent 20 # Down
    Start-Sleep -Seconds 1
    Write-Host "Selecting Settings..."
    & $adb -s $Serial shell input keyevent 23 # Enter
    Start-Sleep -Seconds 3 # Wait for Settings to load
    Take-Screenshot "tv_settings.png"

    # ── Screen 8: tv_diagnostics.png (Diagnostics Screen) ────────────
    Write-Host "Focusing Connection Diagnostics..."
    & $adb -s $Serial shell input keyevent 20 # Down to Connection Diagnostics
    Start-Sleep -Seconds 1
    Write-Host "Selecting Connection Diagnostics..."
    & $adb -s $Serial shell input keyevent 23 # Enter to launch diagnostics
    Start-Sleep -Seconds 4 # Wait for diagnostics page to load
    Take-Screenshot "tv_diagnostics.png"

    # Navigate back to reset state
    Write-Host "Going back..."
    & $adb -s $Serial shell input keyevent 4 # Back from diagnostics
    Start-Sleep -Seconds 1
    & $adb -s $Serial shell input keyevent 4 # Back from settings
    Start-Sleep -Seconds 1

    Write-Host "Successfully captured all 8 TV screenshots!" -ForegroundColor Green

} finally {
    # ── Reset Resolution and Density ─────────────────────────────────
    Write-Host "Resetting device resolution and density..." -ForegroundColor Yellow
    & $adb -s $Serial shell wm size reset
    & $adb -s $Serial shell wm density reset
    Write-Host "Reset complete." -ForegroundColor Green
}

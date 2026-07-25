# capture-tablet-screenshots.ps1
# Automates navigation and captures 8 tablet screenshots in 9:16 aspect ratio (1080x1920)

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

# ── Step 1: Force Tablet Resolution & Density ────────────────────────
Write-Host "Setting device to 1080x1920 tablet mode (density 220)..." -ForegroundColor Yellow
& $adb shell wm size 1080x1920
& $adb shell wm density 220
Start-Sleep -Seconds 4

# Ensure app is in foreground
& $adb shell am start -n com.quasar.tvparser/com.quasar.tvparser.MainActivity | Out-Null
Start-Sleep -Seconds 15

try {
    # ── Screen 1: Movies Catalog ──────────────────────────────────────
    # We are currently on the Movies catalog screen from the previous step.
    # Let's verify and take the screenshot.
    Take-Screenshot "tablet_movies.png"

    # ── Screen 2: Movie Detail ────────────────────────────────────────
    # Tap the first movie card (bounds on screen: center [347, 418])
    Write-Host "Tapping first movie card to open details..."
    & $adb shell input tap 347 418
    Start-Sleep -Seconds 3
    Take-Screenshot "tablet_detail.png"

    # Go back to Movies catalog
    Write-Host "Navigating back to Movies catalog..."
    & $adb shell input keyevent 4
    Start-Sleep -Seconds 2

    # Go back to Watch home screen
    Write-Host "Navigating back to Watch home screen..."
    & $adb shell input keyevent 4
    Start-Sleep -Seconds 2

    # ── Screen 3: Home/Watch Screen ───────────────────────────────────
    # Scroll up to the top of the Watch screen to reset scroll state
    Write-Host "Scrolling up to the top of the Watch screen..."
    & $adb shell input swipe 540 900 540 1700
    Start-Sleep -Seconds 2
    Take-Screenshot "tablet_home.png"

    # ── Screen 4: Search Screen ───────────────────────────────────────
    # Tap Search tab at bottom navigation bar (center [352, 1800])
    Write-Host "Navigating to Search screen..."
    & $adb shell input tap 352 1800
    Start-Sleep -Seconds 2
    Take-Screenshot "tablet_search.png"

    # ── Screen 5: Favorites Screen ────────────────────────────────────
    # Tap Favorites tab at bottom navigation bar (center [540, 1800])
    Write-Host "Navigating to Favorites screen..."
    & $adb shell input tap 540 1800
    Start-Sleep -Seconds 2
    Take-Screenshot "tablet_favorites.png"

    # ── Screen 6: Settings Screen ─────────────────────────────────────
    # Tap Settings tab at bottom navigation bar (center [916, 1800])
    Write-Host "Navigating to Settings screen..."
    & $adb shell input tap 916 1800
    Start-Sleep -Seconds 2
    Take-Screenshot "tablet_settings.png"

    # Tap Watch tab at bottom to return to Home (center [164, 1800])
    Write-Host "Returning to Watch home screen..."
    & $adb shell input tap 164 1800
    Start-Sleep -Seconds 2

    # ── Screen 7: Live TV Catalog ─────────────────────────────────────
    # Scroll down so that Live TV Categories chips are visible
    Write-Host "Scrolling down to see Live TV categories..."
    & $adb shell input swipe 540 1350 540 600
    Start-Sleep -Seconds 2

    # Tap the "ES: Spain Locales" category chip to open channels grid
    # Bounds in scroll dump: center [608, 270]
    Write-Host "Tapping Live TV category chip..."
    & $adb shell input tap 608 270
    Start-Sleep -Seconds 3
    Take-Screenshot "tablet_live.png"

    # Go back to Watch home screen
    Write-Host "Navigating back to Watch home screen..."
    & $adb shell input keyevent 4
    Start-Sleep -Seconds 2

    # ── Screen 8: Series Catalog ──────────────────────────────────────
    # Scroll down further to see Featured Series "See All" button
    Write-Host "Scrolling down to Series section..."
    & $adb shell input swipe 540 1350 540 400
    Start-Sleep -Seconds 2

    # Tap "See All" button for Featured Series (bounds: center [968, 1674])
    Write-Host "Tapping Featured Series 'See All'..."
    & $adb shell input tap 968 1674
    Start-Sleep -Seconds 3
    Take-Screenshot "tablet_series.png"

    # Go back to Watch home screen
    Write-Host "Navigating back to Watch home screen..."
    & $adb shell input keyevent 4
    Start-Sleep -Seconds 2

    Write-Host "Successfully captured all 8 tablet screenshots!" -ForegroundColor Green

} finally {
    # ── Reset Resolution and Density ─────────────────────────────────
    Write-Host "Resetting device resolution and density..." -ForegroundColor Yellow
    & $adb shell wm size reset
    & $adb shell wm density reset
    Write-Host "Reset complete." -ForegroundColor Green
}

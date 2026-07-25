param(
    [string]$Serial = "emulator-5554"
)

$ErrorActionPreference = "Stop"
$adb = "C:\Users\Qanva\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$out = "C:\Users\Qanva\Desktop\TV Parcer\store_release_package"
$pkg = "com.quasar.tvparser"

function Shot([string]$name) {
    & $adb -s $Serial shell screencap -p "/sdcard/$name"
    & $adb -s $Serial pull "/sdcard/$name" (Join-Path $out $name) | Out-Null
    Write-Host "saved $name"
}

function Ensure-App {
    $fg = (& $adb -s $Serial shell dumpsys activity activities 2>$null | Select-String "topResumedActivity=.*$pkg")
    if (-not $fg) {
        Write-Host "App not foreground - relaunching"
        & $adb -s $Serial shell am start -n "$pkg/$pkg.MainActivity" | Out-Null
        Start-Sleep -Seconds 8
    }
}

function TapXY([int]$x, [int]$y) {
    Write-Host "tap $x,$y"
    & $adb -s $Serial shell input tap $x $y
}

Write-Host "Cold start..."
& $adb -s $Serial shell am force-stop $pkg | Out-Null
& $adb -s $Serial shell pm clear $pkg | Out-Null
Start-Sleep -Seconds 2
& $adb -s $Serial shell am start -n "$pkg/$pkg.MainActivity" | Out-Null
Start-Sleep -Seconds 20
Ensure-App
Shot "tv_login_start.png"

Write-Host "Select M3U toggle..."
TapXY 1580 300
Start-Sleep -Seconds 2
Ensure-App
Shot "tv_login_m3u_only.png"

Write-Host "Focus URL field and set playlist..."
TapXY 1400 455
Start-Sleep -Seconds 1
# Select all then replace: KEYCODE_MOVE_HOME then shift+end is hard; just type after deletes
& $adb -s $Serial shell input keyevent 123 | Out-Null
for ($i = 0; $i -lt 90; $i++) { & $adb -s $Serial shell input keyevent 67 | Out-Null }
& $adb -s $Serial shell input text "https://tvparser.com/sample.m3u"
Start-Sleep -Seconds 1

Write-Host "Submit field with ENTER (maps to onDone -> Sign In row)..."
& $adb -s $Serial shell input keyevent 66
Start-Sleep -Seconds 2
Ensure-App
Shot "tv_login_url_clean.png"

Write-Host "Press DPAD_CENTER for Sign In..."
& $adb -s $Serial shell input keyevent 23
Start-Sleep -Seconds 4
Ensure-App

# If still on login, tap Sign In button center
$fg = (& $adb -s $Serial shell dumpsys activity activities 2>$null | Select-String "topResumedActivity=.*$pkg")
TapXY 1400 640
Start-Sleep -Seconds 16
Ensure-App
Shot "tv_dashboard_after_login.png"

$fg2 = & $adb -s $Serial shell dumpsys activity activities 2>$null | Select-String "topResumedActivity"
Write-Host $fg2
Write-Host "Done."

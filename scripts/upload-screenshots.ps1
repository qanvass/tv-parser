# upload-screenshots.ps1
# Programmatically uploads 8 phone screenshots and 8 10-inch tablet screenshots to Google Play Console.

$ErrorActionPreference = "Stop"

$PackageName = "com.quasar.tvparser"
$Language = "en-US"
$ServiceAccountKey = $env:GOOGLE_PLAY_SERVICE_ACCOUNT_JSON

if ([string]::IsNullOrWhiteSpace($ServiceAccountKey)) {
    $ServiceAccountKey = "C:\Users\Qanva\secrets\tv-parser-deploy.json"
}

if (!(Test-Path $ServiceAccountKey)) {
    Write-Error "Service account JSON key file not found at: $ServiceAccountKey"
    exit 1
}

# ── Screenshots Lists ────────────────────────────────────────────────
$screenshotDir = "C:\Users\Qanva\Desktop\TV Parcer\store_release_package"

# 8 Phone Screenshots
$phoneScreenshots = @(
    "screenshot_login.png",
    "screenshot_home.png",
    "screenshot_live.png",
    "screenshot_series.png",
    "screenshot_detail.png",
    "screenshot_settings.png",
    "screenshot_search.png",
    "screenshot_movies.png"
)

# 8 10-inch Tablet Screenshots
$tabletScreenshots = @(
    "tablet_home.png",
    "tablet_search.png",
    "tablet_favorites.png",
    "tablet_settings.png",
    "tablet_live.png",
    "tablet_movies.png",
    "tablet_detail.png",
    "tablet_series.png"
)

# Verify all screenshots exist locally
Write-Host "Verifying screenshot files..." -ForegroundColor Yellow
foreach ($s in $phoneScreenshots) {
    $path = Join-Path $screenshotDir $s
    if (!(Test-Path $path)) {
        Write-Error "Required phone screenshot missing: $path"
        exit 1
    }
}
foreach ($t in $tabletScreenshots) {
    $path = Join-Path $screenshotDir $t
    if (!(Test-Path $path)) {
        Write-Error "Required tablet screenshot missing: $path"
        exit 1
    }
}
Write-Host "All 16 screenshots found locally." -ForegroundColor Green

# ── JWT Authentication ───────────────────────────────────────────────
function ConvertTo-Base64Url {
    param([byte[]]$bytes)
    [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function Get-ServiceAccountToken {
    param([string]$keyPath)
    $key = Get-Content $keyPath -Raw | ConvertFrom-Json
    $header = @{ alg = "RS256"; typ = "JWT" } | ConvertTo-Json -Compress
    $headerB64 = ConvertTo-Base64Url ([System.Text.Encoding]::UTF8.GetBytes($header))

    $now = [int][double]::Parse((Get-Date -Date ((Get-Date).ToUniversalTime()) -UFormat %s))
    $claims = @{
        iss   = $key.client_email
        scope = "https://www.googleapis.com/auth/androidpublisher"
        aud   = "https://oauth2.googleapis.com/token"
        iat   = $now
        exp   = $now + 3600
    } | ConvertTo-Json -Compress
    $claimsB64 = ConvertTo-Base64Url ([System.Text.Encoding]::UTF8.GetBytes($claims))

    $unsigned = "$headerB64.$claimsB64"

    $pemContent = $key.private_key
    $pemContent = $pemContent -replace "-----BEGIN PRIVATE KEY-----", ""
    $pemContent = $pemContent -replace "-----END PRIVATE KEY-----", ""
    $pemContent = $pemContent -replace "\s+", ""
    $keyBytes = [Convert]::FromBase64String($pemContent)

    $cngKeyBlob = [System.Security.Cryptography.CngKey]::Import(
        $keyBytes,
        [System.Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob
    )
    $rsa = New-Object System.Security.Cryptography.RSACng($cngKeyBlob)

    $dataBytes = [System.Text.Encoding]::UTF8.GetBytes($unsigned)
    $signature = $rsa.SignData(
        $dataBytes,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
    )
    $signatureB64 = ConvertTo-Base64Url $signature
    $jwt = "$unsigned.$signatureB64"

    $tokenResponse = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body @{
        grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer"
        assertion  = $jwt
    }

    return $tokenResponse.access_token
}

Write-Host "Authenticating with Google Play Developer API..."
$token = Get-ServiceAccountToken -keyPath $ServiceAccountKey
$headers = @{
    "Authorization" = "Bearer $token"
}

$apiBase = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PackageName"
$uploadBase = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$PackageName"

# ── Create Edit Session ──────────────────────────────────────────────
Write-Host "Creating edit session..."
$edit = Invoke-RestMethod -Uri "$apiBase/edits" -Method Post -Headers $headers -ContentType "application/json" -Body "{}"
$editId = $edit.id
Write-Host "Edit Session ID: $editId"

try {
    # ── Clear existing phone screenshots to prevent duplicates ───────
    Write-Host "Clearing existing phone screenshots..."
    try {
        Invoke-RestMethod -Uri "$apiBase/edits/$editId/listings/$Language/phoneScreenshots" -Method Delete -Headers $headers -ErrorAction SilentlyContinue | Out-Null
        Write-Host "Cleared existing phone screenshots successfully." -ForegroundColor Green
    } catch {
        Write-Host "No existing phone screenshots to clear (skipping): $_"
    }

    # ── Clear existing 10-inch tablet screenshots to prevent duplicates ──
    Write-Host "Clearing existing 10-inch tablet screenshots..."
    try {
        Invoke-RestMethod -Uri "$apiBase/edits/$editId/listings/$Language/tenInchScreenshots" -Method Delete -Headers $headers -ErrorAction SilentlyContinue | Out-Null
        Write-Host "Cleared existing tablet screenshots successfully." -ForegroundColor Green
    } catch {
        Write-Host "No existing tablet screenshots to clear (skipping): $_"
    }

    # ── Upload Phone Screenshots ─────────────────────────────────────
    Write-Host "Uploading 8 phone screenshots..." -ForegroundColor Yellow
    foreach ($s in $phoneScreenshots) {
        $path = Join-Path $screenshotDir $s
        Write-Host "Uploading phone screenshot: $s..."
        $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $path).Path)
        $uploadResult = Invoke-RestMethod -Uri "$uploadBase/edits/$editId/listings/$Language/phoneScreenshots?uploadType=media" -Method Post -Headers $headers -ContentType "image/png" -Body $bytes
        Write-Host "Uploaded $s successfully." -ForegroundColor Green
    }

    # ── Upload Tablet Screenshots ────────────────────────────────────
    Write-Host "Uploading 8 10-inch tablet screenshots..." -ForegroundColor Yellow
    foreach ($t in $tabletScreenshots) {
        $path = Join-Path $screenshotDir $t
        Write-Host "Uploading tablet screenshot: $t..."
        $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $path).Path)
        $uploadResult = Invoke-RestMethod -Uri "$uploadBase/edits/$editId/listings/$Language/tenInchScreenshots?uploadType=media" -Method Post -Headers $headers -ContentType "image/png" -Body $bytes
        Write-Host "Uploaded $t successfully." -ForegroundColor Green
    }

    # ── Commit Edit Session ──────────────────────────────────────────
    Write-Host "Committing all changes to Google Play Console..." -ForegroundColor Yellow
    $commitResult = Invoke-RestMethod -Uri "$apiBase/edits/$editId:commit" -Method Post -Headers $headers
    Write-Host "Successfully committed all phone and tablet screenshots to Google Play Console!" -ForegroundColor Green

} catch {
    Write-Host "Failed to upload screenshots: $_" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $errBody = $reader.ReadToEnd()
        Write-Host "API Details: $errBody" -ForegroundColor Red
    }
    Write-Host "Discarding edit session..." -ForegroundColor Yellow
    Invoke-RestMethod -Uri "$apiBase/edits/$editId" -Method Delete -Headers $headers -ErrorAction SilentlyContinue | Out-Null
    exit 1
}

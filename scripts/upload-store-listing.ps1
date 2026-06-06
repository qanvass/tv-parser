# upload-store-listing.ps1
# Programmatically updates short/full descriptions, app icon, feature graphic, and TV banner via the Google Play Developer API.

$ErrorActionPreference = "Stop"

$PackageName = "com.quasar.tvparser"
$Language = "en-US"
$ServiceAccountKey = $env:GOOGLE_PLAY_SERVICE_ACCOUNT_JSON
if ([string]::IsNullOrWhiteSpace($ServiceAccountKey)) {
    $ServiceAccountKey = "C:\Users\Qanva\secrets\tv-parser-deploy.json"
}

# ── Paths ────────────────────────────────────────────────────────────
$iconSource = "C:\Users\Qanva\Desktop\TV Parcer\tv parser app icon.png"
$iconTarget = "C:\Users\Qanva\Desktop\TV Parcer\store_release_package\app_icon_512.png"
$featureGraphic = "C:\Users\Qanva\Desktop\TV Parcer\store_release_package\feature_graphic.png"
$tvBannerSource = "C:\Users\Qanva\Desktop\TV Parcer\Use this Android Tv Banner.png"
$tvBannerTarget = "C:\Users\Qanva\Desktop\TV Parcer\store_release_package\tv_banner_1280.png"

# ── Resize App Icon to 512x512 ───────────────────────────────────────
Write-Host "Creating 512x512 app icon..."
try {
    [Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null
    $srcImg = [System.Drawing.Image]::FromFile($iconSource)
    $destBmp = New-Object System.Drawing.Bitmap(512, 512)
    $graphics = [System.Drawing.Graphics]::FromImage($destBmp)
    
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    
    $srcRect = New-Object System.Drawing.Rectangle(0, 0, $srcImg.Width, $srcImg.Height)
    $destRect = New-Object System.Drawing.Rectangle(0, 0, 512, 512)
    $graphics.DrawImage($srcImg, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    
    if (Test-Path $iconTarget) { Remove-Item $iconTarget -Force }
    $destBmp.Save($iconTarget, [System.Drawing.Imaging.ImageFormat]::Png)
    
    $graphics.Dispose()
    $destBmp.Dispose()
    $srcImg.Dispose()
    Write-Host "Generated 512x512 App Icon at: $iconTarget" -ForegroundColor Green
} catch {
    Write-Error "Failed to generate 512x512 app icon: $_"
    exit 1
}

# ── Resize TV Banner to 1280x720 ─────────────────────────────────────
Write-Host "Creating 1280x720 TV banner..."
try {
    $srcImg = [System.Drawing.Image]::FromFile($tvBannerSource)
    $destBmp = New-Object System.Drawing.Bitmap(1280, 720)
    $graphics = [System.Drawing.Graphics]::FromImage($destBmp)
    
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    
    $srcRect = New-Object System.Drawing.Rectangle(0, 0, $srcImg.Width, $srcImg.Height)
    $destRect = New-Object System.Drawing.Rectangle(0, 0, 1280, 720)
    $graphics.DrawImage($srcImg, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    
    if (Test-Path $tvBannerTarget) { Remove-Item $tvBannerTarget -Force }
    $destBmp.Save($tvBannerTarget, [System.Drawing.Imaging.ImageFormat]::Png)
    
    $graphics.Dispose()
    $destBmp.Dispose()
    $srcImg.Dispose()
    Write-Host "Generated 1280x720 TV Banner at: $tvBannerTarget" -ForegroundColor Green
} catch {
    Write-Error "Failed to generate 1280x720 TV banner: $_"
    exit 1
}

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

Write-Host "Authenticating..."
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
    # ── Update Listing Text ──────────────────────────────────────────
    Write-Host "Updating Short & Full descriptions for $Language..."
    $shortDesc = "Organize and stream your personal media playlists with TV Parser."
    $descPath = "C:\Users\Qanva\Desktop\TV Parcer\store_release_package\store_description.txt"
    if (Test-Path $descPath) {
        $fullDesc = [System.IO.File]::ReadAllText($descPath)
        Write-Host "Loaded description from $descPath"
    } else {
        $fullDesc = "TV Parser is a premium media player and library organization app for users with valid provider credentials or authorized playlist access.`n`nOrganize and stream your personal media library with ease. TV Parser provides a beautiful, native interface to manage, search, and play back your authorized media playlists. Featuring high-performance VLC playback engines, device layout optimizations for phones and TVs, Chromecast support, and connection diagnostics.`n`nImportant Note: TV Parser is a pure media player shell. The app does not provide, host, sell, or include any media content or provider streams. Users must supply their own credentials or content playlists to utilize playback features."
    }

    $listingBody = @{
        title            = "TV Parser"
        shortDescription = $shortDesc
        fullDescription  = $fullDesc
    } | ConvertTo-Json -Depth 5

    $listingResult = Invoke-RestMethod -Uri "$apiBase/edits/$editId/listings/$Language" -Method Put -Headers $headers `
        -ContentType "application/json" -Body $listingBody
    Write-Host "Listing text updated successfully." -ForegroundColor Green

    # ── Clear existing images first to prevent duplicate errors ──────
    Write-Host "Clearing existing graphics catalog..."
    try {
        Invoke-RestMethod -Uri "$apiBase/edits/$editId/listings/$Language/icon" -Method Delete -Headers $headers -ErrorAction SilentlyContinue | Out-Null
        Invoke-RestMethod -Uri "$apiBase/edits/$editId/listings/$Language/featureGraphic" -Method Delete -Headers $headers -ErrorAction SilentlyContinue | Out-Null
        Invoke-RestMethod -Uri "$apiBase/edits/$editId/listings/$Language/tvBanner" -Method Delete -Headers $headers -ErrorAction SilentlyContinue | Out-Null
    } catch {
        # Silent ignore if clear fails
    }

    # ── Upload App Icon ──────────────────────────────────────────────
    Write-Host "Uploading App Icon (512x512 px)..."
    $iconBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $iconTarget).Path)
    $uploadIcon = Invoke-RestMethod -Uri "$uploadBase/edits/$editId/listings/$Language/icon?uploadType=media" -Method Post -Headers $headers `
        -ContentType "image/png" -Body $iconBytes
    Write-Host "App Icon uploaded successfully." -ForegroundColor Green

    # ── Upload Feature Graphic ───────────────────────────────────────
    Write-Host "Uploading Feature Graphic (1024x500 px)..."
    $featureBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $featureGraphic).Path)
    $uploadFG = Invoke-RestMethod -Uri "$uploadBase/edits/$editId/listings/$Language/featureGraphic?uploadType=media" -Method Post -Headers $headers `
        -ContentType "image/png" -Body $featureBytes
    Write-Host "Feature Graphic uploaded successfully." -ForegroundColor Green

    # ── Upload TV Banner ─────────────────────────────────────────────
    Write-Host "Uploading TV Banner (1280x720 px)..."
    $bannerBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $tvBannerTarget).Path)
    $uploadBanner = Invoke-RestMethod -Uri "$uploadBase/edits/$editId/listings/$Language/tvBanner?uploadType=media" -Method Post -Headers $headers `
        -ContentType "image/png" -Body $bannerBytes
    Write-Host "TV Banner uploaded successfully." -ForegroundColor Green

    # ── Commit Edit Session ──────────────────────────────────────────
    Write-Host "Committing all store listing changes..."
    $commitResult = Invoke-RestMethod -Uri "$apiBase/edits/$editId:commit" -Method Post -Headers $headers
    Write-Host "Successfully committed listing and graphic assets to Google Play!" -ForegroundColor Green

} catch {
    Write-Host "Failed to update store listing: $_" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $errBody = $reader.ReadToEnd()
        Write-Host "API Details: $errBody" -ForegroundColor Red
    }
    Write-Host "Discarding edit session..."
    Invoke-RestMethod -Uri "$apiBase/edits/$editId" -Method Delete -Headers $headers -ErrorAction SilentlyContinue | Out-Null
    exit 1
}

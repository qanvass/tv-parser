<#
.SYNOPSIS
    Upload a signed AAB to Google Play Internal Testing track.

.DESCRIPTION
    Uses the Google Play Developer API (Android Publisher API v3) to:
    1. Authenticate via a service account JSON key (path from env var)
    2. Create an edit session
    3. Check for versionCode conflicts
    4. Upload the AAB
    5. Assign the bundle to Internal Testing only
    6. Commit the edit and log results

    This script NEVER promotes to Production. Manual review is required.

.PARAMETER AabPath
    Path to the signed AAB file.
    Default: .\build\app\outputs\bundle\release\app-release.aab

.PARAMETER ReleaseNotes
    Optional release notes for the upload.

.ENVIRONMENT
    GOOGLE_PLAY_SERVICE_ACCOUNT_JSON
        Required. Absolute path to the Google Cloud service account JSON key.
        The key file must be stored OUTSIDE this repository.
        Example: C:\Users\you\secrets\tv-parser-play-deploy.json

.EXAMPLE
    $env:GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = "C:\Users\you\secrets\tv-parser-play-deploy.json"
    .\scripts\deploy-internal.ps1

.EXAMPLE
    .\scripts\deploy-internal.ps1 -ReleaseNotes "AI search improvements"
#>

param(
    [string]$AabPath = ".\build\app\outputs\bundle\release\app-release.aab",
    [string]$ReleaseNotes = ""
)

$ErrorActionPreference = "Stop"

# ── Constants ────────────────────────────────────────────────────────
$PackageName = "com.quasar.tvparser"
$Track = "internal"  # LOCKED to Internal Testing. Never auto-promote.

# ── Helpers ──────────────────────────────────────────────────────────
function Write-Step { param([string]$msg) Write-Host "`n[DEPLOY] $msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$msg) Write-Host "[  OK  ] $msg" -ForegroundColor Green }
function Write-Fail { param([string]$msg) Write-Host "[ FAIL ] $msg" -ForegroundColor Red }
function Write-Warn { param([string]$msg) Write-Host "[ WARN ] $msg" -ForegroundColor Yellow }

function ConvertTo-Base64Url {
    param([byte[]]$bytes)
    [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function Get-ServiceAccountToken {
    param([string]$keyPath)

    $key = Get-Content $keyPath -Raw | ConvertFrom-Json

    # Build JWT header
    $header = @{ alg = "RS256"; typ = "JWT" } | ConvertTo-Json -Compress
    $headerB64 = ConvertTo-Base64Url ([System.Text.Encoding]::UTF8.GetBytes($header))

    # Build JWT claims
    $now = [int][double]::Parse(
        (Get-Date -Date ((Get-Date).ToUniversalTime()) -UFormat %s)
    )
    $claims = @{
        iss   = $key.client_email
        scope = "https://www.googleapis.com/auth/androidpublisher"
        aud   = "https://oauth2.googleapis.com/token"
        iat   = $now
        exp   = $now + 3600
    } | ConvertTo-Json -Compress
    $claimsB64 = ConvertTo-Base64Url ([System.Text.Encoding]::UTF8.GetBytes($claims))

    $unsigned = "$headerB64.$claimsB64"

    # Sign with RSA private key (PowerShell 5.1 compatible)
    $pemContent = $key.private_key
    $pemContent = $pemContent -replace "-----BEGIN PRIVATE KEY-----", ""
    $pemContent = $pemContent -replace "-----END PRIVATE KEY-----", ""
    $pemContent = $pemContent -replace "\s+", ""
    $keyBytes = [Convert]::FromBase64String($pemContent)

    # Use CngKey for PKCS8 import (works on PS 5.1 / .NET Framework 4.x)
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

    # Exchange JWT for access token
    $tokenResponse = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body @{
        grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer"
        assertion  = $jwt
    }

    return $tokenResponse.access_token
}

# ── Banner ───────────────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  TV Parser - Google Play Internal Testing Deploy" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Package: $PackageName"
Write-Host "  Track:   $Track (locked - no auto-promotion)"
Write-Host ""

# ── Pre-flight: Environment Variable ────────────────────────────────
Write-Step "Checking environment variable"

$ServiceAccountKey = $env:GOOGLE_PLAY_SERVICE_ACCOUNT_JSON

if ([string]::IsNullOrWhiteSpace($ServiceAccountKey)) {
    Write-Fail "Environment variable GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is not set."
    Write-Host ""
    Write-Host "  Set it to the absolute path of your Google Cloud service account JSON key:" -ForegroundColor Yellow
    Write-Host '  $env:GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = "C:\Users\you\secrets\tv-parser-play-deploy.json"' -ForegroundColor Gray
    Write-Host ""
    Write-Host "  The key file must be stored OUTSIDE this repository." -ForegroundColor Yellow
    Write-Host "  See scripts\PLAY_DEPLOY_SETUP.md for full setup instructions." -ForegroundColor Gray
    exit 1
}

# ── Pre-flight: Key File ────────────────────────────────────────────
Write-Step "Validating service account key"

if (-not (Test-Path $ServiceAccountKey)) {
    Write-Fail "Service account key file not found: $ServiceAccountKey"
    exit 1
}

# Safety: reject if the key is inside this repo
$repoRoot = (Resolve-Path ".\").Path
$keyResolved = (Resolve-Path $ServiceAccountKey).Path
if ($keyResolved.StartsWith($repoRoot)) {
    Write-Fail "Service account key must be stored OUTSIDE the repository."
    Write-Host "  Key path:  $keyResolved" -ForegroundColor Red
    Write-Host "  Repo root: $repoRoot" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Move the key to a secure location outside this project folder." -ForegroundColor Yellow
    exit 1
}

# Validate JSON structure
try {
    $keyContent = Get-Content $ServiceAccountKey -Raw | ConvertFrom-Json
    if (-not $keyContent.client_email -or -not $keyContent.private_key) {
        Write-Fail "Key file is missing required fields (client_email, private_key)."
        exit 1
    }
    Write-OK "Key: $($keyContent.client_email)"
} catch {
    Write-Fail "Key file is not valid JSON: $_"
    exit 1
}

# ── Pre-flight: AAB ─────────────────────────────────────────────────
Write-Step "Checking AAB"

if (-not (Test-Path $AabPath)) {
    Write-Fail "AAB not found: $AabPath"
    Write-Host ""
    Write-Host "  Build it first:" -ForegroundColor Yellow
    Write-Host "  cd android && .\gradlew.bat :app:bundleRelease" -ForegroundColor Gray
    exit 1
}

$aabInfo = Get-Item $AabPath
$aabSizeMB = [math]::Round($aabInfo.Length / 1MB, 1)
Write-OK "AAB: $($aabInfo.Name) ($aabSizeMB MB)"
Write-OK "Built: $($aabInfo.LastWriteTime)"

# ── Authenticate ─────────────────────────────────────────────────────
Write-Step "Authenticating with Google Play Developer API"
try {
    $token = Get-ServiceAccountToken -keyPath $ServiceAccountKey
    Write-OK "Authentication successful"
} catch {
    Write-Fail "Authentication failed: $_"
    Write-Host ""
    Write-Host "  Common causes:" -ForegroundColor Yellow
    Write-Host "  - Google Play Developer API not enabled in Google Cloud Console" -ForegroundColor Gray
    Write-Host "  - Service account not invited in Google Play Console" -ForegroundColor Gray
    Write-Host "  - JSON key expired or revoked" -ForegroundColor Gray
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $token"
}

$apiBase = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PackageName"

# ── Create Edit ──────────────────────────────────────────────────────
Write-Step "Creating edit session"
try {
    $edit = Invoke-RestMethod -Uri "$apiBase/edits" -Method Post -Headers $headers -ContentType "application/json" -Body "{}"
    $editId = $edit.id
    Write-OK "Edit created: $editId"
} catch {
    Write-Fail "Failed to create edit: $_"
    exit 1
}

# ── Check Existing Version Codes ─────────────────────────────────────
Write-Step "Checking for versionCode conflicts on '$Track' track"
$existingCodes = @()
try {
    $trackInfo = Invoke-RestMethod -Uri "$apiBase/edits/$editId/tracks/$Track" -Method Get -Headers $headers
    if ($trackInfo.releases) {
        foreach ($release in $trackInfo.releases) {
            if ($release.versionCodes) {
                $existingCodes += $release.versionCodes
            }
        }
    }
    if ($existingCodes.Count -gt 0) {
        Write-Warn "Existing versionCodes on '$Track': $($existingCodes -join ', ')"
    } else {
        Write-OK "No existing releases on '$Track' track"
    }
} catch {
    Write-OK "Track '$Track' has no prior releases (will be created)"
}

# ── Upload AAB ───────────────────────────────────────────────────────
Write-Step "Uploading AAB ($aabSizeMB MB) - this may take a few minutes..."
try {
    $uploadUri = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$PackageName/edits/$editId/bundles?uploadType=media"

    $aabBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $AabPath).Path)

    $uploadResult = Invoke-RestMethod -Uri $uploadUri -Method Post -Headers $headers `
        -ContentType "application/octet-stream" -Body $aabBytes

    $uploadedVersionCode = $uploadResult.versionCode
    Write-OK "Upload complete"
    Write-OK "Version code: $uploadedVersionCode"
    Write-OK "SHA256: $($uploadResult.sha256)"

    # Detect duplicate versionCode
    if ($existingCodes -contains $uploadedVersionCode) {
        Write-Fail "DUPLICATE: versionCode $uploadedVersionCode already exists on '$Track' track!"
        Write-Host ""
        Write-Host "  Fix: Bump the version in pubspec.yaml:" -ForegroundColor Yellow
        Write-Host "    version: X.Y.Z+$($uploadedVersionCode + 1)" -ForegroundColor Gray
        Write-Host "  Then rebuild and re-run this script." -ForegroundColor Yellow

        # Clean up the edit
        Invoke-RestMethod -Uri "$apiBase/edits/$editId" -Method Delete -Headers $headers -ErrorAction SilentlyContinue | Out-Null
        exit 1
    }
} catch {
    Write-Fail "Upload failed: $_"
    Invoke-RestMethod -Uri "$apiBase/edits/$editId" -Method Delete -Headers $headers -ErrorAction SilentlyContinue | Out-Null
    exit 1
}

# ── Assign to Internal Testing Track ─────────────────────────────────
Write-Step "Assigning to '$Track' track (Internal Testing only)"
try {
    $releaseBody = @{
        track = $Track
        releases = @(
            @{
                versionCodes = @($uploadedVersionCode)
                status       = "completed"
            }
        )
    }

    if ($ReleaseNotes) {
        $releaseBody.releases[0].releaseNotes = @(
            @{
                language = "en-US"
                text     = $ReleaseNotes
            }
        )
    }

    $trackResult = Invoke-RestMethod -Uri "$apiBase/edits/$editId/tracks/$Track" -Method Put -Headers $headers `
        -ContentType "application/json" -Body ($releaseBody | ConvertTo-Json -Depth 5)

    Write-OK "Track '$Track' updated"
} catch {
    Write-Fail "Track assignment failed: $_"
    Invoke-RestMethod -Uri "$apiBase/edits/$editId" -Method Delete -Headers $headers -ErrorAction SilentlyContinue | Out-Null
    exit 1
}

# ── Commit Edit ──────────────────────────────────────────────────────
Write-Step "Committing release"
try {
    $commitResult = Invoke-RestMethod -Uri "$apiBase/edits/$editId:commit" -Method Post -Headers $headers
    Write-OK "Release committed successfully"
} catch {
    Write-Fail "Commit failed: $_"
    exit 1
}

# ── Final Summary ────────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Package:       $PackageName"
Write-Host "  Track:         $Track"
Write-Host "  Version Code:  $uploadedVersionCode"
Write-Host "  AAB Size:      $aabSizeMB MB"
Write-Host "  Timestamp:     $([DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss UTC'))"
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "  Production promotion requires manual review in Play Console." -ForegroundColor Yellow
Write-Host ""

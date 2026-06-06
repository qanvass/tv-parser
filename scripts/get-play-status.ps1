# get-play-status.ps1
# Diagnostics script to check TV Parser release status, tracks, and testers programmatically via Android Publisher API.

$ErrorActionPreference = "Stop"

$PackageName = "com.quasar.tvparser"
$ServiceAccountKey = $env:GOOGLE_PLAY_SERVICE_ACCOUNT_JSON
if ([string]::IsNullOrWhiteSpace($ServiceAccountKey)) {
    $ServiceAccountKey = "C:\Users\Qanva\secrets\tv-parser-deploy.json"
}

if (-not (Test-Path $ServiceAccountKey)) {
    Write-Error "Service account JSON key file not found: $ServiceAccountKey"
    exit 1
}

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

# Create edit session
Write-Host "Creating edit session..."
$edit = Invoke-RestMethod -Uri "$apiBase/edits" -Method Post -Headers $headers -ContentType "application/json" -Body "{}"
$editId = $edit.id
Write-Host "Edit Session ID: $editId"

try {
    # 1. Fetch Track Releases
    Write-Host "`n--- Tracks Configuration ---"
    $tracks = @("internal", "alpha", "beta", "production")
    foreach ($trackName in $tracks) {
        try {
            $trackInfo = Invoke-RestMethod -Uri "$apiBase/edits/$editId/tracks/$trackName" -Method Get -Headers $headers
            Write-Host "Track: $trackName" -ForegroundColor Cyan
            if ($trackInfo.releases) {
                foreach ($release in $trackInfo.releases) {
                    Write-Host "  Release: $($release.name)"
                    Write-Host "    Version Codes: $($release.versionCodes -join ', ')"
                    Write-Host "    Status:        $($release.status)"
                    if ($release.releaseNotes) {
                        Write-Host "    Release Notes:"
                        foreach ($note in $release.releaseNotes) {
                            Write-Host "      [$($note.language)] $($note.text)"
                        }
                    }
                }
            } else {
                Write-Host "  No releases active."
            }
        } catch {
            Write-Host "Track $($trackName): Not configured or accessible." -ForegroundColor Yellow
        }
    }

    # 2. Fetch Testers for internal testing
    Write-Host "`n--- Tester Lists (Internal Track) ---"
    try {
        $testers = Invoke-RestMethod -Uri "$apiBase/edits/$editId/testers/internal" -Method Get -Headers $headers
        if ($testers.googleGroups) {
            Write-Host "Associated Google Groups for testing:" -ForegroundColor Green
            foreach ($group in $testers.googleGroups) {
                Write-Host "  - $group"
            }
        } else {
            Write-Host "No Google Groups registered for internal track." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Failed to fetch internal track testers: $_" -ForegroundColor Red
    }

    # 3. Fetch app bundle list
    Write-Host "`n--- Uploaded App Bundles ---"
    try {
        $bundles = Invoke-RestMethod -Uri "$apiBase/edits/$editId/bundles" -Method Get -Headers $headers
        if ($bundles.bundles) {
            foreach ($b in $bundles.bundles) {
                Write-Host "Bundle Version Code: $($b.versionCode)" -ForegroundColor Green
                Write-Host "  SHA256: $($b.sha256)"
                Write-Host "  SHA1:   $($b.sha1)"
            }
        } else {
            Write-Host "No bundles uploaded in this edit session."
        }
    } catch {
        Write-Host "Failed to fetch bundles: $_" -ForegroundColor Red
    }

} finally {
    # Clean up / delete edit session so we don't block
    Write-Host "`nClosing edit session..."
    Invoke-RestMethod -Uri "$apiBase/edits/$editId" -Method Delete -Headers $headers -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Edit session closed."
}

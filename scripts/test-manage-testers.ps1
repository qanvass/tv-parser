# test-manage-testers.ps1
# Script to test managing internal testers and device configurations programmatically.

$ErrorActionPreference = "Stop"

$PackageName = "com.quasar.tvparser"
$ServiceAccountKey = $env:GOOGLE_PLAY_SERVICE_ACCOUNT_JSON

if ([string]::IsNullOrWhiteSpace($ServiceAccountKey)) {
    Write-Error "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON environment variable is not set."
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

# Try querying deviceTierConfigs (doesn't require an edit session)
Write-Host "`n--- Device Tier Configurations ---"
try {
    $deviceConfigs = Invoke-RestMethod -Uri "$apiBase/deviceTierConfigs" -Method Get -Headers $headers
    Write-Host "Device Tier Configs retrieved successfully:" -ForegroundColor Green
    Write-Host ($deviceConfigs | ConvertTo-Json -Depth 5)
} catch {
    Write-Host "Could not retrieve Device Tier Configs: $_" -ForegroundColor Yellow
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $errBody = $reader.ReadToEnd()
        Write-Host "Details: $errBody" -ForegroundColor Red
    }
}

# Create edit session for tester management
Write-Host "`nCreating edit session for tester updates..."
$edit = Invoke-RestMethod -Uri "$apiBase/edits" -Method Post -Headers $headers -ContentType "application/json" -Body "{}"
$editId = $edit.id
Write-Host "Edit Session ID: $editId"

try {
    # Try updating the testers list with the user's emails
    # Let's see if the Google Play API accepts them directly in the googleGroups parameter,
    # or if we can see the exact validation error returned.
    Write-Host "`nTesting PUT /edits/$editId/testers/internal..."
    
    # We will try passing the emails as googleGroups to see if they are accepted
    $testerBody = @{
        googleGroups = @("qanvass@gmail.com", "moad.devloper@gmail.com")
    } | ConvertTo-Json -Compress

    try {
        $updateTesters = Invoke-RestMethod -Uri "$apiBase/edits/$editId/testers/internal" -Method Put -Headers $headers `
            -ContentType "application/json" -Body $testerBody
        Write-Host "Successfully updated testers via API!" -ForegroundColor Green
        Write-Host ($updateTesters | ConvertTo-Json -Depth 5)
        
        # Commit the edit to apply the change
        Write-Host "Committing testers change..."
        $commitResult = Invoke-RestMethod -Uri "$apiBase/edits/$editId:commit" -Method Post -Headers $headers
        Write-Host "Committed successfully!" -ForegroundColor Green
    } catch {
        Write-Host "Failed to update/commit testers:" -ForegroundColor Red
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $errBody = $reader.ReadToEnd()
            Write-Host "API Error Body: $errBody" -ForegroundColor Red
        } else {
            Write-Host "Error details: $_" -ForegroundColor Red
        }
    }
} finally {
    # Clean up / delete edit session if it was not committed
    Write-Host "`nEnsuring edit session is closed..."
    Invoke-RestMethod -Uri "$apiBase/edits/$editId" -Method Delete -Headers $headers -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Done."
}

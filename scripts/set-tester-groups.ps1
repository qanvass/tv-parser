# set-tester-groups.ps1
# Script to associate Google Groups with the Internal Testing track programmatically via the Google Play Developer API.

param(
    [Parameter(Mandatory=$true)]
    [string[]]$Groups
)

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

Write-Host "Creating edit session..."
$edit = Invoke-RestMethod -Uri "$apiBase/edits" -Method Post -Headers $headers -ContentType "application/json" -Body "{}"
$editId = $edit.id
Write-Host "Edit Session ID: $editId"

try {
    Write-Host "Updating testers list for internal track to groups: $($Groups -join ', ')..."
    
    $testerBody = @{
        googleGroups = $Groups
    } | ConvertTo-Json -Compress

    $updateTesters = Invoke-RestMethod -Uri "$apiBase/edits/$editId/testers/internal" -Method Put -Headers $headers `
        -ContentType "application/json" -Body $testerBody
    
    Write-Host "Testers list successfully configured." -ForegroundColor Green
    
    Write-Host "Committing changes..."
    $commitResult = Invoke-RestMethod -Uri "$apiBase/edits/$editId:commit" -Method Post -Headers $headers
    Write-Host "Successfully committed changes to Google Play Console." -ForegroundColor Green

} catch {
    Write-Host "Failed to update tester groups: $_" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $errBody = $reader.ReadToEnd()
        Write-Host "API Details: $errBody" -ForegroundColor Red
    }
    # Clean up / delete the edit
    Write-Host "Discarding edit session..."
    Invoke-RestMethod -Uri "$apiBase/edits/$editId" -Method Delete -Headers $headers -ErrorAction SilentlyContinue | Out-Null
    exit 1
}

# resize-banner.ps1
# Crops and resizes the existing TV banner to fit the exact 1024x500 px Google Play Feature Graphic requirements.

$ErrorActionPreference = "Stop"

$sourcePath = "C:\Users\Qanva\Desktop\TV Parcer\Use this Android Tv Banner.png"
$targetPath = "C:\Users\Qanva\Desktop\TV Parcer\store_release_package\feature_graphic.png"

Write-Host "Loading image: $sourcePath"
[Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null

$srcImg = [System.Drawing.Image]::FromFile($sourcePath)
$srcW = $srcImg.Width
$srcH = $srcImg.Height

Write-Host "Original dimensions: $($srcW)x$($srcH)"

# Math for centering crop at 1024:500 (2.048 aspect ratio)
$targetW = 1024
$targetH = 500
$targetRatio = $targetW / $targetH

# Source dimensions to crop
$cropW = $srcW
$cropH = [math]::Round($srcW / $targetRatio)

if ($cropH -gt $srcH) {
    # If height is limited, base on height instead
    $cropH = $srcH
    $cropW = [math]::Round($srcH * $targetRatio)
}

$cropX = [math]::Max(0, [math]::Round(($srcW - $cropW) / 2))
$cropY = [math]::Max(0, [math]::Round(($srcH - $cropH) / 2))

Write-Host "Cropping rect: X=$cropX, Y=$cropY, Width=$cropW, Height=$cropH"

# Create a new blank bitmap for target dimensions (1024x500)
$destBmp = New-Object System.Drawing.Bitmap($targetW, $targetH)
$graphics = [System.Drawing.Graphics]::FromImage($destBmp)

# Set high-quality scaling modes
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

# Draw the cropped portion onto the resized target canvas
$srcRect = New-Object System.Drawing.Rectangle($cropX, $cropY, $cropW, $cropH)
$destRect = New-Object System.Drawing.Rectangle(0, 0, $targetW, $targetH)

$graphics.DrawImage($srcImg, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)

# Save resized image
Write-Host "Saving resized image to: $targetPath"
$destBmp.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)

# Clean up
$graphics.Dispose()
$destBmp.Dispose()
$srcImg.Dispose()

Write-Host "Successfully generated Feature Graphic: 1024x500 pixels" -ForegroundColor Green

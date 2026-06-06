# get-image-sizes.ps1
[Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null
$files = Get-ChildItem -Path "c:\Users\Qanva\Desktop\TV Parcer" -Include "*.png", "*.jpg", "*.jpeg" -Recurse -ErrorAction SilentlyContinue
foreach ($file in $files) {
    try {
        $img = [System.Drawing.Image]::FromFile($file.FullName)
        [PSCustomObject]@{
            Name   = $file.Name
            Width  = $img.Width
            Height = $img.Height
            Folder = $file.Directory.Name
        }
        $img.Dispose()
    } catch {
        # ignore non-image files or locked files
    }
}

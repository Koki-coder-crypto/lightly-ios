param(
  [string]$Source = "Assets.xcassets\\AppIcon.appiconset\\AppIcon-1024.png"
)

Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $Source
$sourceImage = [System.Drawing.Image]::FromFile((Resolve-Path $Source))
$sizes = @{
  "AppIcon-20@2x.png" = 40; "AppIcon-20@3x.png" = 60
  "AppIcon-29@2x.png" = 58; "AppIcon-29@3x.png" = 87
  "AppIcon-40@2x.png" = 80; "AppIcon-40@3x.png" = 120
  "AppIcon-60@2x.png" = 120; "AppIcon-60@3x.png" = 180
}
foreach ($item in $sizes.GetEnumerator()) {
  $bitmap = New-Object System.Drawing.Bitmap($item.Value, $item.Value)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.DrawImage($sourceImage, 0, 0, $item.Value, $item.Value)
  $graphics.Dispose()
  $bitmap.Save((Join-Path $root $item.Key), [System.Drawing.Imaging.ImageFormat]::Png)
  $bitmap.Dispose()
}
$sourceImage.Dispose()
Write-Output "Created iPhone icon variants in $root"

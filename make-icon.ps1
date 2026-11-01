# Generates the app icons (icon.ico = active/green, icon-idle.ico = idle/grey).
# Run: powershell -ExecutionPolicy Bypass -File make-icon.ps1
param([string]$OutDir = $PSScriptRoot, [string]$PreviewPng = "")

Add-Type -AssemblyName System.Drawing
$sizes = 16, 20, 24, 32, 40, 48, 64, 128, 256

function C([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }

function Draw-Icon([int]$s, [bool]$idle) {
    # Flat rounded square with a white power symbol. Green = active, grey = idle.
    $bmp = New-Object System.Drawing.Bitmap $s, $s
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.PixelOffsetMode = 'HighQuality'
    $g.Clear([System.Drawing.Color]::Transparent)

    $bgColor = if ($idle) { C '#6B7280' } else { C '#16A34A' }

    # Background
    $m = [Math]::Max(0.5, $s * 0.03)
    $w = $s - 2 * $m
    $r = $w * 0.24
    $bg = New-Object System.Drawing.Drawing2D.GraphicsPath
    $bg.AddArc($m, $m, 2*$r, 2*$r, 180, 90)
    $bg.AddArc($m + $w - 2*$r, $m, 2*$r, 2*$r, 270, 90)
    $bg.AddArc($m + $w - 2*$r, $m + $w - 2*$r, 2*$r, 2*$r, 0, 90)
    $bg.AddArc($m, $m + $w - 2*$r, 2*$r, 2*$r, 90, 90)
    $bg.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush $bgColor), $bg)

    # Power symbol: open ring + vertical bar
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), ([Math]::Max(1.6, $s * 0.085))
    $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
    $cx = $s * 0.5; $cy = $s * 0.545; $rr = $s * 0.235
    $g.DrawArc($pen, ($cx - $rr), ($cy - $rr), (2*$rr), (2*$rr), 307, 286)
    $g.DrawLine($pen, $cx, ($cy - $s * 0.33), $cx, ($cy - $s * 0.07))

    $g.Dispose()
    return $bmp
}

function Write-Ico([string]$path, [bool]$idle) {
    $pngs = foreach ($s in $sizes) {
        $b = Draw-Icon $s $idle
        $ms = New-Object System.IO.MemoryStream
        $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
        ,@($s, $ms.ToArray())
    }
    $fs = [System.IO.File]::Create($path)
    $bw = New-Object System.IO.BinaryWriter $fs
    $bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$pngs.Count)
    $offset = 6 + 16 * $pngs.Count
    foreach ($p in $pngs) {
        $dim = if ($p[0] -ge 256) { 0 } else { $p[0] }
        $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
        $bw.Write([UInt16]1); $bw.Write([UInt16]32)
        $bw.Write([UInt32]$p[1].Length); $bw.Write([UInt32]$offset)
        $offset += $p[1].Length
    }
    foreach ($p in $pngs) { $bw.Write([byte[]]$p[1]) }
    $bw.Close()
}

Write-Ico (Join-Path $OutDir 'icon.ico') $false
Write-Ico (Join-Path $OutDir 'icon-idle.ico') $true

if ($PreviewPng) {
    # Contact sheet of all sizes, active row on top, idle row below
    $sheet = New-Object System.Drawing.Bitmap 760, 560
    $g = [System.Drawing.Graphics]::FromImage($sheet); $g.Clear((C '#F3F4F6'))
    $x = 10
    foreach ($s in 16, 24, 32, 48, 64, 128, 256) {
        $g.DrawImage((Draw-Icon $s $false), $x, 10, $s, $s)
        $g.DrawImage((Draw-Icon $s $true), $x, 290, $s, $s)
        $x += $s + 12
    }
    $g.Dispose(); $sheet.Save($PreviewPng); $sheet.Dispose()
}

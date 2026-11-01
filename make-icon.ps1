# Generates the app icons (icon.ico = active/colour, icon-idle.ico = idle/grey).
# Run: powershell -ExecutionPolicy Bypass -File make-icon.ps1
param([string]$OutDir = $PSScriptRoot, [string]$PreviewPng = "")

Add-Type -AssemblyName System.Drawing
$sizes = 16, 20, 24, 32, 40, 48, 64, 128, 256

function C([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }

function Draw-Icon([int]$s, [bool]$idle) {
    $bmp = New-Object System.Drawing.Bitmap $s, $s
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.PixelOffsetMode = 'HighQuality'
    $g.Clear([System.Drawing.Color]::Transparent)

    if ($idle) { $bgA = C '#4B5563'; $bgB = C '#6B7280'; $accent = C '#D1D5DB'; $iris = C '#9CA3AF' }
    else       { $bgA = C '#1E1B4B'; $bgB = C '#4F46E5'; $accent = C '#FBBF24'; $iris = C '#F59E0B' }

    # Rounded-square background with diagonal gradient
    $m = [Math]::Max(0.5, $s * 0.03)
    $w = $s - 2 * $m
    $r = $w * 0.24
    $bg = New-Object System.Drawing.Drawing2D.GraphicsPath
    $bg.AddArc($m, $m, 2*$r, 2*$r, 180, 90)
    $bg.AddArc($m + $w - 2*$r, $m, 2*$r, 2*$r, 270, 90)
    $bg.AddArc($m + $w - 2*$r, $m + $w - 2*$r, 2*$r, 2*$r, 0, 90)
    $bg.AddArc($m, $m + $w - 2*$r, 2*$r, 2*$r, 90, 90)
    $bg.CloseFigure()
    $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush ([System.Drawing.PointF]::new(0, 0)), ([System.Drawing.PointF]::new($s, $s)), $bgA, $bgB
    $g.FillPath($grad, $bg)

    # Eye (almond) shape
    $cx = $s * 0.5; $cy = $s * 0.58
    $ex = $s * 0.36; $ey = $s * 0.22
    $eye = New-Object System.Drawing.Drawing2D.GraphicsPath
    $eye.AddBezier(($cx - $ex), $cy, ($cx - $ex*0.45), ($cy - $ey*1.35), ($cx + $ex*0.45), ($cy - $ey*1.35), ($cx + $ex), $cy)
    $eye.AddBezier(($cx + $ex), $cy, ($cx + $ex*0.45), ($cy + $ey*1.35), ($cx - $ex*0.45), ($cy + $ey*1.35), ($cx - $ex), $cy)
    $eye.CloseFigure()
    $g.FillPath([System.Drawing.Brushes]::White, $eye)

    # Iris, pupil, highlight (clipped to the eye)
    $g.SetClip($eye)
    $ir = $s * 0.155
    $g.FillEllipse((New-Object System.Drawing.SolidBrush $iris), ($cx - $ir), ($cy - $ir), (2*$ir), (2*$ir))
    $pr = $s * 0.07
    $g.FillEllipse((New-Object System.Drawing.SolidBrush (C '#111827')), ($cx - $pr), ($cy - $pr), (2*$pr), (2*$pr))
    if ($s -ge 24) {
        $hr = $s * 0.035
        $g.FillEllipse([System.Drawing.Brushes]::White, ($cx - $ir*0.45 - $hr), ($cy - $ir*0.45 - $hr), (2*$hr), (2*$hr))
    }
    $g.ResetClip()

    # Rays above the eye ("wide awake") - skipped at the tiniest sizes for clarity
    if ($s -ge 20) {
        $pen = New-Object System.Drawing.Pen $accent, ([Math]::Max(1.2, $s * 0.06))
        $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
        foreach ($deg in -50, -90, -130) {
            $a = $deg * [Math]::PI / 180
            $r1 = $s * 0.27; $r2 = $s * 0.39
            $ox = $cx; $oy = $cy - $s * 0.02
            $g.DrawLine($pen, ($ox + $r1*[Math]::Cos($a)), ($oy + $r1*[Math]::Sin($a)), ($ox + $r2*[Math]::Cos($a)), ($oy + $r2*[Math]::Sin($a)))
        }
    }
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

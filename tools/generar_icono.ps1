# Genera assets/icon/icono.png (fondo azul) e icono_frente.png (adaptable).
# Uso: powershell -File tools/generar_icono.ps1  y luego  dart run flutter_launcher_icons
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$pfc.AddFontFile("$root\assets\fonts\GreatVibes-Regular.ttf")
$fam = $pfc.Families[0]
$navy = [System.Drawing.Color]::FromArgb(255, 10, 36, 94)
$goldB = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 241, 190, 72))

function Draw-Mark($g, [float]$s, [float]$u) {
  $cx = $s / 2; $cy = $s / 2
  $w = $u * 0.42; $h = $u * 0.20
  $top = $cy - $u * 0.40; $base = $top + $h
  $pts = @(
    (New-Object System.Drawing.PointF ($cx - $w / 2), $base),
    (New-Object System.Drawing.PointF ($cx - $w / 2), ($top + $h * 0.25)),
    (New-Object System.Drawing.PointF ($cx - $w / 4), ($top + $h * 0.62)),
    (New-Object System.Drawing.PointF $cx, $top),
    (New-Object System.Drawing.PointF ($cx + $w / 4), ($top + $h * 0.62)),
    (New-Object System.Drawing.PointF ($cx + $w / 2), ($top + $h * 0.25)),
    (New-Object System.Drawing.PointF ($cx + $w / 2), $base)
  )
  $g.FillPolygon($goldB, $pts)
  $r = $u * 0.03
  $g.FillEllipse($goldB, ($cx - $w / 2 - $r), ($top + $h * 0.25 - $r * 1.8), $r * 2, $r * 2)
  $g.FillEllipse($goldB, ($cx - $r), ($top - $r * 1.8), $r * 2, $r * 2)
  $g.FillEllipse($goldB, ($cx + $w / 2 - $r), ($top + $h * 0.25 - $r * 1.8), $r * 2, $r * 2)
  $g.FillRectangle($goldB, ($cx - $w / 2), ($base + $u * 0.015), $w, ($u * 0.035))
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddString("LR", $fam, 0, [float]($u * 0.62), (New-Object System.Drawing.PointF 0, 0), [System.Drawing.StringFormat]::GenericTypographic)
  $b = $path.GetBounds()
  $areaTop = $base + $u * 0.10; $areaH = $u * 0.46
  $scale = [Math]::Min(($u * 0.80) / $b.Width, $areaH / $b.Height)
  $m = New-Object System.Drawing.Drawing2D.Matrix
  $m.Translate([float]($cx - $b.Width * $scale / 2), [float]$areaTop)
  $m.Scale([float]$scale, [float]$scale)
  $m.Translate([float](-$b.X), [float](-$b.Y))
  $path.Transform($m)
  $g.FillPath([System.Drawing.Brushes]::White, $path)
}

foreach ($cfg in @(@{ n = 'icono.png'; u = 0.80; bg = $true }, @{ n = 'icono_frente.png'; u = 0.56; bg = $false })) {
  $s = 1024
  $bmp = New-Object System.Drawing.Bitmap $s, $s
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  if ($cfg.bg) { $g.Clear($navy) } else { $g.Clear([System.Drawing.Color]::Transparent) }
  Draw-Mark $g $s ([float]($s * $cfg.u))
  $bmp.Save("$root\assets\icon\$($cfg.n)", [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
}

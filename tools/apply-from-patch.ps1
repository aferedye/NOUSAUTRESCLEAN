param([string]$Patch = "patch.txt")
$ErrorActionPreference = "Stop"
if (-not (Test-Path $Patch)) { Write-Error "Patch not found: $Patch"; exit 1 }

$raw = Get-Content -Raw -Encoding UTF8 $Patch
$lines = $raw -split "`r?`n"
$i = 0

function Ensure-Dir($p){ $d = Split-Path -Parent $p; if($d){ if(-not (Test-Path $d)){ New-Item -ItemType Directory -Force -Path $d | Out-Null } } }

while ($i -lt $lines.Count) {
  $line = $lines[$i]
  if ([string]::IsNullOrWhiteSpace($line)) { $i++; continue }
  $t = $line.TrimStart()
  if ($t.StartsWith("##")) { $i++; continue }

  if ($line.StartsWith("@@FILE ")) {
    $path = $line.Substring(7).Trim().Trim('"')
    $i++
    $buf = New-Object System.Collections.Generic.List[string]
    while ($i -lt $lines.Count -and $lines[$i] -ne "@@END") { $buf.Add($lines[$i]); $i++ }
    if ($i -ge $lines.Count) { throw "Missing @@END for " + $path }
    $content = [string]::Join("`r`n", $buf)
    Ensure-Dir $path
    $enc = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($path, $content, $enc)
    Write-Host "✔ Wrote $path" -ForegroundColor Green
    $i++
    continue
  }

  if ($line.StartsWith("@@CMD ")) {
    $cmd = $line.Substring(6)
    if ([string]::IsNullOrWhiteSpace($cmd)) { throw "Empty @@CMD" }
    Write-Host "→ $cmd" -ForegroundColor Cyan

    $global:LASTEXITCODE = 0
    $oldEA = $ErrorActionPreference
    $ErrorActionPreference = "Stop"
    try {
      iex $cmd
      if (-not $?) { throw "Command failed: $cmd" }
      if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) { throw "Command failed (exit $LASTEXITCODE): $cmd" }
    } catch {
      throw $_
    } finally {
      $ErrorActionPreference = $oldEA
    }
    $i++
    continue
  }

  Write-Host "(ignored) $line" -ForegroundColor DarkGray
  $i++
}

Write-Host "✅ Patch terminé." -ForegroundColor Green
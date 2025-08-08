param(
  [string]$PatchFile = "patch.txt",
  [int]$IntervalMs = 500,
  [switch]$RunOnceAtStart = $true,
  [switch]$AutoClearOnSuccess = $true,
  [switch]$NoPush
)
$ErrorActionPreference = "Stop"
function Info($m){ Write-Host ("[INFO] " + $m) -ForegroundColor Cyan }
function Ok($m){ Write-Host ("[OK]   " + $m) -ForegroundColor Green }
function Err($m){ Write-Host ("[ERR]  " + $m) -ForegroundColor Red }

# .nopush sentinel
if (Test-Path "tools\.nopush") { $NoPush = $true }

if (-not (Test-Path $PatchFile)) { New-Item -ItemType File -Path $PatchFile | Out-Null }
$script:Full = (Resolve-Path $PatchFile).Path
$script:ApplyScript = Join-Path (Get-Location) "tools\apply-from-patch.ps1"
$script:AutoClear = [bool]$AutoClearOnSuccess
$script:prev = (Get-Item $script:Full).LastWriteTimeUtc

$mode = if ($NoPush) { "NoPush (commit local, pas de push)" } else { "AutoPush (commit + push)" }
Info ("Watcher started. Mode: " + $mode)
Info ("Polling " + $script:Full + " every " + $IntervalMs + "ms  (Ctrl+C to stop)")

function Write-Template {
  $tpl = @(
    "## New patch (add @@FILE / @@CMD then Ctrl+S)",
    "# Quick test: uncomment one of the next lines to verify watcher/NoPush:",
    "# @@CMD echo TEST WATCHER / NOPUSH OK",
    "# @@CMD git checkout patch-YYYY-MM-DD_HH-mm-ss  # remplace par un tag réel",
    "## @@CMD composer dump-autoload -o",
    "## @@FILE src/Controller/PingController.php",
    "## <?php",
    "## // your code here",
    "## @@END"
  )
  Set-Content -Encoding UTF8 $script:Full $tpl
  $script:prev = (Get-Item $script:Full).LastWriteTimeUtc
  Ok "patch.txt cleared (template written)"
}

function ApplyOnce {
  try {
    Info ("Applying " + $script:Full)
    if ($NoPush) {
      & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ApplyScript -Patch $script:Full -NoPush
    } else {
      & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ApplyScript -Patch $script:Full
    }
    $code = $LASTEXITCODE
    if ($code -eq 0) {
      Ok "Patch applied"
      if ($script:AutoClear) { Write-Template }
    } else {
      Err ("Patch failed (exit " + $code + ")")
    }
  } catch { Err ("Exception: " + $_.Exception.Message) }
}

if ($RunOnceAtStart) { ApplyOnce }
while ($true) {
  Start-Sleep -Milliseconds $IntervalMs
  try { $cur = (Get-Item $script:Full).LastWriteTimeUtc } catch { continue }
  if ($cur -ne $script:prev) {
    $script:prev = $cur
    ApplyOnce
  }
}
param(
  [string]$PatchFile = "patch.txt",
  [int]$IntervalMs = 500,
  [switch]$RunOnceAtStart = $true,
  [switch]$AutoClearOnSuccess = $true
)
$ErrorActionPreference = "Stop"
function Info($m){ Write-Host ("[ " + (Get-Date -Format "HH:mm:ss") + " ] " + $m) -ForegroundColor Cyan }
function Ok($m){ Write-Host ("[ " + (Get-Date -Format "HH:mm:ss") + " ] " + $m) -ForegroundColor Green }
function Err($m){ Write-Host ("[ " + (Get-Date -Format "HH:mm:ss") + " ] " + $m) -ForegroundColor Red }

if (-not (Test-Path $PatchFile)) { New-Item -ItemType File -Path $PatchFile | Out-Null }
$script:Full = (Resolve-Path $PatchFile).Path
$script:ApplyScript = Join-Path (Get-Location) "tools\apply-from-patch.ps1"
$script:AutoClear = [bool]$AutoClearOnSuccess
$script:prev = (Get-Item $script:Full).LastWriteTimeUtc

function Write-Template {
  $tpl = @(
    "## New patch (empty) - add @@FILE / @@CMD then Ctrl+S",
    "## Example:",
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
    & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ApplyScript -Patch $script:Full
    $code = $LASTEXITCODE
    if ($code -eq 0) {
      Ok "Patch applied"
      if ($script:AutoClear) { Write-Template }
    } else {
      Err ("Patch failed (exit " + $code + ")")
    }
  } catch { Err ("Exception: " + $_.Exception.Message) }
}

Info ("Polling " + $script:Full + " every " + $IntervalMs + "ms  (Ctrl+C to stop)")
if ($RunOnceAtStart) { ApplyOnce }
while ($true) {
  Start-Sleep -Milliseconds $IntervalMs
  try { $cur = (Get-Item $script:Full).LastWriteTimeUtc } catch { continue }
  if ($cur -ne $script:prev) {
    $script:prev = $cur
    ApplyOnce
  }
}
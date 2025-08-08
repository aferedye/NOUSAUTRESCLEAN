param(
  [string]$Patch = "patch.txt",
  [string]$Branch = "main",
  [switch]$AutoPush = $true,
  [switch]$NoPush
)

$ErrorActionPreference = "Stop"
function Info($m){ Write-Host ("[INFO] " + $m) -ForegroundColor Cyan }
function Ok($m){ Write-Host ("[OK]   " + $m) -ForegroundColor Green }
function Warn($m){ Write-Host ("[WARN] " + $m) -ForegroundColor Yellow }
function Fail($m){ Write-Host ("[ERR]  " + $m) -ForegroundColor Red }

# Honor sentinel .nopush
if (Test-Path "tools\.nopush") { $NoPush = $true }

# Concurrency lock
$lockPath = "tools\.apply.lock"
if (Test-Path $lockPath) { Warn "Another apply seems running (found $lockPath). Abort."; exit 2 }
New-Item -ItemType File -Path $lockPath -Force | Out-Null
try {
  # Banner mode
  $mode = if ($NoPush) { "NoPush (commit local, pas de push)" } else { "AutoPush (commit + push origin/$Branch)" }
  Write-Host "==================================================" -ForegroundColor DarkGray
  Write-Host (" APPLY PATCH - Mode: " + $mode) -ForegroundColor Magenta
  Write-Host "==================================================" -ForegroundColor DarkGray

  if (-not (Test-Path $Patch)) { Fail "Patch not found: $Patch"; exit 1 }
  $raw = Get-Content -Raw -Encoding UTF8 $Patch
  if ([string]::IsNullOrWhiteSpace($raw)) { Warn "Patch is empty. Nothing to do."; exit 0 }

  # Backup
  Copy-Item $Patch "$Patch.bak" -Force
  Info ("Backup: $Patch.bak")

  # Detect mode (diff git vs DSL)
  $diffMode = $raw -match '^\s*\*\*\*\s+Begin Patch' -or $raw -match '^\s*diff --git' -or $raw -match '^\s*Index: '
  function Ensure-Dir([string]$p){
    $d = Split-Path -Parent $p
    if ($d -and -not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
  }

  if ($diffMode) {
    Info "Mode: GIT DIFF"
    $cmd = 'git apply --whitespace=fix --reject --verbose "{0}"' -f (Resolve-Path $Patch).Path
    Info $cmd
    iex $cmd
    if ($LASTEXITCODE -ne 0) { Fail "git apply failed (exit $LASTEXITCODE)"; exit $LASTEXITCODE }
    Ok "Diff applied"
  } else {
    Info "Mode: DSL (@@FILE / @@CMD)"
    $lines = $raw -split "`r?`n"
    $i = 0
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
        if ($i -ge $lines.Count) { Fail "Missing @@END for $path"; exit 1 }
        $content = [string]::Join("`r`n", $buf)
        Ensure-Dir $path
        $enc = New-Object System.Text.UTF8Encoding($false)
        [IO.File]::WriteAllText($path, $content, $enc)
        Write-Host ("[OK]   Wrote " + $path) -ForegroundColor Green
        $i++ ; continue
      }

      if ($line.StartsWith("@@CMD ")) {
        $cmd = $line.Substring(6)
        if ([string]::IsNullOrWhiteSpace($cmd)) { Fail "Empty @@CMD"; exit 1 }
        Info ("Run: " + $cmd)
        $global:LASTEXITCODE = 0
        $oldEA = $ErrorActionPreference; $ErrorActionPreference = "Stop"
        try {
          iex $cmd
          if (-not $?) { throw "Command failed: $cmd" }
          if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) { throw "Command failed (exit $LASTEXITCODE): $cmd" }
        } finally { $ErrorActionPreference = $oldEA }
        $i++ ; continue
      }

      Write-Host ("[WARN] ignored: " + $line) -ForegroundColor Yellow
      $i++
    }
    Ok "DSL patch applied"
  }

  # Git add/commit/push
  git rev-parse --is-inside-work-tree 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Info "Initializing git repository"
    git init | Out-Null
  }

  # Ensure branch exists and checked out
  $current = (git rev-parse --abbrev-ref HEAD 2>$null).Trim()
  if (-not $current) { $current = "" }
  if ($current -ne $Branch) {
    git rev-parse --verify $Branch 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Info "Creating branch $Branch"
      git checkout -b $Branch | Out-Null
    } else {
      Info "Checkout $Branch"
      git checkout $Branch | Out-Null
    }
  }

  Info "Staging changes"
  git add -A

  # Tag value for template line (defaults to placeholder)
  $tagForTpl = "patch-YYYY-MM-DD_HH-mm-ss"

  # Any change?
  $summary = (git status --porcelain) -split "`r?`n" | Where-Object { $_ -ne "" }
  if (-not $summary -or $summary.Count -eq 0) {
    Warn "No changes to commit. Skipping commit/push/tag."
  } else {
    $added    = @($summary | Where-Object { $_ -match '^\?\?' } | ForEach-Object { $_.Substring(3) })
    $modified = @($summary | Where-Object { $_ -match '^( M|M )' } | ForEach-Object { $_.Substring(3) })
    $deleted  = @($summary | Where-Object { $_ -match '^( D|D )' } | ForEach-Object { $_.Substring(3) })

    $firstLine = ($raw -split "`r?`n" | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1)
    if (-not $firstLine) { $firstLine = "auto patch" }
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $parts = @("[auto] $firstLine ($ts)")
    if ($added.Count)    { $parts += "added: " + ($added -join ', ') }
    if ($modified.Count) { $parts += "modified: " + ($modified -join ', ') }
    if ($deleted.Count)  { $parts += "deleted: " + ($deleted -join ', ') }
    $msg = ($parts -join " | ")

    Info ("Committing: " + $msg)
    git commit -m "$msg" 2>$null | Out-Null

    # Tagging
    $tagName = "patch-" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
    git tag $tagName 2>$null | Out-Null
    Ok ("Tag created: " + $tagName)
    $tagForTpl = $tagName

    # Patch history log
    $histDir = "tools\patch-history"
    if (-not (Test-Path $histDir)) { New-Item -ItemType Directory -Force -Path $histDir | Out-Null }
    $logPath = Join-Path $histDir ($tagName + ".txt")
    $commitShow = (& git show --name-status --format=medium HEAD)
    $log = @()
    $log += "Tag: $tagName"
    $log += "Date: $ts"
    $log += ""
    $log += "Summary:"
    if ($added.Count)    { $log += "  Added:    " + ($added -join ', ') }
    if ($modified.Count) { $log += "  Modified: " + ($modified -join ', ') }
    if ($deleted.Count)  { $log += "  Deleted:  " + ($deleted -join ', ') }
    $log += ""
    $log += "Commit:"
    $log += $commitShow
    Set-Content -Encoding UTF8 $logPath $log
    Ok ("Patch history -> " + $logPath)

    # Push?
    $doPush = (-not $NoPush) -and $AutoPush
    if ($doPush) {
      $hasRemote = (git remote 2>$null) -match '^origin$'
      if (-not $hasRemote) {
        Warn "No 'origin' remote configured. Skipping push."
      } else {
        Info "Pushing to origin/$Branch"
        git push -u origin $Branch
        Info ("Pushing tag " + $tagName)
        git push origin $tagName
      }
    } else {
      Warn "Skipping push (NoPush or AutoPush disabled)."
    }
  }

  # Clear patch file (template + handy test lines)
  $tpl = @(
    "## New patch (add @@FILE / @@CMD then Ctrl+S)",
    "# Quick test: uncomment one of the next lines to verify watcher/NoPush:",
    "# @@CMD echo TEST WATCHER / NOPUSH OK",
    "# @@CMD git checkout $tagForTpl  # dernier tag créé automatiquement",
    "## @@FILE path/to/file.ext",
    "## content...",
    "## @@END",
    "## @@CMD composer dump-autoload -o"
  )
  Set-Content -Encoding UTF8 $Patch $tpl
  Ok "Patch file cleared"
  Ok "Done"
}
finally {
  if (Test-Path $lockPath) { Remove-Item $lockPath -Force }
}
# --- SNIP (tout le fichier existe déjà) ---
# Remplace juste le bloc qui prépare $tagForTpl et l'alimente en fin d'exécution.

  # Tag value for template line (defaults to placeholder)
  $tagForTpl = "patch-YYYY-MM-DD_HH-mm-ss"

  # Any change?
  $summary = (git status --porcelain) -split "`r?`n" | Where-Object { $_ -ne "" }
  if (-not $summary -or $summary.Count -eq 0) {
    Warn "No changes to commit. Skipping commit/push/tag."
    # NEW: récupérer le dernier tag existant pour remplir le template
    $lastTag = (& git describe --tags --abbrev=0 2>$null)
    if ($LASTEXITCODE -eq 0 -and $lastTag) { $tagForTpl = $lastTag.Trim() }
  } else {
    # ... (ton code de commit inchangé)
    Info ("Committing: " + $msg)
    git commit -m "$msg" 2>$null | Out-Null

    # Tagging
    $tagName = "patch-" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
    git tag $tagName 2>$null | Out-Null
    Ok ("Tag created: " + $tagName)
    $tagForTpl = $tagName

    # ... (push + history inchangés)
  }

  # Clear patch file (template + handy test lines)
  $tpl = @(
    "## New patch (add @@FILE / @@CMD then Ctrl+S)",
    "# Quick test: uncomment one of the next lines to verify watcher/NoPush:",
    "# @@CMD echo TEST WATCHER / NOPUSH OK",
    "# @@CMD git checkout $tagForTpl  # dernier tag créé (ou le plus récent existant)",
    "## @@FILE path/to/file.ext",
    "## content...",
    "## @@END",
    "## @@CMD composer dump-autoload -o"
  )
# --- SNIP ---
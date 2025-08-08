param (
    [string]$PatchFile = "patch.txt"
)

Write-Host "👂 Surveillance de $PatchFile - Ctrl+C pour arrêter" -ForegroundColor Cyan

# Vérifie si le fichier existe
if (-not (Test-Path $PatchFile)) {
    Write-Host "❌ $PatchFile introuvable, création..." -ForegroundColor Yellow
    New-Item -ItemType File -Path $PatchFile | Out-Null
}

$fullPath = Resolve-Path $PatchFile

# Configure le watcher
$fsw = New-Object IO.FileSystemWatcher (Split-Path $fullPath), (Split-Path $fullPath -Leaf)
$fsw.NotifyFilter = [IO.NotifyFilters]'LastWrite, FileName'

# Action sur modification
Register-ObjectEvent $fsw Changed -Action {
    Start-Sleep -Milliseconds 200  # petite pause pour éviter les accès concurrents
    Write-Host "`n📄 Patch modifié, application..." -ForegroundColor Yellow
    powershell -ExecutionPolicy Bypass -File "tools\apply-from-patch.ps1" $using:PatchFile
    Write-Host "✅ Patch appliqué à $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Green
}

# Boucle d’attente
while ($true) { Start-Sleep 1 }

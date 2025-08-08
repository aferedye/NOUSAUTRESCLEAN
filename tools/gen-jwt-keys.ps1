param()
$ErrorActionPreference = "Stop"

function Info($m){ Write-Host ("[INFO] " + $m) -ForegroundColor Cyan }
function Ok($m){ Write-Host ("[OK] " + $m) -ForegroundColor Green }
function Fail($m){ Write-Host ("[ERR] " + $m) -ForegroundColor Red }

# 1) Locate openssl.exe
$openssl = $null
try { $openssl = (Get-Command openssl -ErrorAction SilentlyContinue).Path } catch {}
if (-not $openssl) {
  $cand = Join-Path ${env:ProgramFiles} "Git\usr\bin\openssl.exe"
  if (Test-Path $cand) { $openssl = $cand }
}
if (-not $openssl) {
  Fail "openssl.exe introuvable. Installe Git for Windows OU ajoute OpenSSL au PATH."
  Fail "Astuce: souvent ici -> C:\Program Files\Git\usr\bin\openssl.exe"
  exit 1
}
Info ("OpenSSL: " + $openssl)

# 2) Ensure dir
$dir = Join-Path (Get-Location) "config\jwt"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

# 3) Remove old keys
$priv = Join-Path $dir "private.pem"
$pub  = Join-Path $dir "public.pem"
if (Test-Path $priv) { Remove-Item $priv -Force }
if (Test-Path $pub)  { Remove-Item $pub  -Force }

# 4) Generate new RSA 4096 keys (no passphrase)
& "$openssl" genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out "$priv"
if ($LASTEXITCODE -ne 0) { Fail "openssl genpkey failed"; exit 1 }
& "$openssl" pkey -in "$priv" -pubout -out "$pub"
if ($LASTEXITCODE -ne 0) { Fail "openssl pkey -pubout failed"; exit 1 }

Ok "Generated:"
Write-Host ("  " + $priv)
Write-Host ("  " + $pub)
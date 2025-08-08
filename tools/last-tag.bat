@echo off
setlocal
for /f "delims=" %%T in ('git describe --tags --abbrev=0 2^>NUL') do set TAG=%%T
if "%TAG%"=="" (
  echo Aucun tag trouvé.
  exit /b 1
)
echo Dernier tag: %TAG%
echo Pour y revenir :
echo git checkout %TAG%
endlocal
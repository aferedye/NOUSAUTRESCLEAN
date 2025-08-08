@echo off
cd /d "%~dp0"
if exist ".nopush" (
  del ".nopush"
  echo [.nopush] OFF - AutoPush re-enabled
) else (
  type nul > ".nopush"
  echo [.nopush] ON - Forcing NoPush mode
)
pause
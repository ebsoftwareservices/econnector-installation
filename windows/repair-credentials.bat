@echo off
setlocal

set "INSTALL_HOME=C:\econnector"

REM The Electron UI starts this script with a Windows administrator prompt.
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if errorlevel 1 (
  echo ERROR: Administrator approval is required.
  exit /b 1
)

if not exist "%INSTALL_HOME%" (
  echo ERROR: eConnector is not installed in %INSTALL_HOME%.
  exit /b 1
)

if not exist "%INSTALL_HOME%\credentials.econnector" (
  type nul > "%INSTALL_HOME%\credentials.econnector"
  if errorlevel 1 goto repair_failed
)
if not exist "%INSTALL_HOME%\tokens.econnector" (
  type nul > "%INSTALL_HOME%\tokens.econnector"
  if errorlevel 1 goto repair_failed
)

icacls "%INSTALL_HOME%\credentials.econnector" /inheritance:r /grant:r *S-1-5-32-545:RW *S-1-5-32-544:F *S-1-5-18:F >nul
if errorlevel 1 goto repair_failed
icacls "%INSTALL_HOME%\tokens.econnector" /inheritance:r /grant:r *S-1-5-32-545:RW *S-1-5-32-544:F *S-1-5-18:F >nul
if errorlevel 1 goto repair_failed

echo eConnector credential storage repaired successfully.
exit /b 0

:repair_failed
echo ERROR: Failed to repair eConnector credential storage.
exit /b 1

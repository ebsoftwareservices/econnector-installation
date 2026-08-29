@echo off
:: BatchGotAdmin
::-------------------------------------
REM  --> Check for permissions
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

REM --> If error flag set, we do not have admin.
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    set "ELEVATE_SCRIPT=%~f0"
    set "ELEVATE_ARGS=%*"
    powershell -NoProfile -Command "$ErrorActionPreference='Stop'; $p = '\"' + $env:ELEVATE_SCRIPT + '\"'; if (-not [string]::IsNullOrEmpty($env:ELEVATE_ARGS)) { $p = $p + ' ' + $env:ELEVATE_ARGS }; Start-Process -FilePath $env:ComSpec -ArgumentList @('/D','/C', $p) -Verb RunAs"
    if errorlevel 1 (
      echo ERROR: Failed to request administrator privileges.
      pause
      exit /b 1
    )
    exit /B

:gotAdmin
    set "UPGRADE_TMP=%TEMP%\econnector-upgrade.bat"
    if /I "%~nx0"=="econnector-upgrade.bat" goto begin_upgrade
    goto relaunch_from_temp

:relaunch_from_temp
    copy /Y "%~f0" "%UPGRADE_TMP%" >NUL
    if errorlevel 1 (
      echo ERROR: Failed to copy upgrade script to "%UPGRADE_TMP%"
      pause
      exit /b 1
    )
    cd /d "%TEMP%"
    call "%UPGRADE_TMP%" %*
    set "RC=%ERRORLEVEL%"
    del /Q "%UPGRADE_TMP%" >NUL 2>&1
    exit /b %RC%

:begin_upgrade
    pushd "%CD%"
    CD /D "%~dp0"
::--------------------------------------

setlocal enableextensions enabledelayedexpansion

set SERVICE_NAME=econnector
set INSTALL_HOME=C:\%SERVICE_NAME%
set REPO=ebsoftwareservices/econnector-installation
set WORK_DIR=%TEMP%\econnector-upgrade
set BACKUP_DIR=%WORK_DIR%\backup
set PKG_DIR=%WORK_DIR%\pkg
set RELEASE_TAG=%~1

@echo on
echo === Econnector Upgrade ===
if "%RELEASE_TAG%"=="" (
    echo Target version: latest
) else (
    echo Target version: %RELEASE_TAG%
)

REM ============================================================
REM [1/4] Stop UI process and Windows service
REM ============================================================
echo.
echo [1/4] Stopping econnector UI and service...
taskkill /F /IM econnector-ui.exe >NUL 2>&1

sc query %SERVICE_NAME% >NUL 2>&1
if errorlevel 1 goto skip_stop
sc stop %SERVICE_NAME% >NUL 2>&1
set /a __wait=0
:wait_stop
sc query %SERVICE_NAME% | findstr /C:"STOPPED" >NUL 2>&1
if not errorlevel 1 goto stopped
set /a __wait+=1
if !__wait! GEQ 30 (
    echo WARN: timed out waiting for service to stop, continuing anyway.
    goto stopped
)
timeout /t 1 /nobreak >NUL
goto wait_stop
:stopped
:skip_stop

REM ============================================================
REM [2/4] Backup credentials/tokens, then uninstall existing copy
REM ============================================================
echo.
echo [2/4] Backing up credentials and uninstalling existing version...
if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%"
mkdir "%BACKUP_DIR%" || exit /B 1
if exist "%INSTALL_HOME%\credentials.econnector" copy /Y "%INSTALL_HOME%\credentials.econnector" "%BACKUP_DIR%\credentials.econnector" >NUL
if exist "%INSTALL_HOME%\tokens.econnector"     copy /Y "%INSTALL_HOME%\tokens.econnector"     "%BACKUP_DIR%\tokens.econnector"     >NUL

if exist "%INSTALL_HOME%\prunsrv.exe" "%INSTALL_HOME%\prunsrv.exe" //DS//%SERVICE_NAME%
if exist "%USERPROFILE%\Desktop\econnector" del /Q "%USERPROFILE%\Desktop\econnector"

REM This script was relaunched from %TEMP% when started from C:\econnector,
REM so the install directory is not locked by the running .bat.
cd /d "%TEMP%"
if exist "%INSTALL_HOME%" rmdir /s /q "%INSTALL_HOME%"
if exist "%INSTALL_HOME%" (
    echo ERROR: Failed to remove "%INSTALL_HOME%". Close File Explorer windows on that folder and retry.
    pause
    exit /B 1
)

REM ============================================================
REM [3/4] Download the requested release package from GitHub
REM ============================================================
echo.
echo [3/4] Downloading new release...
mkdir "%PKG_DIR%" || exit /B 1

if "%RELEASE_TAG%"=="" (
    for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Invoke-RestMethod -UseBasicParsing https://api.github.com/repos/%REPO%/releases/latest).tag_name"`) do set RELEASE_TAG=%%i
    if "!RELEASE_TAG!"=="" (
        echo ERROR: failed to query latest release tag.
        exit /B 1
    )
    echo Resolved latest tag: !RELEASE_TAG!
)

set ZIP_URL=https://github.com/%REPO%/releases/download/!RELEASE_TAG!/econnector-installation-win.zip
set ZIP_PATH=%PKG_DIR%\econnector-installation-win.zip

powershell -NoProfile -Command "$ErrorActionPreference='Stop'; Start-BitsTransfer -Source $env:ZIP_URL -Destination $env:ZIP_PATH"
if errorlevel 1 (
    echo ERROR: download failed from !ZIP_URL!
    pause
    exit /B 1
)

powershell -NoProfile -Command "$ErrorActionPreference='Stop'; Expand-Archive -Force -Path $env:ZIP_PATH -DestinationPath (Join-Path $env:PKG_DIR 'extracted')"
if errorlevel 1 (
    echo ERROR: failed to extract !ZIP_PATH!.
    pause
    exit /B 1
)

REM ============================================================
REM [4/4] Run install.bat from the freshly downloaded package
REM ============================================================
echo.
echo [4/4] Installing new version...
pushd "%PKG_DIR%\extracted"
call install.bat
set INSTALL_RC=!errorlevel!
popd

if not "!INSTALL_RC!"=="0" (
    echo ERROR: install.bat exited with code !INSTALL_RC!.
    pause
    exit /B !INSTALL_RC!
)

REM Restore the user's credentials/tokens. install.bat just (re)created these
REM files as empty with the correct ACL; overwriting via copy /Y keeps the
REM ACL intact while replacing the content with our backup.
echo.
echo Restoring credentials and tokens...
if exist "%BACKUP_DIR%\credentials.econnector" copy /Y "%BACKUP_DIR%\credentials.econnector" "%INSTALL_HOME%\credentials.econnector" >NUL
if exist "%BACKUP_DIR%\tokens.econnector"     copy /Y "%BACKUP_DIR%\tokens.econnector"     "%INSTALL_HOME%\tokens.econnector"     >NUL

echo.
echo Upgrade complete. Version !RELEASE_TAG! installed.
endlocal
exit /B 0

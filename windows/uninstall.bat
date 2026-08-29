@echo off
setlocal EnableExtensions
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
    set "SERVICE_NAME=econnector"
    set "INSTALL_HOME=C:\%SERVICE_NAME%"
    set "UNINST_TMP=%TEMP%\econnector-uninstall.bat"

    REM Running this .bat from C:\econnector locks the file (and therefore the
    REM directory) on Windows. Always continue from a temp copy.
    if /I "%~nx0"=="econnector-uninstall.bat" goto begin_uninstall
    goto relaunch_from_temp

:relaunch_from_temp
    copy /Y "%~f0" "%UNINST_TMP%" >NUL
    if errorlevel 1 (
      echo ERROR: Failed to copy uninstall script to "%UNINST_TMP%"
      pause
      exit /b 1
    )
    cd /d "%TEMP%"
    if errorlevel 1 (
      echo ERROR: Failed to change directory to "%TEMP%"
      pause
      exit /b 1
    )
    call "%UNINST_TMP%"
    set "RC=%ERRORLEVEL%"
    del /Q "%UNINST_TMP%" >NUL 2>&1
    exit /b %RC%

:begin_uninstall
    cd /d "%TEMP%"
::--------------------------------------

echo Uninstalling Econnector...

taskkill /F /IM econnector-ui.exe >NUL 2>&1

sc query %SERVICE_NAME% >NUL 2>&1
if not errorlevel 1 (
  echo Stopping service %SERVICE_NAME%...
  sc stop %SERVICE_NAME% >NUL 2>&1
  timeout /t 3 /nobreak >NUL
)

if exist "%INSTALL_HOME%\prunsrv.exe" (
  "%INSTALL_HOME%\prunsrv.exe" //DS//%SERVICE_NAME% >NUL 2>&1
)
sc delete %SERVICE_NAME% >NUL 2>&1

if exist "%USERPROFILE%\Desktop\econnector" del /Q "%USERPROFILE%\Desktop\econnector"

echo Removing "%INSTALL_HOME%"...
set /a __tries=0
:rm_retry
if exist "%INSTALL_HOME%" rmdir /s /q "%INSTALL_HOME%"
if not exist "%INSTALL_HOME%" goto rm_ok
set /a __tries+=1
if %__tries% LSS 5 (
  timeout /t 1 /nobreak >NUL
  goto rm_retry
)

echo.
echo ERROR: Could not fully remove "%INSTALL_HOME%".
echo Close File Explorer windows opened on that folder and try again.
pause
exit /b 1

:rm_ok
echo Uninstall completed.
exit /b 0

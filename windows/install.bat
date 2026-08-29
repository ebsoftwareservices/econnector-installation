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
    pushd "%CD%"
    CD /D "%~dp0"
    if errorlevel 1 (
      echo ERROR: Failed to change directory to "%~dp0"
      goto fail
    )
::--------------------------------------

echo Installing Econnector...
set "SERVICE_NAME=econnector"
set "CLASS_FILE=econnector-daemon.jar"
set "INSTALL_HOME=C:\%SERVICE_NAME%"
set "PR_LOGPATH=%INSTALL_HOME%\procrun-logs"
set "SCRIPT_PATH=%~dp0"
set "FILES_DIR=%SCRIPT_PATH%files"

REM Detect CPU architecture (amd64 or arm64)
set "EC_ARCH="
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "EC_ARCH=arm64"
if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "EC_ARCH=amd64"
if /i "%PROCESSOR_ARCHITEW6432%"=="ARM64" set "EC_ARCH=arm64"
if /i "%PROCESSOR_ARCHITEW6432%"=="AMD64" if "%EC_ARCH%"=="" set "EC_ARCH=amd64"
if "%EC_ARCH%"=="" (
  echo ERROR: Unsupported CPU architecture: %PROCESSOR_ARCHITECTURE%
  goto fail
)
echo Installing for %EC_ARCH%...

set "NEED_FULL_INSTALL=0"
if not exist "%PR_LOGPATH%" set "NEED_FULL_INSTALL=1"
if not exist "%INSTALL_HOME%\%CLASS_FILE%" set "NEED_FULL_INSTALL=1"
if not exist "%INSTALL_HOME%\prunsrv.exe" set "NEED_FULL_INSTALL=1"
set "JDK_EXIST="
for /d %%I in ("%INSTALL_HOME%\jdk*") do set "JDK_EXIST=1"
if not defined JDK_EXIST set "NEED_FULL_INSTALL=1"

if "%NEED_FULL_INSTALL%"=="0" (
  echo Existing complete installation detected. Repairing credential storage...
  if not exist "%SCRIPT_PATH%repair-credentials.bat" (
    echo ERROR: Missing repair script: repair-credentials.bat
    goto fail
  )
  if /I not "%SCRIPT_PATH%"=="%INSTALL_HOME%\" (
    copy /Y "%SCRIPT_PATH%repair-credentials.bat" "%INSTALL_HOME%\repair-credentials.bat"
    if errorlevel 1 (
      echo ERROR: Failed to copy repair-credentials.bat to "%INSTALL_HOME%"
      goto fail
    )
  )
  call "%INSTALL_HOME%\repair-credentials.bat"
  if errorlevel 1 goto fail
  echo Credential storage repaired successfully.
  exit /b 0
)
if exist "%PR_LOGPATH%" (
  echo Incomplete installation detected under %INSTALL_HOME%. Performing a full install.
)

if not exist "%SCRIPT_PATH%bin\prunsrv-%EC_ARCH%.exe" (
  echo ERROR: Missing Procrun service binary: "%SCRIPT_PATH%bin\prunsrv-%EC_ARCH%.exe"
  goto fail
)
if not exist "%FILES_DIR%\%CLASS_FILE%" (
  echo ERROR: Missing payload: "%FILES_DIR%\%CLASS_FILE%"
  goto fail
)

REM install java
if /i "%EC_ARCH%"=="arm64" (
  set "JDK_URL=https://corretto.aws/downloads/resources/25.0.2.10.1/amazon-corretto-25.0.2.10.1-windows-aarch64-jdk.zip"
) else (
  set "JDK_URL=https://corretto.aws/downloads/resources/25.0.2.10.1/amazon-corretto-25.0.2.10.1-windows-x64-jdk.zip"
)

set "JDK_ZIP=%SCRIPT_PATH%jdk.zip"
set "JDK_ZIP_TMP=%SCRIPT_PATH%jdk.zip.tmp"

if not exist "%JDK_ZIP%" (
  echo Downloading JDK...
  powershell -NoProfile -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile($env:JDK_URL, $env:JDK_ZIP_TMP)"
  if errorlevel 1 (
    echo ERROR: Failed to download JDK from %JDK_URL%
    goto fail
  )
  move /y "%JDK_ZIP_TMP%" "%JDK_ZIP%"
  if errorlevel 1 (
    echo ERROR: Failed to save jdk.zip
    goto fail
  )
)

if not exist "%INSTALL_HOME%" (
  mkdir "%INSTALL_HOME%"
  if errorlevel 1 (
    echo ERROR: Failed to create "%INSTALL_HOME%"
    goto fail
  )
)

echo Extracting JDK to %INSTALL_HOME%...
powershell -NoProfile -Command "$ErrorActionPreference='Stop'; Expand-Archive -Force -Path $env:JDK_ZIP -DestinationPath $env:INSTALL_HOME"
if errorlevel 1 (
  echo ERROR: Failed to extract JDK from "%JDK_ZIP%"
  if exist "%JDK_ZIP%" del /Q "%JDK_ZIP%"
  goto fail
)

set "JDK_DIR="
for /d %%I in ("%INSTALL_HOME%\jdk*") do set "JDK_DIR=%%~fI"
if not defined JDK_DIR (
  echo ERROR: Failed to locate extracted JDK directory under %INSTALL_HOME%.
  echo Contents of %INSTALL_HOME%:
  dir "%INSTALL_HOME%"
  goto fail
)
set "PR_JVM=%JDK_DIR%\bin\server\jvm.dll"
if not exist "%PR_JVM%" (
  echo ERROR: Failed to locate JVM: %PR_JVM%
  goto fail
)
echo JDK installed at %JDK_DIR%

REM Service log configuration
set "PR_LOGPREFIX=%SERVICE_NAME%"
set "PR_STDOUTPUT=auto"
set "PR_STDERROR=auto"
set "PR_PIDFILE=procrun.pid"
set "PR_LOGLEVEL=Error"
set "PR_DESCRIPTION=%SERVICE_NAME%"

REM Startup configuration
set "PR_INSTALL=%INSTALL_HOME%\prunsrv.exe"
set "PR_CLASSPATH=%INSTALL_HOME%\%CLASS_FILE%"
set "PR_STARTUP=auto"
set "PR_STARTMODE=jvm"
set "PR_STARTCLASS=com.ebsoftwareservices.econnector.daemon.EconnectorDaemonOnWindows"
set "PR_STARTMETHOD=windowsService"
set "PR_STARTPARAMS=start"
set "PR_JVMOPTIONS=-Djar.dir=%INSTALL_HOME%"

REM Shutdown configuration
set "PR_STOPMODE=jvm"
set "PR_STOPCLASS=com.ebsoftwareservices.econnector.daemon.EconnectorDaemonOnWindows"
set "PR_STOPMETHOD=windowsService"
set "PR_STOPPARAMS=stop"

REM Do not use "call :label" in this script. cmd.exe re-invokes %0 to jump to a
REM label; if the installer path contains spaces and %0 is unquoted, that
REM becomes "cannot find the batch file copy_file" (French: "nom de fichier de commandes").

REM Install service
mkdir "%PR_LOGPATH%" >NUL 2>&1

echo Copying installer scripts...
for %%F in ("%SCRIPT_PATH%*.bat") do (
  copy /Y "%%~fF" "%INSTALL_HOME%\%%~nxF"
  if errorlevel 1 (
    echo ERROR: Failed to copy "%%~fF" to "%INSTALL_HOME%\%%~nxF"
    goto fail
  )
  if not exist "%INSTALL_HOME%\%%~nxF" (
    echo ERROR: File missing after copy: "%INSTALL_HOME%\%%~nxF"
    goto fail
  )
)
if not exist "%INSTALL_HOME%\repair-credentials.bat" (
  echo ERROR: Missing installed repair script: repair-credentials.bat
  goto fail
)

echo Copying application files...
copy /Y "%FILES_DIR%\%CLASS_FILE%" "%INSTALL_HOME%\%CLASS_FILE%"
if errorlevel 1 (
  echo ERROR: Failed to copy "%FILES_DIR%\%CLASS_FILE%" to "%INSTALL_HOME%\%CLASS_FILE%"
  goto fail
)
if not exist "%INSTALL_HOME%\%CLASS_FILE%" (
  echo ERROR: File missing after copy: "%INSTALL_HOME%\%CLASS_FILE%"
  goto fail
)

for %%F in ("%FILES_DIR%\*.json") do (
  copy /Y "%%~fF" "%INSTALL_HOME%\%%~nxF"
  if errorlevel 1 (
    echo ERROR: Failed to copy "%%~fF" to "%INSTALL_HOME%\%%~nxF"
    goto fail
  )
  if not exist "%INSTALL_HOME%\%%~nxF" (
    echo ERROR: File missing after copy: "%INSTALL_HOME%\%%~nxF"
    goto fail
  )
)

if exist "%FILES_DIR%\econnector-ui.exe" (
  copy /Y "%FILES_DIR%\econnector-ui.exe" "%INSTALL_HOME%\econnector-ui.exe"
  if errorlevel 1 (
    echo ERROR: Failed to copy econnector-ui.exe to "%INSTALL_HOME%"
    goto fail
  )
  if not exist "%INSTALL_HOME%\econnector-ui.exe" (
    echo ERROR: File missing after copy: "%INSTALL_HOME%\econnector-ui.exe"
    goto fail
  )
)

copy /Y "%SCRIPT_PATH%bin\prunsrv-%EC_ARCH%.exe" "%INSTALL_HOME%\prunsrv.exe"
if errorlevel 1 (
  echo ERROR: Failed to copy prunsrv.exe to "%INSTALL_HOME%"
  goto fail
)
if not exist "%INSTALL_HOME%\prunsrv.exe" (
  echo ERROR: File missing after copy: "%INSTALL_HOME%\prunsrv.exe"
  goto fail
)
if exist "%SCRIPT_PATH%bin\prunmgr-%EC_ARCH%.exe" (
  copy /Y "%SCRIPT_PATH%bin\prunmgr-%EC_ARCH%.exe" "%INSTALL_HOME%\prunmgr.exe"
  if errorlevel 1 (
    echo ERROR: Failed to copy prunmgr.exe to "%INSTALL_HOME%"
    goto fail
  )
)

if exist "%INSTALL_HOME%\econnector-ui.exe" (
  mklink "%USERPROFILE%\Desktop\econnector" "%INSTALL_HOME%\econnector-ui.exe"
  if errorlevel 1 (
    echo WARN: Failed to create desktop shortcut.
  )
)

"%INSTALL_HOME%\prunsrv.exe" //DS//%SERVICE_NAME% >NUL 2>&1
"%INSTALL_HOME%\prunsrv.exe" //IS//%SERVICE_NAME%
if errorlevel 1 (
  echo ERROR: Failed to install Windows service %SERVICE_NAME%.
  goto fail
)

REM ---- On-demand privilege removal ----
REM Predicate the credential/token files with an explicit ACL so the UI (running
REM as a normal user) can overwrite them without UAC. SIDs are used instead of
REM names to be locale-independent.
REM   S-1-5-32-545 = BUILTIN\Users         (R,W = read/write without delete)
REM   S-1-5-32-544 = BUILTIN\Administrators (F = Full, for maintenance)
REM   S-1-5-18     = NT AUTHORITY\SYSTEM    (F = Full, daemon runs as SYSTEM)
type nul > "%INSTALL_HOME%\credentials.econnector"
if errorlevel 1 goto install_failed
type nul > "%INSTALL_HOME%\tokens.econnector"
if errorlevel 1 goto install_failed
icacls "%INSTALL_HOME%\credentials.econnector" /inheritance:r /grant:r *S-1-5-32-545:RW *S-1-5-32-544:F *S-1-5-18:F
if errorlevel 1 goto install_failed
icacls "%INSTALL_HOME%\tokens.econnector" /inheritance:r /grant:r *S-1-5-32-545:RW *S-1-5-32-544:F *S-1-5-18:F
if errorlevel 1 goto install_failed

REM Grant Interactive Users (IU) the right to start/stop the service so the UI
REM does not need to elevate. The SDDL below sets only the DACL (D:); the SACL
REM (audit) is intentionally omitted so sc.exe preserves the existing audit
REM policy and we don't need SE_SECURITY_NAME at install time. ACEs are the
REM service defaults with RP+WP (SERVICE_START + SERVICE_STOP) added to IU.
sc sdset %SERVICE_NAME% "D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWRPWPLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)"
if errorlevel 1 goto install_failed

echo.
echo Installation completed successfully.
exit /b 0

:install_failed
echo ERROR: Failed to create writable credential storage.

:fail
echo.
echo Installation FAILED. Please fix the error above and run install.bat again.
pause
exit /b 1

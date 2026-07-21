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
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    set params = %*:"="
    echo UAC.ShellExecute "cmd.exe", "/c %~s0 %params%", "", "runas", 1 >> "%temp%\getadmin.vbs"

    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    pushd "%CD%"
    CD /D "%~dp0"
::--------------------------------------

@echo on
echo Installing Econnector...
set SERVICE_NAME=econnector
set CLASS_FILE=econnector-daemon.jar
set INSTALL_HOME=C:\%SERVICE_NAME%
set PR_LOGPATH=%INSTALL_HOME%\procrun-logs
SET SCRIPT_PATH=%~dp0

REM Detect CPU architecture (amd64 or arm64)
set EC_ARCH=
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set EC_ARCH=arm64
if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" set EC_ARCH=amd64
if /i "%PROCESSOR_ARCHITEW6432%"=="ARM64" set EC_ARCH=arm64
if /i "%PROCESSOR_ARCHITEW6432%"=="AMD64" if "%EC_ARCH%"=="" set EC_ARCH=amd64
if "%EC_ARCH%"=="" (
  echo Unsupported CPU architecture: %PROCESSOR_ARCHITECTURE%
  pause
  goto:eof
)
echo Installing for %EC_ARCH%...

if exist "%PR_LOGPATH%" (
  echo Existing eConnector installation detected. Repairing credential storage...
  if not exist "%SCRIPT_PATH%\repair-credentials.bat" (
    echo Missing repair script: repair-credentials.bat
    exit /b 1
  )
  if /I not "%SCRIPT_PATH%"=="%INSTALL_HOME%\" (
    copy /Y "%SCRIPT_PATH%\repair-credentials.bat" "%INSTALL_HOME%\repair-credentials.bat" >NUL 2>&1
    if errorlevel 1 exit /b 1
  )
  call "%INSTALL_HOME%\repair-credentials.bat"
  if errorlevel 1 exit /b 1
  exit /b 0
)

if not exist "%SCRIPT_PATH%\bin\prunsrv-%EC_ARCH%.exe" (
  echo Missing Procrun service binary: bin\prunsrv-%EC_ARCH%.exe
  pause
  goto:eof
)

REM install java
if /i "%EC_ARCH%"=="arm64" (
  set JDK_URL=https://corretto.aws/downloads/resources/25.0.2.10.1/amazon-corretto-25.0.2.10.1-windows-aarch64-jdk.zip
) else (
  set JDK_URL=https://corretto.aws/downloads/resources/25.0.2.10.1/amazon-corretto-25.0.2.10.1-windows-x64-jdk.zip
)

if not exist jdk.zip (
powershell -command "Start-BitsTransfer -Source %JDK_URL% -Destination jdk.zip.tmp"
move /y jdk.zip.tmp jdk.zip
)

if not exist "%INSTALL_HOME%" mkdir "%INSTALL_HOME%"
powershell -command "Expand-Archive -Force jdk.zip %INSTALL_HOME%"

set JDK_DIR=
for /d %%I in ("%INSTALL_HOME%\jdk*") do set JDK_DIR=%%~fI
if "%JDK_DIR%"=="" (
  echo Failed to locate extracted JDK directory under %INSTALL_HOME%.
  pause
  goto:eof
)
set PR_JVM=%JDK_DIR%\bin\server\jvm.dll
if not exist "%PR_JVM%" (
  echo Failed to locate JVM: %PR_JVM%
  pause
  goto:eof
)

REM Service log configuration
set PR_LOGPREFIX=%SERVICE_NAME%
set PR_STDOUTPUT=auto
set PR_STDERROR=auto
set PR_PIDFILE=procrun.pid
set PR_LOGLEVEL=Error
set PR_DESCRIPTION=%SERVICE_NAME%

REM Startup configuration
set PR_INSTALL=%INSTALL_HOME%\prunsrv.exe
set PR_CLASSPATH=%INSTALL_HOME%\%CLASS_FILE%
set PR_STARTUP=auto
set PR_STARTMODE=jvm
set PR_STARTCLASS=com.ebsoftwareservices.econnector.daemon.EconnectorDaemonOnWindows
set PR_STARTMETHOD=windowsService
set PR_STARTPARAMS=start
set PR_JVMOPTIONS=-Djar.dir=%INSTALL_HOME%

REM Shutdown configuration
set PR_STOPMODE=jvm
set PR_STOPCLASS=com.ebsoftwareservices.econnector.daemon.EconnectorDaemonOnWindows
set PR_STOPMETHOD=windowsService
set PR_STOPPARAMS=stop

REM Install service
mkdir "%PR_LOGPATH%" >NUL 2>&1
xcopy /E /Y "%SCRIPT_PATH%*.bat" "%INSTALL_HOME%\" >NUL 2>&1
if errorlevel 1 (
  echo ERROR: Failed to copy installer scripts to %INSTALL_HOME%.
  exit /b 1
)
if not exist "%INSTALL_HOME%\repair-credentials.bat" (
  echo ERROR: Missing installed repair script: repair-credentials.bat
  exit /b 1
)
if exist "%SCRIPT_PATH%\files\*.jar" xcopy /Y %SCRIPT_PATH%\files\*.jar "%INSTALL_HOME%\" >NUL 2>&1
if exist "%SCRIPT_PATH%\files\*.json" xcopy /Y %SCRIPT_PATH%\files\*.json "%INSTALL_HOME%\" >NUL 2>&1
if exist "%SCRIPT_PATH%\files\econnector-ui.exe" copy /Y "%SCRIPT_PATH%\files\econnector-ui.exe" "%INSTALL_HOME%\" >NUL 2>&1
copy /Y "%SCRIPT_PATH%\bin\prunsrv-%EC_ARCH%.exe" "%INSTALL_HOME%\prunsrv.exe" >NUL 2>&1
if exist "%SCRIPT_PATH%\bin\prunmgr-%EC_ARCH%.exe" copy /Y "%SCRIPT_PATH%\bin\prunmgr-%EC_ARCH%.exe" "%INSTALL_HOME%\prunmgr.exe" >NUL 2>&1
if exist "%INSTALL_HOME%\econnector-ui.exe" mklink "%USERPROFILE%"\Desktop\econnector "%INSTALL_HOME%"\econnector-ui.exe
"%INSTALL_HOME%\prunsrv.exe" //DS//%SERVICE_NAME% >NUL 2>&1
"%INSTALL_HOME%\prunsrv.exe" //IS//%SERVICE_NAME%
REM "%INSTALL_HOME%\prunsrv.exe" //ES//%SERVICE_NAME%

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

exit /b 0

:install_failed
echo ERROR: Failed to create writable credential storage.
exit /b 1

:eof

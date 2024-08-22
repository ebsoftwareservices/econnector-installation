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

if exist %PR_LOGPATH% (
  echo There is a copy of %SERVICE_NAME% installed, please remove it first.
  pause
  goto:eof
)

REM install java
if not exist jdk.zip (
powershell -command "Start-BitsTransfer -Source https://download.java.net/java/GA/jdk21.0.2/f2283984656d49d69e91c558476027ac/13/GPL/openjdk-21.0.2_windows-x64_bin.zip -Destination jdk.zip.tmp"
move /y jdk.zip.tmp jdk.zip
)

powershell -command "Expand-Archive jdk.zip %INSTALL_HOME%"
set PR_JVM=%INSTALL_HOME%\jdk-21.0.2\bin\server\jvm.dll

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
xcopy /E %SCRIPT_PATH%\*.bat "%INSTALL_HOME%" >NUL 2>&1
xcopy /E %SCRIPT_PATH%\files\* "%INSTALL_HOME%" >NUL 2>&1
mklink "%USERPROFILE%"\Desktop\econnector "%INSTALL_HOME%"\econnector-ui.exe
"%INSTALL_HOME%\prunsrv.exe" //DS//%SERVICE_NAME% >NUL 2>&1
"%INSTALL_HOME%\prunsrv.exe" //IS//%SERVICE_NAME%
REM "%INSTALL_HOME%\prunsrv.exe" //ES//%SERVICE_NAME%

:eof

echo Installing Econnector...
set SERVICE_NAME=econnector
set CLASS_FILE=econnector-daemon.jar
set INSTALL_HOME=C:\%SERVICE_NAME%
set PR_LOGPATH=%INSTALL_HOME%\logs
SET SCRIPT_PATH=%~dp0

if exist %PR_LOGPATH% (
  echo There is a copy of %SERVICE_NAME% installed, please remove it first.
  pause
  goto end
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
set PR_STDOUTPUT=stdout.txt
set PR_STDERROR=stderr.txt
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

:end

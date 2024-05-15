echo "Installing Econnector..."
@echo off 
call config.bat

set INSTALL_HOME=C:\%SERVICE_NAME%

REM Service log configuration
set PR_LOGPREFIX=%SERVICE_NAME%
set PR_LOGPATH=%INSTALL_HOME%\logs
set PR_STDOUTPUT=auto
set PR_STDERROR=auto
set PR_LOGLEVEL=Info
set PR_DESCRIPTION=%SERVICE_NAME%

REM Path to java installation
REM https://download.java.net/java/GA/jdk21.0.2/f2283984656d49d69e91c558476027ac/13/GPL/openjdk-21.0.2_windows-x64_bin.zip
set PR_JVM=%INSTALL_HOME%\jdk-21\bin\server\jvm.dll
set PR_INSTALL=%INSTALL_HOME%\prunsrv.exe
set PR_CLASSPATH=%INSTALL_HOME%\%CLASS_FILE%
 
REM Startup configuration
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

REM Install servic 
mkdir "%PR_LOGPATH%" >NUL 2>&1
xcopy /E . "%INSTALL_HOME%" >NUL 2>&1
"%INSTALL_HOME%\prunsrv.exe" //DS//%SERVICE_NAME% >NUL 2>&1
"%INSTALL_HOME%\prunsrv.exe" //IS//%SERVICE_NAME%
@echo on
"%INSTALL_HOME%\prunsrv.exe" //ES//%SERVICE_NAME%

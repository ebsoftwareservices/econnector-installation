echo "Uninstalling Econnector..."
@echo off 
call config.bat
set INSTALL_HOME=C:\%SERVICE_NAME%

@echo on

"%INSTALL_HOME%\prunsrv.exe" //DS//%SERVICE_NAME%
del "%USERPROFILE%"\Desktop\econnector
rmdir /s /q %INSTALL_HOME%

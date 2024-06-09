echo Uninstalling Econnector...
@echo off 
set SERVICE_NAME=econnector
set INSTALL_HOME=C:\%SERVICE_NAME%

@echo on

"%INSTALL_HOME%\prunsrv.exe" //DS//%SERVICE_NAME%
del "%USERPROFILE%"\Desktop\econnector
rmdir /s /q %INSTALL_HOME%

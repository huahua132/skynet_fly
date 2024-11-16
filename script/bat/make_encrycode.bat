@echo off
set skynet_fly_path=%1
set key=%2
set targetpath=%3

set lua=%skynet_fly_path%\skynet\3rd\lua\lua.exe
set script_path=%skynet_fly_path%\script\lua

if not exist "%lua%" (
    echo Lua executable not found at: %lua%
    exit /b 1
)

%lua% "%script_path%\encrycode.lua" %skynet_fly_path% %key% %targetpath%
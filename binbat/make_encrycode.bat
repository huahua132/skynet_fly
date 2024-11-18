@echo off
set skynet_fly_path=%1
set key=%2
set targetpath=%3

if "%skynet_fly_path%" == "" (
    echo please format make_encrycode.bat skynet_fly_path key targetpath
    exit /b 1
)

if "%key%" == "" (
    echo please format make_encrycode.bat skynet_fly_path key targetpath
    exit /b 1
)

if "%targetpath%" == "" (
    echo please format make_encrycode.bat skynet_fly_path key targetpath
    exit /b 1
)

set bat_path="%skynet_fly_path%/script/bat"

if not exist "%bat_path%\make_server.bat" (
    echo make_server.bat not exists %bat_path%
    exit /b 1
)

call "%bat_path%\make_encrycode.bat" %skynet_fly_path% %key% %targetpath%


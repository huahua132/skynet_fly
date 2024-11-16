@echo off
set skynet_fly_path=%1
if "%skynet_fly_path%" == "" (
    echo "please format make_server.bat skynet_fly_path"
    exit /b 1
)

set load_mods_name=%2
if "%skynet_fly_path%" == "" (
    load_mods_name="load_mods"
)

set bat_path="%skynet_fly_path%/script/bat"

if not exist "%bat_path%\make_server.bat" (
    echo make_server.bat not exists %bat_path%
    exit /b 1
)

call "%bat_path%\make_server.bat" %skynet_fly_path% %load_mods_name%
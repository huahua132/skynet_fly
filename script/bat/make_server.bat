@echo off
set skynet_fly_path=%1
set load_mods_name=%2

set lua=%skynet_fly_path%\skynet\3rd\lua\lua.exe
set script_path=%skynet_fly_path%\script\lua

if not exist "%lua%" (
    echo Lua executable not found at: %lua%
    exit /b 1
)

%lua% "%script_path%\write_config.lua" %skynet_fly_path% %load_mods_name%
%lua% "%script_path%\write_runsh.lua" %skynet_fly_path%
%lua% "%script_path%\write_reloadsh.lua" %skynet_fly_path%
%lua% "%script_path%\write_stopsh.lua" %skynet_fly_path%
%lua% "%script_path%\write_check_reloadsh.lua" %skynet_fly_path%
%lua% "%script_path%\write_killmodsh.lua" %skynet_fly_path%
%lua% "%script_path%\write_restartsh.lua" %skynet_fly_path%
%lua% "%script_path%\write_try_again_reloadsh.lua" %skynet_fly_path%
%lua% "%script_path%\write_fasttimesh.lua" %skynet_fly_path%
%lua% "%script_path%\write_hotfixsh.lua" %skynet_fly_path%
%lua% "%script_path%\write_check_hotfixsh.lua" %skynet_fly_path%
%lua% "%script_path%\write_upsharedatash.lua" %skynet_fly_path%

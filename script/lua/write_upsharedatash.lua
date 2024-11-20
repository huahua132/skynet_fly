local assert = assert
local ARGV = {...}
local skynet_fly_path = ARGV[1]
assert(skynet_fly_path,'缺少 skynet_fly_path')

package.cpath = skynet_fly_path .. "/luaclib/?.so;"
package.path = './?.lua;' .. skynet_fly_path .."/lualib/?.lua;"
local file_util = require "skynet-fly.utils.file_util"
local svr_name = file_util.get_cur_dir_name()

local skynet_path = file_util.path_join(skynet_fly_path, '/skynet')
local lua_path = skynet_path .. '/3rd/lua/lua'
local server_path = "./"
local script_path = file_util.path_join(skynet_fly_path, '/script/lua')

if not file_util.is_window() then 
	local shell_str = "#!/bin/bash\n"
	shell_str = shell_str .. [[
if [ "$#" -ne 1 ]; then
	echo "please format make/script/upsharedata.sh load_mods.lua"
	exit 1
fi
load_mods_name=$1
shift
]]
	shell_str = shell_str .. string.format("%s %s/console.lua %s %s ${load_mods_name} get_list | \n",lua_path,script_path,skynet_fly_path,svr_name)
	shell_str = shell_str .. string.format("xargs curl -s |\n")
	shell_str = shell_str .. string.format("xargs %s %s/console.lua %s %s ${load_mods_name} find_server_id sharedata_service 2 | \\\n",lua_path,script_path,skynet_fly_path,svr_name)
	shell_str = shell_str .. string.format("xargs -t -I {} %s %s/console.lua %s %s ${load_mods_name} upsharedata {} | \n",lua_path,script_path,skynet_fly_path,svr_name)
	shell_str = shell_str .. string.format("xargs -t curl -s | \n")
	shell_str = shell_str .. string.format("xargs -t %s %s/console.lua %s %s ${load_mods_name} handle_upsharedata_result | xargs",lua_path,script_path,skynet_fly_path,svr_name)

	local shell_path = server_path .. 'make/script/'

	local isok, err = file_util.mkdir(shell_path)
	if not isok then
		error("create shell_path err " .. err)
	end

	local file_path = shell_path .. 'upsharedata.sh'

	local file = io.open(file_path,'w+')
	assert(file)
	file:write(shell_str)
	file:close()
	print("make " .. file_path)
else
    --windows
    lua_path = file_util.convert_linux_to_windows_relative(lua_path) .. ".exe"
	script_path = file_util.convert_linux_to_windows_relative(script_path)
	skynet_fly_path = file_util.convert_linux_to_windows_relative(skynet_fly_path)
	skynet_path = file_util.convert_linux_to_windows_relative(skynet_path)
    local bat_str = [[
@echo off
set load_mods=%1

if "%load_mods%" == "" (
	echo please format make/script/upsharedata.bat load_mods.lua
	exit /b 1
)

set getlisturl=""
for /f %%i in ('{lua_path} {skynet_fly_path}\script\lua\console.lua {skynet_fly_path} {svr_name} %load_mods% get_list') do (
	set getlisturl=%%i
)
echo %getlisturl%
set serverid=""
for /f "delims=" %%i in ('curl -s %getlisturl%') do (
	echo %%i | findstr /C:"sharedata_service" > nul
	if not errorlevel 1 set serverid=%%i
)

if "%serverid%" == "" (
	echo not found serverid
	exit /b 1
)

set up_url=""
for /f "delims=" %%i in ('{lua_path} {skynet_fly_path}\script\lua\console.lua {skynet_fly_path} {svr_name} %load_mods% upsharedata %serverid:~0,9%') do (
	set up_url=%%i
)

echo %up_url:~1,-1%

for /f "delims=" %%i in ('curl -s -X GET "%up_url:~1,-1%"') do (
	echo %%i
	{lua_path} {skynet_fly_path}\script\lua\console.lua {skynet_fly_path} record %load_mods% handle_upsharedata_result %%i
	goto end
)

:end
]]
    bat_str = string.gsub(bat_str, "{(.-)}", function(name)
        if name == "svr_name" then
            return svr_name
        elseif name == "lua_path" then
            return lua_path
        elseif name == "skynet_path" then
            return skynet_path
        elseif name == "skynet_fly_path" then
            return skynet_fly_path
        else
            error("unknown pat name:", name)
        end
    end)

    local bat_path = server_path .. 'make\\script\\'
    local isok, err = file_util.mkdir(bat_path)
    if not isok then
        error("create bat_path err " .. err)
    end
    local file_path = bat_path .. 'upsharedata.bat'

    local file = io.open(file_path,'w+')
    assert(file)
    file:write(bat_str)
    file:close()
    print("make " .. file_path)
end
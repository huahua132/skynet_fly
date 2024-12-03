local assert = assert
local ARGV = {...}
local skynet_fly_path = ARGV[1]
assert(skynet_fly_path,'缺少 skynet_fly_path')

if package.config:sub(1, 1) == '\\' then
	package.cpath = skynet_fly_path .. "/luaclib/?.dll;"
else
	package.cpath = skynet_fly_path .. "/luaclib/?.so;"
end
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
	echo "please format make/script/try_again_reload.sh load_mods.lua"
	exit 1
fi

if [ ! -f "./make/$1.tmp_reload_cmd.txt" ]; then
	echo "not try_reload file"
	exit 1 \n 
fi
]]
	shell_str = shell_str .. string.format("%s %s/console.lua %s %s $1 try_again_reload | \n",lua_path,script_path,skynet_fly_path,svr_name)
	shell_str = shell_str .. string.format("xargs -t curl -s | \n")
	shell_str = shell_str .. string.format("xargs -t %s %s/console.lua %s %s $1 handle_reload_result | xargs \n",lua_path,script_path,skynet_fly_path,svr_name)

	local shell_path = server_path .. 'make/script/'

	local isok, err = file_util.mkdir(shell_path)
	if not isok then
		error("create shell_path err " .. err)
	end

	local file_path = shell_path .. 'try_again_reload.sh'

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
	--windows
	local bat_str = [[
@echo off
set load_mods=%1

if "%load_mods%" == "" (
    echo please format make\script\try_again_reload.sh load_mods.lua
    exit /b 1
)

if not exist .\make\%load_mods%.tmp_reload_cmd.txt (
    echo not need try_again_reload
    exit /b 1
)

set reload_url = ""
for /f "delims=" %%i in ('{lua_path} {skynet_fly_path}\script\lua\console.lua {skynet_fly_path} {svr_name} %load_mods% try_again_reload') do (
	set reload_url=%%i
)

echo %reload_url:~1,-1%

for /f "delims=" %%i in ('curl -s -X GET "%reload_url:~1,-1%"') do (
	echo %%i
	{lua_path} {skynet_fly_path}\script\lua\console.lua {skynet_fly_path} {svr_name} %load_mods% handle_reload_result %%i
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
	local file_path = bat_path .. 'try_again_reload.bat'

	local file = io.open(file_path,'w+')
	assert(file)
	file:write(bat_str)
	file:close()
	print("make " .. file_path)
end
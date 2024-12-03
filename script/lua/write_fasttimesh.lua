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
if [ "$#" -ne 3 ]; then
	echo "please format make/script/fasttime.sh load_mods.lua 2023:10:26-19:22:50 1"
	exit 1
fi
]]
	shell_str = shell_str .. string.format('%s %s/console.lua %s %s $1 fasttime "$2" $3 | \n',lua_path,script_path,skynet_fly_path,svr_name)
	shell_str = shell_str .. string.format("xargs -t curl -s \n")

	local shell_path = server_path .. 'make/script/'

	local isok, err = file_util.mkdir(shell_path)
	if not isok then
		error("create shell_path err " .. err)
	end

	local file_path = shell_path .. 'fasttime.sh'

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
set data_time=%2
set once_add=%3

if "%load_mods%" == "" (
    echo please format make/script/fasttime.sh load_mods.lua 2023:10:26-19:22:50 1
    exit /b 1
)

if "%data_time%" == "" (
    echo please format make/script/fasttime.sh load_mods.lua 2023:10:26-19:22:50 1
    exit /b 1
)

if "%once_add%" == "" (
    echo please format make/script/fasttime.sh load_mods.lua 2023:10:26-19:22:50 1
    exit /b 1
)

set url = ""
for /f "delims=" %%i in ('{lua_path} {skynet_fly_path}\script\lua\console.lua {skynet_fly_path} {svr_name} %load_mods% fasttime "%data_time%" %once_add%') do (
	set url=%%i
)

for /f "delims=" %%i in ('curl -s -X GET "%url:~1,-1%"') do (
    echo %%i
)
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
	local file_path = bat_path .. 'fasttime.bat'

	local file = io.open(file_path,'w+')
	assert(file)
	file:write(bat_str)
	file:close()
	print("make " .. file_path)
end
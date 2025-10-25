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
if [ "$#" -lt 1 ]; then
	echo "arg1 [load_mods] 启动的load_mods配置"
	echo "please format make/script/stop.sh load_mods.lua"
	exit 1
fi
load_mods_name=$1
]]

	shell_str = shell_str .. string.format('if pgrep -f "skynet.make/%s_config.lua ${load_mods_name}" > /dev/null; then\n', svr_name)
	shell_str = shell_str .. string.format("\t%s %s/console.lua %s %s ${load_mods_name} get_list | \n",lua_path,script_path,skynet_fly_path,svr_name)
	shell_str = shell_str .. string.format("\txargs curl -s |\n")
	shell_str = shell_str .. string.format("\txargs %s %s/console.lua %s %s ${load_mods_name} find_server_id container_mgr 2 | \n",lua_path,script_path,skynet_fly_path,svr_name)
	shell_str = shell_str .. string.format("\txargs -t %s %s/console.lua %s %s ${load_mods_name} call shutdown | \n",lua_path,script_path,skynet_fly_path,svr_name)
	shell_str = shell_str .. string.format("\txargs -t curl -s\n")
	shell_str = shell_str .. string.format('\tpids=$(pgrep -f "skynet.make/%s_config.lua ${load_mods_name}")\n',svr_name)
	shell_str = shell_str .. string.format('\tfor pid in $pids; do\n')
	shell_str = shell_str .. string.format('\t\tkill $pid\n')
	shell_str = shell_str .. string.format('\t\techo kill $pid\n')
	shell_str = shell_str .. string.format('\t\twait $pid 2>/dev/null\n')
	shell_str = shell_str .. string.format('\tdone\n')
	shell_str = shell_str .. string.format('\techo kill ok\n')
	shell_str = shell_str .. "\trm -f ./make/skynet.$1.pid\n"
	shell_str = shell_str .. string.format("\trm -f ./make/%s_config.lua.$1.run\n",svr_name)
	shell_str = shell_str .. "\trm -f ./make/$1.old\n"
	shell_str = shell_str .. "\trm -rf ./make/module_info_$(echo \"$load_mods_name\" | sed 's/\\.lua$//')\n"
	shell_str = shell_str .. "\trm -rf ./make/hotfix_info_$(echo \"$load_mods_name\" | sed 's/\\.lua$//')\n"
	shell_str = shell_str .. "else\n"
	shell_str = shell_str .. "\techo not exists pid\n"
	shell_str = shell_str .. "fi\n"

	local shell_path = server_path .. 'make/script/'

	local isok, err = file_util.mkdir(shell_path)
	if not isok then
		error("create shell_path err " .. err)
	end

	local file_path = shell_path .. 'stop.sh'

	local file = io.open(file_path,'w+')
	assert(file)
	file:write(shell_str)
	file:close()
	print("make " .. file_path)
else
	lua_path = file_util.convert_linux_to_windows_relative(lua_path) .. ".exe"
	script_path = file_util.convert_linux_to_windows_relative(script_path)
	skynet_fly_path = file_util.convert_linux_to_windows_relative(skynet_fly_path)
	skynet_path = file_util.convert_linux_to_windows_relative(skynet_path)
	--windows
	local bat_str = [[
@echo off
set load_mods=%1
if "%load_mods%" == "" (
	echo arg1 [load_mods] 启动的load_mods配置
	echo please format make\script\stop.bat load_mods.lua
	exit /b 1
)

set found=0
for /f "skip=3 tokens=2" %%i in ('tasklist /FI "WINDOWTITLE eq skynet make\{svr_name}_config.lua %load_mods%"') do (
	if not "%%i" == "" (
		set found=1
	)
)

if %found% == 0 (
	echo not found pid
	exit /b 1
)

set getlisturl=""
for /f %%i in ('{lua_path} {skynet_fly_path}\script\lua\console.lua {skynet_fly_path} {svr_name} %load_mods% get_list') do (
	set getlisturl=%%i
)
echo %getlisturl%
set serverid=""
for /f "delims=" %%i in ('curl -s %getlisturl%') do (
	echo %%i | findstr /C:"container_mgr" > nul
	if not errorlevel 1 set serverid=%%i
)

if "%serverid%" == "" (
	echo not found serverid
	exit /b 1
)
echo %serverid:~0,9%
set shut_down_url=""
for /f %%i in ('{lua_path} {skynet_fly_path}\script\lua\console.lua {skynet_fly_path} {svr_name} %load_mods% ^call ^shutdown %serverid:~0,9%') do (
	set shut_down_url=%%i
)

echo %shut_down_url:~1,-1%

for /f "delims=" %%i in ('curl -s -X GET "%shut_down_url:~1,-1%"') do (
	echo %%i
)

for /f "skip=3 tokens=2" %%i in ('tasklist /FI "WINDOWTITLE eq skynet make\{svr_name}_config.lua %load_mods%"') do (
	if not "%%i" == "" (
		echo taskkill %%i
		taskkill /PID %%i /F
	)
)

del /F .\make\{svr_name}_config.lua.%load_mods%.run
del /F .\make\%load_mods%.old
rmdir /S /Q .\make\module_info_%load_mods:~0,-4%
rmdir /S /Q .\make\hotfix_info_%load_mods:~0,-4%
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
	local file_path = bat_path .. 'stop.bat'

	local file = io.open(file_path,'w+')
	assert(file)
	file:write(bat_str)
	file:close()
	print("make " .. file_path)
end
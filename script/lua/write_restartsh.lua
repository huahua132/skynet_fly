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

local server_path = "./"

if not file_util.is_window() then
	local shell_str = "#!/bin/bash\n"
	shell_str = shell_str .. [[
if [ "$#" -lt 1 ]; then
	echo "arg1 [load_mods] 启动的load_mods配置"
	echo "arg2 [is_daemon] 是否守护进程运行 1是0不是 默认1"
	echo "arg3 [recordfile] 播放录像文件路径  可选"
	echo "please format make/script/restart.sh load_mods is_daemon"
	exit 1
fi
]]
	shell_str = shell_str .. "sh make/script/stop.sh $1" .. '\n'
	shell_str = shell_str .. "sleep 1" .. '\n'
	shell_str = shell_str .. "sh make/script/run.sh $1 $2 $3" .. '\n'

	local shell_path = server_path .. 'make/script/'

	local isok, err = file_util.mkdir(shell_path)
	if not isok then
		error("create shell_path err " .. err)
	end

	local file_path = shell_path .. 'restart.sh'

	local file = io.open(file_path,'w+')
	assert(file)
	file:write(shell_str)
	file:close()
	print("make " .. file_path)
else
	--windows
	local bat_str = [[
@echo off
set load_mods=%1
if "%load_mods%" == "" (
	echo please format make\script\run.bat load_mods.lua is_daemon recordfile
	exit /b 1
)

call make\script\stop.bat %1

call make\script\run.bat %1 %2 %3
]]
    local bat_path = server_path .. 'make\\script\\'
    local isok, err = file_util.mkdir(bat_path)
    if not isok then
        error("create bat_path err " .. err)
    end
    local file_path = bat_path .. 'restart.bat'

    local file = io.open(file_path,'w+')
    assert(file)
    file:write(bat_str)
    file:close()
    print("make " .. file_path)
end
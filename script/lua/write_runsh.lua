local assert = assert
local ARGV = {...}
local skynet_fly_path = ARGV[1]
assert(skynet_fly_path,'缺少 skynet_fly_path')

package.cpath = skynet_fly_path .. "/luaclib/?.so;"
package.path = './?.lua;' .. skynet_fly_path .."/lualib/?.lua;"
local file_util = require "skynet-fly.utils.file_util"
local svr_name = file_util.get_cur_dir_name()

local skynet_path = file_util.path_join(skynet_fly_path, '/skynet')
local server_path = "./"
local lua_path = skynet_path .. '/3rd/lua/lua'
local script_path = file_util.path_join(skynet_fly_path, '/script/lua')

local shell_str = "#!/bin/bash\n"
shell_str = shell_str .. [[
if [ "$#" -lt 1 ]; then
	echo "arg1 [load_mods] 启动的load_mods配置"
	echo "arg2 [is_daemon] 是否守护进程运行 1是0不是 默认1"
	echo "arg3 [recordfile] 播放录像文件路径  可选"
	echo "please format make/script/run.sh load_mods.lua is_daemon"
	exit 1
fi
]]
shell_str = shell_str .. string.format("echo run %s $1 $2 $3\n",svr_name)
shell_str = shell_str .. string.format("%s %s/write_config.lua %s $1 $2 $3\n",lua_path,script_path,skynet_fly_path)
shell_str = shell_str .. string.format("%s %s/console.lua %s %s $1 create_running_config\n",lua_path,script_path,skynet_fly_path,svr_name)
shell_str = shell_str .. string.format("%s %s/console.lua %s %s $1 create_load_mods_old\n",lua_path,script_path,skynet_fly_path,svr_name)
shell_str = shell_str .. string.format("%s/skynet make/%s_config.lua $1\n",skynet_path,svr_name)
local shell_path = server_path .. 'make/script/'

if not os.execute("mkdir -p " .. shell_path) then
	error("create shell_path err")
end

local file_path = shell_path .. 'run.sh'

local file = io.open(file_path,'w+')
assert(file)
file:write(shell_str)
file:close()
print("make " .. file_path)
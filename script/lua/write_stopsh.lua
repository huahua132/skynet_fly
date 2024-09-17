local assert = assert
local ARGV = {...}
local skynet_fly_path = ARGV[1]
assert(skynet_fly_path,'缺少 skynet_fly_path')

package.cpath = skynet_fly_path .. "/luaclib/?.so;"
package.path = './?.lua;' .. skynet_fly_path .."/lualib/?.lua;"
local file_util = require "skynet-fly.utils.file_util"
local svr_name = file_util.get_cur_dir_name()

local server_path = "./"

local shell_str = "#!/bin/bash\n"
shell_str = shell_str .. [[
if [ "$#" -lt 1 ]; then
	echo "arg1 [load_mods] 启动的load_mods配置"
	echo "please format script/stop.sh load_mods.lua"
	exit 1
fi
]]
shell_str = shell_str .. string.format("pkill -f skynet.make/%s_config.lua.$1\n",svr_name)
shell_str = shell_str .. "rm -f ./make/skynet.$1.pid\n"
shell_str = shell_str .. string.format("rm -f ./make/%s_config.lua.$1.run\n",svr_name)
shell_str = shell_str .. "rm -f ./make/$1.old\n"
shell_str = shell_str .. "rm -rf ./make/module_info.$1\n"
shell_str = shell_str .. "rm -rf ./make/hotfix_info.$1\n"
shell_str = shell_str .. string.format("echo kill %s $1\n",svr_name)

local shell_path = server_path .. 'make/script/'

if not os.execute("mkdir -p " .. shell_path) then
	error("create shell_path err")
end

local file_path = shell_path .. 'stop.sh'

local file = io.open(file_path,'w+')
assert(file)
file:write(shell_str)
file:close()
print("make " .. file_path)
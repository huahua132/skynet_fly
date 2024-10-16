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

local shell_str = "#!/bin/bash\n"
shell_str = shell_str .. [[
if [ "$#" -lt 1 ]; then
	echo "arg1 [load_mods] 启动的load_mods配置"
	echo "please format script/stop.sh load_mods.lua"
	exit 1
fi
load_mods_name=$1
]]

shell_str = shell_str .. string.format('if pgrep -f "skynet.make/%s_config.lua ${load_mods_name}" > /dev/null; then\n', svr_name)
shell_str = shell_str .. string.format("\t%s %s/console.lua %s %s ${load_mods_name} get_list | \n",lua_path,script_path,skynet_fly_path,svr_name)
shell_str = shell_str .. string.format("\txargs curl -s |\n")
shell_str = shell_str .. string.format("\txargs %s %s/console.lua %s %s ${load_mods_name} find_server_id contriner_mgr 2 | \n",lua_path,script_path,skynet_fly_path,svr_name)
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
shell_str = shell_str .. "\trm -rf ./make/module_info.$1\n"
shell_str = shell_str .. "\trm -rf ./make/hotfix_info.$1\n"
shell_str = shell_str .. "else\n"
shell_str = shell_str .. "\techo not exists pid\n"
shell_str = shell_str .. "fi\n"

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
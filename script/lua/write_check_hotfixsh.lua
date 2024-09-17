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
if [ "$#" -ne 1 ]; then
	echo "please format make/script/check_hotfix.sh load_mods.lua"
	exit 1
fi
]]
shell_str = shell_str .. string.format("%s %s/console.lua %s %s $1 check_hotfix | \n",lua_path,script_path,skynet_fly_path,svr_name)
shell_str = shell_str .. string.format("xargs -r -t sh make/script/hotfix.sh $1 \n",lua_path,script_path,skynet_fly_path,svr_name)

local shell_path = server_path .. 'make/script/'

if not os.execute("mkdir -p " .. shell_path) then
	error("create shell_path err")
end

local file_path = shell_path .. 'check_hotfix.sh'

local file = io.open(file_path,'w+')
assert(file)
file:write(shell_str)
file:close()
print("make " .. file_path)

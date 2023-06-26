local ARGV = {...}
local skynet_fly_path = ARGV[1]
local svr_name = ARGV[2]
local cmd = ARGV[3]
assert(skynet_fly_path,'缺少 skynet_fly_path')
assert(svr_name,'缺少 svr_name')
assert(cmd,"缺少命令")

package.cpath = skynet_fly_path .. "/luaclib/?.so;"
package.path = './?.lua;' .. skynet_fly_path .."/lualib/?.lua;"

local lfs = require "lfs"
local util = require "util"
local json = require "cjson"
debug_port = nil
local skynet_cfg_path = string.format("%s_config",svr_name)
require(skynet_cfg_path)

local function get_host()
	assert(debug_port)
	return string.format("http://127.0.0.1:%s",debug_port)
end

local CMD = {}

function CMD.get_list()
	print(get_host() .. '/list')
end

function CMD.find_server_id()
	local module_name = assert(ARGV[4])
	local offset = assert(ARGV[5])
	for i = 5,#ARGV do
		local line = ARGV[i]
		if string.find(line,module_name,nil,true) then
			print(ARGV[i - offset])
			return
		end
	end
	assert(1 == 2)
end

function CMD.reload()
	local module_name = assert(ARGV[4])
	local server_id = assert(ARGV[5])
	local skynet_fly_mod_path = skynet_fly_path .. '/module'
	local svr_mod_path = './module'

	local is_exists = false
	local find_path_list = {svr_mod_path,skynet_fly_mod_path}
	for _,path in ipairs(find_path_list) do
		for filename in util.diripairs(path) do
			if string.find(filename,module_name .. '.lua',nil,true) then
				is_exists = true
				break
			end
		end
	end
	assert(is_exists)

	local mod_config = require "mod_config"
	local mod_cfg = mod_config[module_name]
	assert(mod_cfg,"not mod_cfg")

	local reload_url = string.format('%s/call/%s/"load_module","%s"',get_host(),server_id,module_name)
	print(string.format("'%s'",reload_url))
end

CMD[cmd]()
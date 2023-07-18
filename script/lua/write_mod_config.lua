local assert = assert
local ARGV = {...}
local skynet_fly_path = ARGV[1]
assert(skynet_fly_path,'缺少 skynet_fly_path')

package.cpath = skynet_fly_path .. "/luaclib/?.so;"
package.path = './?.lua;' .. skynet_fly_path .."/lualib/utils/?.lua;"

local lfs = require "lfs"
local json = require "cjson"
local table_util = require "table_util"

local skynet_path = skynet_fly_path .. '/skynet/'
local server_path = "./"

local mod_config_path = server_path .. '/' .. 'mod_config.lua'

local old_mod_config = loadfile(mod_config_path)

if not old_mod_config then
    local file = io.open(mod_config_path,'w+')
    assert(file)
	local mod_config = require "load_mods"
	assert(mod_config)
    file:write(table_util.table_to_luafile("M",mod_config))
    file:close()
else
    local new = require "load_mods"
    local old = old_mod_config()
    local def = table_util.check_def_table(new,old)
	local mod_config = table_util.update_tab_by_def(def,old,{['typedef'] = true,['reduce'] = true,['add'] = true})
	local new_file = io.open(mod_config_path,'w+')
	new_file:write(table_util.table_to_luafile("M",mod_config))
    new_file:close()
end
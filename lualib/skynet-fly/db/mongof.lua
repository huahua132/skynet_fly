
local contriner_client = require "skynet-fly.client.contriner_client"
local mongo = require "skynet.db.mongo"
contriner_client:register("share_config_m")

local assert = assert
local setmetatable = setmetatable

local g_instance_map = {}
local M = {}

function M.new_client(db_name)
	local cli = contriner_client:new('share_config_m')
	local conf_map = cli:mod_call('query','mongo')
	assert(conf_map and conf_map[db_name],"not mongo conf")

	local conf = conf_map[db_name]
	
	local c = mongo.client(conf)
    local db = c[conf.authdb]
    return db
end

function M.instance(db_name)
	if not g_instance_map[db_name] then
		g_instance_map[db_name] = M.new_client(db_name)
	end

	return g_instance_map[db_name]
end

return M
local skynet = require "skynet"
local skynet_util = require "skynet-fly.utils.skynet_util"
require "skynet.manager"

local tinsert = table.insert
local pairs = pairs

local CMD = {}

local service_map = {}

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,	-- PTYPE_CLIENT = 3
	unpack = function() end,
	dispatch = function(_, address)
		local w = service_map[address]
		if w then
			for _,rsp in pairs(w) do
                rsp(true,true)
			end
			service_map[address] = nil
		end
	end
}

function CMD.watch(source, server_id)
    if not service_map[server_id] then
        service_map[server_id] = {}
    end
    
    service_map[server_id][source] = skynet.response()
    return skynet_util.NOT_RET
end

function CMD.unwatch(source, server_id)
    if not service_map[server_id] or not service_map[server_id][source] then
        return 
    end

    local rsp = service_map[server_id][source]
    service_map[server_id][source] = nil
    rsp(true,false)
    return skynet_util.NOT_RET
end

skynet.start(function()
    skynet.register('.monitor_exit')
    skynet_util.lua_dispatch(CMD)
end)

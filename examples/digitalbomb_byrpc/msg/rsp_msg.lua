local errorcode = require "enum.errorcode"
local RPC = require "enum.RPC"

local setmetatable = setmetatable 

local M = {}
local meta = {__index = M}

function M:new(interface_mgr)
	local t = {
		interface_mgr = interface_mgr
	}
	setmetatable(t,meta)
	return t
end

function M:rsp_msg(player_id, req_packid, msgbody, rsp_session)
    if not rsp_session then
        return
    end
	local rsp_packid = RPC[req_packid]
    if not rsp_packid then
        return
    end
    self.interface_mgr:rpc_rsp_msg(player_id, rsp_packid, msgbody, rsp_session)
end

return M
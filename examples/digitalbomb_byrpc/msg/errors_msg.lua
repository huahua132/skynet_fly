local errorcode = require "enum.errorcode"
local msg_id = require "enum.msg_id"

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

function M:errors(player_id, code, msg, packid, rsp_session)
	if not code then
		code = errorcode.UNKNOWN_ERR
		msg = "UNKNOWN err"
	end
	local error = {
		code = code,
		msg = msg,
		packid = packid,
	}
	if rsp_session then
		self.interface_mgr:rpc_error_msg(player_id, msg_id.errors_Error, error, rsp_session)
	else
		self.interface_mgr:rpc_push_msg(player_id, msg_id.errors_Error, error, rsp_session)
	end
end

return M
local errorcode = require "enum.errorcode"
local skynet = require "skynet"
local test_proto = skynet.getenv("test_proto")

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

function M:errors(player_id,code,msg,packname)
	if not code then
		code = errorcode.UNKNOWN_ERR
		msg = "UNKNOWN err"
	end
	local error = {
		code = code,
		msg = msg,
		packname = packname,
	}

	if test_proto == 'pb' then
		self.interface_mgr:send_msg(player_id,'.errors.Error',error)    --pb
	else
		self.interface_mgr:send_msg(player_id,'Error',error)			--sp
	end
end

return M
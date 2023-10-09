local errorcode = require "errorcode"

local setmetatable = setmetatable 

local M = {}
local meta = {__index = M}

function M:new(agent_mgr)
	local t = {
		agent_mgr = agent_mgr
	}
	setmetatable(t,meta)
	return t
end

function M:errors(player_id,code,msg,packname)
	if not code then
		code = errorcode.UNKOWN_ERR
		msg = "unkown err"
	end
	local error = {
		code = code,
		msg = msg,
		packname = packname,
	}

	self.agent_mgr:send_msg(player_id,'.errors.Error',error)
end

return M
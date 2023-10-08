local pbnet_util = require "pbnet_util"

local setmetatable = setmetatable

local agent_mgr = nil

local M = {}
local meta = {__index = M}

function M:new(agent_mgr)
	local t = {
		agent_mgr = agent_mgr
	}
	setmetatable(t,meta)
	return t
end

function M:login_res(player_id,login_res)
	self.agent_mgr:send_msg(player_id,'.login.LoginRes',login_res)
end

function M:login_out_res(player_id,login_out_res)
	self.agent_mgr:send_msg(player_id,'.login.LoginOutRes',login_out_res)
end

function M:match_res(player_id,match_res)
	self.agent_mgr:send_msg(player_id,'.login.matchRes',match_res)
end

return M
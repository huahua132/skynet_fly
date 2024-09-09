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

function M:login_res(player_id,login_res)
	self.interface_mgr:send_msg(player_id,'.login.LoginRes',login_res)
end

function M:login_out_res(player_id,login_out_res)
	self.interface_mgr:send_msg(player_id,'.login.LoginOutRes',login_out_res)
end

function M:match_res(player_id,match_res)
	self.interface_mgr:send_msg(player_id,'.login.matchRes',match_res)
end

function M:server_info_res(player_id,server_info_res)
	self.interface_mgr:send_msg(player_id,'.login.serverInfoRes',server_info_res)
end

return M
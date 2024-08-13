local setmetatable = setmetatable

local test_proto = 'sp'

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
	if test_proto == 'pb' then
		self.interface_mgr:send_msg(player_id,'.login.LoginRes',login_res)
	else
		self.interface_mgr:send_msg(player_id,'LoginRes',login_res)
	end
end

function M:login_out_res(player_id,login_out_res)
	if test_proto == 'pb' then
		self.interface_mgr:send_msg(player_id,'.login.LoginOutRes',login_out_res)
	else
		self.interface_mgr:send_msg(player_id,'LoginOutRes',login_out_res)
	end
end

function M:match_res(player_id,match_res)
	if test_proto == 'pb' then
		self.interface_mgr:send_msg(player_id,'.login.matchRes',match_res)
	else
		self.interface_mgr:send_msg(player_id,'matchRes',match_res)
	end
end

function M:server_info_res(player_id,server_info_res)
	if test_proto == 'pb' then
		self.interface_mgr:send_msg(player_id,'.login.serverInfoRes',server_info_res)
	else
		self.interface_mgr:send_msg(player_id,'serverInfoRes',server_info_res)
	end
end

return M
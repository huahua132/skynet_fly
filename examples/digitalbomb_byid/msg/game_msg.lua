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

function M:broad_enter_cast(enter_cast)
    self.interface_mgr:broad_cast_msg(msg_id.game_EnterCast,enter_cast)
end

function M:broad_leave_cast(leave_cast)
    self.interface_mgr:broad_cast_msg(msg_id.game_LeaveCast,leave_cast)
end

function M:game_status_res(player_id,status_res)
    self.interface_mgr:send_msg(player_id,msg_id.game_GameStatusRes,status_res)
end

function M:broad_next_doing_cast(next_doing_cast)
    self.interface_mgr:broad_cast_msg(msg_id.game_NextDoingCast,next_doing_cast)
end

function M:broad_game_start(game_start_cast)
    self.interface_mgr:broad_cast_msg(msg_id.game_GameStartCast,game_start_cast)
end

function M:broad_game_over(game_over_cast)
    self.interface_mgr:broad_cast_msg(msg_id.game_GameOverCast,game_over_cast)
end

function M:broad_doing_cast(doing_cast)
    self.interface_mgr:broad_cast_msg(msg_id.game_DoingCast,doing_cast)
end

return M
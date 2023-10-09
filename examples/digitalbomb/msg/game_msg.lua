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

function M:broad_enter_cast(enter_cast)
    self.agent_mgr:broad_cast_msg('.game.EnterCast',enter_cast)
end

function M:broad_leave_cast(leave_cast)
    self.agent_mgr:broad_cast_msg('.game.LeaveCast',leave_cast)
end

function M:game_status_res(player_id,status_res)
    self.agent_mgr:send_msg(player_id,'.game.GameStatusRes',status_res)
end

function M:broad_next_doing_cast(next_doing_cast)
    self.agent_mgr:broad_cast_msg('.game.NextDoingCast',next_doing_cast)
end

function M:broad_game_start(game_start_cast)
    self.agent_mgr:broad_cast_msg('.game.GameStartCast',game_start_cast)
end

function M:broad_game_over(game_over_cast)
    self.agent_mgr:broad_cast_msg('.game.GameOverCast',game_over_cast)
end

function M:broad_doing_cast(doing_cast)
    self.agent_mgr:broad_cast_msg('.game.DoingCast',doing_cast)
end

return M
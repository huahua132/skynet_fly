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

function M:broad_enter_cast(enter_cast)
    if test_proto == 'pb' then
        self.interface_mgr:broad_cast_msg('.game.EnterCast',enter_cast) --pb
    else
        self.interface_mgr:broad_cast_msg('EnterCast',enter_cast)       --sp
    end    
end

function M:broad_leave_cast(leave_cast)
    if test_proto == 'pb' then
        self.interface_mgr:broad_cast_msg('.game.LeaveCast',leave_cast)
    else
        self.interface_mgr:broad_cast_msg('LeaveCast',leave_cast)
    end
end

function M:game_status_res(player_id,status_res)
    if test_proto == 'pb' then
        self.interface_mgr:send_msg(player_id,'.game.GameStatusRes',status_res)
    else
        self.interface_mgr:send_msg(player_id,'GameStatusRes',status_res)
    end
end

function M:broad_next_doing_cast(next_doing_cast)
    if test_proto == 'pb' then
        self.interface_mgr:broad_cast_msg('.game.NextDoingCast',next_doing_cast)
    else
        self.interface_mgr:broad_cast_msg('NextDoingCast',next_doing_cast)
    end    
end

function M:broad_game_start(game_start_cast)
    if test_proto == 'pb' then
        self.interface_mgr:broad_cast_msg('.game.GameStartCast',game_start_cast)
    else
        self.interface_mgr:broad_cast_msg('GameStartCast',game_start_cast)
    end    
end

function M:broad_game_over(game_over_cast)
    if test_proto == 'pb' then
        self.interface_mgr:broad_cast_msg('.game.GameOverCast',game_over_cast)
    else
        self.interface_mgr:broad_cast_msg('GameOverCast',game_over_cast)
    end    
end

function M:broad_doing_cast(doing_cast)
    if test_proto == 'pb' then 
        self.interface_mgr:broad_cast_msg('.game.DoingCast',doing_cast)
    else
        self.interface_mgr:broad_cast_msg('DoingCast',doing_cast)
    end
end

return M
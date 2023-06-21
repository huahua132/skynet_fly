local skynet = require "skynet"
local SEAT_STATE = require "SEAT_STATE"
local setmetatable = setmetatable
local assert = assert

local M = {}

local meta = {__index = M}

function M:new()
	local t = {
		player = nil,
		state = SEAT_STATE.empty,
	}

	setmetatable(t,meta)
	return t
end

function M:enter(player)
	assert(player)
	self.player = player
	self.state = SEAT_STATE.waitting
end

function M:leave()
	self.player = nil
	self.state = SEAT_STATE.empty
end

function M:is_empty()
	return self.state == SEAT_STATE.empty
end

function M:is_can_leave()
	return self.state ~= SEAT_STATE.playing
end

function M:send_msg(cmd,args)
	if not self.player then
		return nil
	end

	skynet.send(self.player.gate,'lua',"server",skynet.self(),cmd,args)
end

function M:get_player()
	return self.player
end

function M:game_start()
	self.state = SEAT_STATE.playing
end

function M:game_over()
	self.state = SEAT_STATE.waitting
end

return M
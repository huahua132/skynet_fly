local seater = require "seater"
local assert = assert
local ipairs = ipairs
local table = table

local M = {}

local g_seat_list = {}
local g_player_seat_map = {}
local g_enter_num = 0

function M.init(num)
	for i = 1,num do
		g_seat_list[i] = seater:new()
	end
end

function M.enter(player)
	local player_id = player.player_id
	assert(not g_player_seat_map[player_id])
	
	for seat_id,seater in ipairs(g_seat_list) do
		if seater:is_empty() then
			seater:enter(player)
			g_player_seat_map[player_id] = seat_id
			g_enter_num = g_enter_num + 1
			break
		end
	end

	return g_player_seat_map[player_id]
end

function M.leave(player)
	local player_id = player.player_id
	assert(g_player_seat_map[player_id])

	local seat_id = g_player_seat_map[player_id]
	local seater = g_seat_list[seat_id]
	if not seater:is_can_leave() then
		return false
	else
		seater:leave()
		g_enter_num = g_enter_num - 1
		g_player_seat_map[player_id] = nil
		return true
	end
end

function M.game_start()
	local game_seat_list = {}
	for seat_id,seater in ipairs(g_seat_list) do
		if not seater:is_empty() then
			seater:game_start()
			table.insert(game_seat_list,seat_id)
		end
	end
	return game_seat_list
end

function M.game_over()
	for seat_id,seater in ipairs(g_seat_list) do
		if not seater:is_empty() then
			seater:game_over()
		end
	end
end

function M.get_player_info_by_seat_id(seat_id)
	local seater = g_seat_list[seat_id]
	assert(seater)
	return seater:get_player()
end

function M.get_player_seat_id(player_id)
	local seat_id = g_player_seat_map[player_id]
	assert(seat_id)
	return seat_id
end

function M.enter_len()
	return g_enter_num
end

function M.broad_cast_msg(cmd,args)
	for _,seater in ipairs(g_seat_list) do
		seater:send_msg(cmd,args)
	end
end

function M.send_msg_by_seat_id(seat_id,cmd,args)
	local seater = g_seat_list[seat_id]
	return seater:send_msg(cmd,args)
end

return M
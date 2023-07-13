local log = require "log"
local skynet = require "skynet"
local timer = require "timer"
local game_table = require "game_table"
local pb_util = require "pb_util"
local errors_msg = require "errors_msg"

local assert = assert
local next = next
local pairs = pairs

local g_player_num = 2

local g_table_map = {}

local ROOM_CMD = {}

function ROOM_CMD.game_over(table_id)
	assert(g_table_map[table_id])
	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map

	for player_id,player in pairs(player_map) do
		local isok,err,errmsg = skynet.call(player.hall_server_id,'lua','goout',player_id)
		if not isok then
			log.error("leave err ",player_id,err,errmsg)
		end
	end
	return true
end

local CMD = {}

function CMD.create_table(table_id)
	log.info("create_table:",table_id)
	assert(not g_table_map[table_id])
	g_table_map[table_id] = {
		player_map = {},
		game_table = game_table(table_id,g_player_num,ROOM_CMD),
	}
	return true
end

function CMD.enter(table_id,player_id,player_info,fd,hall_server_id)
	log.info("enter:",table_id,player_id,player_info,fd,hall_server_id)
	assert(g_table_map[table_id])
	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map

	assert(not player_map[player_id])

	player_map[player_id] = {
		player_info = player_info,
		fd = fd,
		hall_server_id = hall_server_id,
	}

	local player = player_map[player_id]

	local isok,errcode,errmsg = t_info.game_table.enter(player)
	if not isok then
		return isok,errcode,errmsg
	end

	return true
end

function CMD.leave(table_id,player_id)
	log.info("leave:",table_id,player_id)
	assert(g_table_map[table_id])

	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map

	assert(player_map[player_id])
	local player = player_map[player_id]
	player_map[player_id] = nil
	if not next(player_map) then
		g_table_map[table_id] = nil
	end

	local isok,errcode,errmsg = t_info.game_table.leave(player)
	if not isok then
		return isok,errcode,errmsg
	end

	log.info("g_table_map:",g_table_map)
	return true
end

function CMD.disconnect(table_id,player_id)
	log.info("disconnect:",table_id,player_id)
	assert(g_table_map[table_id])
	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map
	assert(player_map[player_id])

	local player = player_map[player_id]
	player.fd = 0
	return true
end

function CMD.reconnect(table_id,player_id,new_fd)
	log.info("reconnect:",table_id,player_id)
	assert(g_table_map[table_id])
	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map
	assert(player_map[player_id])

	local player = player_map[player_id]
	player.fd = new_fd
	return true
end

function CMD.request(table_id,player_id,packname,req)
	log.info("request:",table_id,player_id,packname,req)
	assert(g_table_map[table_id])
	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map
	assert(player_map[player_id])
	local player = player_map[player_id]

	local isok,errcode,errmsg
	if packname == '.game.DoingReq' then
		isok,errcode,errmsg = t_info.game_table.play(player,req)
	end

	if not isok then
		log.error("request err ",errcode,errmsg,packname)
		errors_msg.errors(player.fd,errcode,errmsg,packname)
	end
	return true
end

function CMD.start()
	pb_util.load('./proto')
	return true
end

function CMD.exit()
	timer:new(timer.minute,0,function()
		if not next(g_table_map) then
			log.info("g_table_map.is_empty can exit")
			skynet.exit()
		else
			log.info("not g_table_map.is_empty can`t exit")
		end
	end)
end

return CMD
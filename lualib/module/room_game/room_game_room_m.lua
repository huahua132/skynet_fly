local log = require "log"
local skynet = require "skynet"
local timer = require "timer"

local assert = assert
local next = next
local pairs = pairs

local g_table_map = {}
local g_room_conf = nil

local room_plug = nil 

local ROOM_CMD = {}

function ROOM_CMD.kick_out_all(table_id)
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
	assert(not g_table_map[table_id])
	g_table_map[table_id] = {
		player_map = {},
		game_table = room_plug.table_creator(table_id,g_room_conf,ROOM_CMD),
	}
	return true
end

function CMD.enter(table_id,player_id,gate,fd,hall_server_id)
	assert(g_table_map[table_id])
	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map

	assert(not player_map[player_id])

	player_map[player_id] = {
		player_id = player_id,
		fd = fd,
		gate = gate,
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
	assert(g_table_map[table_id])

	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map

	assert(player_map[player_id])

	local player = player_map[player_id]
	local isok,errcode,errmsg = t_info.game_table.leave(player)
	if not isok then
		return isok,errcode,errmsg
	end

	player_map[player_id] = nil
	if not next(player_map) then
		g_table_map[table_id] = nil
	end

	return true
end

function CMD.disconnect(gate,fd,table_id,player_id)
	assert(g_table_map[table_id])
	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map
	assert(player_map[player_id])

	local player = player_map[player_id]
	if player.fd ~= fd then
		log.warn("disconnect ",player.fd,fd)
		return
	end
	player.fd = 0
	player.gate = nil
	t_info.game_table.disconnect(player)
	return true
end

function CMD.reconnect(gate,fd,table_id,player_id)
	assert(g_table_map[table_id])
	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map
	assert(player_map[player_id])

	local player = player_map[player_id]
	player.fd = fd
	player.gate = gate

	t_info.game_table.reconnect(player)
	return true
end

function CMD.request(table_id,player_id,packname,req)
	assert(g_table_map[table_id])
	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map
	assert(player_map[player_id])
	local player = player_map[player_id]
	t_info.game_table.handler(player,packname,req)
	return true
end

function CMD.start(config)
	
	assert(config.room_plug, "not room_plug")
	assert(config.room_conf,"not room_conf")

	g_room_conf = config.room_conf
	
	room_plug = require (config.room_plug)
	assert(room_plug.init,"not room_plug init")                 --初始化
	assert(room_plug.table_creator,"not table_creator")         --桌子建造者

	local tmp_table = room_plug.table_creator(1,g_room_conf,ROOM_CMD)

	assert(tmp_table.enter,"table_creator not enter")           --坐下
	assert(tmp_table.leave,"table_creator not leave")           --离开
	assert(tmp_table.disconnect,"table_creator not disconnect") --掉线
	assert(tmp_table.reconnect,"table_creator not reconnect")   --重连
	assert(tmp_table.handler,"table_creator not handler")       --消息处理

	room_plug.init()
	return true
end

function CMD.exit()
	timer:new(timer.minute,0,function()
		if not next(g_table_map) then
			log.info("g_table_map.is_empty can exit")
			skynet.exit()
		else
			log.info("not g_table_map.is_empty can`t exit",g_table_map)
		end
	end)
end

return CMD
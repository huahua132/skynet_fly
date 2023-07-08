local log = require "log"
local skynet = require "skynet"
local timer = require "timer"

local assert = assert
local next = next

local g_table_map = {}

local CMD = {}

function CMD.create_table(table_id)
	log.info("create_table:",table_id)
	assert(not g_table_map[table_id])
	g_table_map[table_id] = {
		player_map = {},
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

	return true
end

function CMD.leave(table_id,player_id)
	log.info("leave:",table_id,player_id)
	assert(g_table_map[table_id])

	local t_info = g_table_map[table_id]
	local player_map = t_info[player_id]

	assert(player_map[player_id])

	player_map[player_id] = nil
	if not next(player_map) then
		g_table_map[table_id] = nil
	end

	return true
end

function CMD.disconnect(table_id,player_id)
	log.info("disconnect:",table_id,player_id)
	assert(g_table_map[table_id])
	local t_info = g_table_map[table_id]
	local player_map = t_info[player_id]
	assert(player_map[player_id])

	local player = player_map[player_id]
	player.fd = 0
	return true
end

function CMD.reconnect(table_id,player_id,new_fd)
	log.info("reconnect:",table_id,player_id)
	assert(g_table_map[table_id])
	local t_info = g_table_map[table_id]
	local player_map = t_info[player_id]
	assert(player_map[player_id])

	local player = player_map[player_id]
	player.fd = new_fd
	return true
end

function CMD.request(table_id,player_id,packname,packtab)
	log.info("request:",table_id,player_id,packname,packtab)
	return true
end

function CMD.start()
	return true
end

function CMD.exit()
	timer:new(timer.minute,0,function()
		if not next(g_table_map) then
			skynet.exit()
		end
	end)
end

return CMD
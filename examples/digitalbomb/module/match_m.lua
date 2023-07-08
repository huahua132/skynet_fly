local log = require "log"
local contriner_client = require "contriner_client"
local skynet = require "skynet"
local queue = require "skynet.queue"()
local timer = require "timer"
local errorcode = require "errorcode"

local assert = assert
local pairs = pairs
local table = table
local ipairs = ipairs
local next = next
local MAX_TABLE = 10                                     --最大桌子数
local g_alloc_table_id = skynet.self() * MAX_TABLE + 1
local INIT_TABLE_ID = g_alloc_table_id
local MAX_TABLE_ID = INIT_TABLE_ID + MAX_TABLE - 1
local MAX_PLAYER_NUM = 2

local g_table_map = {}
local g_player_map = {}

local function matching_table()
	local table_num_map = {}

	for table_id,t_info in pairs(g_table_map) do
		local player_num = #t_info.player_list
		if not table_num_map[player_num] then
			table_num_map[player_num] = {}
		end
		table.insert(table_num_map[player_num],t_info)
	end

	--log.info("matching_table",g_table_map,table_num_map)

	for i = MAX_PLAYER_NUM - 1,0,-1 do
		local t_list = table_num_map[i]
		if t_list then
			for _,t_info in ipairs(t_list) do
				return t_info
			end
		end
	end

	return nil
end

local function alloc_table_id()
	log.info("alloc_table_id",g_alloc_table_id)
	local table_id = nil
	local cur_start_id = g_alloc_table_id
	while not table_id do
		if not g_table_map[g_alloc_table_id] then
			table_id = g_alloc_table_id
		end
		g_alloc_table_id = g_alloc_table_id + 1
		if g_alloc_table_id > MAX_TABLE_ID then
			g_alloc_table_id = INIT_TABLE_ID
		end
		if g_alloc_table_id == cur_start_id then
			break
		end
	end
	return table_id
end

local function create_table()
	log.info("create_table")
	local table_id = alloc_table_id()
	if not table_id then
		log.error("alloc_table_id err ",table_id)
		return nil,errorcode.TABLE_FULL,"not table"
	end

	local room_client = contriner_client:new("room_m",nil,function() return false end)
	room_client:set_mod_num(table_id)
	local room_server_id = room_client:get_mod_server_id()
	local new_table = {
		room_client = room_client,
		room_server_id = room_server_id,
		table_id = table_id,
		player_list = {},
		max_player_num = MAX_PLAYER_NUM,
	}
	
	local ok,errocode,errormsg = skynet.call(room_server_id,'lua','create_table',table_id) 
	if ok then
		g_table_map[table_id] = new_table
		return new_table
	else
		log.error("create table err ",table_id)
		return nil,errocode,errormsg
	end
end

local CMD = {}

function CMD.match(player_id,player_info,fd,hall_server_id)
	log.info("match:",player_id,player_info,fd,hall_server_id)
	assert(not g_player_map[player_id])
	return queue(function()
		local t_info = matching_table()
		local ok,errcode,errmsg
		if not t_info then
			t_info,errcode,errmsg = create_table()
			if not t_info then
				log.fatal("create_table err ",errcode,errmsg)
				return nil,errcode,errmsg
			end
		end

		local room_server_id = t_info.room_server_id
		local table_id = t_info.table_id
		ok,errcode,errmsg = skynet.call(room_server_id,'lua','enter',table_id,player_id,player_info,fd,hall_server_id)
		if not ok then
			log.error("enter table fail ",player_id,errcode,errmsg)
			return nil,errcode,errmsg
		else
			g_player_map[player_id] = t_info
			local player_list = t_info.player_list
			table.insert(player_list,player_id)
			log.info("match succ ",room_server_id,table_id)
			return room_server_id,table_id
		end
	end)
end

function CMD.leave(player_id)
	log.info("leave:",player_id)
	local t_info = assert(g_player_map[player_id])
	return queue(function()
		local room_server_id = t_info.room_server_id
		local table_id = t_info.table_id

		if not skynet.call(room_server_id,'lua','leave',table_id,player_id) then
			log.error("leave table fail ",table_id,player_id)
			return
		else
			local player_list = t_info.player_list
			for i = #player_list,1,-1 do
				if player_list[i] == player_id then
					table.remove(player_list,i)
					break
				end
			end
			if #player_list <= 0 then
				g_table_map[table_id] = nil 
			end
			g_player_map[player_id] = nil
			log.info("leave succ ",room_server_id,table_id,g_table_map)
			return true
		end
	end)
end

function CMD.start()
	return true
end

function CMD.exit()
	timer:new(timer.minute,0,function()
		if not next(g_player_map) then
			log.info("g_player_map.is_empty can exit")
			skynet.exit()
		else
			log.info("not g_player_map.is_empty can`t exit",g_player_map)
		end
	end)
end

return CMD
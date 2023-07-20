local log = require "log"
local contriner_client = require "contriner_client"
local skynet = require "skynet"
local queue = require "skynet.queue"()
local timer = require "timer"

local assert = assert
local pairs = pairs
local table = table
local ipairs = ipairs
local next = next

local SELF_ADDRESS = nil

local g_alloc_table_id = 1              --桌子id分配
local INIT_TABLE_ID = g_alloc_table_id  --初始id
local MAX_TABLE_ID = nil				--最大id

local match_plug = nil       --匹配插件

local g_table_map = {}
local g_player_map = {}

local function alloc_table_id()
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

	return SELF_ADDRESS .. ':' .. table_id,table_id
end

local function create_table()
	local table_id,num_id = alloc_table_id()
	if not table_id then
		log.info("alloc_table_id err ",table_id)
		return match_plug.tablefull()
	end

	local room_client = contriner_client:new("room_game_room_m",nil,function() return false end)
	room_client:set_mod_num(num_id)
	local room_server_id = room_client:get_mod_server_id()
	local new_table = {
		room_client = room_client,
		room_server_id = room_server_id,
		table_id = table_id,
		player_list = {},
	}

	match_plug.createtable(table_id)
	
	local ok,errocode,errormsg = skynet.call(room_server_id,'lua','create_table',table_id) 
	if ok then
		g_table_map[table_id] = new_table
		return table_id
	else
		return nil,errocode,errormsg
	end
end

local CMD = {}

function CMD.match(gate,fd,player_id,hall_server_id)
	assert(not g_player_map[player_id])
	return queue(function()
		local table_id = match_plug.match(player_id)
		local ok,errcode,errmsg
		if not table_id then
			table_id,errcode,errmsg = create_table()
			if not table_id then
				log.info("create_table err ",errcode,errmsg)
				return nil,errcode,errmsg
			end
		end

		local t_info = g_table_map[table_id]
		local room_server_id = t_info.room_server_id
		local table_id = t_info.table_id
		ok,errcode,errmsg = skynet.call(room_server_id,'lua','enter',table_id,player_id,gate,fd,hall_server_id)
		if not ok then
			log.info("enter table fail ",player_id,errcode,errmsg)
			return nil,errcode,errmsg
		else
			g_player_map[player_id] = t_info
			local player_list = t_info.player_list
			table.insert(player_list,player_id)

			match_plug.entertable(table_id,player_id)
			return room_server_id,table_id
		end
	end)
end

function CMD.leave(player_id)
	local t_info = assert(g_player_map[player_id])
	return queue(function()
		local room_server_id = t_info.room_server_id
		local table_id = t_info.table_id
		local ok,errcode,errmsg = skynet.call(room_server_id,'lua','leave',table_id,player_id)
		if not ok then
			log.info("leave table fail ",table_id,player_id,errcode,errmsg)
			return nil,errcode,errmsg
		else
			local player_list = t_info.player_list
			for i = #player_list,1,-1 do
				if player_list[i] == player_id then
					table.remove(player_list,i)
					break
				end
			end
			match_plug.leavetable(table_id,player_id)
			if #player_list <= 0 then
				g_table_map[table_id] = nil
				match_plug.dismisstable(table_id)
			end
			g_player_map[player_id] = nil
			return true
		end
	end)
end

function CMD.start(config)
	SELF_ADDRESS = skynet.self()
	assert(config.match_plug,"not match_plug")
	assert(config.MAX_TABLES,"not MAX_TABLES")  --最大桌子数量

	MAX_TABLE_ID = INIT_TABLE_ID + config.MAX_TABLES - 1

	match_plug = require (config.match_plug)
	assert(match_plug.init,"not match init")           --初始化
	assert(match_plug.match,"not match")		       --匹配
	assert(match_plug.tablefull,"not tablefull")       --桌子已满
	assert(match_plug.createtable,"not createtable")   --创建桌子
	assert(match_plug.entertable,"not entertable")     --进入桌子
	assert(match_plug.leavetable,"not leavetable")     --离开桌子
	assert(match_plug.dismisstable,"not dismisstable") --解散桌子

	match_plug.init()
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
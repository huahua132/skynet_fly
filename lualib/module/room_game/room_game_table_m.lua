local log = require "log"
local skynet = require "skynet"
local timer = require "timer"

local assert = assert
local next = next
local pairs = pairs
local setmetatable = setmetatable

local g_table_map = {}
local g_config = nil
local table_plug = nil
-------------------------------------------------------------------------------
--private
-------------------------------------------------------------------------------
--踢出所有玩家
local function kick_out_all(table_id)
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

--发送消息
local function send_msg(table_id,player_id,packname,pack_body)
    assert(g_table_map[table_id])
    local t_info = g_table_map[table_id]
	local player_map = t_info.player_map
    local player = player_map[player_id]
	if not player then
		log.info("send msg not player ",player_id,packname)
		return
	end
    table_plug.send(player.gate,player.fd,packname,pack_body)
end

--发送消息给部分玩家
local function send_msg_by_player_list(table_id,player_list,packname,pack_body)
	for i = 1,#player_list do
		send_msg(table_id,player_list[i],packname,pack_body)
	end
end

--广播发送消息
local function broad_cast_msg(table_id,packname,pack_body)
    assert(g_table_map[table_id])
	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map
	for player_id,_ in pairs(player_map) do
		send_msg(table_id,player_id,packname,pack_body)
	end
end
-------------------------------------------------------------------------------
--interface
-------------------------------------------------------------------------------
local interface = {}
local meta = {__index = interface}

function interface:new(table_id)
    local t = {
        table_id = table_id
    }
    setmetatable(t,meta)
    return t
end
--踢出该桌子所有玩家
function interface:kick_out_all()
    return kick_out_all(self.table_id)
end
--给玩家发消息
function interface:send_msg(player_id,packname,pack_body)
    return send_msg(self.table_id,player_id,packname,pack_body)
end
--给玩家列表发消息
function interface:send_msg_by_player_list(player_list,packname,pack_body)
    return send_msg_by_player_list(self.table_id,player_list,packname,pack_body)
end
--桌子广播
function interface:broad_cast_msg(packname,pack_body)
    return broad_cast_msg(self.table_id,packname,pack_body)
end
-------------------------------------------------------------------------------
--CMD
-------------------------------------------------------------------------------
local CMD = {}
--创建房间
function CMD.create_table(table_id)
	assert(not g_table_map[table_id])
	g_table_map[table_id] = {
		player_map = {},
		game_table = table_plug.table_creator(table_id,g_config.instance_name),
	}
	return true
end

--进入房间
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

	local isok,errcode,errmsg = t_info.game_table.enter(player_id)
	if not isok then
		return isok,errcode,errmsg
	end

	return true
end

--离开房间
function CMD.leave(table_id,player_id)
	assert(g_table_map[table_id])

	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map

	assert(player_map[player_id])

	local player = player_map[player_id]
	local isok,errcode,errmsg = t_info.game_table.leave(player_id)
	if not isok then
		return isok,errcode,errmsg
	end

	player_map[player_id] = nil
	if not next(player_map) then
		g_table_map[table_id] = nil
	end

	return true
end

--掉线
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
	t_info.game_table.disconnect(player_id)
	return true
end

--重新连接
function CMD.reconnect(gate,fd,table_id,player_id)
	assert(g_table_map[table_id])
	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map
	assert(player_map[player_id])

	local player = player_map[player_id]
	player.fd = fd
	player.gate = gate

	t_info.game_table.reconnect(player_id)
	return true
end

--协议消息请求，由hall大厅服转发过来
function CMD.request(table_id,player_id,packname,pack_body)
	assert(g_table_map[table_id])
	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map
	assert(player_map[player_id])
	local player = player_map[player_id]

    local func = t_info.game_table.handle[packname]
    if not func then
        log.info("dorp package ",packname,pack_body)
    else
        func(player_id,packname,pack_body)
    end
	return true
end

function CMD.start(config)
	g_config = config
	assert(config.table_plug, "not table_plug")
	assert(config.table_conf,"not table_conf")	
	table_plug = require (config.table_plug)
	assert(table_plug.init,"not table_plug init")                 --初始化
	assert(table_plug.table_creator,"not table_creator")          --桌子建造者
    assert(table_plug.send,"not send")                           --消息发送函数

    table_plug.init(interface)
	local tmp_table = table_plug.table_creator(1,config.instance_name)

	assert(tmp_table.enter,"table_creator not enter")           --坐下
	assert(tmp_table.leave,"table_creator not leave")           --离开
	assert(tmp_table.disconnect,"table_creator not disconnect") --掉线
	assert(tmp_table.reconnect,"table_creator not reconnect")   --重连
    assert(tmp_table.handle,"table_creator not handle")         --消息处理

	
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
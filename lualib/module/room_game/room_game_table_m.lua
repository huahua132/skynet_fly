local log = require "log"
local skynet = require "skynet"
local timer = require "timer"

local assert = assert
local next = next
local pairs = pairs
local setmetatable = setmetatable
local tostring = tostring
local tinsert = table.insert

local g_table_map = {}
local g_config = nil
local table_plug = nil
-------------------------------------------------------------------------------
--private
-------------------------------------------------------------------------------
local function get_table_info(table_id)
	if not g_table_map[table_id] then
		log.warn("get_table_info not exists table_id = ",table_id)
		return
	end
	return g_table_map[table_id]
end

local function get_player_info(table_id,player_id)
	if not g_table_map[table_id] then
		log.warn("get_player_info not exists table_id = ",table_id)
		return
	end
	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map

	if not player_map[player_id] then
		log.warn("get_player_info not exists player_id = ",player_id)
		return
	end

	return player_map[player_id]
end

--踢出所有玩家
local function kick_out_all(table_id)
	if not g_table_map[table_id] then
		log.warn("kick_out_all not exists table_id = ",table_id)
		return
	end
	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map

	for player_id,player in pairs(player_map) do
		local isok,err,errmsg = skynet.call(player.hall_server_id,'lua','leave_table',player_id)
		if not isok then
			log.warn("kick_player err ",player_id,err,errmsg)
		end
	end
	return true
end

--踢出单个玩家
local function kick_player(table_id,player_id)
	local player = get_player_info(table_id,player_id)
	if not player then
		log.warn("kick_player not exists ",table_id,player_id)
		return false
	end

	local isok,err,errmsg = skynet.call(player.hall_server_id,'lua','leave_table',player_id)
	if not isok then
		log.warn("kick_player err ",player_id,err,errmsg)
		return false
	end
	return true
end

local function is_online(table_id,player_id)
	local player = get_player_info(table_id,player_id)
	if not player then
		log.warn("is_online not exists ",table_id,player_id)
		return
	end

	return player.fd ~= 0
end

--发送消息
local function send_msg(table_id,player_id,packname,pack_body)
	if not is_online(table_id,player_id) then
		log.info("send msg not online ",table_id,player_id)
		return
	end
	local player = get_player_info(table_id,player_id)
    table_plug.send(player.gate,player.fd,packname,pack_body)
end

--发送消息给部分玩家
local function send_msg_by_player_list(table_id,player_list,packname,pack_body)
	local t_info = get_table_info(table_id)
	if not t_info then
		log.warn("send_msg_by_player_list not exists table_id = ",table_id)
		return
	end
	
	local player_map = t_info.player_map

	local gate_list = {}
	local fd_list = {}
	for i = 1,#player_list do
		local player_id = player_list[i]
		local player = player_map[player_id]
		if not player then
			log.info("send_msg_by_player_list not exists ",player_id)
		else
			if player.fd > 0 then
				tinsert(gate_list,player.gate)
				tinsert(fd_list,player.fd)
			else
				log.info("send_msg_by_player_list not online ",player_id)
			end
		end
	end

	if #gate_list <= 0 then return end
	
	table_plug.broadcast(gate_list,fd_list,packname,pack_body)
end

--广播发送消息
local function broad_cast_msg(table_id,packname,pack_body,filter_map)
	if not g_table_map[table_id] then
		log.warn("broad_cast_msg not exists table_id = ",table_id)
		return
	end
	filter_map = filter_map or {}

	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map

	local gate_list = {}
	local fd_list = {}
	for player_id,player in pairs(player_map) do
		if not filter_map[player_id] then
			if player.fd > 0 then
				tinsert(gate_list,player.gate)
				tinsert(fd_list,player.fd)
			else
				log.info("send_msg_by_player_list not online ",player_id)
			end
		end
	end

	if #gate_list <= 0 then return end
	
	table_plug.broadcast(gate_list,fd_list,packname,pack_body)
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
--踢出单个玩家
function interface:kick_player(player_id)
	return kick_player(self.table_id,player_id)
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
--用send的方式给大厅发消息
function interface:send_hall(player_id,cmd,...)
	local table_id = self.table_id
	local player = get_player_info(table_id,player_id)
	if not player then
		log.warn("send_hall not exists player ",table_id,player_id)
		return
	end
	skynet.send(player.hall_server_id,'lua',cmd,player_id,...)
end
--用call的方式给大厅服发消息
function interface:call_hall(player_id,cmd,...)
	local table_id = self.table_id
	local player = get_player_info(table_id,player_id)
	if not player then
		log.warn("call_hall not exists player ",table_id,player_id)
		return
	end

	return skynet.call(player.hall_server_id,'lua',cmd,player_id,...)
end
--用send的方式给分配服发消息
function interface:send_alloc(cmd,...)
	local table_id = self.table_id
	local t_info = get_table_info(table_id)
	if not t_info then
		log.warn("send_alloc not exists t_info ",table_id)
		return
	end
	skynet.send(t_info.alloc_server_id,'lua',cmd,table_id,...)
end
--用call的方式给分配服发消息
function interface:call_alloc(cmd,...)
	local table_id = self.table_id
	local t_info = get_table_info(table_id)
	if not t_info then
		log.warn("call_alloc not exists player ",table_id)
		return
	end

	return skynet.call(t_info.alloc_server_id,'lua',cmd,table_id,...)
end
-------------------------------------------------------------------------------
--CMD
-------------------------------------------------------------------------------
local CMD = {}
--创建房间
function CMD.create_table(table_id,alloc_server_id)
	assert(not g_table_map[table_id])
	g_table_map[table_id] = {
		alloc_server_id = alloc_server_id,
		player_map = {},
		game_table = table_plug.table_creator(table_id,g_config.instance_name),
	}
	return true,g_config
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
		hall_server_id = hall_server_id,     --大厅服id
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
    assert(table_plug.send,"not send")                            --消息发送函数
	assert(table_plug.broadcast,"not broadcast")   				  --广播发包函数

    table_plug.init(interface)
	local tmp_table = table_plug.table_creator(1,config.instance_name)

	assert(tmp_table.enter,"table_creator not enter")           --坐下
	assert(tmp_table.leave,"table_creator not leave")           --离开
	assert(tmp_table.disconnect,"table_creator not disconnect") --掉线
	assert(tmp_table.reconnect,"table_creator not reconnect")   --重连
    assert(tmp_table.handle,"table_creator not handle")         --消息处理

	if table_plug.register_cmd then
		for name,func in pairs(table_plug.register_cmd) do
			assert(not CMD[name],"repeat cmd " .. name)
			CMD[name] = func
		end
	end
	
	return true
end

function CMD.check_exit()
	local is_check_ok = true
	for _,t_info in pairs(g_table_map) do
		if t_info.game_table.check_exit then
			is_check_ok = t_info.game_table.check_exit()
			if not is_check_ok then return false end
		end
	end
	
	if not next(g_table_map) then
		log.info("g_table_map.is_empty can exit")
		return true
	else
		log.info("not g_table_map.is_empty can`t exit",g_table_map)
		return false
	end
end

--预告退出
function CMD.herald_exit()
	for _,t_info in pairs(g_table_map) do
		if t_info.game_table.herald_exit then
			t_info.game_table.herald_exit()
		end
	end
end

--取消退出
function CMD.cancel_exit()
	for _,t_info in pairs(g_table_map) do
		if t_info.game_table.cancel_exit then
			t_info.game_table.cancel_exit()
		end
	end
end


--确认退出
function CMD.fix_exit()
	for _,t_info in pairs(g_table_map) do
		if t_info.game_table.fix_exit then
			t_info.game_table.fix_exit()
		end
	end
end

--退出
function CMD.exit()
	local is_exit = true
	for _,t_info in pairs(g_table_map) do
		if t_info.game_table.exit then
			is_exit = t_info.game_table.exit()
			if not is_exit then return false end
		end
	end
	return true
end

return CMD
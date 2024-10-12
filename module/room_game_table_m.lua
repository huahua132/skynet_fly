local log = require "skynet-fly.log"
local skynet = require "skynet"
local timer = require "skynet-fly.timer"
local contriner_client = require "skynet-fly.client.contriner_client"
local skynet_util = require "skynet-fly.utils.skynet_util"
local table_util = require "skynet-fly.utils.table_util"
contriner_client:register("share_config_m")

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
local function kick_out_all(table_id, reason)
	if not g_table_map[table_id] then
		log.warn("kick_out_all not exists table_id = ",table_id)
		return
	end
	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map

	for player_id,player in pairs(player_map) do
		local isok,err,errmsg = skynet.call(player.hall_server_id,'lua','leave_table',player_id, reason)
		if not isok then
			log.warn("kick_player err ",player_id,err,errmsg)
		end
	end
	return true
end

--踢出单个玩家
local function kick_player(table_id, player_id, reason)
	local player = get_player_info(table_id,player_id)
	if not player then
		log.warn("kick_player not exists ",table_id,player_id)
		return false
	end

	local isok,err,errmsg = skynet.call(player.hall_server_id,'lua','leave_table', player_id, reason)
	if not isok then
		log.warn("kick_player err ",player_id,err,errmsg)
		return false
	end
	return true
end

local function is_online(table_id,player_id)
	local player = get_player_info(table_id,player_id)
	if not player then
		return false
	end

	return player.fd ~= 0
end

--发送消息
local function send_msg(table_id, player_id, header, body)
	if not is_online(table_id,player_id) then
		log.info("send msg not online ",table_id, player_id, header)
		return
	end
	local player = get_player_info(table_id, player_id)
	if player.is_ws then
		table_plug.ws_send(player.gate, player.fd, header, body)
	else
		table_plug.send(player.gate, player.fd, header, body)
	end
end

--发送消息给部分玩家
local function send_msg_by_player_list(table_id, player_list, header, body)
	local t_info = get_table_info(table_id)
	if not t_info then
		log.warn("send_msg_by_player_list not exists table_id = ",table_id, header)
		return
	end
	
	local player_map = t_info.player_map

	local gate_list = {}
	local fd_list = {}

	local ws_gate_list = {}
	local ws_fd_list = {}
	for i = 1,#player_list do
		local player_id = player_list[i]
		local player = player_map[player_id]
		if not player then
			log.info("send_msg_by_player_list not exists ",player_id)
		else
			if player.fd > 0 then
				if player.is_ws then
					tinsert(ws_gate_list, player.gate)
					tinsert(ws_fd_list, player.fd)
				else
					tinsert(gate_list, player.gate)
					tinsert(fd_list, player.fd)
				end
			else
				log.info("send_msg_by_player_list not online ",player_id)
			end
		end
	end

	if #gate_list > 0 then
		table_plug.broadcast(gate_list, fd_list, header, body)
	end
	
	if #ws_gate_list > 0 then
		table_plug.ws_broadcast(ws_gate_list, ws_fd_list, header, body)
	end
end

--广播发送消息
local function broad_cast_msg(table_id, header, body, filter_map)
	if not g_table_map[table_id] then
		log.warn("broad_cast_msg not exists table_id = ",table_id)
		return
	end
	filter_map = filter_map or {}

	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map

	local gate_list = {}
	local fd_list = {}

	local ws_gate_list = {}
	local ws_fd_list = {}

	for player_id,player in pairs(player_map) do
		if not filter_map[player_id] then
			if player.fd > 0 then
				if player.is_ws then
					tinsert(ws_gate_list, player.gate)
					tinsert(ws_fd_list, player.fd)
				else
					tinsert(gate_list, player.gate)
					tinsert(fd_list, player.fd)
				end
			else
				log.info("send_msg_by_player_list not online ",player_id)
			end
		end
	end

	if #gate_list > 0 then
		table_plug.broadcast(gate_list, fd_list, header, body)
	end

	if #ws_gate_list > 0 then
		table_plug.ws_broadcast(ws_gate_list, ws_fd_list, header, body)
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
function interface:kick_out_all(reason)
    return kick_out_all(self.table_id, reason)
end
--踢出单个玩家
function interface:kick_player(player_id, reason)
	return kick_player(self.table_id, player_id, reason)
end
--给玩家发消息
function interface:send_msg(player_id,header,body)
    return send_msg(self.table_id,player_id,header,body)
end
--给玩家列表发消息
function interface:send_msg_by_player_list(player_list,header,body)
    return send_msg_by_player_list(self.table_id,player_list,header,body)
end
--桌子广播
function interface:broad_cast_msg(header,body)
    return broad_cast_msg(self.table_id,header,body)
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

--获取客户端连接IP:PORT
function interface:get_addr(player_id)
	local table_id = self.table_id
	local player = get_player_info(table_id, player_id)
	if not player then
		return ""
	end

	return player.addr
end
-------------------------------------------------------------------------------
--CMD
-------------------------------------------------------------------------------
local CMD = {}
--创建房间
function CMD.create_table(table_id, alloc_server_id, ...)
	assert(not g_table_map[table_id])
	g_table_map[table_id] = {
		alloc_server_id = alloc_server_id,
		player_map = {},
		game_table = table_plug.table_creator(table_id, g_config.instance_name, ...),
	}
	return true,g_config
end

--进入房间
function CMD.enter(table_id, player_id, gate, fd, is_ws, addr, hall_server_id)
	assert(g_table_map[table_id])
	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map

	assert(not player_map[player_id])

	player_map[player_id] = {
		player_id = player_id,
		fd = fd,
		gate = gate,
		hall_server_id = hall_server_id,     --大厅服id
		is_ws = is_ws,
		addr = addr,
	}

	local isok,errcode,errmsg = t_info.game_table.enter(player_id)
	if not isok then
		return isok,errcode,errmsg
	end

	return true
end

--离开房间
function CMD.leave(table_id, player_id, reason)
	assert(g_table_map[table_id])

	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map

	assert(player_map[player_id])

	local isok,errcode,errmsg = t_info.game_table.leave(player_id, reason)
	if not isok then
		return isok,errcode,errmsg
	end

	player_map[player_id] = nil

	return true
end

--销毁房间
function CMD.dismisstable(table_id)
	assert(g_table_map[table_id])
	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map
	if next(player_map) then  --还有玩家
		return false
	end

	g_table_map[table_id] = nil
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
function CMD.reconnect(gate, fd, is_ws, addr, table_id, player_id)
	assert(g_table_map[table_id])
	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map
	assert(player_map[player_id])

	local player = player_map[player_id]
	player.fd = fd
	player.gate = gate
	player.is_ws = is_ws
	player.addr = addr

	t_info.game_table.reconnect(player_id)
	return true
end

--协议消息请求，由hall大厅服转发过来
function CMD.request(table_id,player_id,header,body)
	assert(g_table_map[table_id])
	local t_info = g_table_map[table_id]
	local player_map = t_info.player_map
	assert(player_map[player_id])

    local func = t_info.game_table.handle[header]
    if not func then
        log.info("dorp package ",header,body)
    else
		if t_info.game_table.handle_before then
			if not t_info.game_table.handle_before(player_id, header, body) then
				return
			end
		end

		if t_info.game_table.handle_end then
			t_info.game_table.handle_end(player_id,header,body,func(player_id,header,body))
		else
			func(player_id,header,body)
		end
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

	skynet.fork(function()
		local confclient = contriner_client:new("share_config_m")
		local room_game_login = confclient:mod_call('query','room_game_login')

		if room_game_login.gateconf then
			assert(table_plug.send,"table_plug not send")                  --发包函数
			assert(table_plug.broadcast,"table_plug not broadcast")   	  --广播发包函数
		end
	
		if room_game_login.wsgateconf then
			assert(table_plug.ws_send,"table_plug not ws_send")            --ws发包函数
			assert(table_plug.ws_broadcast,"table_plug not ws_broadcast")  --ws广播发包函数
		end
	end)

    table_plug.init(interface)
	local tmp_table = table_plug.table_creator(1,config.instance_name)

	assert(tmp_table.enter,"table_creator not enter")           --坐下
	assert(tmp_table.leave,"table_creator not leave")           --离开
	assert(tmp_table.disconnect,"table_creator not disconnect") --掉线
	assert(tmp_table.reconnect,"table_creator not reconnect")   --重连
    assert(tmp_table.handle,"table_creator not handle")         --消息处理

	if table_plug.register_cmd then
		for name,func in pairs(table_plug.register_cmd) do
			skynet_util.extend_cmd_func(name, func)
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
		log.info("not g_table_map.is_empty can`t exit table_count = ", table_util.count(g_table_map))
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
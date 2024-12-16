--大厅

local skynet = require "skynet"
local log = require "skynet-fly.log"
local timer = require "skynet-fly.timer"
local queue = require "skynet.queue"
local contriner_client = require "skynet-fly.client.contriner_client"
local string_util = require "skynet-fly.utils.string_util"
local time_util = require "skynet-fly.utils.time_util"
local skynet_util = require "skynet-fly.utils.skynet_util"
local table_util = require "skynet-fly.utils.table_util"

contriner_client:register("room_game_alloc_m", "share_config_m")

local assert = assert
local pcall = pcall
local next = next
local xx_pcall = xx_pcall
local tonumber = tonumber
local pairs = pairs
local tinsert = table.insert

local SELF_ADDRESS = nil
local g_player_map = {}
local g_fd_map = {}
local g_handle_map = {}

local hall_plug = nil

local EMPTY = {}
----------------------------------------------------------------------------------
--private
----------------------------------------------------------------------------------
local function new_join_table(agent, table_name, join_cmd, ...)
	local alloc_client = contriner_client:new("room_game_alloc_m",table_name,function() return false end)
	local gate = agent.gate
	local fd = agent.fd
	local player_id = agent.player_id
	local hall_server_id = agent.hall_server_id

	local table_server_id,table_id,errmsg = alloc_client:mod_call(join_cmd, player_id, gate, fd, agent.is_ws, agent.addr, hall_server_id, table_name, ...)
	if not table_server_id then
		return false,table_id,errmsg
	end
	agent.alloc_client = alloc_client
	agent.table_server_id = table_server_id
	agent.table_id = table_id
	agent.table_name = table_name

	--进入成功的回调
	if hall_plug.join_table then
		hall_plug.join_table(player_id, table_name, table_id)
	end

	return table_id
end

--创建房间
local function create_join_table(agent, table_name, ...)
	return new_join_table(agent, table_name, "create_join", ...)
end

--匹配进入
local function match_join_table(agent, table_name, ...)
	return new_join_table(agent, table_name, "match_join", ...)
end

--join_table必须用id，因为table_id已经绑定了alloc服务
local function join_table(agent, player_id, table_name, table_id)
	local s_str = string_util.split(table_id,':')
	local alloc_server_id = tonumber(s_str[1])
	if not alloc_server_id then
		log.warn("join_table not alloc_server_id ",table_id)
		return
	end
	local gate = agent.gate
	local fd = agent.fd
	local hall_server_id = agent.hall_server_id
	local table_server_id,table_id,errmsg = xx_pcall(skynet.call, alloc_server_id, 'lua', "join", player_id, gate, fd, agent.is_ws, agent.addr, hall_server_id, table_name, table_id)
	if not table_server_id then
		return false,table_id,errmsg
	end
	agent.alloc_server_id = alloc_server_id
	agent.table_server_id = table_server_id
	agent.table_id = table_id
	agent.table_name = table_name

	--进入成功的回调
	if hall_plug.join_table then
		hall_plug.join_table(player_id, table_name, table_id)
	end

	return table_id
end
--离开桌子
local function leave(agent, reason)
	local isok,errcode,errmsg
	isok = true
	local alloc_client = agent.alloc_client           --走匹配的
	local alloc_server_id = agent.alloc_server_id     --直接进入房间的
	if alloc_client then
		isok,errcode,errmsg = alloc_client:mod_call('leave', agent.player_id, reason)
	elseif alloc_server_id then
		isok,errcode,errmsg = xx_pcall(skynet.call, alloc_server_id, 'lua', 'leave', agent.player_id, reason)
	end

	if not isok then
		log.error("can`t leave !!! ", agent.player_id, errcode, errmsg)
		return nil,errcode,errmsg
	end

	local table_name, table_id = agent.table_name, agent.table_id
	agent.alloc_client = nil
	agent.alloc_server_id = nil
	agent.table_server_id = nil
	agent.table_id = nil
	agent.table_name = nil
	
	if table_name and table_id and hall_plug.leave_table then
		hall_plug.leave_table(agent.player_id, table_name, table_id, reason)
	end

	return true
end

local function handle_msg(agent, header, body, rsp_session)
	local func = g_handle_map[header]
	if not func then
		local table_server_id = agent.table_server_id
		local table_id = agent.table_id
		if not table_server_id then
			log.info("dorp package ", header, body, rsp_session)
		else
			skynet.send(table_server_id, 'lua', 'request', table_id, agent.player_id, header, body, rsp_session)
		end
	else
		
		if hall_plug.handle_before then
			if not hall_plug.handle_before(agent.player_id, header, body, rsp_session) then
				return
			end
		end
		if hall_plug.handle_end_rpc then --增加目的是考虑到 handle_end的兼容性
			local handle_res = {func(agent.player_id, header, body, rsp_session)}
			hall_plug.handle_end_rpc(agent.player_id, header, body, rsp_session, handle_res)
		elseif hall_plug.handle_end then
			hall_plug.handle_end(agent.player_id, header, body, func(agent.player_id, header, body, rsp_session))
		else
			func(agent.player_id, header, body, rsp_session)
		end
	end
end
--消息分发
local function dispatch(fd, source, msg, sz)
	skynet.ignoreret()
	local agent = g_fd_map[fd]
	if not agent then
		log.error("dispatch msg not agent ", fd)
		return
	end

	local unpack = nil
	if agent.is_ws then
		unpack = hall_plug.ws_unpack
	else
		unpack = hall_plug.unpack
	end
	local header, body = unpack(msg, sz)
	if not header then
		log.error("unpack err ",header, body)
		return
	end

	local rsp_session = nil
	if hall_plug.rpc_pack then
		local pre_header = header
		header, body, rsp_session = hall_plug.rpc_pack.handle_msg(header, body)
		if not header then
			log.error("rpc_pack handle_msg err ", pre_header, body)
		end
	end
	
	agent.queue(handle_msg, agent, header, body, rsp_session)
end
--连接大厅
local function connect(agent, is_reconnect, is_jump_join)
	local gate = agent.gate
	local fd = agent.fd
	local player_id = agent.player_id
	local login_res = nil
	if not is_reconnect then
		login_res = hall_plug.connect(player_id, is_jump_join)
	else
		login_res = hall_plug.reconnect(player_id)
		local table_server_id = agent.table_server_id
		local table_id = agent.table_id
		if table_server_id then
			skynet.send(table_server_id, 'lua', 'reconnect', gate, fd, agent.is_ws, agent.addr, table_id, player_id)
		end
	end

	return login_res
end

--登出
local function goout(agent, reason, is_jump_exit)
	local player_id = agent.player_id
	local isok,errcode,errmsg = leave(agent, reason)
	if not isok then
		log.error("can`t leave !!! ",player_id, errcode, errmsg)
		return nil,errcode,errmsg
	end
	hall_plug.goout(player_id, is_jump_exit)

	if not is_jump_exit then
		skynet.send(agent.watchdog, 'lua', 'goout', player_id)
	end

	g_fd_map[agent.fd] = nil
	g_player_map[player_id] = nil
	return true
end

local CMD = {}
----------------------------------------------------------------------------------
--interface
----------------------------------------------------------------------------------
local function send_msg(agent, header, body)
	if agent.is_ws then
		hall_plug.ws_send(agent.gate, agent.fd, header, body)
	else
		hall_plug.send(agent.gate, agent.fd, header, body)
	end
end

local interface = {}
--创建进入房间
function interface:create_join_table(player_id, table_name, ...)
	local agent = g_player_map[player_id]
	if not agent then
		log.warn("create_join_table agent not exists ", player_id)
		return
	end

	if agent.table_lock then
		log.warn("create_join_table is lock ", player_id, table_name)
		return
	end

	--已经存在房间了
	if agent.table_server_id then
		log.warn("create_join_table table_server_id is exists", player_id)
		return
	end
	agent.table_lock = true
	local ret,errcode,errmsg = agent.queue(create_join_table, agent, table_name, ...)
	agent.table_lock = nil
	return ret,errcode,errmsg
end


--匹配进入
function interface:match_join_table(player_id, table_name, ...)
	local agent = g_player_map[player_id]
	if not agent then
		log.warn("match_join_table agent not exists ", player_id)
		return
	end

	if agent.table_lock then
		log.warn("match_join_table is lock ", player_id, table_name)
		return
	end

	--已经存在房间了
	if agent.table_server_id then
		log.warn("match_join_table table_server_id is exists", player_id)
		return
	end
	agent.table_lock = true
	local ret,errcode,errmsg = agent.queue(match_join_table, agent, table_name, ...)
	agent.table_lock = nil
	return ret,errcode,errmsg
end

--进入房间
function interface:join_table(player_id, table_name, table_id)
	local agent = g_player_map[player_id]
	if not agent then
		log.warn("join agent not exists ", player_id)
		return
	end

	if agent.table_lock then
		log.warn("join is lock ", player_id, table_name)
		return
	end

	--已经存在房间了
	if agent.table_server_id then
		log.warn("join table_server_id is exists", player_id)
		return
	end
	agent.table_lock = true
	local ret,errcode,errmsg = agent.queue(join_table, agent, player_id, table_name, table_id)
	agent.table_lock = nil
	return ret,errcode,errmsg
end
--离开房间
function interface:leave_table(player_id, reason)
	local agent = g_player_map[player_id]
	if not agent then
		log.warn("leave agent not exists ",player_id)
		return
	end

	if agent.table_lock then
		log.warn("match_join is lock ",player_id)
		return
	end

	if not agent.table_server_id then
		log.warn("leave not exists room ",player_id)
	end

	agent.table_lock = true
	local ret,errcode,errmsg = agent.queue(leave, agent, reason)
	agent.table_lock = nil
	return ret,errcode,errmsg
end
--登出
function interface:goout(player_id, reason)
	return CMD.goout(player_id, reason)
end
--设置消息处理函数
function interface:handle(header,func)
	assert(not g_handle_map[header], "exists handle : " .. header)
	g_handle_map[header] = func
end
--是否在线
function interface:is_online(player_id)
	local agent = g_player_map[player_id]
	if not agent then
		return false
	end

	return agent.fd ~= 0
end
--发送消息
function interface:send_msg(player_id, header, body)
	if not interface:is_online(player_id) then
		log.info("send msg not online ", player_id, header)
		return
	end
	local agent = g_player_map[player_id]
	send_msg(agent, header, body)
end

--发送消息给部分玩家
function interface:send_msg_by_player_list(player_list, header, body)
	local gate_list = {}
	local fd_list = {}

	local ws_gate_list = {}
	local ws_fd_list = {}

	for i = 1, #player_list do
		local player_id = player_list[i]
		local agent = g_player_map[player_id]
		if not agent then
			log.info("send_msg_by_player_list not exists ",player_id)
		else
			if agent.fd > 0 then
				if agent.is_ws then
					tinsert(ws_gate_list, agent.gate)
					tinsert(ws_fd_list, agent.fd)
				else
					tinsert(gate_list, agent.gate)
					tinsert(fd_list, agent.fd)
				end
			else
				log.info("send_msg_by_player_list not online ",player_id)
			end
		end
	end

	if #gate_list > 0 then
		hall_plug.broadcast(gate_list, fd_list, header, body)
	end

	if #ws_gate_list > 0 then
		hall_plug.ws_broadcast(ws_gate_list, ws_fd_list, header, body)
	end
end

--广播发送消息
function interface:broad_cast_msg(header, body, filter_map)
	filter_map = filter_map or EMPTY

	local gate_list = {}
	local fd_list = {}

	local ws_gate_list = {}
	local ws_fd_list = {}

	for player_id,agent in pairs(g_player_map) do
		if not filter_map[player_id] then
			if agent.fd > 0 then
				if agent.is_ws then
					tinsert(ws_gate_list, agent.gate)
					tinsert(ws_fd_list, agent.fd)
				else
					tinsert(gate_list, agent.gate)
					tinsert(fd_list, agent.fd)
				end
			else
				log.info("broad_cast_msg not online ",player_id)
			end
		end
	end

	if #gate_list > 0 then
		hall_plug.broadcast(gate_list, fd_list, header, body)
	end

	if #ws_gate_list > 0 then
		hall_plug.ws_broadcast(ws_gate_list, ws_fd_list, header, body)
	end
end

--获取大厅id
function interface:get_hall_server_id()
	return SELF_ADDRESS
end

--获取分配服id
function interface:get_alloc_server_id(player_id)
	local agent = g_player_map[player_id]
	if not agent then
		return 0
	end
	local alloc_client = agent.alloc_client           --走匹配的
	local alloc_server_id = agent.alloc_server_id     --直接进入房间的
	if alloc_client then
		return alloc_client:get_mod_server_id()
	end

	if alloc_server_id then
		return alloc_server_id
	end

	return 0
end

--获取桌子服id
function interface:get_table_server_id(player_id)
	local agent = g_player_map[player_id]
	if not agent then
		return 0
	end

	return agent.table_server_id or 0
end

--获取桌子id
function interface:get_table_id(player_id)
	local agent = g_player_map[player_id]
	if not agent then
		return "0:0"
	end

	return agent.table_id or "0:0"
end

--执行队列
function interface:queue(player_id, func, ...)
	local agent = g_player_map[player_id]
	if not agent then
		log.warn("queue agent not exists ", player_id)
		return nil
	end
	return agent.queue(func, ...)
end

--获取客户端连接IP:PORT
function interface:get_addr(player_id)
	local agent = g_player_map[player_id]
	if not agent then
		return ""
	end

	return agent.addr
end

--rpc回复消息
function interface:rpc_rsp_msg(player_id, header, msgbody, rsp_session)
	if not interface:is_online(player_id) then
		log.info("rpc_msg not online ", player_id, header)
		return
	end
	local agent = g_player_map[player_id]

	local body = hall_plug.rpc_pack.pack_rsp(msgbody, rsp_session)
	send_msg(agent, header, body)
end

--rpc回复error消息
function interface:rpc_error_msg(player_id, header, msgbody, rsp_session)
	if not interface:is_online(player_id) then
		log.info("error_msg not online ", player_id, header)
		return
	end
	local agent = g_player_map[player_id]

	local body = hall_plug.rpc_pack.pack_error(msgbody, rsp_session)
	send_msg(agent, header, body)
end

--rpc推送消息
function interface:rpc_push_msg(player_id, header, msgbody)
	if not interface:is_online(player_id) then
		log.info("error_msg not online ", player_id, header)
		return
	end
	local agent = g_player_map[player_id]
	local body = hall_plug.rpc_pack.pack_push(msgbody)
	send_msg(agent, header, body)
end

--rpc推送消息给部分玩家
function interface:rpc_push_by_player_list(player_list, header, msgbody)
	local gate_list = {}
	local fd_list = {}

	local ws_gate_list = {}
	local ws_fd_list = {}

	for i = 1, #player_list do
		local player_id = player_list[i]
		local agent = g_player_map[player_id]
		if not agent then
			log.info("rpc_push_by_player_list not exists ",player_id)
		else
			if agent.fd > 0 then
				if agent.is_ws then
					tinsert(ws_gate_list, agent.gate)
					tinsert(ws_fd_list, agent.fd)
				else
					tinsert(gate_list, agent.gate)
					tinsert(fd_list, agent.fd)
				end
			else
				log.info("rpc_push_by_player_list not online ",player_id)
			end
		end
	end
	local body = hall_plug.rpc_pack.pack_push(msgbody)
	if #gate_list > 0 then
		hall_plug.broadcast(gate_list, fd_list, header, body)
	end

	if #ws_gate_list > 0 then
		hall_plug.ws_broadcast(ws_gate_list, ws_fd_list, header, body)
	end
end

--rpc推送消息给全部玩家
function interface:rpc_push_broad_cast(header, msgbody, filter_map)
	filter_map = filter_map or EMPTY

	local gate_list = {}
	local fd_list = {}

	local ws_gate_list = {}
	local ws_fd_list = {}

	for player_id,agent in pairs(g_player_map) do
		if not filter_map[player_id] then
			if agent.fd > 0 then
				if agent.is_ws then
					tinsert(ws_gate_list, agent.gate)
					tinsert(ws_fd_list, agent.fd)
				else
					tinsert(gate_list, agent.gate)
					tinsert(fd_list, agent.fd)
				end
			else
				log.info("broad_cast_msg not online ",player_id)
			end
		end
	end
	local body = hall_plug.rpc_pack.pack_push(msgbody)
	if #gate_list > 0 then
		hall_plug.broadcast(gate_list, fd_list, header, body)
	end

	if #ws_gate_list > 0 then
		hall_plug.ws_broadcast(ws_gate_list, ws_fd_list, header, body)
	end
end
----------------------------------------------------------------------------------
--CMD
----------------------------------------------------------------------------------
local function connect_new(gate, fd, is_ws, addr, player_id, watchdog, is_jump_join)
	--先设置转发，成功后再建立连接管理映射，不然存在建立连接，客户端立马断开的情况，掉线无法通知到此服务
	if fd > 0 and not skynet.call(gate, 'lua', 'forward', fd) then
		return nil, -1, "forward err"
	end
	local agent = g_player_map[player_id]
	local is_reconnect = false
	if not agent then
		agent = {
			player_id = player_id,
			fd = fd,
			gate = gate,
			watchdog = watchdog,
			queue = queue(),
			hall_server_id = SELF_ADDRESS,
			dis_conn_time = 0,         --掉线时间
			is_ws = is_ws,			   --是否websocket连接
			addr = addr,
		}
		g_player_map[player_id] = agent
	else
		if agent.is_goout then
			log.error("exiting ....",player_id)
			return nil, -1, "exiting"
		end
		g_fd_map[agent.fd] = nil
		agent.fd = fd
		agent.gate = gate
		agent.watchdog = watchdog
		agent.is_ws = is_ws
		agent.addr = addr
		is_reconnect = true
	end

	g_fd_map[fd] = agent
	return agent.queue(connect, agent, is_reconnect, is_jump_join)
end

function CMD.connect(gate, fd, is_ws, addr, player_id, watchdog)
	return connect_new(gate, fd, is_ws, addr, player_id, watchdog)
end
--掉线
function CMD.disconnect(gate,fd,player_id)
	local agent = g_fd_map[fd]
	if not agent then 
		return
	end

	g_fd_map[fd] = nil

	if fd ~= agent.fd then
		log.info("disconnect agent is reconnect ",fd,agent.fd,player_id)
		return
	end
	
	agent.fd = 0
	agent.gate = 0
	agent.dis_conn_time = time_util.skynet_int_time()

	hall_plug.disconnect(player_id)
	local table_server_id = agent.table_server_id
	local table_id = agent.table_id
	if table_server_id then
		skynet.send(table_server_id,'lua','disconnect',gate,fd,table_id,player_id)
	end
end

function CMD.leave_table(player_id, reason)
	return interface:leave_table(player_id, reason)
end

--登出
function CMD.goout(player_id, reason)
	local agent = g_player_map[player_id]
	if not agent then
		log.warn("goout not agent ",player_id, reason)
		return
	end

	if agent.goouting then
		log.warn("repeat goout ",player_id, reason)
		return
	end

	agent.goouting = true
	local ret,errcode,errmsg = agent.queue(goout, agent, reason)
	agent.goouting = false
	return ret,errcode,errmsg
end

--从旧服务跳出
function CMD.jump_exit(player_id)
	local agent = g_player_map[player_id]
	if not agent then
		return nil, -1, "agent not exists"
	end

	if agent.goouting then
		return nil, -1, "repeat goout"
	end

	agent.goouting = true
	local ret, errcode, errmsg = agent.queue(goout, agent, "jump_exit", true)
	agent.goouting = false
	return ret, errcode, errmsg
end

--跳入新服务
function CMD.jump_join(gate, fd, is_ws, addr, player_id, watchdog)
	return connect_new(gate, fd, is_ws, addr, player_id, watchdog, true)
end

function CMD.start(config)
	SELF_ADDRESS = skynet.self()
	assert(config.hall_plug,"not hall_plug")

	hall_plug = require(config.hall_plug)
	assert(hall_plug.init,"not init")             --初始化

	skynet.fork(function ()
		local confclient = contriner_client:new("share_config_m")
		local room_game_login = confclient:mod_call('query','room_game_login')

		if room_game_login.gateconf then
			assert(hall_plug.unpack,"hall_plug not unpack")              --解包函数
			assert(hall_plug.send,"hall_plug not send")                  --发包函数
			assert(hall_plug.broadcast,"hall_plug not broadcast")   				   --广播发包函数
		end
	
		if room_game_login.wsgateconf then
			assert(hall_plug.ws_unpack,"hall_plug not ws_unpack")        --ws解包函数
			assert(hall_plug.ws_send,"hall_plug not ws_send")            --ws发包函数
			assert(hall_plug.ws_broadcast,"hall_plug not ws_broadcast")  --ws广播发包函数
		end
	end)

	assert(hall_plug.connect,"not connect")       --连接大厅
	assert(hall_plug.disconnect,"not disconnect") --掉线
	assert(hall_plug.reconnect,"not reconnect")   --重连
	assert(hall_plug.goout,"not goout")           --退出
	assert(hall_plug.disconn_time_out,"not disconn_time_out") --掉线超时清理时间

	if hall_plug.register_cmd then
		for name,func in pairs(hall_plug.register_cmd) do
			skynet_util.extend_cmd_func(name, func)
		end
	end

	--检查掉线超时，掉线超时还没有重新连接的需要清理
	local timer_obj = timer:new(timer.minute,timer.loop,function()
		local cur_time = time_util.skynet_int_time()
		for player_id,agent in table_util.sort_ipairs_byk(g_player_map) do
			if g_player_map[player_id] and not interface:is_online(agent.player_id) and cur_time - agent.dis_conn_time > hall_plug.disconn_time_out then
				local isok,errorcode,errormsg = interface:goout(agent.player_id, "disconnect time out")
				if not isok then
					log.warn("disconn_time_out goout err ",errorcode,errormsg)
				end
			end
		end
	end)
	timer_obj:after_next()

	hall_plug.init(interface)
	skynet.register_protocol {
		id = skynet.PTYPE_CLIENT,
		name = "client",
		unpack = function(msg, sz)
			return msg, sz
		end,
		dispatch = dispatch,
	}

	return true
end

--检查退出
function CMD.check_exit()
	if hall_plug.check_exit and not hall_plug.check_exit() then
		return false
	end
	
	if not next(g_player_map) then
		log.info("g_player_map.is_empty can exit")
		return true
	else
		log.info("not g_player_map.is_empty can`t exit player_count = ", table_util.count(g_player_map))
		return false
	end
end

--预告退出
function CMD.herald_exit()
	if hall_plug.herald_exit then
		hall_plug.herald_exit()
	end
end

--取消退出
function CMD.cancel_exit()
	if hall_plug.cancel_exit then
		hall_plug.cancel_exit()
	end
end


--确认退出
function CMD.fix_exit()
	if hall_plug.fix_exit then
		hall_plug.fix_exit()
	end
end

--退出
function CMD.exit()
	if hall_plug.exit then
		return hall_plug.exit()
	else
		return true
	end
end

--安全关服处理
skynet_util.reg_shutdown_func(function()
	log.warn("-------------shutdown save begin---------------")
	for player_id,agent in table_util.sort_ipairs_byk(g_player_map) do
		if g_player_map[player_id] then
			local isok,errorcode,errormsg = interface:goout(agent.player_id, "shutdown")
			if not isok then
				log.warn("shutdown goout err ",errorcode,errormsg)
			else
				log.warn("shutdown goout succ ", agent.player_id)
			end
		end
	end
	log.warn("-------------shutdown save end---------------")
end)

return CMD
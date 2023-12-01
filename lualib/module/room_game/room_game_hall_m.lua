--大厅

local skynet = require "skynet"
local log = require "log"
local timer = require "timer"
local queue = require "queue"
local contriner_client = require "contriner_client"
local string_util = require "string_util"
local time_util = require "time_util"

contriner_client:register("room_game_alloc_m")

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
local g_msg_send = nil
----------------------------------------------------------------------------------
--private
----------------------------------------------------------------------------------
local function new_join_table(agent, table_name, join_cmd)
	local alloc_client = contriner_client:new("room_game_alloc_m",table_name,function() return false end)
	local gate = agent.gate
	local fd = agent.fd
	local player_id = agent.player_id
	local hall_server_id = agent.hall_server_id

	local table_server_id,table_id,errmsg = alloc_client:mod_call(join_cmd, player_id, gate, fd, hall_server_id, table_name)
	if not table_server_id then
		return false,table_id,errmsg
	end
	agent.alloc_client = alloc_client
	agent.table_server_id = table_server_id
	agent.table_id = table_id
	return table_id
end

--创建房间
local function create_join_table(agent, table_name)
	return new_join_table(agent, table_name, "create_join")
end

--匹配进入
local function match_join_table(agent, table_name)
	return new_join_table(agent, table_name, "match_join")
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
	local table_server_id,table_id,errmsg = xx_pcall(skynet.call,alloc_server_id,"join",player_id, gate, fd, hall_server_id, table_name, table_id)
	if not table_server_id then
		return false,table_id,errmsg
	end
	agent.alloc_server_id = alloc_server_id
	agent.table_server_id = table_server_id
	agent.table_id = table_id
	return table_id
end
--离开桌子
local function leave(agent)
	local isok,errcode,errmsg
	isok = true
	local alloc_client = agent.alloc_client           --走匹配的
	local alloc_server_id = agent.alloc_server_id     --直接进入房间的
	if alloc_client then
		isok,errcode,errmsg = alloc_client:mod_call('leave',agent.player_id)
	elseif alloc_server_id then
		isok,errcode,errmsg = xx_pcall(skynet.call,alloc_server_id,'leave',agent.player_id)
	end

	if not isok then
		log.error("can`t leave !!! ",agent.player_id,errcode,errmsg)
		return nil,errcode,errmsg
	end
	agent.alloc_client = nil
	agent.alloc_server_id = nil
	agent.table_server_id = nil
	agent.table_id = nil
	return true
end

local function handle_msg(agent,packname,pack_body)
	local func = g_handle_map[packname]
	if not func then
		local table_server_id = agent.table_server_id
		local table_id = agent.table_id
		if not table_server_id then
			log.info("dorp package ",packname,pack_body)
		else
			skynet.send(table_server_id,'lua','request',table_id,agent.player_id,packname,pack_body)
		end
	else
		func(agent.player_id,packname,pack_body)
	end
end
--消息分发
local function dispatch(fd,source,packname,pack_body)
	skynet.ignoreret()
	if not packname then
		log.error("unpack err ",packname,pack_body)
		return
	end

	local agent = g_fd_map[fd]
	if not agent then
		log.error("dispatch not agent ",fd,packname,pack_body)
		return
	end
	
	agent.queue(handle_msg,agent,packname,pack_body)
end
--连接大厅
local function connect(agent,is_reconnect)
	local gate = agent.gate
	local fd = agent.fd
	local player_id = agent.player_id
	local login_res = nil
	if not is_reconnect then
		login_res = hall_plug.connect(player_id)
	else
		login_res = hall_plug.reconnect(player_id)
		local table_server_id = agent.table_server_id
		local table_id = agent.table_id
		if table_server_id then
			skynet.send(table_server_id,'lua','reconnect',gate,fd,table_id,player_id)
		end
	end

	return login_res
end

local function clean_agent(player_id)
	g_player_map[player_id] = nil
end
--登出
local function goout(agent)
	local player_id = agent.player_id
	local isok,errcode,errmsg = leave(agent)
	if not isok then
		log.error("can`t leave !!! ",player_id,errcode,errmsg)
		return nil,errcode,errmsg
	end
	hall_plug.goout(player_id)
	skynet.send(agent.watchdog,'lua','goout',player_id)
	skynet.fork(clean_agent,player_id)
	return true
end

local CMD = {}
----------------------------------------------------------------------------------
--interface
----------------------------------------------------------------------------------
local interface = {}
--创建进入房间
function interface:create_join_table(player_id,table_name)
	local agent = g_player_map[player_id]
	if not agent then
		log.warn("create_join_table agent not exists ",player_id)
		return
	end

	if agent.table_lock then
		log.warn("create_join_table is lock ",player_id,table_name)
		return
	end

	--已经存在房间了
	if agent.table_server_id then
		log.warn("create_join_table table_server_id is exists",player_id)
		return
	end
	agent.table_lock = true
	local ret,errcode,errmsg = agent.queue(create_join_table,agent,table_name)
	agent.table_lock = nil
	return ret,errcode,errmsg
end


--匹配进入
function interface:match_join_table(player_id,table_name)
	local agent = g_player_map[player_id]
	if not agent then
		log.warn("match_join_table agent not exists ",player_id)
		return
	end

	if agent.table_lock then
		log.warn("match_join_table is lock ",player_id,table_name)
		return
	end

	--已经存在房间了
	if agent.table_server_id then
		log.warn("match_join_table table_server_id is exists",player_id)
		return
	end
	agent.table_lock = true
	local ret,errcode,errmsg = agent.queue(match_join_table,agent,table_name)
	agent.table_lock = nil
	return ret,errcode,errmsg
end

--进入房间
function interface:join_table(player_id,table_name,table_id)
	local agent = g_player_map[player_id]
	if not agent then
		log.warn("join agent not exists ",player_id)
		return
	end

	if agent.table_lock then
		log.warn("join is lock ",player_id,table_name)
		return
	end

	--已经存在房间了
	if agent.table_server_id then
		log.warn("join table_server_id is exists",player_id)
		return
	end
	agent.table_lock = true
	local ret,errcode,errmsg = agent.queue(join_table,agent,player_id,table_name,table_id)
	agent.table_lock = nil
	return ret,errcode,errmsg
end
--离开房间
function interface:leave_table(player_id)
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
	local ret,errcode,errmsg = agent.queue(leave,agent)
	agent.table_lock = nil
	return ret,errcode,errmsg
end
--登出
function interface:goout(player_id)
	return CMD.goout(player_id)
end
--设置消息处理函数
function interface:handle(packname,func)
	g_handle_map[packname] = func
end
--是否在线
function interface:is_online(player_id)
	local agent = g_player_map[player_id]
	if not agent then
		log.info("is_online not agent ",player_id)
		return false
	end

	return agent.fd ~= 0
end
--发送消息
function interface:send_msg(player_id,packname,pack_body)
	if not interface:is_online(player_id) then
		log.info("send msg not online ",player_id,packname)
		return
	end
	local agent = g_player_map[player_id]
	hall_plug.send(agent.gate,agent.fd,packname,pack_body)
end

--发送消息给部分玩家
function interface:send_msg_by_player_list(player_list,packname,pack_body)
	local gate_list = {}
	local fd_list = {}
	for i = 1, #player_list do
		local player_id = player_list[i]
		local agent = g_player_map[player_id]
		if not agent then
			log.info("send_msg_by_player_list not exists ",player_id)
		else
			if agent.fd > 0 then
				tinsert(gate_list, agent.gate)
				tinsert(fd_list, agent.fd)
			else
				log.info("send_msg_by_player_list not online ",player_id)
			end
		end
	end

	if #gate_list <= 0 then return end

	hall_plug.broadcast(gate_list,fd_list,packname,pack_body)
end

--广播发送消息
function interface:broad_cast_msg(packname,pack_body,filter_map)
	filter_map = filter_map or {}

	local gate_list = {}
	local fd_list = {}
	for player_id,agent in pairs(g_player_map) do
		if not filter_map[player_id] then
			if agent.fd > 0 then
				tinsert(gate_list, agent.gate)
				tinsert(fd_list, agent.fd)
			else
				log.info("broad_cast_msg not online ",player_id)
			end
		end
	end

	if #gate_list <= 0 then return end

	hall_plug.broadcast(gate_list,fd_list,packname,pack_body)
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
		return 0
	end

	return agent.table_id or "0:0"
end
----------------------------------------------------------------------------------
--CMD
----------------------------------------------------------------------------------

function CMD.connect(gate,fd,player_id,watchdog)
	--先设置转发，成功后再建立连接管理映射，不然存在建立连接，客户端立马断开的情况，掉线无法通知到此服务
	skynet.call(gate,'lua','forward',fd) --设置转发不成功，此处会断言，以下就不会执行了，就当它没有来连接过
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
		}
		g_player_map[player_id] = agent
	else
		if agent.is_goout then
			log.error("exiting ....",player_id)
			return 
		end
		agent.fd = fd
		agent.gate = gate
		agent.watchdog = watchdog
		is_reconnect = true
	end

	g_fd_map[fd] = agent
	return agent.queue(connect,agent,is_reconnect)
end
--掉线
function CMD.disconnect(gate,fd,player_id)
	local agent = g_fd_map[fd]
	if not agent then 
		log.error("disconnect not agent ",fd,player_id)
		return
	end

	g_fd_map[fd] = nil

	if fd ~= agent.fd then
		log.warn("disconnect agent is reconnect ",fd,agent.fd,player_id)
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

function CMD.leave_table(player_id)
	return interface:leave_table(player_id)
end

--登出
function CMD.goout(player_id)
	local agent = g_player_map[player_id]
	if not agent then
		log.error("goout not agent ",player_id)
		return
	end

	if agent.is_goout then
		log.warn("repeat goout ",player_id)
		return
	end

	agent.is_goout = true
	local ret,errcode,errmsg = agent.queue(goout,agent)
	agent.is_goout = false
	return ret,errcode,errmsg
end

function CMD.start(config)
	SELF_ADDRESS = skynet.self()
	assert(config.hall_plug,"not hall_plug")

	hall_plug = require(config.hall_plug)
	assert(hall_plug.init,"not init")             --初始化
	assert(hall_plug.unpack,"not unpack")         --解包函数
	assert(hall_plug.send,"not send")             --发包函数
	assert(hall_plug.broadcast,"not broadcast")   --广播发包函数
	assert(hall_plug.connect,"not connect")       --连接大厅
	assert(hall_plug.disconnect,"not disconnect") --掉线
	assert(hall_plug.reconnect,"not reconnect")   --重连
	assert(hall_plug.goout,"not goout")           --退出
	assert(hall_plug.disconn_time_out,"not disconn_time_out") --掉线超时清理时间

	if hall_plug.register_cmd then
		for name,func in pairs(hall_plug.register_cmd) do
			assert(not CMD[name],"repeat cmd " .. name)
			CMD[name] = func
		end
	end

	--检查掉线超时，掉线超时还没有重新连接的需要清理
	local timer_obj = timer:new(timer.minute,timer.loop,function()
		local cur_time = time_util.skynet_int_time()
		for _,agent in pairs(g_player_map) do
			if not interface:is_online(agent.player_id) and cur_time - agent.dis_conn_time > hall_plug.disconn_time_out then
				log.info("disconn_time_out ",agent.player_id)
				--尝试登出
				local isok,errorcode,errormsg = interface:goout(agent.player_id)
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
		unpack = hall_plug.unpack,
		dispatch = dispatch,
	}

	return true
end

function CMD.check_exit()
	if not next(g_player_map) then
		log.info("g_player_map.is_empty can exit")
		return true
	else
		log.info("not g_player_map.is_empty can`t exit",g_player_map)
		return false
	end
end

function CMD.exit()
	return true
end

return CMD
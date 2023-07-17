local skynet = require "skynet"
local log = require "log"
local timer = require "timer"
local queue = require "queue"
local contriner_client = require "contriner_client"

local assert = assert
local pcall = pcall
local next = next

local g_player_map = {}
local g_fd_map = {}

local CMD = {}

local hall_plug = nil

local function dispatch(fd,source,packname,req)
	skynet.ignoreret()
	if not packname then
		log.error("unpack err ",packname,req)
		return
	end

	local agent = g_fd_map[fd]
	if not agent then
		log.error("dispatch not agent ",fd,packname,req)
		return
	end

	if not hall_plug.dispatch(fd,packname,req,CMD) then
		local room_server = agent.room_server
		local table_id = agent.table_id
		local player_id = agent.player_id
		if room_server then
			skynet.send(room_server,'lua','request',table_id,player_id,packname,req)
		else
			log.info("dorp package ",packname,req)
		end
	end

end

function CMD.connect(fd,player_id,gate)
	local agent = g_player_map[player_id]
	if not agent then
	 	agent = {
			player_id = player_id,
			fd = fd,
			gate = gate,
			queue = queue(),
		}
		g_player_map[player_id] = agent
	else
		if agent.is_goout then
			log.error("exiting ....",player_id)
			return 
		end
		agent.fd = fd
	end

	g_fd_map[fd] = agent
	return agent.queue(function()
		if not agent.match_client then
			agent.match_client = contriner_client:new("match_m",nil,function() return false end)
			local room_server,table_id,errmsg = agent.match_client:mod_call('match',player_id,fd,skynet.self())
			if not room_server then
				return false,table_id,errmsg
			end

			agent.room_server = room_server
			agent.table_id = table_id
			hall_plug.connect(fd,player_id)
		else
			local room_server = agent.room_server
			local table_id = agent.table_id
			skynet.send(room_server,'lua','reconnect',fd,table_id,player_id)
			hall_plug.reconnect(fd,player_id)
		end

		pcall(skynet.call,agent.gate,'lua','forward',fd)
		return {
			player_id = agent.player_id,
			hall_server_id = skynet.self(),
			match_server_id = agent.match_client:get_mod_server_id(),
			room_server_id = agent.room_server,
			table_id = agent.table_id,
		}
	end)
end

function CMD.disconnect(fd,player_id)
	local agent = g_fd_map[fd]
	if not agent then 
		log.error("disconnect not agent ",fd,player_id)
		return
	end

	g_fd_map[fd] = nil
	agent.fd = 0

	local room_server = agent.room_server
	local table_id = agent.table_id

	if g_player_map[player_id] then
		skynet.send(room_server,'lua','disconnect',fd,table_id,player_id)
	end

	hall_plug.disconnect(fd,player_id)
end

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
	return agent.queue(function()
		local match_client = agent.match_client
		local isok,errcode,errmsg = match_client:mod_call('leave',player_id)
		agent.is_goout = false
		if not isok then
			log.error("leave faild !!! ",player_id)
			return nil,errcode,errmsg
		end

		g_player_map[player_id] = nil
		skynet.send(agent.gate,'lua','kick',agent.fd)
		skynet.send('.login','lua','goout',player_id)
		hall_plug.goout(player_id)
		return true
	end)
end

function CMD.start(config)
	assert(config.hall_plug,"not hall_plug")

	hall_plug = require(config.hall_plug)
	assert(hall_plug.init,"not init")             --初始化
	assert(hall_plug.unpack,"not unpack")         --解包函数
	assert(hall_plug.dispatch,"not dispatch")     --消息分发
	assert(hall_plug.connect,"not connect")       --连接大厅
	assert(hall_plug.disconnect,"not disconnect") --掉线
	assert(hall_plug.reconnect,"not reconnect")   --重连
	assert(hall_plug.goout,"not goout")           --退出

	hall_plug.init()
	skynet.register_protocol {
		id = skynet.PTYPE_CLIENT,
		name = "client",
		unpack = hall_plug.unpack,
		dispatch = dispatch,
	}

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
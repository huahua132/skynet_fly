
local log = require "log"
local skynet = require "skynet"
local contriner_client = require "contriner_client"
local queue = require "skynet.queue"
local timer = require "timer"
local pbnet_util = require "pbnet_util"
local pb_util = require "pb_util"
local errors_msg = require "errors_msg"
local login_msg = require "login_msg"
local pcall = pcall
local next = next

local g_player_map = {}
local g_fd_map = {}

local M = {}

M.unpack = pbnet_util.unpack

function M.init()
	pb_util.load("./proto")
end

function M.dispatch(fd,packname,req)
	local agent = M.get_agent(fd)
	if not agent then
		log.error("dispatch not agent ",fd,packname)
		return
	end
	if packname == '.login.LoginOutReq' then
		local ok,errorcode,errormsg = M.goout(agent.player_id)
		if not ok then
			log.error("dispatch err ",errorcode,errormsg)
			errors_msg.errors(fd,errorcode,errormsg,packname)
		else
			login_msg.login_out_res(fd,agent.player_id)
		end
	else
		log.info("send_request:",fd,packname,req)
		local room_server = agent.room_server
		local table_id = agent.table_id
		local player_id = agent.player_id

		skynet.send(room_server,'lua','request',table_id,player_id,packname,req)
	end
end

function M.connect(player_id,player_info,fd,gate)
	local agent = g_player_map[player_id]

	if not agent then
	 	agent = {
			player_id = player_id,
			player_info = player_info,
			fd = fd,
			gate = gate,
			queue = queue(),
		}
		g_player_map[player_id] = agent
	else
		if agent.is_goout then
			log.fatal("exiting ....",player_id)
			return 
		end
		g_fd_map[agent.fd] = nil
		agent.fd = fd
	end

	g_fd_map[fd] = agent
	return agent.queue(function()
		if not agent.match_client then
			agent.match_client = contriner_client:new("match_m",nil,function() return false end)
			local room_server,table_id,errmsg = agent.match_client:mod_call('match',player_id,player_info,fd,skynet.self())
			if not room_server then
				return false,table_id,errmsg
			end

			agent.room_server = room_server
			agent.table_id = table_id
		else
			local room_server = agent.room_server
			local table_id = agent.table_id
			skynet.send(room_server,'lua','reconnect',table_id,player_id,fd)
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

function M.disconnect(fd,player_id)
	local agent = g_fd_map[fd]
	if not agent then 
		log.error("disconnect not agent ",fd,player_id)
		return
	end

	g_fd_map[fd] = nil
	agent.fd = 0

	local room_server = agent.room_server
	local table_id = agent.table_id

	log.error("disconnect:",room_server,player_id,table_id)
	skynet.send(room_server,'lua','disconnect',table_id,player_id)
end

function M.goout(player_id)
	local agent = g_player_map[player_id]
	if not agent then
		log.error("goout not agent ",player_id)
		return
	end
	agent.is_goout = true
	return agent.queue(function()
		local match_client = agent.match_client
		if not match_client:mod_call('leave',player_id) then
			log.error("leave faild !!! ",player_id)
			return
		end

		g_player_map[player_id] = nil
		g_fd_map[agent.fd] = nil
		skynet.send(agent.gate,'lua','kick',agent.fd)
		skynet.send('.login','lua','goout',player_id)
		return true
	end)
end

function M.get_agent(fd)
	return g_fd_map[fd]
end

function M.empty()
	return not next(g_player_map)
end

function M.info()
	return g_player_map,g_fd_map
end

return M
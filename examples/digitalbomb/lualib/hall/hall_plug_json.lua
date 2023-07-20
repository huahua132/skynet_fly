
local log = require "log"
local skynet = require "skynet"
local contriner_client = require "contriner_client"
local queue = require "skynet.queue"
local timer = require "timer"
local jsonet_util = require "jsonet_util"
local errors_msg_json = require "errors_msg_json"
local login_msg_json = require "login_msg_json"
local pcall = pcall
local next = next
local assert = assert

local g_fd_map = {}

local M = {}

M.unpack = jsonet_util.unpack

function M.init()
	
end

function M.dispatch(gate,fd,packname,req,CMD)
	local agent = g_fd_map[fd]
	if not agent then
		log.error("dispatch not agent ",fd,packname)
		return
	end
	if packname ~= '.login.LoginOutReq' then
		return false
	end

	local ok,errorcode,errormsg = CMD.goout(agent.player_id)
	if not ok then
		log.error("dispatch err ",errorcode,errormsg)
		errors_msg_json.errors(gate,fd,errorcode,errormsg,packname)
	else
		login_msg_json.login_out_res(gate,fd,{player_id = agent.player_id})
	end
		
	return true
end

function M.connect(gate,fd,player_id)
	log.info("hall_plug connect ",fd,player_id)
	assert(not g_fd_map[fd])
	g_fd_map[fd] = {
		player_id = player_id
	}
end

function M.disconnect(gate,fd,player_id)
	log.info("hall_plug disconnect ",fd,player_id)
	assert(g_fd_map[fd])
	g_fd_map[fd] = nil
end

function M.reconnect(gate,fd,player_id)
	log.info("hall_plug reconnect ",fd,player_id)
	assert(not g_fd_map[fd])
	g_fd_map[fd] = {
		player_id = player_id
	}
end

function M.goout(player_id)
	log.info("hall_plug goout ",player_id)
end

return M
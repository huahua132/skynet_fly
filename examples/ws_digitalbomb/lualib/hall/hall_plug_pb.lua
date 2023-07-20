
local log = require "log"
local skynet = require "skynet"
local contriner_client = require "contriner_client"
local queue = require "skynet.queue"
local timer = require "timer"
local ws_pbnet_util = require "ws_pbnet_util"
local pb_netpack = require "pb_netpack"
local errors_msg = require "errors_msg"
local login_msg = require "login_msg"
local pcall = pcall
local next = next
local assert = assert

local g_fd_map = {}

local M = {}

M.unpack = ws_pbnet_util.unpack

function M.init()
	pb_netpack.load("./proto")
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
		errors_msg.errors(gate,fd,errorcode,errormsg,packname)
	else
		login_msg.login_out_res(gate,fd,{player_id = agent.player_id})
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
local log = require "skynet-fly.log"
local skynet = require "skynet"
local timer = require "skynet-fly.timer"
local websocket = require "http.websocket"
local socket = require "skynet.socket"
local pb_netpack = require "skynet-fly.netpack.pb_netpack"
local sp_netpack = require "skynet-fly.netpack.sp_netpack"
local table_util = require "skynet-fly.utils.table_util"
local msg_id = require "enum.msg_id"
local pack_helper = require "common.pack_helper"
local container_client = require "skynet-fly.client.container_client"
local rpc_client = require "skynet-fly.utils.net.rpc_client"
container_client:register("share_config_m")

local net_util = nil

local test_proto = skynet.getenv("test_proto")

local CMD = {}

local g_config

local function dispatch(fd,packid,res)
	log.info("dispatch:", g_config.protocol, fd, packid, res)
end

local function connnect(handle)
	local confclient = container_client:new("share_config_m")
	local room_game_login = confclient:mod_call('query','room_game_login')
	local fd
	if g_config.protocol == 'websocket' then
		local port = room_game_login.wsgateconf.port
		assert(port, "not wsgateconf port")
		fd = websocket.connect("ws://127.0.0.1:" .. port)
	else
		local port = room_game_login.gateconf.port
		assert(port, "not gateconf port")
		fd = socket.open('127.0.0.1', port)
	end
	if not fd then
		log.error("connect faild ")
		return
	end

	local rpc_cli = rpc_client:new(function(header, body)
		net_util.send(nil, fd, header, body)
	end, timer.second * 5)

	socket.onclose(fd, function()
		rpc_cli:close()
	end)

	net_util.recv(fd,handle or dispatch)
	return fd, rpc_cli
end

local function close(fd)
	if g_config.protocol == 'websocket' then
		websocket.close(fd)
	else
		socket.close(fd)
	end
end
--玩游戏
local function player_game()
	local fd
	local rpc_cli
	fd, rpc_cli = connnect(function(_, header, body)
		local packid, msgbody = rpc_cli:handle_msg(header, body)
		if packid == nil then
			log.error("handle_msg err ", header, msgbody)
		elseif packid == false then
			--说明是rpc回复
			return
		end
		--推送的消息
		log.info("push msg:", g_config.player_id, fd, g_config.protocol, packid, msgbody)

		if packid == msg_id.game_NextDoingCast then
			if msgbody.doing_player_id ~= g_config.player_id then
				return
			end
			log.error("NextDoingCast sleep 1 ",coroutine.running())
			skynet.sleep(math.random(300,500))
			log.error("NextDoingCast sleep 2 ",coroutine.running())
			local min_num = msgbody.min_num
			local max_num = msgbody.max_num

			local opt_num = math.random(min_num,max_num)
			rpc_cli:push(msg_id.game_DoingReq, {
				opt_num = opt_num,
			})
		elseif packid == msg_id.game_GameStatusRes then
			local next_doing = msgbody.next_doing
			if next_doing.doing_player_id ~= g_config.player_id then
				return
			end
			log.error("GameStatusRes sleep 1 ",coroutine.running())
			skynet.sleep(math.random(300,500))
			log.error("GameStatusRes sleep 2 ",coroutine.running())
			local min_num = next_doing.min_num
			local max_num = next_doing.max_num
			
			local opt_num = math.random(min_num,max_num)
			rpc_cli:push(msg_id.game_DoingReq, {
				opt_num = opt_num,
			})
		elseif packid == msg_id.game_GameOverCast then
			local login_out_req = {
				player_id = g_config.player_id,
			}
			local packid, login_out_res = rpc_cli:req(msg_id.login_LoginOutReq, login_out_req)
			log.info("login_LoginOutReq >>> ", g_config.player_id, packid, login_out_res)
		end
	end)

	--请求登录
	local login_req = {
		account = g_config.account,
		password = g_config.password,
		player_id = g_config.player_id,
	}
	local packid, login_res = rpc_cli:req(msg_id.login_LoginReq, login_req)
	if not packid or packid == msg_id.errors_Error then
		log.info("登录失败", g_config.player_id, login_res)
		return
	end
	log.info("login_res >>> ", g_config.player_id, packid, login_res)

	--请求匹配房间
	local packid, match_res = rpc_cli:req(msg_id.login_matchReq, {table_name = "room_3"})
	if not packid or packid == msg_id.errors_Error then
		log.info("匹配房间失败 ", g_config.player_id, match_res)
		return
	end
	log.info("match_res >>> ", g_config.player_id, packid, match_res)
	--请求房间状态
	local packid, game_status_res = rpc_cli:req(msg_id.game_GameStatusReq, {player_id = g_config.player_id})
	if not packid or packid == msg_id.errors_Error then
		log.info("请求房间状态失败 ", g_config.player_id, game_status_res)
		return
	end
	log.info("game_status_res >>> ", g_config.player_id, packid, game_status_res)

	--请求服务器信息
	local packid, game_server_info_res = rpc_cli:req(msg_id.login_serverInfoReq, {player_id = g_config.player_id})
	if not packid or packid == msg_id.errors_Error then
		log.info("请求服务器信息出错 ", g_config.player_id, game_server_info_res)
		return
	end
	log.info("game_server_info_res >>> ", g_config.player_id, packid, game_server_info_res)

	local next_doing = game_status_res.next_doing
		if next_doing.doing_player_id ~= g_config.player_id then
			return
		end
		log.error("GameStatusRes sleep 1 ",coroutine.running())
		skynet.sleep(math.random(300,500))
		log.error("GameStatusRes sleep 2 ",coroutine.running())
		local min_num = next_doing.min_num
		local max_num = next_doing.max_num
		
		local opt_num = math.random(min_num,max_num)
		rpc_cli:push(msg_id.game_DoingReq, {
			opt_num = opt_num,
		})

	return fd
end

function CMD.start(config)
	pb_netpack.load('./proto')
	sp_netpack.load('./sproto')
	g_config = config

	if g_config.protocol == 'websocket' then
		if test_proto == 'pb' then
			net_util = require "skynet-fly.utils.net.ws_pbnet_byrpc"  --pb
		else
			net_util = require "skynet-fly.utils.net.ws_spnet_byrpc"
		end
	else
		if test_proto == 'pb' then
			net_util = require "skynet-fly.utils.net.pbnet_byrpc"     --pb
		else
			net_util = require "skynet-fly.utils.net.spnet_byrpc"
		end
	end
	pack_helper.set_packname_id()
	pack_helper.set_sp_packname_id()
	
	skynet.fork(function()
		player_game()
	end)
	
	return true
end

function CMD.exit()
	return true
end

return CMD
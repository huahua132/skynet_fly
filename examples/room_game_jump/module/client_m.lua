local log = require "skynet-fly.log"
local skynet = require "skynet"
local timer = require "skynet-fly.timer"
local websocket = require "http.websocket"
local pb_netpack = require "skynet-fly.netpack.pb_netpack"
local table_util = require "skynet-fly.utils.table_util"
local contriner_client = require "skynet-fly.client.contriner_client"
local module_info = require "skynet-fly.etc.module_info"
contriner_client:register("share_config_m")

local CMD = {}

local g_config
local net_util = nil

local function dispatch(fd,packname,res)
	log.info("dispatch:",g_config.protocol,fd,packname,res)
end

local function connnect(handle)
	local confclient = contriner_client:new("share_config_m")
	local room_game_login = confclient:mod_call('query','room_game_login')
	local port = room_game_login.wsgateconf.port
	assert(port, "not wsgateconf port")
	local fd = websocket.connect("ws://127.0.0.1:" .. port)
	if not fd then
		log.error("connect faild ")
		return
	end

	local login_req = {
		account = g_config.account,
		password = g_config.password,
		player_id = g_config.player_id,
	}

	net_util.recv(fd,handle or dispatch)

	net_util.send(nil,fd,'.login.LoginReq',login_req)

	return fd
end

local function loginout(fd)
	local login_out_req = {
		player_id = g_config.player_id,
	}

	net_util.send(nil,fd,'.login.LoginOutReq',login_out_req)
end

local function close(fd)
	websocket.close(fd)
end

--在线跳转测试
local function online_jump_test()
	local fd = connnect()

	skynet.sleep(100)
	--热更
	log.info("热更:")
	skynet.call('.contriner_mgr','lua','load_modules', skynet.self(), "room_game_hall_m")
	for i = 1, 3 do
		net_util.send(nil, fd, '.login.serverInfoReq', {player_id = g_config.player_id})
	end

	skynet.sleep(100)
	close(fd)
end

--离线跳转测试
local function offline_jump_test()
	local fd = connnect()
	skynet.sleep(100)
	close(fd)

	log.info("热更:")
	skynet.call('.contriner_mgr','lua','load_modules', skynet.self(), "room_game_hall_m")
	for i = 1, 3 do
		net_util.send(nil, fd, '.login.serverInfoReq', {player_id = g_config.player_id})
	end

	fd = connnect()
	skynet.sleep(100)
	for i = 1, 3 do
		net_util.send(nil, fd, '.login.serverInfoReq', {player_id = g_config.player_id})
	end
	skynet.sleep(100)
	close(fd)
end

--跳转时登出测试
local function loginout_jump_test()
	local fd = connnect()
	skynet.sleep(100)

	log.info("热更:")
	skynet.call('.contriner_mgr','lua','load_modules', skynet.self(), "room_game_hall_m")

	loginout(fd)
end

--进入桌子后跳转测试
local function table_jump_test()
	local fd = connnect()
	skynet.sleep(100)

	net_util.send(nil,fd,'.login.matchReq',{table_name = "room_3"})

	log.info("热更:")
	skynet.call('.contriner_mgr','lua','load_modules', skynet.self(), "room_game_hall_m")
end

function CMD.start(config)
	pb_netpack.load('./proto')
	g_config = config

	net_util = require "skynet-fly.utils.net.ws_pbnet_util" --pb
	
	skynet.fork(function()
		--online_jump_test()
		--offline_jump_test()
		--loginout_jump_test()
		table_jump_test()
	end)
	
	return true
end

function CMD.exit()
	return true
end

return CMD
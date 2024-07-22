local skynet = require "skynet"
local socket = require "skynet.socket"
local log = require "skynet-fly.log"
local skynet_util = require "skynet-fly.utils.skynet_util"
local assert = assert
local string = string
local pcall = pcall

local g_maxclient = nil
local g_client_num = 0
local g_slave_list = {}

local g_fd_map = {}

local CMD = {}

function CMD.open(source,conf)
	local instance = conf.instance or 8
	conf.watchdog = conf.watchdog or source
	conf.protocol = conf.protocol or "ws"

	g_maxclient = conf.maxclient or 1024

	local protocol = conf.protocol
	assert(protocol == "ws" or protocol == "wss","protocol err")

	for i = 1, instance do
		local s_id = skynet.newservice('ws_slave')
		skynet.call(s_id,'lua','open',conf)
		g_slave_list[i] = s_id
	end

	local address = conf.address or "0.0.0.0"
	local port = assert(conf.port,"conf not port")
	
	local listen_fd = socket.listen(address,port)
	log.info(string.format("listen websocket port:%s protocol:%s",port,protocol))

	local balance = 1
	local s_len = #g_slave_list
	socket.start(listen_fd,function(fd,addr)
		assert(not g_fd_map[fd],"repeat fd " .. fd)
		if g_client_num >= g_maxclient then
			log.warn("ws_gate connect full ",port,g_client_num,g_maxclient,fd,addr)
			socket.close_fd(fd)
			return
		end

		g_client_num = g_client_num + 1

		local s_id = g_slave_list[balance]
		balance = balance + 1
		if balance > s_len then
			balance = 1
		end

		g_fd_map[fd] = true
		local isok, err = pcall(skynet.call, s_id, 'lua', 'accept', fd, addr)
		if not isok then
			log.error("ws_gate accept err ", err)
		end
		g_fd_map[fd] = nil
		g_client_num = g_client_num - 1
	end)
end

skynet.start(function()
	skynet_util.lua_src_dispatch(CMD)
end)

skynet_util.register_info_func("info", function()
	log.info("ws_gate info ", g_client_num)
end)
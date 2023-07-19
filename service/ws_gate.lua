local skynet = require "skynet"
local socket = require "socket"
local log = require "log"
local assert = assert
local string = string

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
	log.error(string.format("listen websocket port:%s protocol:%s",port,protocol))

	local balance = 1
	local s_len = #g_slave_list
	socket.start(listen_fd,function(fd,addr)
		assert(not g_fd_map[fd],"repeat fd " .. fd)
		if g_client_num >= g_maxclient then
			log.error("ws_gate connect full ",port,g_client_num,g_maxclient,fd,addr)
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
		skynet.send(s_id,'lua','accept', fd, addr)
	end)
end

function CMD.closed(_,fd)
	assert(g_fd_map[fd],"closed not exists fd " .. fd)
	g_client_num = g_client_num - 1
end

skynet.start(function()
	skynet.dispatch('lua',function(session,source,cmd,...)
		local f = CMD[cmd]
		assert(f,'cmd no found :'..cmd)
	
		if session == 0 then
			f(source,...)
		else
			skynet.retpack(f(source,...))
		end
	end)
end)
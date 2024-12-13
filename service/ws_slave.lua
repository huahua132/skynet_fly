local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local socketdriver = require "skynet.socketdriver"
local log = require "skynet-fly.log"
local skynet_util = require "skynet-fly.utils.skynet_util"
local assert = assert
local string = string
local tinsert = table.insert

local CLOSE_CODE = {
	normal = 1000,
	goingaway = 1001,
}

local CLOSE_REASON = {
	[1000] = " Normal Closure",			  --表示连接已经按照预期的方式正常关闭。这是最常见的关闭码，表示双方都希望关闭连接，并且没有错误或异常发生。
	[1001] = "Going Away",       		  --表示端点（客户端或服务器）正在离开，并且不再可用。这可能是因为服务器正在停机，或者客户端离开了当前页面。
	[1002] = "Protocol Error",            --表示收到的数据在解析时违反了WebSocket协议的规则。
	[1003] = "Unsupported Data",          --表示收到了不支持的数据类型或数据格式。
	[1004] = "unknown err",                --保留错误码
	[1005] = "No Status Received",        --表示预期的关闭状态码没有收到。请注意，此关闭码是由于WebSocket协议的限制而不是由应用程序发送的。
	[1006] = "Abnormal Closure",          --表示连接已经关闭，但关闭码未知。通常发生在连接出现异常而没有正确关闭的情况。
	[1007] = "Invalid Data",              --表示收到的数据在解析时被认为是不合法的UTF-8数据。
	[1008] = "Policy Violation",          --表示收到的数据违反了WebSocket服务器的策略。
	[1009] = "Message Too Big ",          --表示收到的消息大小超过了服务器支持的最大消息大小限制。
	[1010] = "Mandatory Extension",       --表示服务器收到了一个不支持或必须使用的扩展。
	[1011] = "Internal Server Error",     --表示服务器在处理请求时遇到了内部错误。
	--1012-1016 - 保留用于未来的扩展。
	[1017] = "Restarting / TLS Handshake Failure ", --表示服务器正在重新启动，或者TLS握手过程失败。
	[1018] = "Unexpected Condition",      --表示服务器收到了一个不符合协议预期的情况。
	--1019-2999 - 保留供私有使用。
	--3000-3999 - 保留用于共享的WebSocket扩展。
	--4000-4999 - 保留供私有使用。
}

local g_nodelay = nil
local g_protocol = nil
local g_watchdog = nil
local g_conn_map = {}

local SELF_ADDRESS = nil

local function closed(fd)
	if not g_conn_map[fd] then return end
	g_conn_map[fd] = nil
	skynet.send(g_watchdog,'lua','socket','close', fd)
end

local HANDLER = {}

--connect / handshake / message / ping / pong / close / error
function HANDLER.connect(fd)
	if g_nodelay then
		socketdriver.nodelay(fd)
	end

	local addr = websocket.addrinfo(fd)
	g_conn_map[fd] = {
		fd = fd,
		addr = addr,
	}

	skynet.send(g_watchdog,'lua', 'socket', 'open', fd, addr, SELF_ADDRESS, true)
end

function HANDLER.handshake(fd,header,url)
	--log.info("handshake:",fd,header,url)
end

function HANDLER.message(fd, msg, msg_type)
	assert(msg_type == "binary" or msg_type == "text")
	local c = g_conn_map[fd]
	local agent = c.agent

	if agent then
		if c.is_pause then
			if not c.msg_que then
				c.msg_que = {}
			end
			tinsert(c.msg_que, msg)
		else
			skynet.redirect(agent, 0, 'client', fd, msg)
		end
	else
		skynet.send(g_watchdog,'lua','socket','data', fd, msg)
	end
end

function HANDLER.ping(fd)
	log.info("ws ping from:",fd)
end

function HANDLER.pong(fd)
	log.info("ws pong from:",fd)
end

function HANDLER.close(fd, code, reason)
	closed(fd)
end

function HANDLER.error(fd)
	log.error("ws error ",fd)
	closed(fd)
end

function HANDLER.warning(ws_obj,sz)
	log.warn("ws warning ",ws_obj,sz)
end

local CMD = {}

function CMD.open(source,conf)
	g_nodelay = conf.nodelay
	g_protocol = conf.protocol
	g_watchdog = conf.watchdog

	SELF_ADDRESS = skynet.self()
end

function CMD.accept(source,fd,addr)
	local isok,err = websocket.accept(fd,HANDLER,g_protocol,addr)
	if not isok then
		log.error("accept err ",fd,addr,err)
	end
end

function CMD.forward(source, fd)
	if not g_conn_map[fd] then
		log.warn("forward not exists fd = ", fd)
		return false
	end
	local c = g_conn_map[fd]
	c.agent = source

	return true
end

function CMD.send_text(_, fd, msg)
	if websocket.is_close(fd) then
		log.warn("send not exists fd ",fd)
	else
		websocket.write(fd,msg,"text")
	end
end

function CMD.send_binary(_,fd, msg)
	if websocket.is_close(fd) then
		log.warn("send not exists fd ",fd)
	else
		websocket.write(fd,msg,"binary")
	end
end

function CMD.broadcast_text(_, fd_list, msg)
	local len = #fd_list
	for i = 1, len do
		local fd = fd_list[i]
		if websocket.is_close(fd) then
			log.warn("broadcast_text not exists fd ",fd)
		else
			websocket.write(fd, msg, "text")
		end
	end
end

function CMD.broadcast_binary(_, fd_list, msg)
	local len = #fd_list
	for i = 1, len do
		local fd = fd_list[i]
		if websocket.is_close(fd) then
			log.warn("broadcast_binary not exists fd ",fd)
		else
			websocket.write(fd, msg, "binary")
		end
	end
end

function CMD.kick(_,fd)
	websocket.close(fd,CLOSE_CODE.normal,CLOSE_REASON[CLOSE_CODE.normal])
end

function CMD.pause(source, fd)
	if not g_conn_map[fd] then
		return false
	end
	local c = g_conn_map[fd]
	c.is_pause = true

	return true
end

function CMD.play(source, fd)
	if not g_conn_map[fd] then
		return false
	end
	local c = g_conn_map[fd]
	c.is_pause = nil

	local msg_que = c.msg_que
	if msg_que then
		local agent = c.agent
		for i = 1, #msg_que do
			if agent then
				skynet.redirect(agent, 0, "client", fd, msg_que[i])
			else
				skynet.send(g_watchdog, "lua", "socket", "data", fd, msg_que[i])
			end
		end

		c.msg_que = nil
	end

	return true
end

skynet.start(function()
	skynet.register_protocol {
		name = "client",
		id = skynet.PTYPE_CLIENT,
	}

	skynet_util.lua_src_dispatch(CMD)
end)

skynet_util.register_info_func("info", function()
	local count = 0
	for k,v in pairs(g_conn_map) do
		count = count + 1
	end
	log.info("ws_slave info ", g_conn_map, count)
end)
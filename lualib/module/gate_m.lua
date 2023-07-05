local skynet = require "skynet"
local timer = require "timer"
local log = require "log"

local type = type
local assert = assert

local gate = nil
local login = nil

local CMD = {}

function CMD.start(config)
	assert(config.address)
	assert(config.port)
	assert(config.login)                --登录检测的模块

	login = require (config.login)

	assert(type(login.unpack) == 'function')
	assert(type(login.dispatch) == 'function')
	assert(type(login.open) == 'function')
	assert(type(login.close) == 'function')
	assert(type(login.error) == 'function')
	assert(type(login.warning) == 'function')	
	assert(type(login.data) == 'function')
	assert(type(login.check_exit) == 'function')
	assert(type(login.init) == 'function')

	skynet.register_protocol {
		name = "client",
		id = skynet.PTYPE_CLIENT,
		unpack = login.unpack,
		dispatch = login.dispatch,
	}
	gate = skynet.uniqueservice('gatef')
	login.init(gate)
	if not skynet.call(gate,'lua','is_open') then
		skynet.call(gate,'lua','open',config)
		log.info("启动 gatef 监听:",config)
	else
		skynet.call(gate,'lua','forward_watchdog')
		log.info("切换看门狗 ")
	end
	
	return true
end

local SOCKET = {}

function SOCKET.open(fd,addr)
	login.open(gate,fd,addr)
end

function SOCKET.close(fd)
	login.close(gate,fd)
end

function SOCKET.error(fd,msg)
	login.error(gate,fd,msg)
end

function SOCKET.warning(fd,size)
	login.warning(gate,fd,size)
end

function SOCKET.data(fd,msg)
	login.data(gate,fd,msg)
end

function CMD.socket(cmd,...)
	local f = SOCKET[cmd]
	assert(f, "not socket cmd " .. cmd)
	f(...)
end

function CMD.exit()
	timer:new(timer.second * 60,0,function()
		if login.check_exit() then
			log.info("gate_m can exit")
			skynet.exit()
		else
			log.info("gate_m can`t exit")
		end
	end)
end

return CMD
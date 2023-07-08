local log = require "log"
local skynet = require "skynet"
local timer = require "timer"
local socket = require "socket"
local pbnet_util = require "pbnet_util"
local pb_util = require "pb_util"
local util = require "util"

local CMD = {}

local g_config

local function dispatch(fd,packname,res)
	log.info("dispatch:",fd,packname,res)
end

local function connnect(handle)
	local fd = socket.open('127.0.0.1',8001)
	if not fd then
		log.error("connect faild ")
		return
	end

	local login_req = {
		account = g_config.account,
		password = g_config.password,
		player_id = g_config.player_id,
	}

	pbnet_util.recv(fd,handle or dispatch)
	pbnet_util.send(fd,'.login.LoginReq',login_req)
	return fd
end

local function loginout(fd)
	local login_out_req = {
		player_id = g_config.player_id,
	}
	pbnet_util.send(fd,'.login.LoginOutReq',login_out_req)
end

--重复登录测试
local function repeat_connect_test()
	connnect()
	connnect()
end

--重复退出测试
local function repeat_loginout_test()
	local fd = connnect()
	skynet.sleep(100)
	loginout(fd)
	loginout(fd)
end

--重连测试
local function reconnecttest()
	local fd = connnect()
	skynet.sleep(100)
	socket.close()
	fd = connnect()
end

--热更后连接退出再登录
local function reload_switch_test(mod_name)
	local wi = coroutine.running()
	local login_res = nil
	local out_wi = nil
	local fd = connnect(function(_,packname,res)
		log.info("reload_switch_test dispatch1:",packname,res)
		if packname == '.login.LoginRes' then
			skynet.wakeup(wi)
			login_res = res
		elseif packname == '.login.LoginOutRes' then
			skynet.wakeup(out_wi)
		end
	end)
	skynet.wait(wi)

	skynet.call('.contriner_mgr','lua','load_module',mod_name)
	loginout(fd)
	out_wi = coroutine.running()
	skynet.wait(out_wi)
	local new_login_res = nil
	local wi = coroutine.running()
	local fd = connnect(function(_,packname,res)
		log.info("reload_switch_test dispatch2:",packname,res)
		if packname == '.login.LoginRes' then
			skynet.wakeup(wi)
			new_login_res = res
		end
	end)
	skynet.wait(wi)
	
	local def_t = util.check_def_table(login_res,new_login_res)
	log.info("reload_switch_test:",def_t,login_res,new_login_res)
	assert(next(def_t))
end

--热更后重连测试
local function reload_reconnet_test(mod_name)
	local wi = coroutine.running()
	local login_res = nil
	local fd = connnect(function(_,packname,res)
		log.info("reload_reconnet_test dispatch1:",packname,res)
		if packname == '.login.LoginRes' then
			skynet.wakeup(wi)
			login_res = res
		end
	end)
	skynet.wait(wi)

	skynet.call('.contriner_mgr','lua','load_module',mod_name)

	local close_wi = coroutine.running()
	socket.onclose(fd,function()
		skynet.wakeup(close_wi)
	end)
	socket.close(fd)
	skynet.wait(close_wi)

	local new_login_res = nil
	local wi = coroutine.running()
	local fd = connnect(function(_,packname,res)
		log.info("reload_reconnet_test dispatch2:",packname,res)
		if packname == '.login.LoginRes' then
			skynet.wakeup(wi)
			new_login_res = res
		end
	end)
	skynet.wait(wi)
	
	local def_t = util.check_def_table(login_res,new_login_res)
	log.info("reload_reconnet_test:",def_t,login_res,new_login_res)
	assert(not next(def_t))
end

function CMD.start(config)
	pb_util.load('./proto')
	g_config = config

	--repeat_connect_test()
	--repeat_loginout_test()

	--reconnecttest()

	--reload_switch_test('hall_m')
	--reload_switch_test('match_m')
	--reload_switch_test('room_m')

	--reload_reconnet_test('hall_m')
	--reload_reconnet_test('match_m')
	reload_reconnet_test('room_m')
	return true
end

function CMD.exit()

end

return CMD
local log = require "log"
local skynet = require "skynet"
local timer = require "timer"
local websocket = require "websocket"
local socket = require "socket"
local pb_netpack = require "pb_netpack"
local table_util = require "table_util"

local net_util = nil

local CMD = {}

local g_config

local function dispatch(fd,packname,res)
	log.info("dispatch:",g_config.net_util,fd,packname,res)
end

local function connnect(handle,player_id)
	local fd
	if g_config.protocol == 'websocket' then
		fd = websocket.connect("ws://127.0.0.1:8001")
	else
		fd = socket.open('127.0.0.1',8001)
	end
	if not fd then
		log.error("connect faild ")
		return
	end

	local login_req = {
		account = g_config.account,
		password = g_config.password,
		player_id = player_id or g_config.player_id,
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
	if g_config.protocol == 'websocket' then
		websocket.close(fd)
	else
		socket.close()
	end
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
	close()
	fd = connnect()
end

--热更后连接退出再登录
local function reload_switch_test(mod_name)
	local wi = coroutine.running()
	local login_res = nil
	local out_wi = nil
	local fd = connnect(function(_,packname,res)
		log.info("reload_switch_test dispatch1:",g_config.net_util,packname,res)
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
	
	local def_t = table_util.check_def_table(login_res,new_login_res)
	log.info("reload_switch_test:",def_t,login_res,new_login_res)
	assert(next(def_t))
end

--热更后重连测试
local function reload_reconnet_test(mod_name)
	local wi = coroutine.running()
	local login_res = nil
	local fd = connnect(function(_,packname,res)
		log.info("reload_reconnet_test dispatch1:",g_config.net_util,packname,res)
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
	close(fd)
	skynet.wait(close_wi)

	local new_login_res = nil
	local wi = coroutine.running()
	local fd = connnect(function(_,packname,res)
		log.info("reload_reconnet_test dispatch2:",g_config.net_util,packname,res)
		if packname == '.login.LoginRes' then
			skynet.wakeup(wi)
			new_login_res = res
		end
	end)
	skynet.wait(wi)
	
	local def_t = table_util.check_def_table(login_res,new_login_res)
	log.info("reload_reconnet_test:",def_t,login_res,new_login_res)
	assert(not next(def_t))
end

--玩游戏
local function player_game(login_res)
	login_res = login_res or {}
	local fd
	fd = connnect(function(_,packname,res)
		log.info("player_game:",fd,g_config.net_util,packname,res)

		if packname == '.game.NextDoingCast' then
			if res.doing_player_id ~= g_config.player_id then
				return
			end
			log.error("NextDoingCast sleep 1 ",coroutine.running())
			skynet.sleep(math.random(300,500))
			log.error("NextDoingCast sleep 2 ",coroutine.running())
			local min_num = res.min_num
			local max_num = res.max_num

			local opt_num = math.random(min_num,max_num)
			net_util.send(nil,fd,'.game.DoingReq',{
				opt_num = opt_num,
			})
		elseif packname == '.login.LoginRes' then
			log.error("发送状态请求")
			for k,v in pairs(res) do
				login_res[k] = v
			end
			net_util.send(nil,fd,'.game.GameStatusReq',{player_id = g_config.player_id})
		elseif packname == '.game.GameStatusRes' then
			local next_doing = res.next_doing
			if next_doing.doing_player_id ~= g_config.player_id then
				return
			end
			log.error("GameStatusRes sleep 1 ",coroutine.running())
			skynet.sleep(math.random(300,500))
			log.error("GameStatusRes sleep 2 ",coroutine.running())
			local min_num = next_doing.min_num
			local max_num = next_doing.max_num
			
			local opt_num = math.random(min_num,max_num)
			net_util.send(nil,fd,'.game.DoingReq',{
				opt_num = opt_num,
			})
		end
	end)

	return fd
end

--玩游戏过程中重连
local function player_game_reconnect()
	local fd = player_game()

	--玩个5秒断开
	skynet.sleep(500)
	--重新连接
	log.info("重新连接:",g_config)
	local fd = player_game()
end

--游戏开始-热更-重连-再重开游戏
local function player_reload_reconnect(mod_name)
	local begin_login_res = {}
	local reconnect_login_res = {}
	local restart_login_res = {}
	local fd = player_game(begin_login_res)

	--玩个3秒断开
	skynet.sleep(300)
	--热更
	log.info("热更:",mod_name)
	skynet.call('.contriner_mgr','lua','load_module',mod_name)
	--重新连接
	skynet.sleep(200)
	log.info("重新连接:",g_config)
	local fd = player_game(reconnect_login_res)

	--上一把断开后
	socket.onclose(fd,function()
		--重新开始
		log.info("重开游戏",g_config)
		skynet.sleep(100)
		local fd = player_game(restart_login_res)

		socket.onclose(fd,function()
			log.error("test over ",begin_login_res,reconnect_login_res,restart_login_res)
		end)
	end)
end

--websocket 连接测试
local function websocket_test()
	local fd_list = {}
	for i = 1,3000 do
		local fd = connnect(nil,i)
		if fd then
			table.insert(fd_list,fd)
		end
	end
	log.error("connect over")
	skynet.sleep(500)

	for _,fd in ipairs(fd_list) do
		websocket.close(fd)
	end
	log.error("disconnect over")
end

function CMD.start(config)
	pb_netpack.load('./proto')
	g_config = config

	net_util = require (config.net_util)
	
	skynet.fork(function()
		--repeat_connect_test()
		--repeat_loginout_test()

		--reconnecttest()

		--reload_switch_test('room_game_hall_m')
		--reload_switch_test('room_game_match_m')
		--reload_switch_test('room_game_room_m')

		--reload_reconnet_test('room_game_hall_m')
		--reload_reconnet_test('room_game_match_m')
		--reload_reconnet_test('room_game_room_m')
		--player_game()
		--player_game_reconnect()
		--player_reload_reconnect('room_game_hall_m')
		--player_reload_reconnect('room_game_match_m')
		--player_reload_reconnect('room_game_room_m')
		websocket_test()
	end)
	
	return true
end

function CMD.exit()

end

return CMD
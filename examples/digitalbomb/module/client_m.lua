local log = require "skynet-fly.log"
local skynet = require "skynet"
local timer = require "skynet-fly.timer"
local websocket = require "http.websocket"
local socket = require "skynet.socket"
local pb_netpack = require "skynet-fly.netpack.pb_netpack"
local sp_netpack = require "skynet-fly.netpack.sp_netpack"
local table_util = require "skynet-fly.utils.table_util"
local container_client = require "skynet-fly.client.container_client"
container_client:register("share_config_m")

local test_proto = skynet.getenv("test_proto")

local CMD = {}

local g_config
local net_util = nil

local function dispatch(fd,packname,res)
	log.info("dispatch:",g_config.protocol,fd,packname,res)
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

	local login_req = {
		account = g_config.account,
		password = g_config.password,
		player_id = g_config.player_id,
	}

	net_util.recv(fd,handle or dispatch)

	if test_proto == 'pb' then
		net_util.send(nil,fd,'.login.LoginReq',login_req)
	else
		net_util.send(nil,fd,'LoginReq',login_req)
	end

	return fd
end

local function loginout(fd)
	local login_out_req = {
		player_id = g_config.player_id,
	}
	if test_proto == 'pb' then
		net_util.send(nil,fd,'.login.LoginOutReq',login_out_req)
	else
		net_util.send(nil,fd,'LoginOutReq',login_out_req)
	end
end

local function close(fd)
	if g_config.protocol == 'websocket' then
		websocket.close(fd)
	else
		socket.close(fd)
	end
end

--掉线测试
local function disconnect_test()
	local fd = connnect()
	skynet.sleep(100)
	close(fd)
end

--重复登录测试
local function repeat_connect_test()
	connnect()
	connnect()
end

--重复登录测试(登录成功之后)
local function repeat_connect1_test()
	connnect()
	skynet.sleep(100)
	connnect()
end

--重复登录测试(断线重连)
local function repeat_connect2_test()
	local fd = connnect()
	skynet.sleep(100)
	close(fd)
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
	close(fd)
	fd = connnect()
end

--热更后连接退出再登录
local function reload_switch_test(mod_name)
	local wi = coroutine.running()
	local login_res = nil
	local out_wi = nil
	local fd
	fd = connnect(function(_,packname,res)
		log.info("reload_switch_test dispatch1:",g_config.protocol,packname,res)
		if packname == 'LoginRes' or packname  == '.login.LoginRes' then
			if test_proto == 'pb' then
				net_util.send(nil,fd,'.login.matchReq',{table_name = "room_3"})
			else
				net_util.send(nil,fd,'matchReq',{table_name = "room_3"})
			end
		elseif packname == 'serverInfoRes' or packname == '.login.serverInfoRes' then
			login_res = res
			skynet.wakeup(wi)
		elseif packname == 'matchRes' or packname == '.login.matchRes' then
			if test_proto == 'pb' then
				net_util.send(nil,fd,'.login.serverInfoReq',{player_id = g_config.player_id})
			else
				net_util.send(nil,fd,'serverInfoReq',{player_id = g_config.player_id})
			end
		elseif packname == 'LoginOutRes' or packname == '.login.LoginOutRes' then
			skynet.wakeup(out_wi)
		end
	end)
	skynet.wait(wi)

	skynet.call('.container_mgr','lua','load_modules', skynet.self(), mod_name)
	loginout(fd)
	out_wi = coroutine.running()
	skynet.wait(out_wi)
	local new_login_res = nil
	local wi = coroutine.running()
	fd = connnect(function(_,packname,res)
		log.info("reload_switch_test dispatch2:",packname,res)
		if packname == 'LoginRes' or packname == '.login.LoginRes' then
			if test_proto == 'pb' then 
				net_util.send(nil,fd,'.login.matchReq',{table_name = "room_3"})
			else
				net_util.send(nil,fd,'matchReq',{table_name = "room_3"})
			end
		elseif packname == 'serverInfoRes' or packname == '.login.serverInfoRes' then
			new_login_res = res
			skynet.wakeup(wi)
		elseif packname == 'matchRes' or packname == '.login.matchRes' then
			if test_proto == 'pb' then
				net_util.send(nil,fd,'.login.serverInfoReq',{player_id = g_config.player_id})
			else
				net_util.send(nil,fd,'serverInfoReq',{player_id = g_config.player_id})
			end
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
		log.info("reload_reconnet_test dispatch1:",g_config.protocol,packname,res)
		if packname == '.login.LoginRes' then
			skynet.wakeup(wi)
			login_res = res
		end
	end)
	skynet.wait(wi)

	skynet.call('.container_mgr','lua','load_modules', skynet.self(),mod_name)

	local close_wi = coroutine.running()

	socket.onclose(fd,function()
		skynet.wakeup(close_wi)
	end)
	close(fd)
	skynet.wait(close_wi)

	local new_login_res = nil
	local wi = coroutine.running()
	local _ = connnect(function(_,packname,res)
		log.info("reload_reconnet_test dispatch2:",g_config.protocol,packname,res)
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
		log.info("player_game:",fd,g_config.protocol,packname,res)

		if packname == 'NextDoingCast' or packname == '.game.NextDoingCast' then
			if res.doing_player_id ~= g_config.player_id then
				return
			end
			log.error("NextDoingCast sleep 1 ",coroutine.running())
			skynet.sleep(math.random(300,500))
			log.error("NextDoingCast sleep 2 ",coroutine.running())
			local min_num = res.min_num
			local max_num = res.max_num

			local opt_num = math.random(min_num,max_num)
			if test_proto == 'pb' then
				net_util.send(nil,fd,'.game.DoingReq',{
					opt_num = opt_num,
				})
			else
				net_util.send(nil,fd,'DoingReq',{
					opt_num = opt_num,
				})
			end
		
		elseif packname == 'LoginRes' or packname == '.login.LoginRes' then
			if test_proto == 'pb' then
				net_util.send(nil,fd,'.game.GameStatusReq',{player_id = g_config.player_id})
				net_util.send(nil,fd,'.login.matchReq',{table_name = "room_3"})
			else
				net_util.send(nil,fd,'GameStatusReq',{player_id = g_config.player_id})
				net_util.send(nil,fd,'matchReq',{table_name = "room_3"})
			end
		elseif packname == 'serverInfoRes' or packname == '.login.serverInfoRes' then
			for k,v in pairs(res) do
				login_res[k] = v
			end
		elseif packname == 'matchRes' or packname == '.login.matchRes' then
			log.error("发送状态请求")
			if test_proto == 'pb' then
				net_util.send(nil,fd,'.game.GameStatusReq',{player_id = g_config.player_id})
			else
				net_util.send(nil,fd,'GameStatusReq',{player_id = g_config.player_id})
			end
		elseif packname == 'GameStatusRes' or packname == '.game.GameStatusRes' then
			if test_proto == 'pb' then
				net_util.send(nil,fd,'.login.serverInfoReq',{player_id = g_config.player_id})
			else
				net_util.send(nil,fd,'serverInfoReq',{player_id = g_config.player_id})
			end
			
			local next_doing = res.next_doing
			if next_doing.doing_player_id ~= g_config.player_id then
				return
			end
			log.error("GameStatusRes sleep 1 ",coroutine.running())
			skynet.sleep(math.random(300,500))
			log.error("GameStatusRes sleep 2 ",coroutine.running())
			local min_num = next_doing.min_num
			local max_num = next_doing.max_num
			--pb
			local opt_num = math.random(min_num,max_num)

			if test_proto == 'pb' then
				net_util.send(nil,fd,'.game.DoingReq',{
					opt_num = opt_num,
				})
			else
				net_util.send(nil,fd,'DoingReq',{
					opt_num = opt_num,
				})
			end	
		elseif packname == 'GameOverCast' or packname == '.game.GameOverCast' then
			loginout(fd)
		end
	end)

	return fd
end

--玩游戏过程中重连
local function player_game_reconnect()
	player_game()

	--玩个5秒断开
	skynet.sleep(500)
	--重新连接
	log.info("重新连接:",g_config)
	player_game()
end

--游戏开始-热更-重连-再重开游戏
local function player_reload_reconnect(mod_name)
	local begin_login_res = {}
	local reconnect_login_res = {}
	local restart_login_res = {}
	player_game(begin_login_res)

	--玩个3秒断开
	skynet.sleep(300)
	--热更
	log.info("热更:",mod_name)
	skynet.call('.container_mgr','lua','load_modules', skynet.self(),mod_name)
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

function CMD.start(config)
	pb_netpack.load('./proto')
	sp_netpack.load('./sproto')
	g_config = config

	if g_config.protocol == 'websocket' then
		if test_proto == 'pb' then
			net_util = require "skynet-fly.utils.net.ws_pbnet_util" --pb
		else
			net_util = require "skynet-fly.utils.net.ws_spnet_util" --sb
		end
	else
		if test_proto == 'pb' then
			net_util = require "skynet-fly.utils.net.pbnet_util"
		else
			net_util = require "skynet-fly.utils.net.spnet_util"
		end
	end
	
	skynet.fork(function()
		--disconnect_test()
		--repeat_connect_test()
		--repeat_connect1_test()
		--repeat_connect2_test()
		--repeat_loginout_test()

		--reconnecttest()

		--reload_switch_test('room_game_hall_m')
		--reload_switch_test('room_game_alloc_m')
		--reload_switch_test('room_game_table_m')

		--reload_reconnet_test('room_game_hall_m')
		--reload_reconnet_test('room_game_alloc_m')
		--reload_reconnet_test('room_game_table_m')
		--player_game()
		--player_game_reconnect()
		player_reload_reconnect('room_game_hall_m')
		--player_reload_reconnect('room_game_alloc_m')
		--player_reload_reconnect('room_game_table_m')
	end)
	
	return true
end

function CMD.exit()
	return true
end

return CMD
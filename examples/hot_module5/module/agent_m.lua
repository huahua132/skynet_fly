local skynet = require "skynet"
local contriner_client = require "contriner_client"
local log = require "log"
local assert = assert

local CMD = {}
local g_seat_id = nil   --座位号
local g_player = nil

local client = nil

local SERVER_CMD = {}

function SERVER_CMD.enter(args)
	
end

function SERVER_CMD.leave(args)
	
end

function SERVER_CMD.game_start(args)
	
end

function SERVER_CMD.game_over(args)
	local ret = client:mod_call('client','leave',g_player)
	if ret then
		g_seat_id = nil 
		log.info("离开成功！！！",g_player.player_id)
	else
		log.info("离开失败！！！",g_player.player_id)
	end

	skynet.timeout(math.random(100,500),function()
		CMD.start(g_player)
	end)
end

function SERVER_CMD.doing_cast(args)
	if args.doing_player_id ~= g_player.player_id then
		return
	end
	local min_num = args.min_num
	local max_num = args.max_num

	skynet.timeout(math.random(100,300),function()
		local opt_num = math.random(min_num,max_num)
		client:mod_send('client','play',g_player,opt_num)
	end)
end

function SERVER_CMD.doing(args)

end

function CMD.server(server_id,cmd,args)
	local f = assert(SERVER_CMD[cmd],"not cmd " .. cmd)
	log.error("server_id =",server_id,cmd,args.content)
	return f(args)
end

function CMD.start(player)
	client = contriner_client:new("service_m",nil,function()
		return not g_seat_id  --没有坐下的情况下可以切换到新服务
	end)

	player.gate = skynet.self()
	g_player = player

	log.info("start ",player.player_id)
	local seat_id = client:mod_call('client','enter',player)
	if seat_id then
		log.info("enter succ ",player.player_id)
		g_seat_id = seat_id
	else
		log.info("enter faild ",player)
	end
	return true
end

function CMD.exit()

end

return CMD
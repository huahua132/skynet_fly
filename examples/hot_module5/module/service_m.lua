local skynet = require "skynet"
local seat_mgr = require "seat_mgr"
local log = require "log"
local GAME_STATE_ENUM = require "GAME_STATE"
local string = string
local assert = assert


--======================enum=================================
local MINE_MIN = 1
local MINE_MAX = 100
--======================enum=================================

--======================Data=================================

local GAME_STATE = GAME_STATE_ENUM.waiting
local g_game_seat_id_list = {}   	     --参与游戏的玩家座位号
local g_mine = 0                         --雷
local g_doing_seat_id = nil              --操作座位号
local g_doing_index = nil
local g_mine_min = nil
local g_mine_max = nil
--======================Data=================================

local function doing_cast()
	--通知操作
	local player = seat_mgr.get_player_info_by_seat_id(g_doing_seat_id)
	local args = {
		content = string.format("请玩家[%s] 操作 选择数字范围[%d,%d]",player.player_id,g_mine_min,g_mine_max),
		doing_player_id = player.player_id,
		min_num = g_mine_min,
		max_num = g_mine_max,
	}
	seat_mgr.broad_cast_msg("doing_cast",args)
end

--======================GAME_STATE===========================
local function game_start()
	GAME_STATE = GAME_STATE_ENUM.playing
	g_game_seat_id_list = seat_mgr.game_start()

	local msg = ""
	for _,seat_id in ipairs(g_game_seat_id_list) do
		local player = seat_mgr.get_player_info_by_seat_id(seat_id)
		msg = msg .. string.format("player_id[%s] nickname[%s]\n",player.player_id,player.nickname)
	end
	local args = {
		content = string.format("游戏开始 ！！！ 参与玩家有 %s",msg)
	}
	seat_mgr.broad_cast_msg("game_start",args)
	
	g_mine = math.random(MINE_MIN,MINE_MAX)         --随机雷
	g_mine_min = MINE_MIN
	g_mine_max = MINE_MAX
	g_doing_index = math.random(1,#g_game_seat_id_list)
	g_doing_seat_id = g_game_seat_id_list[g_doing_index]   --先手

	log.info("游戏开始！！！数字雷是",g_mine)
	doing_cast()
end

local function game_over(player)
	log.info("游戏结束！！！")
	local args = {
		content = string.format("游戏结束 玩家[%s]踩雷了 %s",player.nickname,g_mine)
	}
	seat_mgr.broad_cast_msg("game_over",args)
	GAME_STATE = GAME_STATE_ENUM.over
	seat_mgr.game_over()
end
--======================GAME_STATE===========================

--======================CLIENT_CMD===========================

--======================CLIENT_CMD===========================
local CMD = {}
local CLIENT_CMD = {}
local IS_CLOSE = false

--玩家进入房间
function CLIENT_CMD.enter(player)
	if IS_CLOSE then 
		log.info("服务已经关闭",player.player_id)
		return nil
	end
	local seat_id = seat_mgr.enter(player)
	if not seat_id then
		log.info("进入房间失败 ",player.player_id)
		return nil
	end
	local args = {
		content = string.format("进入房间 player_id = %s nickname=%s seat_id = %s",player.player_id,player.nickname,seat_id),
		enter_player = player
	}
	seat_mgr.broad_cast_msg("enter",args)
	log.info("进入房间成功 ",player.player_id)
	if seat_mgr.enter_len() >= 2 then
		skynet.fork(game_start)
	end

	return seat_id
end

--玩家离开房间
function CLIENT_CMD.leave(player)
	local seat_id = seat_mgr.leave(player)
	if not seat_id then
		log.info("离开房间失败 ",player.player_id)
		return nil
	end
	local args = {
		content = string.format("离开房间 player_id = %s nickname=%s",player.player_id,player.nickname),
		leave_player = player,
	}
	seat_mgr.broad_cast_msg("leave",args)
	log.info("离开房间成功 ",player.player_id)

	return seat_id
end

--玩家操作
function CLIENT_CMD.play(player,opt_num)
	if GAME_STATE ~= GAME_STATE_ENUM.playing then
		log.info("游戏还没有开始！！！")
	end

	local seat_id = seat_mgr.get_player_seat_id(player.player_id)
	if seat_id ~= g_doing_seat_id then
		log.info("不是该玩家操作 ",player.player_id)
		return nil
	end
	if opt_num < g_mine_min or opt_num > g_mine_max then
		log.info("play args err ",player.player_id,opt_num)
		return nil
	end

	local args = {
		content = string.format("玩家操作[%s] num[%s]",player.player_id,opt_num),
		doing_player_id = player.player_id,
		min_num = g_mine_min,
		max_num = g_mine_max,
	}
	seat_mgr.broad_cast_msg("doing",args)

	if opt_num == g_mine then  --踩雷 游戏结束
		return game_over(player)
	elseif opt_num > g_mine then
		g_mine_max = opt_num - 1
	else
		g_mine_min = opt_num + 1
	end

	--切换操作人
	g_doing_index = g_doing_index + 1
	if g_doing_index > #g_game_seat_id_list then
		g_doing_index = g_doing_index % #g_game_seat_id_list
	end
 	g_doing_seat_id = g_game_seat_id_list[g_doing_index]
	doing_cast()
	return true
end

--======================CLIENT_CMD===========================

--======================CMD==================================

function CMD.client(cmd,...)
	local f = assert(CLIENT_CMD[cmd])
	return f(...)
end

function CMD.start(config)
	assert(config)
	local player_num = config.player_num
	assert(player_num)
	seat_mgr.init(player_num)
	MINE_MIN = config.min_num
	MINE_MAX = config.max_num
	return true
end

function CMD.exit()
	IS_CLOSE = true
	while true do
		if seat_mgr.enter_len() <= 0 then
			log.info("桌子没有人了，可以退出 ",seat_mgr.enter_len())
			skynet.exit()
		end

		log.info("桌子还有人不能退出 ",seat_mgr.enter_len())
		skynet.sleep(500)
	end
end
--======================CMD==================================

return CMD
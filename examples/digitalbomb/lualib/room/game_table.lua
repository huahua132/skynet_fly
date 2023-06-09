local skynet = require "skynet"
local seater = require "seater"
local log = require "log"
local GAME_STATE_ENUM = require "GAME_STATE"
local seater = require "seater"
local errorcode = require "errorcode"

local string = string
local assert = assert
local ipairs = ipairs
local table = table
local math = math

--======================enum=================================
local MINE_MIN = 1
local MINE_MAX = 100
--======================enum=================================

return function(table_id,player_num,ROOM_CMD)
	local m_table_id = table_id
    local m_game_state = GAME_STATE_ENUM.waiting --参与游戏的玩家座位号
    local m_mine = 0                             --雷
    local m_doing_seat_id = nil                  --操作座位号
    local m_mine_min = nil
    local m_mine_max = nil
    local m_seat_list = {}
    local m_player_seat_map = {}
    local m_enter_num = 0
	local m_game_seat_id_list = {}
	local m_doing_index

	local function broadcast(packname,pack)
		for _,seat_player in ipairs(m_seat_list) do
			seat_player:send_msg(packname,pack)
		end
	end

    for i = 1,player_num do
        m_seat_list[i] = seater:new()
    end

	local function next_doing_cast()
		--通知操作
		local player = m_seat_list[m_doing_seat_id]:get_player()
		local args = {
			doing_seat_id = m_doing_seat_id,
			doing_player_id = player.player_info.player_id,
			min_num = m_mine_min,
			max_num = m_mine_max,
		}
		broadcast('.game.NextDoingCast',args)
	end

	local function game_start()
		m_game_state = GAME_STATE_ENUM.playing
		m_game_seat_id_list = {}

		for seat_id,seater in ipairs(m_seat_list) do
			if not seater:is_empty() then
				seater:game_start()
				table.insert(m_game_seat_id_list,seat_id)
			end
		end
	
		broadcast('.game.GameStartCast',{seat_id_list = m_game_seat_id_list})
		
		m_mine = math.random(MINE_MIN,MINE_MAX)         --随机雷
		m_mine_min = MINE_MIN
		m_mine_max = MINE_MAX
		m_doing_index = math.random(1,#m_game_seat_id_list)
		m_doing_seat_id = m_game_seat_id_list[m_doing_index]   --先手
	
		log.info("游戏开始！！！数字雷是",m_mine)
		next_doing_cast()
	end

	local function game_over(player)
		log.info("游戏结束！！！")
		local args = {
			lose_player_id = player.player_id,
			mine = m_mine,
		}

		broadcast('.game.GameOverCast',args)
		m_game_state = GAME_STATE_ENUM.over

		for seat_id,seater in ipairs(m_seat_list) do
			if not seater:is_empty() then
				seater:game_over()
			end
		end
		ROOM_CMD.game_over(m_table_id)
		return true
	end

    return {
        enter = function(player)
            local player_id = player.player_info.player_id
            assert(not m_player_seat_map[player_id])
            
            local alloc_seat_id = nil
            for seat_id,seater in ipairs(m_seat_list) do
                if seater:is_empty() then
                    seater:enter(player)
                    m_player_seat_map[player_id] = seat_id
                    m_enter_num = m_enter_num + 1
                    alloc_seat_id = seat_id
                    break
                end
            end

            if not alloc_seat_id then
                log.info("进入房间失败 ",player.player_info.player_id)
                return nil,errorcode.TABLE_ENTER_ERR,"enter err"
            end
          
			broadcast('.game.EnterCast',{
				player_id = player_id,
				seat_id = alloc_seat_id,
				nickname = player.player_info.nickname,
			})
            if m_enter_num >= 2 then
                skynet.fork(game_start)
            end
        
            return alloc_seat_id
        end,

		leave = function(player)
			local player_id = player.player_info.player_id
			local seat_id = m_player_seat_map[player_id]
			if not seat_id then
				log.error("not in table ",player_id)
				return
			end

			local seater = m_seat_list[seat_id]
			if not seater:is_can_leave() then
				return false
			else
				seater:leave()
				m_enter_num = m_enter_num - 1
				m_player_seat_map[player_id] = nil
			end

			broadcast('.game.LeaveCast',{
				player_id = player_id,
				seat_id = seat_id,
				nickname = player.player_info.nickname,
			})
			log.info("离开房间成功 ",player_id)

			return seat_id
		end,

		play = function(player,args)
			if m_game_state ~= GAME_STATE_ENUM.playing then
				log.info("游戏还没有开始！！！")
				return
			end
			
			local player_id = player.player_info.player_id
			local seat_id = m_player_seat_map[player_id]
			if seat_id ~= m_doing_seat_id then
				log.info("不是该玩家操作 ",player_id)
				return nil
			end

			local opt_num = args.opt_num
			if not opt_num then
				log.info("not opt_num ",args)
				return
			end

			if opt_num < m_mine_min or opt_num > m_mine_max then
				log.info("play args err ",player_id,opt_num)
				return nil
			end
		
			local args = {
				player_id = player_id,
				seat_id = seat_id,
				opt_num = opt_num,
			}
			broadcast('.game.DoingCast',args)
		
			if opt_num == m_mine then  --踩雷 游戏结束
				return game_over(player)
			elseif opt_num > m_mine then
				m_mine_max = opt_num - 1
			else
				m_mine_min = opt_num + 1
			end
		
			--切换操作人
			m_doing_index = m_doing_index + 1
			if m_doing_index > #m_game_seat_id_list then
				m_doing_index = m_doing_index % #m_game_seat_id_list
			end
			m_doing_seat_id = m_game_seat_id_list[m_doing_index]
			next_doing_cast()
			return true
		end,

		game_status_req = function(player,args)
			local player_id = player.player_info.player_id
			local seat_id = m_player_seat_map[player_id]
			if not seat_id then
				log.error("not in table ",player_id)
				return
			end

			local seater = m_seat_list[seat_id]
			local doing_seat_player = nil
			local doing_player_id = 0
			local doing_seat_id = 0
			if m_seat_list[m_doing_seat_id] then
				doing_seat_player = m_seat_list[m_doing_seat_id]:get_player()
				doing_player_id = doing_seat_player.player_info.player_id
				doing_seat_id = m_doing_seat_id
			end
			
			seater:send_msg('.game.GameStatusRes',{
				game_state = m_game_state,
				next_doing = {
					doing_player_id = doing_player_id,
					doing_seat_id = doing_seat_id,
					min_num = m_mine_min,
					max_num = m_mine_max,
				}
			})
			return true
		end
    }
end
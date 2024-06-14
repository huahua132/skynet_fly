local skynet = require "skynet"
local pb_netpack = require "skynet-fly.netpack.pb_netpack"
local module_cfg = require "skynet-fly.etc.module_info".get_cfg()
local log = require "skynet-fly.log"
local GAME_STATE_ENUM = require "enum.GAME_STATE"
local seater = require "table.seater"
local errorcode = require "enum.errorcode"
local errors_msg = require "msg.errors_msg"
local game_msg = require "msg.game_msg"

local pbnet_util = require "skynet-fly.utils.net.pbnet_util"
local ws_pbnet_util = require "skynet-fly.utils.net.ws_pbnet_util"

local string = string
local assert = assert
local ipairs = ipairs
local table = table
local math = math

local g_table_conf = module_cfg.table_conf
local g_interface_mgr = nil

--======================enum=================================
local MINE_MIN = 1
local MINE_MAX = 100
--======================enum=================================

local M = {}

--发包函数
M.send = pbnet_util.send
--广播函数
M.broadcast = pbnet_util.broadcast

--发包函数
M.ws_send = ws_pbnet_util.send
--广播函数
M.ws_broadcast = ws_pbnet_util.broadcast

function M.init(interface_mgr)
	g_interface_mgr = interface_mgr
	assert(g_table_conf.player_num,"not player_num")
	pb_netpack.load('./proto')
end

function M.table_creator(table_id)
	local m_HANDLE = {}
	local m_interface_mgr = g_interface_mgr:new(table_id)
	local m_errors_msg = errors_msg:new(m_interface_mgr)
	local m_game_msg = game_msg:new(m_interface_mgr)
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

    for i = 1,g_table_conf.player_num do
        m_seat_list[i] = seater:new()
    end

	local function next_doing_cast()
		--通知操作
		local player = m_seat_list[m_doing_seat_id]:get_player()
		local args = {
			doing_seat_id = m_doing_seat_id,
			doing_player_id = player.player_id,
			min_num = m_mine_min,
			max_num = m_mine_max,
		}

		m_game_msg:broad_next_doing_cast(args)
	end


-----------------------------------------------------------------------
--state
-----------------------------------------------------------------------
	local function game_start()
		m_interface_mgr:call_alloc("update_state",GAME_STATE_ENUM.playing)
		m_game_state = GAME_STATE_ENUM.playing
		m_game_seat_id_list = {}

		for seat_id,seater in ipairs(m_seat_list) do
			if not seater:is_empty() then
				seater:game_start()
				table.insert(m_game_seat_id_list,seat_id)
			end
		end
	
		m_game_msg:broad_game_start({seat_id_list = m_game_seat_id_list})
		
		m_mine = math.random(MINE_MIN,MINE_MAX)         --随机雷
		m_mine_min = MINE_MIN
		m_mine_max = MINE_MAX
		m_doing_index = math.random(1,#m_game_seat_id_list)
		m_doing_seat_id = m_game_seat_id_list[m_doing_index]   --先手
	
		log.info("游戏开始！！！数字雷是",m_mine)
		next_doing_cast()
	end

	local function game_over(player_id)
		log.info("游戏结束！！！")
		m_interface_mgr:call_alloc("update_state",GAME_STATE_ENUM.over)
		m_game_state = GAME_STATE_ENUM.over
		local args = {
			lose_player_id = player_id,
			mine = m_mine,
		}

		m_game_msg:broad_game_over(args)


		for seat_id,seater in ipairs(m_seat_list) do
			if not seater:is_empty() then
				seater:game_over()
			end
		end
		m_interface_mgr:kick_out_all()
		return true
	end
-----------------------------------------------------------------------
--state
-----------------------------------------------------------------------
    return {
        enter = function(player_id)
            assert(not m_player_seat_map[player_id])
            
            local alloc_seat_id = nil
            for seat_id,seater in ipairs(m_seat_list) do
                if seater:is_empty() then
                    seater:enter(player_id)
                    m_player_seat_map[player_id] = seat_id
                    m_enter_num = m_enter_num + 1
                    alloc_seat_id = seat_id
                    break
                end
            end

            if not alloc_seat_id then
                log.info("进入房间失败 ",player_id)
                return nil,errorcode.TABLE_ENTER_ERR,"enter err"
            end
			
			m_game_msg:broad_enter_cast({
				player_id = player_id,
				seat_id = alloc_seat_id,
			})
		
            if m_enter_num >= 2 then
                skynet.fork(game_start)
            end
        
            return alloc_seat_id
        end,

		leave = function(player_id)
			local seat_id = m_player_seat_map[player_id]
			if not seat_id then
				log.error("not in table ",player_id)
				return
			end

			local seater = m_seat_list[seat_id]
			if not seater:is_can_leave() then
				return false,errorcode.playing,"playing..."
			else
				seater:leave()
				m_enter_num = m_enter_num - 1
				m_player_seat_map[player_id] = nil
			end

			m_game_msg:broad_leave_cast({
				player_id = player_id,
				seat_id = seat_id,
			})
			log.info("离开房间成功 ",player_id)
			return seat_id
		end,

		disconnect = function(player_id)
			log.error("disconnect:",player_id)
		end,

		reconnect = function(player_id)
			log.error("reconnect:",player_id)
		end,

		handle = {
			['.game.DoingReq'] = function(player_id,packname,pack_body)
				if m_game_state ~= GAME_STATE_ENUM.playing then
					log.info("游戏还没有开始！！！")
					return
				end
	
				local seat_id = m_player_seat_map[player_id]
				if seat_id ~= m_doing_seat_id then
					log.info("不是该玩家操作 ",player_id)
					return nil
				end
	
				local opt_num = pack_body.opt_num
				if not opt_num then
					log.info("not opt_num ",pack_body)
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
				
				m_game_msg:broad_doing_cast(args)
	
				if opt_num == m_mine then  --踩雷 游戏结束
					return game_over(player_id)
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

			['.game.GameStatusReq'] = function(player_id,packname,pack_body)
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
					doing_player_id = doing_seat_player.player_id
					doing_seat_id = m_doing_seat_id
				end
				log.error("send_msg GameStatusRes",player_id)
				m_game_msg:game_status_res(player_id,{
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
		},

		handle_end = function(player_id, packname, pack_body, ret, errcode, errmsg)
			log.info("handle_end >>> ", player_id, packname, ret, errcode, errmsg)
			if not ret then
				m_errors_msg:errors(player_id, errcode, errmsg, packname)
			end
		end,
		------------------------------------服务退出回调-------------------------------------
		herald_exit = function()
			log.error("预告退出")
		end,

		exit = function()
			log.error("退出")
			return true
		end,
		
		fix_exit = function()
			log.error("确认要退出")
			m_interface_mgr:call_alloc("update_state", GAME_STATE_ENUM.stop)
		end,

		cancel_exit = function()
			log.error("取消退出")
		end,

		check_exit = function()
			log.error("检查退出")
			return true
		end,
    }
end

return M
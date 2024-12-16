local log = require "skynet-fly.log"
local GAME_STATE_ENUM = require "enum.GAME_STATE"
local seater = require "table.seater"
local errorcode = require "enum.errorcode"
local game_msg = require "msg.game_msg"
local skynet = require "skynet"

local setmetatable = setmetatable
local string = string
local assert = assert
local ipairs = ipairs
local table = table
local math = math

local M = {}
local mt = {__index = M}

function M:new(interface_mgr, table_conf, table_id)
    local m_interface_mgr = interface_mgr
    local t = {
        m_interface_mgr = m_interface_mgr,
        m_game_msg = game_msg:new(m_interface_mgr),
        m_table_id = table_id,
        m_table_conf = table_conf,
        m_game_state = GAME_STATE_ENUM.waiting, --参与游戏的玩家座位号
        m_mine = 0,                             --雷
        m_doing_seat_id = nil,                  --操作座位号
        m_mine_min = nil,
        m_mine_max = nil,
        m_seat_list = {},
        m_player_seat_map = {},
        m_enter_num = 0,
        m_game_seat_id_list = {},
        m_doing_index = nil,
    }

    for i = 1,table_conf.player_num do
        t.m_seat_list[i] = seater:new()
    end

    setmetatable(t, mt)
    return t
end

--通知操作
function M:next_doing_cast()
    --通知操作
    local player = self.m_seat_list[self.m_doing_seat_id]:get_player()
    local args = {
        doing_seat_id = self.m_doing_seat_id,
        doing_player_id = player.player_id,
        min_num = self.m_mine_min,
        max_num = self.m_mine_max,
    }

    self.m_game_msg:broad_next_doing_cast(args)
end

-----------------------------------------------------------------------
--state
-----------------------------------------------------------------------
function M:game_start()
    self.m_interface_mgr:call_alloc("update_state", GAME_STATE_ENUM.playing)
    self.m_game_state = GAME_STATE_ENUM.playing
    self.m_game_seat_id_list = {}

    for seat_id,seater in ipairs(self.m_seat_list) do
        if not seater:is_empty() then
            seater:game_start()
            table.insert(self.m_game_seat_id_list,seat_id)
        end
    end

    self.m_game_msg:broad_game_start({seat_id_list = self.m_game_seat_id_list})
    
    local m_table_conf = self.m_table_conf
    self.m_mine = math.random(m_table_conf.mine_min, m_table_conf.mine_max)         --随机雷
    self.m_mine_min = m_table_conf.mine_min
    self.m_mine_max = m_table_conf.mine_max
    self.m_doing_index = math.random(1, #self.m_game_seat_id_list)
    self.m_doing_seat_id = self.m_game_seat_id_list[self.m_doing_index]   --先手

    log.info("游戏开始！！！数字雷是",self.m_mine)
    self:next_doing_cast()
end

function M:game_over(player_id)
    log.info("游戏结束！！！")
    self.m_interface_mgr:call_alloc("update_state", GAME_STATE_ENUM.over)
    self.m_game_state = GAME_STATE_ENUM.over
    local args = {
        lose_player_id = player_id,
        mine = self.m_mine,
    }

    self.m_game_msg:broad_game_over(args)


    for seat_id,seater in ipairs(self.m_seat_list) do
        if not seater:is_empty() then
            seater:game_over()
        end
    end
    self.m_interface_mgr:kick_out_all()
    return true
end
-----------------------------------------------------------------------
--state
-----------------------------------------------------------------------

-----------------------------------------------------------------------
--client
-----------------------------------------------------------------------
function M:enter(player_id)
    assert(not self.m_player_seat_map[player_id])
            
    local alloc_seat_id = nil
    for seat_id,seater in ipairs(self.m_seat_list) do
        if seater:is_empty() then
            seater:enter(player_id)
            self.m_player_seat_map[player_id] = seat_id
            self.m_enter_num = self.m_enter_num + 1
            alloc_seat_id = seat_id
            break
        end
    end

    if not alloc_seat_id then
        log.info("进入房间失败 ",player_id)
        return nil,errorcode.TABLE_ENTER_ERR,"enter err"
    end
    
    self.m_game_msg:broad_enter_cast({
        player_id = player_id,
        seat_id = alloc_seat_id,
    })

    if self.m_enter_num >= 2 then
        skynet.fork(function()
            self:game_start()
        end)
    end

    return alloc_seat_id
end

function M:leave(player_id)
    local seat_id = self.m_player_seat_map[player_id]
    if not seat_id then
        log.error("not in table ",player_id)
        return
    end

    local seater = self.m_seat_list[seat_id]
    if not seater:is_can_leave() then
        return false,errorcode.playing,"playing..."
    else
        seater:leave()
        self.m_enter_num = self.m_enter_num - 1
        self.m_player_seat_map[player_id] = nil
    end

    self.m_game_msg:broad_leave_cast({
        player_id = player_id,
        seat_id = seat_id,
    })
    log.info("离开房间成功 ",player_id)
    return seat_id
end

function M:disconnect(player_id)
    log.error("disconnect:",player_id)
end

function M:reconnect(player_id)
    log.error("reconnect:",player_id)
end
-----------------------------------------------------------------------
--client
-----------------------------------------------------------------------

-----------------------------------------------------------------------
--client req
-----------------------------------------------------------------------
function M:doing_req(player_id, packname, pack_body)
    if self.m_game_state ~= GAME_STATE_ENUM.playing then
        log.info("游戏还没有开始！！！")
        return
    end

    local seat_id = self.m_player_seat_map[player_id]
    if seat_id ~= self.m_doing_seat_id then
        log.info("不是该玩家操作 ",player_id)
        return nil
    end

    local opt_num = pack_body.opt_num
    if not opt_num then
        log.info("not opt_num ",pack_body)
        return
    end

    if opt_num < self.m_mine_min or opt_num > self.m_mine_max then
        log.info("play args err ",player_id,opt_num)
        return nil
    end

    local args = {
        player_id = player_id,
        seat_id = seat_id,
        opt_num = opt_num,
    }
    
    self.m_game_msg:broad_doing_cast(args)

    if opt_num == self.m_mine then  --踩雷 游戏结束
        return self:game_over(player_id)
    elseif opt_num > self.m_mine then
        self.m_mine_max = opt_num - 1
    else
        self.m_mine_min = opt_num + 1
    end

    --切换操作人
    self.m_doing_index = self.m_doing_index + 1
    if self.m_doing_index > #self.m_game_seat_id_list then
        self.m_doing_index = self.m_doing_index % #self.m_game_seat_id_list
    end
    self.m_doing_seat_id = self.m_game_seat_id_list[self.m_doing_index]
    self:next_doing_cast()
    return true
end

function M:game_status_req(player_id, packname, pack_body)
    local seat_id = self.m_player_seat_map[player_id]
    if not seat_id then
        log.error("not in table ",player_id)
        return
    end

    local doing_seat_player = nil
    local doing_player_id = 0
    local doing_seat_id = 0
    if self.m_seat_list[self.m_doing_seat_id] then
        doing_seat_player = self.m_seat_list[self.m_doing_seat_id]:get_player()
        doing_player_id = doing_seat_player.player_id
        doing_seat_id = self.m_doing_seat_id
    end
    log.error("send_msg GameStatusRes",player_id)
    return {
        game_state = self.m_game_state,
        next_doing = {
            doing_player_id = doing_player_id,
            doing_seat_id = doing_seat_id,
            min_num = self.m_mine_min,
            max_num = self.m_mine_max,
        }
    }
end
-----------------------------------------------------------------------
--client req
-----------------------------------------------------------------------

-----------------------------------------------------------------------
--sys
-----------------------------------------------------------------------
function M:herald_exit()
    log.error("预告退出", self.m_table_id)
end

function M:exit()
	log.error("退出", self.m_table_id)
	return true
end

function M:fix_exit()
    log.fatal("确认要退出", self.m_table_id, GAME_STATE_ENUM.stop)
    self.m_interface_mgr:call_alloc("update_state", GAME_STATE_ENUM.stop)
end

function M:cancel_exit()
    log.error("取消退出", self.m_table_id)
end

function M:check_exit()
    log.error("检查退出", self.m_table_id)
end
-----------------------------------------------------------------------
--sys
-----------------------------------------------------------------------

return M
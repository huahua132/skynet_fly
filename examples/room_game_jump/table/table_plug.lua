local ws_pbnet_util = require "skynet-fly.utils.net.ws_pbnet_util"
local log = require "skynet-fly.log"
local timer = require "skynet-fly.timer"

local M = {}

function M.init(interface_mgr)

end

M.ws_send = ws_pbnet_util.send
M.ws_broadcast = ws_pbnet_util.broadcast

--游戏桌子创建者
function M.table_creator(table_id)
	local m_player_map = {}

    return {
		--玩家进入桌子
        enter = function(player_id)
			log.info("enter ", player_id)
			m_player_map[player_id] = {
				is_canleave = false
			}

			timer:new(timer.second * 5, 1, function()
				m_player_map[player_id].is_canleave = true 
			end)
            return true
        end,
		--玩家离开桌子
		leave = function(player_id)
			log.info("leave ", player_id)
			if not m_player_map[player_id] then
				return nil, -1, "not in table"
			end
			if not m_player_map[player_id].is_canleave then
				return nil, -1, "can`t leave"
			end
			m_player_map[player_id] = nil
			return true
		end,
		--玩家掉线
		disconnect = function(player_id)
			log.info("disconnect ", player_id)
		end,
		--玩家重连
		reconnect = function(player_id)
			log.info("reconnect ", player_id)
		end,
		--消息分发处理
		handle = {}
    }
end

return M
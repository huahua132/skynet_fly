local skynet = require "skynet"
local pb_netpack = require "skynet-fly.netpack.pb_netpack"
local module_cfg = require "skynet-fly.etc.module_info".get_cfg()
local table_logic = require "table.table_logic"
local errors_msg = require "msg.errors_msg"
local log = require "skynet-fly.log"
local msg_id = require "enum.msg_id"
local pack_helper = require "common.pack_helper"

local assert = assert

local g_table_conf = module_cfg.table_conf
local g_interface_mgr = nil

--======================enum=================================
local MINE_MIN = 1
local MINE_MAX = 100
--======================enum=================================

local M = {}

M.send = require(module_cfg.net_util).send
--广播函数
M.broadcast = require(module_cfg.net_util).broadcast

function M.init(interface_mgr)
	g_interface_mgr = interface_mgr
    g_table_conf.mine_min = MINE_MIN
    g_table_conf.mine_max = MINE_MAX
	assert(g_table_conf.player_num,"not player_num")
	pb_netpack.load('./proto')
	pack_helper.set_packname_id()
end

function M.table_creator(table_id, table_name, ...)
	local args = {...}
	local create_player_id = args[1]
    local m_interface_mgr = g_interface_mgr:new(table_id)
	local m_errors_msg = errors_msg:new(m_interface_mgr)
    local m_logic = table_logic:new(m_interface_mgr, g_table_conf, table_id)

	log.info("table_creator >>> ",table_id, table_name, create_player_id)

    return {
        enter = function(player_id)
            return m_logic:enter(player_id)
        end,

		leave = function(player_id)
			return m_logic:leave(player_id)
		end,

		disconnect = function(player_id)
			return m_logic:disconnect(player_id)
		end,

		reconnect = function(player_id)
			return m_logic:reconnect(player_id)
		end,
        
		handle = {
			[msg_id.game_DoingReq] = function(player_id,packname,pack_body)
                m_logic:doing_req(player_id,packname,pack_body)
			end,

			[msg_id.game_GameStatusReq] = function(player_id,packname,pack_body)
				m_logic:game_status_req(player_id,packname,pack_body)
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
			return m_logic:herald_exit()
		end,

		exit = function()
			return m_logic:exit()
		end,
		
		fix_exit = function()
			return m_logic:fix_exit()
		end,

		cancel_exit = function()
			return m_logic:cancel_exit()
		end,

		check_exit = function()
			return m_logic:check_exit()
		end,
    }
end

return M
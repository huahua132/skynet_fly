local log = require "skynet-fly.log"
local errorcode = require "enum.errorcode"
local GAME_STATE = require "enum.GAME_STATE"
local skynet = require "skynet"
local timer = require "skynet-fly.timer"

local pairs = pairs
local table = table
local ipairs = ipairs
local assert = assert
local next = next

local g_table_map = {}
local g_cant_enter_map = {}

local M = {}

local CMD = {}

function CMD.update_state(table_id,state)
	log.info("update_state:",table_id)

	local t_info = g_table_map[table_id]
	if not t_info then
		log.warn("update state not exists table_id = ",table_id)
		return
	end

	log.fatal("update_state:", table_id, state)
	if t_info.state == GAME_STATE.stop then
		return
	end
	t_info.state = state
end

M.register_cmd = CMD

function M.init(alloc_mgr) --初始化
	--初始化的时候不能访问其他服务，用fock让它启动完成再去
	skynet.fork(function()
		log.info("创建桌子》》》》》》》》",alloc_mgr.create_table("room_3", 10001000))
	end)

	-- 监听有没有空桌子
	timer:new(timer.minute,0,function()
		local empty_map = alloc_mgr.get_empty_map()
		for table_id,empty_time in pairs(empty_map) do
			local t_info = g_table_map[table_id]
			if not t_info then
				log.error("桌子不存在", table_id)
			else
				if t_info.state == GAME_STATE.stop then
					log.error("销毁已经停止的空桌子》》》》》》》", table_id, t_info.state, alloc_mgr.dismisstable(table_id),empty_time)
				else
					log.error("桌子还不能销毁>>>>>>>>>>>>>>>>>", table_id, t_info.state)
				end
			end
		end
	end)
end

local function check_can_join(t_info,player_id)
	local max_player_num = t_info.config.table_conf.player_num
	if t_info.state ~= GAME_STATE.waiting then
		return false
	end

	if #t_info.player_list + 1 > max_player_num then
		return false
	end

	return true
end

function M.match(player_id) --匹配
	local table_num_map = {}

	local max_player_num = 0
	for table_id,t_info in pairs(g_table_map) do
		local player_num = #t_info.player_list
		if not table_num_map[player_num] then
			table_num_map[player_num] = {}
		end
		if not g_cant_enter_map[table_id] then
			table.insert(table_num_map[player_num],t_info)
		end

		if t_info.config.table_conf.player_num > max_player_num then
			max_player_num = t_info.config.table_conf.player_num
		end
	end

	--log.info("matching_table",g_table_map,table_num_map)

	for i = max_player_num - 1,0,-1 do
		local t_list = table_num_map[i]
		if t_list then
			for _,t_info in ipairs(t_list) do
				if check_can_join(t_info,player_id) then
					return t_info.table_id
				end
			end
		end
	end

	return nil
end

function M.createtable(table_name, table_id, config, create_player_id) --创建桌子
	log.info("createtable:",table_id)
	assert(not g_table_map[table_id],"repeat table_id")
	g_table_map[table_id] = {
		table_id = table_id,
		table_name = table_name,
		config = config,
		state = GAME_STATE.waiting,
		player_list = {}
	}
end

function M.entertable(table_id,player_id)  --进入桌子
	log.info("entertable:",table_id,player_id)
	assert(g_table_map[table_id],"table not exists")

	local t_info = g_table_map[table_id]
	local player_list = t_info.player_list

	for i = 1,#player_list do
		local pid = player_list[i]
		if pid == player_id then
			log.error("entertable player exists ",table_id,player_id)
			return
		end
	end

	table.insert(t_info.player_list,player_id)
	if #t_info.player_list == t_info.config.table_conf.player_num then
		g_cant_enter_map[table_id] = true
	end
end

function M.leavetable(table_id,player_id)  --离开桌子
	log.info("leavetable:",table_id,player_id)
	assert(g_table_map[table_id],"table not exists")

	local t_info = g_table_map[table_id]
	local player_list = t_info.player_list

	for i = #player_list,1,-1 do
		local pid = player_list[i]
		if pid == player_id then
			table.remove(player_list,i)
			return
		end
	end

	log.error("leavetable player not exists ",table_id,player_id) 
end

function M.dismisstable(table_id) --解散桌子
	log.info("dismisstable:",table_id)
	assert(g_table_map[table_id],"table not exists")

	local t_info = g_table_map[table_id]
	local player_list = t_info.player_list

	assert(not next(player_list),"dismisstable exists player " .. #player_list)

	g_cant_enter_map[table_id] = nil
	g_table_map[table_id] = nil
end

function M.tablefull()
	return nil,errorcode.TABLE_FULL,"table full"
end

function M.table_not_exists()
	return nil,errorcode.TABLE_NOT_EXISTS,"not table"
end

------------------------------------服务退出回调-------------------------------------
function M.herald_exit()
    log.error("预告退出")
end

function M.exit()
    log.error("退出")
    return true
end

function M.fix_exit()
    log.error("确认要退出")
end

function M.cancel_exit()
    log.error("取消退出")
end

function M.check_exit()
    log.error("检查退出")
    return true
end


return M
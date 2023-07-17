local log = require "log"
local errorcode = require "errorcode"

local pairs = pairs
local table = table
local ipairs = ipairs
local assert = assert
local next = next

local g_table_map = {}
local MAX_PLAYER_NUM = 2

local M = {}

function M.init() --初始化

end

function M.match(player_id) --匹配
	local table_num_map = {}

	for table_id,t_info in pairs(g_table_map) do
		local player_num = #t_info.player_list
		if not table_num_map[player_num] then
			table_num_map[player_num] = {}
		end
		table.insert(table_num_map[player_num],t_info)
	end

	--log.info("matching_table",g_table_map,table_num_map)

	for i = MAX_PLAYER_NUM - 1,0,-1 do
		local t_list = table_num_map[i]
		if t_list then
			for _,t_info in ipairs(t_list) do
				return t_info.table_id
			end
		end
	end

	return nil
end

function M.createtable(table_id) --创建桌子
	log.info("createtable:",table_id)
	assert(not g_table_map[table_id],"repeat table_id")
	g_table_map[table_id] = {
		table_id = table_id,
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

	g_table_map[table_id] = nil
end

function M.tablefull()
	return nil,errorcode.TABLE_FULL,"not table"
end

return M
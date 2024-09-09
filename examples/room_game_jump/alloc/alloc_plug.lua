local log = require "skynet-fly.log"
local errorcode = require "enum.errorcode"

local M = {}

function M.init(alloc_mgr) --初始化
end

function M.match(player_id) --匹配
	return nil
end

function M.createtable(table_name, table_id) --创建桌子
	log.info("createtable:",table_name, table_id)
end

function M.entertable(table_id,player_id)  --进入桌子
	log.info("entertable:",table_id,player_id)
end

function M.leavetable(table_id,player_id)  --离开桌子
	log.info("leavetable:",table_id,player_id)
end

function M.dismisstable(table_id) --解散桌子
	log.info("dismisstable:",table_id)
end

function M.tablefull()
	return nil,errorcode.TABLE_FULL,"table full"
end

function M.table_not_exists()
	return nil,errorcode.TABLE_NOT_EXISTS,"not table"
end

return M
---#API
---#content ---
---#content title: orm uselog适配器
---#content date: 2025-03-28 21:00:00
---#content categories: ["skynet_fly API 文档","数据库相关"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [ormadapter_uselog](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/db/ormadapter/ormadapter_uselog.lua)

local use_log = require "skynet-fly.use_log"
local log = require "skynet-fly.log"
local json = require "cjson.safe"
local watch_server = require "skynet-fly.rpc.watch_server"
local skynet = require "skynet"

local setmetatable = setmetatable
local assert = assert
local pairs = pairs
local error = error
local tinsert = table.insert
local tremove = table.remove
local pcall = pcall
local ipairs = ipairs
local math = math

local M = {}
local mata = {__index = M}

---#desc 新建适配器对象
---@param file_path string 日志存放路径
---@param file_name string 文件名
---@param flush_inval number? flush间隔时间
---@param max_age number? 最大保留天数
---@return table obj
function M:new(file_path, file_name, flush_inval, maxage)
    local t = {
        _db = use_log:new(file_path, file_name, flush_inval, maxage),
        _tab_name = nil,
        _field_list = nil,
        _field_map = nil,
        _key_list = nil,
    }

    setmetatable(t, mata)

    return t
end

---#desc 设置发布同步信息
function M:set_sub_syn(channel_name)
    self._channel_name = channel_name
    return self
end

function M:builder(tab_name, field_list, field_map, key_list, indexs_list)
    self._tab_name = tab_name
    self._field_map = field_map
    self._key_list = key_list
    self._field_list = field_list
    self._indexs_list = indexs_list

    if self._channel_name then
        --发布信息同步
        skynet.fork(function()
            watch_server.pubsyn(self._channel_name, {
                [tab_name] = {
                    field_map = field_map,
                    key_list = key_list,
                    field_list = field_list,
                    indexs_list = indexs_list,
                }
            })
        end)
    end

    --insert_one 创建一条数据
    self._insert_one = function(entry_data)
        local strData, err = json.encode(entry_data)
        if not strData then
            log.error("_insert_one err ", err, entry_data)
            return
        end

        self._db:write_log(strData)
        return true
    end

    return self
end

-- 批量创建表数据
function M:create_entry(entry_data_list)
    error("cant` use")
end

-- 创建一条数据
function M:create_one_entry(entry_data)
    return self._insert_one(entry_data)
end

-- 查询表数据
function M:get_entry(key_values)
    error("cant` use")
end

-- 查询一条表数据
function M:get_one_entry(key_values)
    error("cant` use")
end

-- 保存表数据
function M:save_entry(entry_data_list, change_map_list)
    error("cant` use")
end

-- 保存一条数据
function M:save_one_entry(entry_data, change_map)
    error("cant` use")
end

-- 删除表数据
function M:delete_entry(key_values)
    error("cant` use")
end

-- IN 查询
function M:get_entry_by_in(in_values, key_values)
    error("cant` use")
end

-- 分页查询
function M:get_entry_by_limit(cursor, limit, sort, key_values, is_only_key)
    error("cant` use")
end

-- 范围删除
function M:delete_entry_by_range(left, right, key_values)
    error("cant` use")
end

-- IN 删除
function M:delete_entry_by_in(in_values, key_values)
    error("cant` use")
end

-- 批量删除
function M:batch_delete_entry(keys_list)
    error("cant` use")
end

--批量范围删除
function M:batch_delete_entry_by_range(query_list)
    error("cant` use")
end

return M
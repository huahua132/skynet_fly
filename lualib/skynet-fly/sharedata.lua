---#API
---#content ---
---#content title: 共享配置数据
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","共享配置数据"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [sharedata](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/sharedata.lua)

local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local sharetable = require "skynet.sharetable"
local watch_syn = require "skynet-fly.watch.watch_syn"
local service_watch_interface = require "skynet-fly.watch.interface.service_watch_interface"
local timer = require "skynet-fly.timer"
local module_info = require "skynet-fly.etc.module_info"
local log = require "skynet-fly.log"
local file_util = require "skynet-fly.utils.file_util"
local string_util = require "skynet-fly.utils.string_util"
local table_util = require "skynet-fly.utils.table_util"

local sinterface = service_watch_interface:new(".sharedata_service")

----------------------------------------------
---#content 使用注意点
---#content 对于使用sharedata配置，被其他外部引用的表会被更新到，sharetable不会，所以如果想拿到最新的配置就必须用这个文件的`get_map,get_map_list,get_data_table`拿取
---#content 对于不想更新到的表sharedata需要做个深拷贝
---#content 直接用sharedata 的表数据传入pb，该部分数据打包不进去，需要深拷贝后导入
----------------------------------------------

local next = next
local assert = assert
local setmetatable = setmetatable
local pairs = pairs
local table = table
local ipairs = ipairs
local type = type
local string = string
local os = os
local loadfile = loadfile
local tonumber = tonumber

local g_recordpath = skynet.getenv("recordpath")

local g_mode_map = {}
local g_data_map = {}
local g_version_map = {}
local g_flush_time_obj = nil

local M = {
    enum = {
        sharedata = 1,
        sharetable = 2,
    }
}
local mt = {__index = M}

local function get_patch_file_path(file_path, patch_dir)
    local depth = 0
    for w in string.gmatch(file_path, "%.%.%/") do
        depth = depth + 1
    end
    local path = patch_dir
    local pat = ""
    if depth == 0 then
        path = path .. 'cur/'
        pat = './'
    else
        for i = 1, depth do
            path = path .. 'pre/'
            pat = pat .. '../'
        end
    end
    
    return string.gsub(file_path, pat, path, 1)
end

local function add_patch(file_path, up_time)
    local function get_patch_dir()
        local base_info = module_info.get_base_info()
        return file_util.path_join(g_recordpath, string.format("sharedata_%s-%s-%s/patch_%s/",
        base_info.module_name, base_info.version, os.date("%Y%m%d-%H%M%S", base_info.launch_time),
        os.date("%Y%m%d-%H%M%S", up_time)))
    end

    if skynet.is_write_record() then        --如果写录像
        local patch_dir = get_patch_dir()
        local new_path = get_patch_file_path(file_path, patch_dir)
        local filename = string.match(file_path, "([^/]+%.lua)$")
        local dir_path = string.gsub(new_path, filename, '', 1)
        local isok, err = file_util.mkdir(dir_path)
        if not isok then
            log.error("record mkdir err ", err)
        else
            local copy_file_obj = file_util.new_copy_file()
            copy_file_obj.set_source_target(file_path, new_path)
            local isok, err = copy_file_obj:execute()
            if not isok then
                log.error("record cp file err ", err)
            end
        end
    end

    if skynet.is_record_handle() then       --如果是读录像
        local patch_dir = get_patch_dir()
        local path = get_patch_file_path(file_path, patch_dir)
        local f = loadfile(path)
        if not f then
            log.error("play record err can`t loadfile ", path)
            error("play record err can`t loadfile")
        end
        g_data_map[file_path] = f()
    end
end

local g_mode_funcs = {}
g_mode_funcs[M.enum.sharedata] = {
    query = function(file_path)
        return sharedata.query(file_path)
    end,
    update = function(file_path)
        if not g_flush_time_obj or g_flush_time_obj:remain_expire() < 0 then
            g_flush_time_obj = timer:new(timer.minute, 1, sharedata.flush)         --刷一下，尽快释放旧数据
        end
        return g_data_map[file_path]
    end
}

g_mode_funcs[M.enum.sharetable] = {
    query = function(file_path)
        return sharetable.query(file_path)
    end,
    update = function(file_path)
        return sharetable.query(file_path)
    end
}

setmetatable(g_data_map, {__index = function(t, k)
    local mode = g_mode_map[k]
    local mode_func = g_mode_funcs[mode]
    local data_table = mode_func.query(k)
    t[k] = data_table
    return data_table
end})

local function watch_update(watchcli, file_path)
    while watchcli:is_watch(file_path) do
        local str = watchcli:await_update(file_path)
        local spstr = string_util.split(str, '-')
        local new_version = tonumber(spstr[1])
        local up_time = tonumber(spstr[2])
        local old_version = g_version_map[file_path]
        if new_version ~= old_version then
            local mode = g_mode_map[file_path]
            local mode_func = g_mode_funcs[mode]
            g_data_map[file_path] = mode_func.update(file_path)
            add_patch(file_path, up_time)
            g_version_map[file_path] = new_version
        end
    end
end

setmetatable(g_version_map, {__index = function(t, k) 
    local cli = watch_syn.new_client(sinterface)
    cli:watch(k)
    local str = cli:await_get(k)
    local spstr = string_util.split(str, '-')
    local version = tonumber(spstr[1])
    t[k] = version

    skynet.fork(watch_update, cli, k)

    return version
end})

---#desc 加载指定路径列表下配置， 废弃，直接用new就行
---@param dir_list table 路径列表
---@param mode number 模式 sharedata or sharetable
function M.load(dir_list, mode)
    
end

local function check_swtich(t)
    local file_path = t.file_path
    if t.version ~= g_version_map[file_path] then
        t.data_table = g_data_map[file_path]
        t.version = g_version_map[file_path]
        for name in pairs(t.map_list_map) do
            t.map_list_map[name] = {}
        end
        for name in pairs(t.map_map) do
            t.map_map[name] = {}
        end
        t.is_builder = false
        t:builder()          --数据更新了重新构建
    end
end

---#desc 配置访问代理
---@param file_path string 配置路径
---@param mode number 模式 sharedata or sharetable
---@return table obj 代理对象
function M:new(file_path, mode)
    assert(mode == M.enum.sharedata or mode == M.enum.sharetable, "not exists mode = " .. mode)
    local sd = skynet.uniqueservice("sharedata_service")
    assert(skynet.call(sd, 'lua', 'load', file_path, mode))
    local t = {
        mode = mode,
        file_path = file_path,
        is_builder = false,
        data_table = nil,           --原始数据表

        check_func_map = {},        --检查函数
        check_line_func = nil,      --单行检查函数
        map_list_map = {},          --map映射列表
        map_list_map_fields = {},   --map映射列表key字段列表
        map_map = {},               --map映射表
        map_map_fields = {},        --map映射表key字段列表
    }
    
    g_mode_map[file_path] = mode
    t.data_table = g_data_map[file_path]
    t.version = g_version_map[file_path]

    setmetatable(t, mt)
    return t
end

---#desc 设置单个字段检查
---@param field_name string 字段名
---@param func function 检查函数
---@return table obj 代理对象
function M:set_check_field(field_name, func)
    assert(not self.is_builder, "builded can`t set_check_field")
    self.check_func_map[field_name] = func
    return self
end

---#desc 设置一行配置检查
---@param func function 检查函数
---@return table obj 代理对象
function M:set_check_line(func)
    assert(not self.is_builder, "builded can`t set_check_line")
    self.check_line_func = func
    return self
end

--[[
     local t = {
        [k1] = {
            [k2] = {
                cfg1,cfg2
            }
        }
    }
]]

---#desc 设置map映射列表
---@param name string 检查函数
---@param ... string 字段名
---@return table obj 代理对象
function M:set_map_list(name, ...)
    assert(not self.is_builder, "builded can`t set_map_list")
    local field_list = {...}
    assert(#field_list > 0, "args len err")
    local map_list_map = self.map_list_map
    assert(not map_list_map[name], "exists map_list_map: " .. name)
    map_list_map[name] = {}

    self.map_list_map_fields[name] = field_list
    return self 
end
--[[
     local t = {
        [k1] = {
            [k2] = cfg1
        }
    }
]]

---#desc 设置纯map映射表
---@param name any
---@param ... string 字段名
---@return table
function M:set_map(name, ...)
    assert(not self.is_builder, "builded can`t set_map")
    local field_list = {...}
    assert(#field_list > 0, "args len err")
    local map_map = self.map_map
    assert(not map_map[name], "exists map_map: " .. name)
    map_map[name] = {}
    self.map_map_fields[name] = field_list
    return self
end

---#desc 构建
function M:builder()
    assert(not self.is_builder, "builded can`t builder")
    self.is_builder = true
    local check_func_map = self.check_func_map
    local check_line_func = self.check_line_func
    local file_path = self.file_path
    local map_list_map = self.map_list_map
    local map_list_map_fields = self.map_list_map_fields
    local map_map = self.map_map
    local map_map_fields = self.map_map_fields
    local data_table = self.data_table

    for index, oneCfg in pairs(data_table) do
        if type(oneCfg) == 'table' then
            for k,v in pairs(oneCfg) do
                local kfunc = check_func_map[k]
                if kfunc then
                    local isok,err = kfunc(v)
                    if not isok then
                        log.warn_fmt("check field err filepath[%s] idx[%s] fieldname[%s] errinfo[%s]", file_path, index, k, err)
                    end
                end
            end
            if check_line_func then
                local isok,err = check_line_func(oneCfg)
                if not isok then
                    log.warn_fmt("check line err filepath[%s] idx[%s] errinfo[%s]", file_path, index, err)
                end
            end

            for name,field_list in pairs(map_list_map_fields) do
                local map = map_list_map[name]
                for _,fieldname in ipairs(field_list) do
                    local v = oneCfg[fieldname]
                    if not v then
                        log.warn_fmt("set maplist err field not exists name[%s] filepath[%s] idx[%s] fieldname[%s]", name, file_path, index, fieldname)
                        break
                    end
                    if not map[v] then
                        map[v] = {}
                    end
                    map = map[v]
                end
                table.insert(map, oneCfg)
            end

            for name,field_list in pairs(map_map_fields) do
                local map = map_map[name]
                local len = #field_list
                for i = 1, len do
                    local fieldname = field_list[i]
                    local v = oneCfg[fieldname]
                    if not v then
                        log.warn_fmt("set map err field not exists name[%s] filepath[%s] idx[%s] fieldname[%s]", name, file_path, index, fieldname)
                        break
                    end
                    if i < len then
                        if not map[v] then
                            map[v] = {}
                        end
                        map = map[v]
                    else
                        if map[v] then
                            log.warn_fmt("set map repeat err field not exists name[%s] filepath[%s] idx[%s] fieldname[%s]", name, file_path, index, fieldname)
                        end
                        map[v] = oneCfg
                    end
                end
            end
        else
            --one 参数表
            local kfunc = check_func_map[index]
            if kfunc then
                local isok,err = kfunc(oneCfg)
                if not isok then
                    log.warn_fmt("check field err filepath[%s] idx[%s] fieldname[%s] errinfo[%s]", file_path, index, oneCfg, err)
                end
            end
        end
    end
    return self
end

--[[
local cfg = {
    items = {{id = 1, count = 2000}}
}
    比如pb需要items,就只需要 M:copy_table(cfg.items)即可
]]
---#desc copy 配置表  直接用sharedata 的表数据传入pb，该部分数据打包不进去，需要深拷贝后导入
---@param tab any
---@return table
function M:copy_table(tab)
    return table_util.copy(tab)
end

---#desc 获取数据表
---@return table
function M:get_data_table()
    assert(self.is_builder, "not build can`t get_data_table")
    check_swtich(self)
    return self.data_table
end

---#desc 获取maplist
---@param name string 索引名
---@return table
function M:get_map_list(name)
    assert(self.is_builder, "not build can`t get_map_list")
    check_swtich(self)
    return self.map_list_map[name]
end

--
---#desc 获取map
---@param name string 索引名
---@return table
function M:get_map(name)
    assert(self.is_builder, "not build can`t get_map")
    check_swtich(self)
    return self.map_map[name]
end

return M
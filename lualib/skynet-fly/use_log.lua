---#API
---#content ---
---#content title: 用户日志
---#content date: 2025-03-28 21:00:00
---#content categories: ["skynet_fly API 文档","日志相关"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [ormadapter_uselog](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/use_log.lua)
---#content用于写固定每天轮换的用户日志

local function log_service()
    local skynet = require "skynet.manager"
    local skynet_util = require "skynet-fly.utils.skynet_util"
    local time_util = require "skynet-fly.utils.time_util"
    local file_util = require "skynet-fly.utils.file_util"
    local timer_point = require "skynet-fly.time_extend.timer_point"
    local logrotate = require "skynet-fly.logrotate"
    local timer = require "skynet-fly.timer"
    local log = require "skynet-fly.log"

    local os = os
    local io = io
    local pairs = pairs
    local math = math
    local setmetatable = setmetatable

    local g_alloc_id = 0
    local g_name_id_map = {}
    local g_id_name_map = {}
    local g_file_map = {}
    local g_iswf_map = {}
    local g_read_file_map = setmetatable({}, {__mode = "kv"})

    local g_readfile_mt = {__gc = function(t)
        t.file:close()
    end}

    local function get_read_obj(file_path, file_name)
        local url = file_util.path_join(file_path, file_name)
        local read_obj = g_read_file_map[url]
        if read_obj then
            return read_obj
        end

        local file, err = io.open(url, 'r')
        if not file then
            return nil, err
        end

        read_obj = setmetatable({}, g_readfile_mt)
        read_obj.file = file
        g_read_file_map[url] = read_obj
        return read_obj
    end

    local function new_alloc_id()
        g_alloc_id = g_alloc_id + 1
        return g_alloc_id
    end

    local function open_file(file_path, file_name)
        local isok, err = file_util.mkdir(file_path)
        if not isok then
            return nil, err
        end

        local cur_time = time_util.time()
        local cur_date = os.date('%Y%m%d', cur_time)
        local url = file_util.path_join(file_path, cur_date .. '_' .. file_name)
        return io.open(url, "a")
    end

    local function flush_file(id)
        local file = g_file_map[id]
        if file then
            file:flush()
        end
    end

    local CMD = {}

    function CMD.new(file_path, file_name, flush_inval, max_age)
        max_age = max_age or 7                                                  --默认7天
        flush_inval = flush_inval or 6000 * 10 + math.random(100, 6000)         --默认10分钟 + 1-60秒的随机间隔
        local url = file_util.path_join(file_path, file_name)
        if g_name_id_map[url] then
            return g_name_id_map[url]
        end

        local file, err = open_file(file_path, file_name)
        if not file then
            return nil, err
        end

        local id = new_alloc_id()
        g_name_id_map[url] = id
        g_id_name_map[id] = {file_path = file_path, file_name = file_name}
        g_file_map[id] = file
        if flush_inval > 0 then
            timer:new(flush_inval, 0, flush_file, id)
        else
            g_iswf_map[id] = true
        end

        skynet.fork(function()
            --日志轮换
            logrotate:new()
            :set_file_path(file_path)
            :set_max_age(max_age)
            :set_back_pattern(file_name)
            :set_point_type(timer_point.EVERY_DAY)
            :builder()
        end)
        return id
    end

    function CMD.log(id, log_str)
        local file = g_file_map[id]
        file:write(log_str .. '\n')
        if g_iswf_map[id] then
            file:flush()
        end
    end

    function CMD.read(file_path, file_name, offset, line_num)
        local read_obj, err = get_read_obj(file_path, file_name)
        if not read_obj then
            return false, err
        end

        read_obj.file:seek('set', offset)
        local ret_str = ""
        for i = 1, line_num do
            local line = read_obj.file:read('L')
            if not line then
                break
            end
            ret_str = ret_str .. line
        end
        local cur_offset = read_obj.file:seek('cur', 0)
        local file_size = read_obj.file:seek('end')
        return true, ret_str, cur_offset, file_size
    end

    skynet.start(function()
        skynet.register(".use_log")
        skynet_util.lua_dispatch(CMD)
        --每日零点重新打开日志文件
        timer_point:new(timer_point.EVERY_DAY)
        :set_hour(0)
        :set_min(0)
        :set_sec(0)
        :builder(function()
            for id, file in pairs(g_file_map) do
                local info = g_id_name_map[id]
                local new_file, err = open_file(info.file_path, info.file_name)
                if not new_file then
                    log.error("reopen log file err ", info.file_path, info.file_name, err)
                else
                    file:flush()
                    file:close()
                    g_file_map[id] = new_file
                end
            end
        end)
    end)
    
    --注册关服处理函数
    skynet_util.reg_shutdown_func(function()
        for id, file in pairs(g_file_map) do
            file:flush()
            file:close()
        end
    end)
end

local service = require "skynet.service"
local skynet = require "skynet"

local M = {}
local setmetatable = setmetatable
local mt = {__index = M}

local g_logd = nil
---#desc 创建日志对象
---@param file_path string 日志存放路径
---@param file_name string 文件名
---@param flush_inval number? flush间隔时间
---@param max_age number? 最大保留天数
function M:new(file_path, file_name, flush_inval, max_age)
    local t = {
        id = 0,
        logd = 0,
    }
    setmetatable(t, mt)
    local logd = g_logd or service.new("use_logd", log_service)
    t.logd = logd
    t.id = skynet.call(logd, 'lua', 'new', file_path, file_name, flush_inval, max_age)
    g_logd = logd
    return t
end
---#desc 写日志
---@param log_str string 日志内容
function M:write_log(log_str)
    skynet.send(self.logd, 'lua', 'log', self.id, log_str)
end

return M
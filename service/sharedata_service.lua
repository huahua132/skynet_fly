---@diagnostic disable: need-check-nil, undefined-field
local skynet = require "skynet.manager"
local sharedata = require "skynet.sharedata"
local sharetable = require "skynet.sharetable"
local skynet_util = require "skynet-fly.utils.skynet_util"
local file_util = require "skynet-fly.utils.file_util"
local time_util = require "skynet-fly.utils.time_util"
local watch_syn = require "skynet-fly.watch.watch_syn"
local queue = require "skynet.queue"()

local log = require "skynet-fly.log"
local lfs = require "lfs"
local json = require "cjson"

local string = string
local pairs = pairs
local assert = assert
local table = table
local tostring = tostring

local ENUM = {
    sharedata = 1,
    sharetable = 2,
}

local MODE_NAME = {
    [1] = "sharedata",
    [2] = "sharetable",
}

local g_watch_server = nil
local g_file_changetime_map = {}
local g_modes = {}

g_modes[ENUM.sharedata] = {
    load = function(file_path)
        sharedata.new(file_path, "@" .. file_path)
    end,
    reload = function(file_path)
        sharedata.update(file_path, "@" .. file_path)
    end
}

g_modes[ENUM.sharetable] = {
    load = function(file_path)
        sharetable.loadfile(file_path)
    end,
    reload = function(file_path)
        sharetable.loadfile(file_path)
    end,
}

local CMD = {}

local function load_new_file(file_path, file_info, cur_time, mode)
    local m = g_modes[mode]
    m.load(file_path)
    g_file_changetime_map[file_path] = {
        version = 1,
        mode = mode,
        last_change_time = file_info.modification,
    }
    g_watch_server:register(file_path, g_file_changetime_map[file_path].version .. '-' .. cur_time)
    log.info("sharedata load loadfile:", file_path)
end

local function load(file_path, mode)
    if not g_modes[mode] then
        return false, "not exists mode:" .. tostring(mode)
    end
    
    if not g_file_changetime_map[file_path] then
        local cur_time = time_util.time()
        file_path = file_util.convert_windows_to_linux_relative(file_path)
        local file_info, errmsg, errno = lfs.attributes(file_path)
        if not file_info then
            return false, string.format("can`t get file_info errmsg[%s] errno[%s]", errmsg, errno)
        end
        load_new_file(file_path, file_info, cur_time, mode)
    else
        local info = g_file_changetime_map[file_path]
        if info.mode ~= mode then
            return false, string.format("mode not match load mode[%s] use mode[%s]", MODE_NAME[info.mode], MODE_NAME[mode])
        end
    end

    return true
end
--加载目录下的配置
function CMD.load(file_path, mode)
    return queue(load, file_path, mode)
end

local function check_reload()
    local reload_list = {}
    local cur_time = time_util.time()
    for file_path, info in pairs(g_file_changetime_map) do
        local file_info, errmsg, errno = lfs.attributes(file_path)
        if not file_info then
            log.warn("check_reload file can`t get info:", file_path, errmsg, errno)
        else
            if file_info.modification ~= info.last_change_time then
                local m = g_modes[info.mode]
                log.info("sharedata check_reload reloadfile:", file_path)
                m.reload(file_path)
                info.last_change_time = file_info.modification
                info.version = info.version + 1
                table.insert(reload_list, file_path)

                g_watch_server:publish(file_path, info.version .. '-' .. cur_time)
            end
        end
    end
    
    return json.encode(reload_list)
end

--检查热更加载过的配置
function CMD.check_reload()
    return queue(check_reload)
end

g_watch_server = watch_syn.new_server(CMD)

skynet.start(function()
    skynet_util.lua_dispatch(CMD)
    skynet.register(".sharedata_service")
end)
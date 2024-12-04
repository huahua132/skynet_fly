local skynet = require "skynet.manager"
local sharedata = require "skynet.sharedata"
local sharetable = require "skynet.sharetable"
local skynet_util = require "skynet-fly.utils.skynet_util"
local file_util = require "skynet-fly.utils.file_util"
local time_util = require "skynet-fly.utils.time_util"
local watch_syn = require "skynet-fly.watch.watch_syn"

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

function CMD.load(dir_list, mode)
    assert(g_modes[mode], "not exists mode:" .. tostring(mode))
    local m = g_modes[mode]
    local cur_time = time_util.time()
    for _,dir in pairs(dir_list) do
        for file_name,file_path,file_info in file_util.diripairs(dir) do
            file_path = file_util.convert_windows_to_linux_relative(file_path)
            log.info("sharedata load loadfile:", file_path)
            if string.find(file_name, '.lua', nil, true) then
                m.load(file_path)
                
                g_file_changetime_map[file_path] = {
                    version = 1,
                    mode = mode,
                    last_change_time = file_info.modification,
                }

                g_watch_server:register(file_path, g_file_changetime_map[file_path].version .. '-' .. cur_time)
            end
        end
    end
end

function CMD.check_reload()
    local reload_list = {}
    local cur_time = time_util.time()
    for file_path, info in pairs(g_file_changetime_map) do
        local file_info, errinfo, errno = lfs.attributes(file_path)
        if not file_info then
            log.warn("check_reload file can`t get info:", file_path, errinfo, errno)
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

g_watch_server = watch_syn.new_server(CMD)

skynet.start(function()
    skynet_util.lua_dispatch(CMD)
    skynet.register(".sharedata_service")
end)
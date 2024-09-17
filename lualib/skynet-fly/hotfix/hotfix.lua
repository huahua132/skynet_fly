local contriner_interface = require "skynet-fly.contriner.contriner_interface"
local SERVER_STATE_TYPE = require "skynet-fly.enum.SERVER_STATE_TYPE"
local log = require "skynet-fly.log"
local string_util = require "skynet-fly.utils.string_util"

local old_require = require
local assert = assert
local ipairs = ipairs
local pairs = pairs
local loadfile = loadfile
local x_pcall = x_pcall
local type = type
local string = string
local rawget = rawget
local tinsert = table.insert
local tsort = table.sort

local g_loadedmap = {}
local M = {}

local g_seq = 1

local g_tb = _G

local g_dummy_env = {}
for k,v in pairs(_ENV) do g_dummy_env[k] = v end

local g_mata = {
    __index = g_tb,
    __newindex = function(t, k, v)
        local oldv = rawget(g_tb, k)
        if v ~= oldv then
            log.warn_fmt("hotfix can`t change global k[%s] newv[%s] oldv[%s]", k, v, oldv)      --热更改变全局变量是很危险的行为
        end
        return oldv
    end,
}

setmetatable(g_dummy_env, g_mata)

--可热更模块加载
function M.require(name)
    if g_loadedmap[name] then
        return old_require(name)
    end
    assert(not string.find(name, 'skynet-fly.hotfix.state_data'), "can`t hotfix file")      --存储状态数据的文件不能热更

    assert(contriner_interface:get_server_state() == SERVER_STATE_TYPE.loading)     --必须load阶段require，否则不好记录文件修改时间
	local package = g_tb.package
    local f_dir = package.searchpath(name, package.path)
    assert(f_dir, "hot_require err can`t find module = " .. name)

    g_loadedmap[name] = {
        dir = f_dir,
        seq = g_seq,
    }
    g_seq = g_seq + 1
    return old_require(name)
end

--热更
function M.hotfix(hotfixmods)
    local hot_ret = {}
    local name_list = string_util.split(hotfixmods, '|')
    local sort_list = {}
    for _,name in ipairs(name_list) do
        local info = g_loadedmap[name]
        if not info then
            log.warn_fmt("hotfix filename not exists name:%s", name)
            hot_ret[name] = "filename not exists"
            return false,hot_ret
        end
        tinsert(sort_list, {
            name = name,
            seq = info.seq,
        })
    end
    tsort(sort_list, function(a, b) return a.seq > b.seq end)
    
    for _,info in ipairs(sort_list) do
        local name = info.name
        local info = g_loadedmap[name]
        local dir = info.dir
        local mainfunc = loadfile(dir, "t", g_dummy_env)
        if not mainfunc then
            log.warn_fmt("hotfix loadfile err name:%s", name)
            hot_ret[name] = "loadfile err"
            return false,hot_ret
        end

        local isok, new_m = x_pcall(mainfunc)
        if not isok then
            log.warn_fmt("hotfix file doing err name:%s err:%s", name, new_m)
            hot_ret[name] = "file doing err:" .. new_m
            return false,hot_ret
        end

        local isok, old_m = x_pcall(old_require, name)
        if not isok then
            log.warn_fmt("hotfix require old_m err name:%s", name)
            hot_ret[name] = "file require old_m err"
            return false,hot_ret
        end

        if type(new_m) ~= 'table' then
            log.warn_fmt("can`t hotfix is not table new_m name:%s", name)
            hot_ret[name] = "can`t hotfix is not table new_m"
            return false,hot_ret
        end

        if type(old_m) ~= 'table' then
            log.warn_fmt("can`t hotfix is not table old_m name:%s", name)
            hot_ret[name] = "can`t hotfix is not table old_m"
            return false,hot_ret
        end

        --值类型不能变
        for k, v in pairs(new_m) do
            local ov = old_m[k]
            if ov and type(ov) ~= type(v) then
                local errstr = string.format("can`t hotfix type change k[%s] new[%s] old[%s]", k, type(v), type(ov))
                log.warn(errstr)
                hot_ret[name] = errstr
                return false,hot_ret
            end
        end

        hot_ret[name] = {
            old_m = old_m,
            new_m = new_m,
        }
    end

    for _,info in ipairs(sort_list) do
        local name = info.name
        local info = hot_ret[name]
        local old_m = info.old_m
        local new_m = info.new_m
        for k,v in pairs(new_m) do
            old_m[k] = v
        end
    end
    
    for i,info in ipairs(sort_list) do
        local name = info.name
        local info = hot_ret[name]
        local old_m = info.old_m
        local hotfix_f = old_m['hotfix']
        if type(hotfix_f) == 'function' then
            local isok, err = x_pcall(hotfix_f)
            if not isok then
                log.warn_fmt("execute hotfix faild name:%s err:%s", name, err)
                hot_ret[name] = "execute hotfix faild err:" .. err
            else
                log.info("hotfix ok ", name)
                hot_ret[name] = "ok:" .. i
            end
        else
            log.info("hotfix ok ", name)
            hot_ret[name] = "ok:" .. i
        end        
    end

    return true,hot_ret
end

--返回loadedmap
function M.get_loadedmap()
    return g_loadedmap
end

return M
local contriner_interface = require "skynet-fly.contriner.contriner_interface"
local SERVER_STATE_TYPE = require "skynet-fly.enum.SERVER_STATE_TYPE"
local log = require "skynet-fly.log"
local string_util = require "skynet-fly.utils.string_util"
local file_util = require "skynet-fly.utils.file_util"
local time_util = require "skynet-fly.utils.time_util"
local module_info = require "skynet-fly.etc.module_info"
local skynet = require "skynet"

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
local sgsub = string.gsub
local os = os

local g_recordpath = skynet.getenv("recordpath")

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
    
    return sgsub(file_path, pat, path, 1)
end

local function get_patch_dir(up_time)
    local base_info = module_info.get_base_info()

    return file_util.path_join(g_recordpath, string.format("hotfix_%s-%s-%s/patch_%s/",
    base_info.module_name, base_info.version, os.date("%Y%m%d-%H%M%S", base_info.launch_time),
    os.date("%Y%m%d-%H%M%S", up_time)))
end

--可热更模块加载
function M.require(name)
    if g_loadedmap[name] then
        return old_require(name)
    end
    assert(not string.find(name, 'skynet-fly.hotfix.state_data'), "can`t hotfix file")      --存储状态数据的文件不能热更

    assert(contriner_interface:get_server_state() == SERVER_STATE_TYPE.loading)     --必须load阶段require，否则不好记录文件修改时间
	local package = g_tb.package
    local f_path = package.searchpath(name, package.path)
    assert(f_path, "hot_require err can`t find module = " .. name)

    g_loadedmap[name] = {
        path = f_path,
        seq = g_seq,
    }
    g_seq = g_seq + 1
    return old_require(name)
end

--热更
function M.hotfix(hotfixmods)
    local base_info = module_info.get_base_info()
    local patch_dir
    local cur_time = time_util.time()
    if skynet.is_record_handle() then              --说明是播放录像
        patch_dir = get_patch_dir(cur_time)
    end

    local hot_ret = {}
    local name_list = string_util.split(hotfixmods, ':::')
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
        local path = info.path
        if patch_dir then
            path = get_patch_file_path(path, patch_dir)
        end
        local mainfunc = loadfile(path, "bt", g_dummy_env)
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

    if skynet.is_write_record() and base_info.index == 1 then --第一个启动记录下就行
        local patch_dir = get_patch_dir(cur_time)
        local copy_file_obj = file_util.new_copy_file()
        local dir_path_map = {}
        for i, info in ipairs(sort_list) do
            local name = info.name
            local info = g_loadedmap[name]
            local path = info.path
            local new_path = get_patch_file_path(path, patch_dir)
            local filename = string.match(path, "([^/]+%.lua)$")
            local dir_path = sgsub(new_path, filename, '', 1)
            dir_path_map[dir_path] = true
            copy_file_obj.set_source_target(path, new_path)
        end

        for dir_path in pairs(dir_path_map) do
            local isok, err = file_util.mkdir(dir_path)
            if not isok then
                log.error("hotfix mkdir err ", dir_path, err)
            end
        end

        local isok, err = copy_file_obj:execute()
        if not isok then
            log.error("hotfix cp file err ", err)
        end
    end

    return true,hot_ret
end

--返回loadedmap
function M.get_loadedmap()
    return g_loadedmap
end

return M
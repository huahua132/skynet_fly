local skynet = require "skynet"
local lfs = require "lfs"
local time_util = require "skynet-fly.utils.time_util"
local file_util = require "skynet-fly.utils.file_util"
local log = require "skynet-fly.log"
local string_util = require "skynet-fly.utils.string_util"
local timer_point = require "skynet-fly.time_extend.timer_point"

local string = string
local assert = assert
local os = os
local tinsert = table.insert
local tremove = table.remove
local tsort = table.sort
local tonumber = tonumber
local ipairs = ipairs
local pairs = pairs

local g_rotates_map = {}

local function os_execute(cmd)
    local isok,status,signal = os.execute(cmd)
    if not isok then
        log.error("os_execute cmd err ",cmd,status,signal)
    end
    return isok
end

local function create_rotate(cfg)
    assert(cfg.filename,"not filename")
    local m_filename = cfg.filename                                     --文件名
    local m_rename_format = cfg.rename_format or "%Y%m%d"               --重命名文件格式
    local m_file_path = cfg.file_path or './'                           --文件路径
    local m_limit_size = cfg.limit_size or 0                            --至少多大才会切割
    local m_max_age = cfg.max_age or 30                                 --最大保留天数
    local m_max_backups = cfg.max_backups or 30                         --最大保留文件数
    local m_sys_cmd = cfg.sys_cmd                                       --轮转时调用的系统命令

    local m_point_type = cfg.point_type or timer_point.EVERY_DAY        --默认每天
    local m_month = cfg.month or 1                                      --几月
    local m_day = cfg.day or 1                                          --几天 
    local m_hour = cfg.hour or 0                                        --几时
    local m_min = cfg.min or 0                                          --几分
    local m_sec = cfg.sec  or 0                                         --几秒
    local m_wday = cfg.wday or 1                                        --周几
    local m_yday = cfg.yday or 1                                        --一年第几天
  
    local m_timer_obj = nil                                             --定时器对象

    m_rename_format = m_rename_format .. '_' .. m_filename
    log.info("log name :",os.date(m_rename_format,time_util.time()))
    --切割
    local function rotate()
        local file_url = m_file_path .. m_filename
        local file_info, errinfo, errno = lfs.attributes(file_url)
        if not file_info then
            log.error("rotate file is not exists ",file_url, errinfo, errno)
            return
        end

        if file_info.mode ~= 'file' then
            log.error("rotate file is not file ",file_url)
            return
        end

        if file_info.size < m_limit_size then
            log.info("rotate file size limit ",file_info.size,m_limit_size)
            return
        end

        --重命名文件
        local target_file_url = string.format("%s%s",m_file_path,os.date(m_rename_format,time_util.time()))
        local rename_cmd = string.format("mv %s %s",file_url,target_file_url)
        os_execute(rename_cmd)

        --执行命令
        if m_sys_cmd then
            for line in m_sys_cmd:gmatch("[^\n]+") do
                local cmd = line:sub(1,line:len() - 2)
                os_execute(cmd)
            end
        end
    end

    --保留文件整理
    local function backup()
        local pathinfo, errinfo, errno = lfs.attributes(m_file_path)
        if not pathinfo then
            log.error("backup path is not exists ",m_file_path, errinfo, errno)
            return
        end

        if pathinfo.mode ~= 'directory' then
            log.error("backup path not is directory ",m_file_path,pathinfo.mode)
            return
        end

        local back_list = {}
        for file_name,file_path,file_info, errmsg, errno in file_util.diripairs(m_file_path) do
            if file_name ~= m_filename and string.find(file_name,m_filename,nil,true) then
                if file_info then
                    tinsert(back_list, {
                        file_path = file_path,
                        time = file_info.modification               --最近一次修改时间
                    })
                else
                    log.warn("backup file can`t get file_info ", file_path, errmsg, errno)
                end
            end
        end

        --最新的在前面
        tsort(back_list,function(a,b) return a.time > b.time end)

        --保留文件数
        for i = #back_list,m_max_backups + 1, -1 do
            --删除文件
            local f = tremove(back_list,i)
            os_execute("rm -f " .. f.file_path)
        end

        local cur_time = os.time()
        local max_age_time = m_max_age * 86400
        --保留天数
        for i = #back_list,1,-1 do
            local f = back_list[i]
            --过期了
            if cur_time - f.time > max_age_time then
                os_execute("rm -f " .. f.file_path)
            else
                --有序的，当前这个没过期，前面的肯定也没有过期
                break
            end
        end
    end

    local time_obj = timer_point:new(m_point_type)
    time_obj:set_month(m_month)
    time_obj:set_day(m_day)
    time_obj:set_hour(m_hour)
    time_obj:set_min(m_min)
    time_obj:set_sec(m_sec)
    time_obj:set_wday(m_wday)
    time_obj:set_yday(m_yday)
    time_obj:builder(function()
        rotate()
        backup()
    end)

    m_timer_obj = time_obj

    return function()
        m_timer_obj:cancel()
    end
end

local CMD = {}

function CMD.add_rotate(server_id, cfg)
    if not g_rotates_map[server_id] then
        g_rotates_map[server_id] = {}
    end
    tinsert(g_rotates_map[server_id],create_rotate(cfg))
    return true
end

function CMD.cancel(server_id)
    local rlist = g_rotates_map[server_id]
    if not rlist then return end

    g_rotates_map[server_id] = nil

    for _,cancel in ipairs(rlist) do
        cancel()
    end
end

function CMD.start(config)
    g_rotates_map[skynet.self()] = {}
    tinsert(g_rotates_map[skynet.self()],create_rotate(config))
    return true
end

function CMD.fix_exit()
    for _,rlist in pairs(g_rotates_map) do
        for _,cancel in ipairs(rlist) do
            cancel()
        end
    end
end

function CMD.exit()
    return true
end

return CMD
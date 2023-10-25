local skynet = require "skynet"
local lfs = require "lfs"
local time_util = require "time_util"
local file_util = require "file_util"
local log = require "log"
local string_util = require "string_util"
local timer_point = require "timer_point"

local string = string
local assert = assert
local os = os
local tinsert = table.insert
local tremove = table.remove
local tsort = table.sort
local tonumber = tonumber

local g_filename = nil    --文件名  
local g_file_path = nil   --文件路径
local g_limit_size = nil  --至少多大才会切割
local g_max_age = nil     --最大保留天数
local g_max_backups = nil --最大保留文件数
local g_sys_cmd = nil     --系统命令
local g_point_type = nil  --默认每天
local g_month = nil       --几月
local g_day = nil         --几天 
local g_hour = nil        --几时
local g_min = nil         --几分
local g_sec = nil         --几秒
local g_wday = nil        --周几
local g_yday = nil        --一年第几天

local g_timer_obj = nil

local function os_execute(cmd)
    local isok,status,signal = os.execute(cmd)
    if not isok then
        log.error("os_execute cmd err ",cmd,status,signal)
    end
    return isok
end

--切割
local function rotate()
    local file_url = g_file_path .. g_filename
    local file_info = lfs.attributes(file_url)
    if not file_info then
        log.error("rotate file is not exists ",file_url)
        return
    end

	if file_info.mode ~= 'file' then
        log.error("rotate file is not file ",file_url)
        return
    end

    if file_info.size < g_limit_size then
        log.info("rotate file size limit ",file_info.size,g_limit_size)
        return
    end

    --重命名文件
    local target_file_url = string.format("%s%s_%s",g_file_path,os.date("%Y%m%d-%H%M%S",os.time()),g_filename)
    local rename_cmd = string.format("mv %s %s",file_url,target_file_url)
    os_execute(rename_cmd)

    --执行命令
    if g_sys_cmd then
        for line in g_sys_cmd:gmatch("[^\n]+") do
            local cmd = line:sub(1,line:len() - 2)
            os_execute(cmd)
        end
    end
end

--保留文件整理
local function backup()
    local pathinfo = lfs.attributes(g_file_path)
    if not pathinfo then
        log.error("backup path is not exists ",g_file_path)
        return
    end

    if pathinfo.mode ~= 'directory' then
        log.error("backup path not is directory ",g_file_path,pathinfo.mode)
        return
    end

    local back_list = {}
    for file_name,file_path,file_info in file_util.diripairs(g_file_path) do
        if file_name ~= g_filename and string.find(file_name,g_filename,nil,true) then
            local date_time = string_util.split(file_name,'_')[1]
            local date_time_str = string_util.split(date_time,'-')
            local date = date_time_str[1]
            local time = date_time_str[2]

            if date and time then
                local year = tonumber(date:sub(1,date:len() - 4))
                local month = tonumber(date:sub(date:len() - 3,date:len() - 2))
                local day = tonumber(date:sub(date:len() - 1))

                local hour = tonumber(time:sub(1,2))
                local min = tonumber(time:sub(3,4))
                local sec = tonumber(time:sub(5,6))

                local date = {year = year,month = month,day = day,hour = hour,min = min,sec = sec}

                tinsert(back_list,{
                    file_name = file_name,
                    file_path = file_path,
                    file_info = file_info,
                    date = date,
                    time = os.time(date),
                })
            else
                log.error("unknown file ",file_name)
            end
        end
    end

    --最新的在前面
    tsort(back_list,function(a,b) return a.time > b.time end)

    --保留文件数
    for i = #back_list,g_max_backups + 1, -1 do
        --删除文件
        local f = tremove(back_list,i)
        os_execute("rm -f " .. f.file_path)
    end

    local cur_time = os.time()
    local max_age_time = g_max_age * 86400
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

local CMD = {}

function CMD.start(config)
    g_filename = config.filename
    assert(g_filename,"not filename")
    g_limit_size = config.limit_size or 0
    g_max_age = config.max_age or 30
    g_max_backups = config.max_backups or 30
    g_file_path = config.file_path or './'
    g_sys_cmd = config.sys_cmd
    g_point_type = config.point_type or timer_point.EVERY_DAY --默认每天
    g_month = config.month or 1         --几月
    g_day = config.day or 1             --几天 
    g_hour = config.hour or 0           --几时
    g_min = config.min or 0             --几分
    g_sec = config.sec or 0             --几秒
    g_wday = config.wday or 1           --周几
    g_yday = config.yday or 1           --一年第几天

    local time_obj = timer_point:new(g_point_type)
    time_obj:set_month(g_month)
    time_obj:set_day(g_day)
    time_obj:set_hour(g_hour)
    time_obj:set_min(g_min)
    time_obj:set_sec(g_sec)
    time_obj:set_wday(g_wday)
    time_obj:set_yday(g_yday)
    time_obj:builder(function()
        rotate()
        backup()
    end)

    g_timer_obj = time_obj
    return true
end

function CMD.exit()
    if g_timer_obj then
        g_timer_obj:cancel()
    end
    return true
end

return CMD
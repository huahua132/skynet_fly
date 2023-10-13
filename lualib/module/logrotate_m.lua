local timer = require "timer"
local skynet = require "skynet"
local lfs = require "lfs"
local time_util = require "time_util"
local file_util = require "file_util"
local log = require "log"
local string_util = require "string_util"

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

local IS_EXIT = false

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
                log.error("unkown file ",file_name)
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

    skynet.fork(function()
        while not IS_EXIT do
            local next_day_time = time_util.day_time(1,0,0,0) --明天凌晨
            local expire = next_day_time - os.time()
            if expire < 0 then
                expire = 0
            end

            skynet.sleep(expire * 100)
            rotate()
            backup()
        end
    end)
    
    return true
end

function CMD.exit()
    IS_EXIT = true
    return tremove
end

return CMD
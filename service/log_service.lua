local skynet = require "skynet"
local skynet_util = require "skynet-fly.utils.skynet_util"
local file_util = require "skynet-fly.utils.file_util"
local time_util = require "skynet-fly.utils.time_util"
require "skynet.manager"

local os = os
local io = io
local error = error
local assert = assert
local print = print
local string = string
local type = type
local table = table
local math_floor = math.floor
local sformat = string.format
local osdate = os.date
local contriner_client = nil

local SELF_ADDRESS = skynet.self()

local file = nil
local file_path = skynet.getenv('logpath')
local file_name = skynet.getenv('logfilename')
local daemon = skynet.getenv('daemon')
local log_is_launch_rename = skynet.getenv('log_is_launch_rename')
local hook_hander_list = {}

local function rename_old_file()
    if log_is_launch_rename ~= 'true' then
        return
    end
    if not daemon then
        return
    end

    local file_p = file_util.path_join(file_path,file_name)
    local oldfile = io.open(file_p, 'r')
    if not oldfile then
        return
    end

    oldfile:close()
    local cur_time = time_util.time()
    local fname = file_util.path_join(file_path, os.date("%Y%m%d-%H%M%S", cur_time) .. '_' .. file_name)
    os.rename(file_p, fname)
end

local function open_file()
    if not daemon then
        return
    end
    if file then
        file:close()
    end
    print(file_path,file_name)
    os.execute('mkdir -p ' .. file_path)
    if not os.execute("mkdir -p " .. file_path) then
        error("create dir err")
    end
    local file_p = file_util.path_join(file_path,file_name)
    file = io.open(file_p, 'a+')
    file:write('open log file' .. file_p .. '\n')
    file:flush()
    assert(file, "can`t open file " .. file_p)
end

skynet.register_protocol {
	name = "text",
	id = skynet.PTYPE_TEXT,
	unpack = skynet.tostring,
	dispatch = function(_, address, msg)
        local cur_time = time_util.skynet_int_time()
        local second,m = math_floor(cur_time / 100), cur_time % 100
        local mstr = sformat("%02d",m)
        local time_date = osdate('[%Y%m%d %H:%M:%S ',second)
        local log_str = '[' .. skynet.address(address) .. ']' .. time_date .. mstr .. ']' .. msg
        
        if file then
            file:write(log_str .. '\n')
            file:flush()
        else
            print(log_str)
        end

        if address ~= SELF_ADDRESS then
            for i = 1,#hook_hander_list do
                hook_hander_list[i](log_str,msg)
            end
        end
	end
}

skynet.register_protocol {
	name = "SYSTEM",
	id = skynet.PTYPE_SYSTEM,
	unpack = function(...) return ... end,
	dispatch = function()
		-- reopen signal
        open_file()
	end
}

local CMD = {}

function CMD.add_hook(file_name)
    if not contriner_client then
        contriner_client = require "skynet-fly.client.contriner_client"
        contriner_client:CMD(CMD)
    end
    
    local func = require(file_name)
    assert(type(func) == 'function', "err file " .. file_name)
    table.insert(hook_hander_list, func)
    return true
end

skynet.start(function()
    rename_old_file()
    open_file()
    skynet_util.lua_dispatch(CMD)
end)


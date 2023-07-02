local skynet = require "skynet"
local redis = require "skynet.db.redis"
local log = require "log"
local assert = assert
local pcall = pcall

local CMD = {}

local g_conn = nil
local reqing_cnt = 0                --正在调用命令数量

function CMD.start(config)
    local host = assert(config.host)
    local port = assert(config.port)
    local auth = assert(config.auth)
    local db = assert(config.db)

    local db_conf = {
        host = host,
        port = port,
        auth = auth,
        db = db,
    }

    local ok,conn = pcall(redis.connect,db_conf)
    if not ok then
        log.fatal("redis connect faild ",db_conf)
        return
    end

    g_conn = conn
end

function CMD.redis_cmd(cmd,...)
    assert(g_conn,'not connnet!!!')
    local f = g_conn[cmd]
    assert(f,"not redis cmd ",cmd)
    reqing_cnt = reqing_cnt + 1
    local is_ok,ret = pcall(f,g_conn,...)
    reqing_cnt = reqing_cnt - 1
    if not is_ok then
        log.fatal("redis conn err ",ret,cmd,...)
        return nil
    else
        return ret 
    end
end

function CMD.exit()
    while reqing_cnt > 0 do
        log.warn("redis_m reqing_cnt = ",reqing_cnt)
        skynet.sleep(6000)
    end

    log.error("redis_m reqing_cnt = ",reqing_cnt)

    skynet.sleep(6000)
    skynet.exit()
end

return CMD
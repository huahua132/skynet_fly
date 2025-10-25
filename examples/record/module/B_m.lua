---@diagnostic disable: discard-returns
local skynet = require "skynet"
local log = require "skynet-fly.log"
local httpc = require "http.httpc"
local container_client = require "skynet-fly.client.container_client"
local socket = require "skynet.socket"
local timer = require "skynet-fly.timer"
local hotfix_func = hotfix_require "testhotfix.hotfix_func"
local hotfix_table = hotfix_require "testhotfix.hotfix_table"
local com_test_hotfix = hotfix_require "com_test_hotfix"
local ccom_test_hotfix = hotfix_require "common.com_test_hotfix"
local sharedata = require "skynet-fly.sharedata"

container_client:register("A_m", "share_config_m")

local CMD = {}

--测试服务相关API
local function test_service_api()
    log.info("skynet.newservice:", skynet.newservice("Cservice"))
    log.info("skynet.uniqueservice:", skynet.uniqueservice('container_mgr'))
    log.info("skynet.queryservice:", skynet.queryservice('container_mgr'))
    log.info("skynet.localname:", skynet.localname('.Cservice'))
end

--call调用
local function test_call()
    log.info("test_call:", container_client:instance("A_m"):mod_call('ping'))
end

--http调用
local function http_call()
    log.info("http_call:", httpc.get("baidu.com"))
end

--socket tcp测试
local function test_tcp()
    local fd = socket.listen("127.0.0.1", 8001)
    log.info("socket.listen: 127.0.0.1 8001 fd = ", fd)
    socket.start(fd, function(id, addr)
        log.info("socket accept new :", id, addr)
        skynet.fork(function()
            socket.start(id)
            while true do
                local str = socket.readline(id, '\n')
                log.info("read buffer:", id, str)
                if str then
                    socket.write(id, str)
                else
                    socket.close(id)
                    return
                end
            end
        end)
    end)
end

--调用redis测试
local function test_redis()
    local redisf = require "skynet-fly.db.redisf"
    local cli = redisf.new_client("test")
    log.info("redis cli set >>> :", cli:set("testkey","hello skynet-fly"))
    log.info("redis cli get >>> :", cli:get("testkey"))
end

--测试utp
local function test_utp()
    local function server()
        local host
        host = socket.udp(function(str, from)
            log.info("utp server v4 recv", str, socket.udp_address(from))
            socket.sendto(host, from, "OK " .. str)
        end , "127.0.0.1", 8765)	-- bind an address
    end
    
    local function client()
        local c = socket.udp(function(str, from)
            log.info("utp client v4 recv", str, socket.udp_address(from))
        end)
        socket.udp_connect(c, "127.0.0.1", 8765)
        for i=1,20 do
            socket.write(c, "hello " .. i)	-- write to the address by udp_connect binding
        end
    end

    local function server_v6()
        local server
        server = socket.udp_listen("::1", 8766, function(str, from)
            log.info(string.format("utp server_v6 recv str:%s from:%s", str, socket.udp_address(from)))
            socket.sendto(server, from, "OK " .. str)
        end)	-- bind an address
        log.info("create server succeed. "..server)
        return server
    end
    
    local function client_v6()
        local c = socket.udp_dial("::1", 8766, function(str, from)
            log.info(string.format("utp client recv v6 response str:%s from:%s", str, socket.udp_address(from)))
        end)
        
        log.info("create client succeed. "..c)
        for i=1,20 do
            socket.write(c, "hello " .. i)	-- write to the address by udp_connect binding
        end
    end

    skynet.fork(server)
    skynet.fork(client)
    skynet.fork(server_v6)
    skynet.fork(client_v6)
end

--测试随机数
local function test_math_rand()
    for i = 1, 10 do
        log.info("math rand :", i, math.random(1, 500))
        skynet.sleep(math.random(50, 100))
        math.randomseed(os.time(), i)
    end
end

--系统时间
local function test_ostime()
    for i = 1,100000000 do
        math.atan(122,33)
        if i % 10000000 == 0 then
            log.info("os.time:", os.time())
            log.info("skynet.time:", skynet.time())
        end
    end
end

--测试 pairs遍历
local function test_pairs()
    --测试 string key   播放时可以保证顺序
    local t = {}
    for i = 1, 10 do
        t['i' .. i] = i
    end
    for k, v in pairs(t) do
        log.info("string pairs:", k, v)
    end

    --测试number key    播放时可以保证顺序
    local num_t = {}
    for i = 1, 10 do
        local num = math.random(1, 10000)
        num_t[num] = i
    end

    for k,v in pairs(num_t) do
        log.info("number pairs:", k, v)
    end

    --测试table key    播放时不能保证顺序
    local table_t = {}
    for i = 1, 10 do
        table_t[{}] = i
    end
    for k,v in pairs(table_t) do
        log.info("table pairs:", k, v)
    end
end

--测试热更
local function test_hotfix()
    timer:new(timer.second * 5, 0, function()
        log.info("hotfixtest:", hotfix_func.hello())
        log.info("hotfixtest:", hotfix_table)
        log.info("com_test_hotfix:", com_test_hotfix.hello())
        log.info("ccom_test_hotfix:", ccom_test_hotfix.hello())
    end)
end

--测试共享数据
local function test_share_data()
    local l_sharedata_test = sharedata:new('./sharedata/test_data.lua', sharedata.enum.sharedata):builder()
    local c_sharedata_test = sharedata:new('../../commonlualib/sharedata/test_data.lua', sharedata.enum.sharedata):builder()
    local l_sharetable_test = sharedata:new('./sharetable/test_data.lua', sharedata.enum.sharetable):builder()
    local c_sharetable_test = sharedata:new('../../commonlualib/sharetable/test_data.lua', sharedata.enum.sharetable):builder()

    timer:new(timer.second * 5, 0, function()
        log.info("l_sharedata_test >>> ", l_sharedata_test:get_data_table())
        log.info("c_sharedata_test >>> ", c_sharedata_test:get_data_table())
        log.info("l_sharetable_test >>> ", l_sharetable_test:get_data_table())
        log.info("c_sharetable_test >>> ", c_sharetable_test:get_data_table())
    end)
end

function CMD.start()
    skynet.fork(function()
        pcall(test_service_api)
        pcall(test_call)
        pcall(http_call)
        pcall(test_tcp)
        pcall(test_redis)
        pcall(test_utp)
        pcall(test_math_rand)
        pcall(test_ostime)
        pcall(test_pairs)
        pcall(test_hotfix)
        pcall(test_share_data)
    end)
    return true
end

function CMD.ping()
    return "pong"
end

function CMD.exit()
    return true
end

return CMD
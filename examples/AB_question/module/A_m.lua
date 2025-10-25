local container_client = require "skynet-fly.client.container_client"
local timer = require "skynet-fly.timer"
local log = require "skynet-fly.log"
local skynet = require "skynet"

container_client:register("B_m")                    --向B注册访问
container_client:set_week_visitor("B_m")            --设置B为弱访问者，B服务的访问不会阻止A旧服务的退出。
container_client:set_always_swtich("B_m")           --A服务热更后， A的旧服务也会一直切换访问新的B服务

container_client:add_queryed_cb("B_m",function()    --查询到B的地址
    log.info("queryed B_m")
end)

container_client:add_updated_cb("B_m",function()    --收到B服务地址的更新
    log.info("updated B_m")
end)

local CMD = {}

function CMD.start()
    timer:new(timer.second * 3,timer.loop,CMD.send_msg_to_b)
    return true
end

function CMD.herald_exit()
    log.error("预告退出")
end

function CMD.exit()
    log.error("退出")
    return true
end

function CMD.fix_exit()
    log.error("确认要退出")
end

function CMD.cancel_exit()
    log.error("取消退出")
end

function CMD.check_exit()
    log.error("检查退出")
    return true
end

function CMD.send_msg_to_b()
    for i = 1,4 do
        local ret = container_client:instance("B_m"):balance_call("hello")                  --简单轮询负载均衡 (假如B有2个服务B_1,B_2 用balance_call调用2次，将分别调用到B1，B2)
        log.info("balance_call send_msg_to_b:", i, ret)
        --对应send发送方式 balance_send
    end
    for i = 1,4 do
        local ret = container_client:instance("B_m"):set_mod_num(1):mod_call("hello")       --模除映射方式  (用1模除一B_m的服务数量从而达到映射发送到固定服务的目的,不用set_mod_num指定mod,mod默认等于skynet.self()）
        log.info("mod_call send_msg_to_b:", i, ret)
        --对应send发送方式 mod_call
    end

    local ret = container_client:instance("B_m"):broadcast_call("hello")                    --给B_m所有服务发
    log.info("broadcast_call:", ret)
    --对应dend发送方式 broadcast

    --by_name方式   相当于提供子名字，有时候相同的服务可能会划分不同的职责，比如一个游戏可能分为A玩法，B玩法，大体逻辑相同，只有很小的区别，这时候可以用子名字，而不用再写一个可热更服务模块了。
    --by_name方式调用我们必须指定`instance_name`，调用API都是在后面加了_by_name

    for i = 1,4 do
        local ret = container_client:instance("B_m", "test_one"):balance_call_by_name("hello")  --简单轮询负载均衡 (假如B有2个服务B_1,B_2 用balance_call调用2次，将分别调用到B1，B2)会排除非test_one的服务。
        log.info("balance_call_by_name send_msg_to_b test_one:", i, ret)
        --对应send发送方式 balance_send_by_name
    end

    for i = 1,4 do
        local ret = container_client:instance("B_m", "test_two"):set_mod_num(1):mod_call_by_name("hello")       --模除映射方式  (用1模除一B_m的服务数量从而达到映射发送到固定服务的目的,不用set_mod_num指定mod,mod默认等于skynet.self()）
        log.info("mod_call_by_name send_msg_to_b test_two:", i, ret)
        --对应send发送方式 mod_call_by_name
    end

    local ret = container_client:instance("B_m", "test_two"):broadcast_call_by_name("hello")                    --给B_m 子名字为test_two所有服务发
    log.info("broadcast_call_by_name:", ret)
    --对应dend发送方式 broadcast_by_name
end

return CMD
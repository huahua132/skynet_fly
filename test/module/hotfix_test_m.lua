local log = require "skynet-fly.log"
local skynet = require "skynet"
local test_local = hotfix_require "common.hotfix.test_local"
local test_local_function = hotfix_require "common.hotfix.test_local_function"
local test_global = hotfix_require "common.hotfix.test_global"
local test_hot_seq2 = hotfix_require "common.hotfix.test_hot_seq2"
local hot_seq2_interface = require "common.hotfix.hot_seq2_interface"
local test_state_data = hotfix_require "common.hotfix.test_state_data"

local CMD = {}

--测试局部变量
local old_func = test_local.create_func()
local function test_local_test()
    log.info("test_local:",test_local.hello())
    local new_func = test_local.create_func()
    log.info("test_local old_func ret :", old_func())
    log.info("test_local new_func tet :", new_func())
end

--测试局部函数
local function test_local_function_test()
    log.info("test_local_function localfunc:", test_local_function.localfunc())
    log.info("test_local_function changefuncname:", test_local_function.change_func_name())
end

--测试全局变量
local function test_global_test()
    log.info_fmt("test_global test1: %s  %s", test_global.test1(), test_global_a)
    log.info_fmt("test_global test2: %s  %s", test_global.test2(), test_global_b)
    log.info_fmt("test_global test3: %s  %s", test_global.test3(), global_func())
    log.info_fmt("test_global test4: %s  %s", test_global.test4(), global_func_a)
end

--测试热更顺序问题
local function test_seq_test()
    log.info_fmt("test_seq: %s %s", test_hot_seq2.test1())
    log.info_fmt("test_seq: %s ", hot_seq2_interface.test2())
end

--测试状态数据
local function test_state_data_test()
    log.info_fmt("test_state_data: %s", test_state_data.test1())
end

function CMD.start()
    skynet.fork(function()
        while true do
            skynet.sleep(500)
            test_local_test()
            --test_local_function_test()
            --test_global_test()
            --test_seq_test()
            --test_state_data_test()
        end
    end)
   
    return true
end

function CMD.exit()
    return true
end

return CMD
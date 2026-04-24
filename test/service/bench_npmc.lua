local skynet = require "skynet"

local mode = ...

if mode == "consumer" then

skynet.start(function()
    skynet.dispatch("lua", function(session)
        if session ~= 0 then
            skynet.ret()
        end
    end)
end)

elseif mode == "producer" then

skynet.start(function()
    skynet.dispatch("lua", function(_, _, _, consumers, n_message)
        local size = #consumers
        local t0 = skynet.hpc()
        for i = 1, n_message do
            skynet.send(consumers[i % size + 1], "lua")
        end
        local t1 = skynet.hpc()
        -- drain all consumers
        for _, c in ipairs(consumers) do
            skynet.call(c, "lua")
        end
        skynet.ret(skynet.pack(t1 - t0))
    end)
end)

else

local N_CONSUMER    = 10
local N_MESSAGE     = 100000
local PRODUCER_LIST = { 1, 10, 100 }

skynet.start(function()
    -- create consumers
    local consumers = {}
    for i = 1, N_CONSUMER do
        consumers[i] = skynet.newservice(SERVICE_NAME, "consumer")
    end

    -- create max producers
    local max_p = PRODUCER_LIST[#PRODUCER_LIST]
    local producers = {}
    for i = 1, max_p do
        producers[i] = skynet.newservice(SERVICE_NAME, "producer")
    end

    print("======================================")
    print(string.format("bench_npmc: %d consumers, %d msg/producer", N_CONSUMER, N_MESSAGE))
    print("======================================")

    for _, np in ipairs(PRODUCER_LIST) do
        -- launch all producers in parallel via fork, collect via call
        local total_cost = 0
        local done = 0
        for i = 1, np do
            skynet.fork(function()
                local cost = skynet.call(producers[i], "lua", "go", consumers, N_MESSAGE)
                total_cost = total_cost + cost
                done = done + 1
            end)
        end
        -- wait all
        while done < np do
            skynet.sleep(1)
        end

        local avg_cost_ms = total_cost / np / 1e6
        local rps = N_MESSAGE / (avg_cost_ms / 1000)
        local total_msg = np * N_MESSAGE

        print(string.format(
            "[producer=%3d]  total_msg=%d  avg_cost=%.2f ms  rps=%.0f msg/s",
            np, total_msg, avg_cost_ms, rps))
    end

    print("======================================")
    skynet.exit()
end)

end

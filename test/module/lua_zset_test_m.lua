local zset = require "skynet-fly.3rd.zset"
local c = require "skiplist.c"
local skynet = require "skynet"

local CMD = {}

local function test()
    local total = 100
    local all = {}
    for i=1, total do
        all[#all + 1] = i
    end

    local function random_choose(t)
        if #t == 0 then
            return
        end
        local i = math.random(#t)
        return table.remove(t, i)
    end

    local zs = zset.new()

    while true do
        local score = random_choose(all)
        if not score then
            break
        end
        local name = "a" .. score
        zs:add(score, name)
    end

    assert(total == zs:count())

    print("rank 28:", zs:rank("a28"))
    print("rev rank 28:", zs:rev_rank("a28"))

    local t = zs:range(1, 10)
    print("rank 1-10:")
    for _, name in ipairs(t) do
        print(name)
    end

    local t = zs:rev_range(1, 10)
    print("rev rank 1-10:")
    for _, name in ipairs(t) do
        print(name)
    end

    print("------------------ dump ------------------")
    zs:dump()

    print("------------------ dump after limit 10 ------------------")
    zs:limit(10)
    zs:dump()

    print("------------------ dump after rev limit 5 ------------------")
    zs:rev_limit(5)
    zs:dump()

    print("------------------ member_by_rank ------------------")
    for rank = 1, 10 do
        print("rank", rank, zs:member_by_rank(rank))
    end

    print("------------------ member_by_rev_rank ------------------")
    for rank = 1, 10 do
        print("rank", rank, zs:member_by_rev_rank(rank))
    end
end

local function test2()
    print(collectgarbage("count"))
    local sl = c()
    
    local total = 500000
    for i=1, total do
        sl:insert(i, tostring(i))
        sl:insert(i, tostring(i))
    end
    
    for i=1, total do
        sl:delete(i, tostring(i))
    end
    
    --[[
    assert(sl:get_rank(1, "1") == 1)
    assert(sl:get_rank(total, tostring(total)) == total)
    
    local rand = math.random(total)
    print(rand)
    assert(sl:get_rank(rand, tostring(rand)) == rand)
    ]]
    
    local a1, a2 = 100, 100000
    local t1 = sl:get_rank_range(a1, a2)
    local t2 = sl:get_rank_range(a2, a1)
    assert(#t1 == #t2)
    for i, name in pairs(t1) do
        assert(name == t2[#t2 -i + 1], name)
    end
    
    local a1, a2 = 100, 100000
    local t1 = sl:get_score_range(a1, a2)
    local t2 = sl:get_score_range(a2, a1)
    assert(#t1 == #t2)
    for i, name in pairs(t1) do
        assert(name == t2[#t2 -i + 1], name)
    end
    
    local function dump_rank_range(sl, r1, r2)
        print("rank range:", r1, r2)
        local t = sl:get_rank_range(r1, r2)
        for i, name in ipairs(t) do
            if r1 <= r2 then
                print(r1+(i-1), name)
            else
                print(r1-(i-1), name)
            end
        end
    end
    
    local r1, r2 = 2, 5
    dump_rank_range(sl, r1, r2)
    dump_rank_range(sl, r2, r1)
    
    
    local function dump_score_range(sl, s1, s2)
        print("score range:", s1, s2)
        local t = sl:get_score_range(s1, s2)
        for _, name in ipairs(t) do
            print(name)
        end
    end
    
    dump_score_range(sl, 10, 15)
    dump_score_range(sl, 15, 10)
    
    function delete_cb(member)
        print("delete:", member)
    end
    sl:delete_by_rank(15, 10, delete_cb)
    
    print(collectgarbage("count"))
    sl = nil
    collectgarbage("collect")
    print(collectgarbage("count"))

    skynet.fork(function()
        collectgarbage("collect")
        print(collectgarbage("count"))    
    end)
end

function CMD.start()
    --test()
    test2()
    collectgarbage("collect")
    print(collectgarbage("count"))    
    collectgarbage("collect")
    print(collectgarbage("count"))    
    collectgarbage("collect")
    print(collectgarbage("count"))    
    collectgarbage("collect")
    print(collectgarbage("count"))
    collectgarbage("collect")
    print(collectgarbage("count"))
    collectgarbage("collect")
    print(collectgarbage("count"))
    collectgarbage("collect")
    print(collectgarbage("count"))
    collectgarbage("collect")
    print(collectgarbage("count"))
    collectgarbage("collect")
    print(collectgarbage("count"))
    return true
end

function CMD.exit()
    return true
end

return CMD
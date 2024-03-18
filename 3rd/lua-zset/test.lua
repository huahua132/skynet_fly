local zset = require "zset"

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

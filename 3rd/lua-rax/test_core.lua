local rax_core = require "rax.core"

local rtree = rax_core.new()
local it = rax_core.newit(rtree)

rax_core.insert(rtree, "/blog/foo/", 1)
rax_core.insert(rtree, "/blog/foo/a/", 2)
rax_core.insert(rtree, "/blog/foo/c/", 3)
rax_core.insert(rtree, "/blog/foo/bar", 4)

local idx = rax_core.find(rtree, "/blog/foo/bar")
assert(idx == 4)

local function match(path)
    local ret = rax_core.search(it, path)
    if not ret then
        error("search failed.")
    end
    while true do
        local idx = rax_core.prev(it, path)
        if idx <= 0 then
            break
        end
        print(idx)
        return idx
    end
end

local path = "/blog/foo/a/b/c"
local idx = match(path)
assert(idx == 2)

local path = "/blog/foo/c/d"
local idx = match(path)
assert(idx == 3)

local path = "/blog/foo/xloo"
local idx = match(path)
assert(idx == 1)

rax_core.dump(rtree)
rax_core.destroy(rtree)

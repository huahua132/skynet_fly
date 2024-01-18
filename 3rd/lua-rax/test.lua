local rax = require "rax"

function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k,v in pairs(o) do
            if type(k) ~= 'number' then k = '"'..k..'"' end
            s = s .. '['..k..'] = ' .. dump(v) .. ', '
        end
        return s .. '} '
    else
        return string.format("%q", o)
    end
end

local route = rax:new()
route:insert("GET", "/1/:id", "t1")
route:insert("POST", "/2", "t2")
route:insert({"GET", "POST"}, "/3/:name/:fuck/*/*", "t3")
route:insert("GET", "/blog/bar*", "t4")
route:insert("GET", "/blog/foo/*", "t5")
route:insert("GET", "/blog/foo/a/*", "t6")
route:insert("GET", "/blog/foo/c/*", "t7")
route:insert("GET", "/blog/foo/bar", "t8")
route:compile()

local function test_match(path, method, ret)
    print("--- try match", path)
    local data, params = route:match(path, method)
    print("match result. data:", dump(data))
    print("params:", dump(params))
    assert(data == ret, "match failed")
    print("match", path, "ok")
    print("--- end match", path, "\n")
end

test_match("/1", "GET", nil)
test_match("/1/hanxi", "GET", "t1")
test_match("/2", "GET", nil)
test_match("/2", "POST", "t2")
test_match("/3/n/f/k1/k2", "GET", "t3")
test_match("/3/nn/ff/k1/k2", "POST", "t3")


test_match("/blog/bar", "GET", "t4")
test_match("/blog/bar/a", "GET", "t4")
test_match("/blog/bar/b", "GET", "t4")
test_match("/blog/bar/c/d/e", "GET", "t4")


test_match("/blog/foo/bar", "GET", "t8")
test_match("/blog/foo/a/b/c", "GET", "t6")
test_match("/blog/foo/c/d", "GET", "t7")
test_match("/blog/foo/gloo", "GET", "t5")
test_match("/blog/fuck", "GET", nil)

route:dump()


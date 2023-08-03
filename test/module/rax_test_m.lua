local rax = require "rax"
local log = require "log"

local CMD = {}

function CMD.start()
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
		log.info("--- try match", path)
		local data, params = route:match(path, method)
		log.info("match result. data:", data)
		log.info("params:", params)

		log.error("test_match:",data,ret,params,path,method)
		assert(data == ret, "match failed")
		log.info("match", path, "ok")
		log.info("--- end match", path, "\n")
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

	return true
end

function CMD.exit()

end

return CMD
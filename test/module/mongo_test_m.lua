local mongof = require "mongof"
local skynet = require "skynet"
local log = require "log"

local CMD = {}

local function test()
    local ok, err, ret
    local db = mongof.new_client('admin')
    db.testcoll:drop_index("*")
    db.testcoll:drop()
    ok, err, ret = db.testcoll:safe_insert({test_key = 1});
	assert(ok and ret and ret.n == 1, err)

	ok, err, ret = db.testcoll:safe_insert({test_key = 2});
	assert(ok and ret and ret.n == 1, err)

    ret = db.testcoll:find({})
    log.info("count:",ret:count())
    local ret_list = {}
    while ret:has_next() do
        local one_ret = ret:next()
        one_ret['_id'] = nil
        table.insert(ret_list, one_ret)
    end

    log.info("ret:",ret_list)

    ret = db.testcoll:find_one({test_key = 1})
    ret['_id'] = nil
    log.info("ret:", ret)
end

function CMD.start()
    skynet.fork(test)
    return true
end

function CMD.exit()
    return true
end

return CMD
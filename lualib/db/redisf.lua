local skynet = require "skynet"
local redis = require "skynet.db.redis"

local setmetatable = setmetatable
local assert = assert

local M = {}
local meta = {__index = M}

function M:new(db_name)
	
end

return M
local M = {}
local mt = {__index = M}
local wmt = {__mode = "kv"}

local assert = assert
local tinsert = table.insert
local tremove = table.remove
local type = type

local setmetatable = setmetatable

function M:new(creator)
	local t = {
        pool_list = setmetatable({}, wmt),
        creator = creator,
    }
	setmetatable(t, mt)
	return t
end

function M:get()
    local obj = tremove(self.pool_list)
    if obj then return obj end
    return self.creator()
end

function M:release(obj)
	local pool_list = self.pool_list
    pool_list[#pool_list + 1] = obj
end

return M
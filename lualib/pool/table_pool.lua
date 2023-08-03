local M = {}
local mt = {__index = M}

local assert = assert
local tinsert = table.insert
local tremove = table.remove
local type = type

local setmetatable = setmetatable

function M:new(cap)
	local t = {
		cap = cap,
		len = cap,
		list = {},
	}
	for i = 1,cap do
		tinsert(t.list,{})
	end
	setmetatable(t,mt)
	return t
end

function M:get()
	if self.len > 0 then
		local t = tremove(self.list,self.len)
		self.len = self.len - 1
		return t
	else
		return {}
	end
end

function M:release(t)
	assert(type(t) == 'table')
	if self.len >= self.cap then
		return
	end

	self.len = self.len + 1
	tinsert(self.list,t)
	return true
end

return M
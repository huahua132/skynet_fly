
--[===================================================================[
TODO:
	- add a nice header with license and stuff..
	- detect plain text files
	- proper testing
	- improve implementation?
	- check gzopen flags for consistency (ex: strategy flag)
--]===================================================================]

local io = require 'io'
local zlib = require 'zlib'

local error, assert, setmetatable, tostring = error, assert, setmetatable, tostring

local _M = {}

function _M.open(filename, mode)
	mode = mode or 'r'
	local r = mode:find('r', 1, true) and true
	local w = mode:find('w', 1, true) and true
	local level = -1

	local lstart, lend = mode:find('%d')
	if (lstart and lend) then
		level = mode:sub(lstart, lend)
	end

	if (not (r or w)) then
		error('file open mode must specify read or write operation')
	end

	local f, z

	local mt = {
		__index = {
			read = function(self, ...)
				return z:read(...)
			end,
			write = function(self, ...)
				return z:write(...)
			end,
			seek = function(self, ...)
				error 'seek not supported on gzip files'
			end,
			lines = function(self, ...)
				return z:lines(...)
			end,
			flush = function(self, ...)
				return z:flush(...) and f:flush()
			end,
			close = function(self, ...)
				return z:close() and f:close()
			end,
		},
		__tostring = function(self)
			return 'gzip object (' .. mode .. ') [' .. tostring(z) .. '] [' .. tostring(f) .. ']'
		end,
	}

	if r then
		f = assert(io.open(filename, 'rb'))
		z = assert(zlib.inflate(f))
	else
		f = assert(io.open(filename, 'wb'))
		z = assert(zlib.deflate(f, level, nil, 15 + 16))
	end

	return setmetatable({}, mt)
end

function _M.lines(filename)
	local gz = _M.open(filename, 'r')
	return function()
		local line = gz and gz:read()
		if line == nil then
			gz:close()
		end
		return line
	end
end

return _M
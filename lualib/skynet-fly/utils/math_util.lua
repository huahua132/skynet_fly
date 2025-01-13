---#API
---#content ---
---#content title: math_util math相关
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","工具函数"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [math_util](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/utils/math_util.lua)
local math = math
local tonumber = tonumber
local string = string
local type = type
local sformat = string.format

local M = {}

---#desc 计算2个经纬度的距离
---@param lon1 number 位置1经度
---@param lat1 number 位置1纬度
---@param lon2 number 位置2经度
---@param lat2 number 位置2纬度
---@return number 距离(米)
function M.haversine(lon1,lat1,lon2,lat2)
	local dlat = math.pi / 180 * (lat2 - lat1)
	local dlon = math.pi / 180 * (lon2 - lon1)
	local lat1 = math.pi / 180 * lat1
	local lat2 = math.pi / 180 * lat2
	local a = math.sin(dlat / 2)^2 + math.sin(dlon / 2)^2 * math.cos(lat1) * math.cos(lat2)
	local c = 2 * math.atan(math.sqrt(a),math.sqrt(1 - a))
	return 6371000 * c
end

---#desc 获取min max
---@param min number 值1
---@param max number 值2
---@return number 较小的
---@return number 较大的
function M.get_min_max(min,max)
	if min <= max then
		return min,max
	else
		return max,min
	end
end

---#desc num/div_num 并保留div_num位小数
---@param num number 值1
---@param div_num number 值2
---@return string 较小的
function M.number_div_str(num, div_num)
	local format = '%0.' .. div_num .. 'f'
	local div = 1
	for i = 1,div_num do
	  div = div * 10
	end
	local res = string.format(format, num / div)
	local result = string.match(res, "^(.-)0*$") -- 使用正则表达式匹配去掉0
	if result:sub(-1) == "." then -- 如果最后一位是小数点
		result = result:sub(1, -2) -- 去掉小数点
	end
	return result
end

M.int8min = -(1 << 7)
M.int8max = (1 << 7) - 1
M.uint8min = 0
M.uint8max = (1 << 8) - 1
M.int16min = -(1 << 15)
M.int16max = (1 << 15) - 1
M.uint16min = 0
M.uint16max = (1 << 16) - 1
M.int32min = -(1 << 31)
M.int32max = (1 << 31) - 1
M.uint32min = 0
M.uint32max = (1 << 32) - 1
M.int64min = -(1 << 63)
M.int64max = (1 << 63) - 1

---#desc 是否有效的int8
---@param num number
function M.is_vaild_int8(num)
	if type(num) ~= 'number' then return false end
	return num >= M.int8min and num <= M.int8max
end

---#desc 是否有效的uint8
---@param num number
function M.is_vaild_uint8(num)
	if type(num) ~= 'number' then return false end
	return num >= M.uint8min and num <= M.uint8max
end

--@desc 是否有效的int16
---@param num number
function M.is_vaild_int16(num)
	if type(num) ~= 'number' then return false end
	return num >= M.int16min and num <= M.int16max
end

---#desc 是否有效的uint16
---@param num number
function M.is_vaild_uint16(num)
	if type(num) ~= 'number' then return false end
	return num >= M.uint16min and num <= M.uint16max
end

---#desc 是否有效的int32
---@param num number
function M.is_vaild_int32(num)
	if type(num) ~= 'number' then return false end
	return num >= M.int32min and num <= M.int32max
end

---#desc 是否有效的uint32
---@param num number
function M.is_vaild_uint32(num)
	if type(num) ~= 'number' then return false end
	return num >= M.uint32min and num <= M.uint32max
end

---#desc 是否有效的int64
---@param num number
function M.is_vaild_int64(num)
	if type(num) ~= 'number' then return false end
	return num >= M.int64min and num <= M.int64max
end

return M
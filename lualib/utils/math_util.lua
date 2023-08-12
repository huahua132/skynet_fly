local math = math
local tonumber = tonumber
local string = string

local M = {}

--计算2个经纬度的距离
function M.haversine(lon1,lat1,lon2,lat2)
	local dlat = math.pi / 180 * (lat2 - lat1)
	local dlon = math.pi / 180 * (lon2 - lon1)
	local lat1 = math.pi / 180 * lat1
	local lat2 = math.pi / 180 * lat2
	local a = math.sin(dlat / 2)^2 + math.sin(dlon / 2)^2 * math.cos(lat1) * math.cos(lat2)
	local c = 2 * math.atan(math.sqrt(a),math.sqrt(1 - a))
	return 6371000 * c
end

--对比大小
function M.get_min_max(min,max)
	if min <= max then
		return min,max
	else
		return max,min
	end
end

function M.number_div_str(num,div_num)
	num = tonumber(num)
	local format = '%0.' .. div_num .. 'f'
	local div = 1
	for i = 1,div_num do
	  div = div * 10
	end
	local res = string.format(format,num / div)
	local result = string.match(res, "^(.-)0*$") -- 使用正则表达式匹配去掉0
	if result:sub(-1) == "." then -- 如果最后一位是小数点
		result = result:sub(1, -2) -- 去掉小数点
	end
	return result
end

return M
local math = math

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

return M
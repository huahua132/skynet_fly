local skynet = require "skynet"
local setmetatable = setmetatable
local assert = assert
local select = select
local pcall = pcall
local ipairs = ipairs
local tunpack = table.unpack

local SELF_ADDRESS = skynet.self()
local g_balance_num_map = {}
local g_version_map = {}

local g_module_id_list_map = setmetatable({},{__index = function(t,key)
	t[key],g_version_map[key] = skynet.call('.contriner_mgr','lua','query',key)
	assert(t[key],"query err " .. key)
	skynet.error(SELF_ADDRESS .. " update " .. key .. " address " .. table.concat(t[key],','))
	g_balance_num_map[key] = 1
	return t[key]
end})

local function call(module_name,server_id,...)
	local ret = {pcall(skynet.call,server_id,'lua',module_name,g_version_map[module_name],...)}
	local is_ok = ret[1]
	local code = ret[2]
	if not is_ok then
		g_module_id_list_map[module_name] = nil
		g_balance_num_map[module_name] = nil
		g_version_map[module_name] = nil
	elseif code == "move" then
		g_module_id_list_map[module_name] = ret[3]
		g_balance_num_map[module_name] = 1
	else
		return select(2,tunpack(ret))
	end
	return nil
end

function skynet.contriner_mod_call(module_name,...)
	for i = 1,2 do
		local id_list = g_module_id_list_map[module_name]
		local index = SELF_ADDRESS % #id_list + 1
		local server_id = id_list[index]
		local ret = {call(module_name,server_id,...)}
		local code = ret[1]
		if code == "OK" then
			return select(2,tunpack(ret))
		end
	end
end


function skynet.contriner_balance_call(module_name,...)
	for i = 1,2 do
		local id_list = g_module_id_list_map[module_name]
		local len = #id_list
		local index = g_balance_num_map[module_name]
		local server_id = id_list[index]
		index = index + 1
		if index > len then
			index = 1
		end
		g_balance_num_map[module_name] = index
		local ret = {call(module_name,server_id,...)}
		local code = ret[1]
		if code == "OK" then
			return select(1,ret)
		end
	end
end

function skynet.contriner_broadcast(module_name,...)
	for i = 1,2 do
		local id_list = g_module_id_list_map[module_name]
		for _,id in ipairs(id_list) do
			local ret = {call(module_name,id,...)}
			local code = ret[1]
			if code ~= "OK" then
				break
			end
		end
	end
end

return skynet
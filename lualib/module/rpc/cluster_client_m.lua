local skynet = require "skynet"
local cluster = require "cluster"
local timer = require "timer"
local log = require "log"

local tonumber = tonumber
local assert = assert
local pairs = pairs
local ipairs = ipairs
local next = next
local tinsert = table.insert
local tremove = table.remove
local tunpack = table.unpack
local x_pcall = x_pcall

local g_node_info_map = {}
local g_config = nil

local function add_node(svr_name,svr_id,host)
	svr_id = tonumber(svr_id)
	assert(svr_name, "not svr_name")
	assert(svr_id, "not svr_id")
	assert(host, "not host")
	if not g_node_info_map[svr_name] then
		g_node_info_map[svr_name] = {
			name_list = {},           --结点名称列表
			host_list = {},			  --结点地址列表
			id_name_map = {},		  --svr_id映射结点名称
			balance = 1,              --简单轮询负载均衡
		}
	end

	local node_info = g_node_info_map[svr_name]
	local id_name_map = node_info.id_name_map
	assert(not id_name_map[svr_id], "is exists " .. svr_id)
	
	local name_list = node_info.name_list
	local host_list = node_info.host_list

	local cluster_name = svr_name .. '_' .. svr_id
	tinsert(name_list,cluster_name)
	tinsert(host_list,host)
	id_name_map[svr_id] = cluster_name

	cluster.reload{[cluster_name] = host}
end

local function del_node(svr_name,svr_id)
	svr_id = tonumber(svr_id)
	assert(svr_name, "not svr_name")
	assert(svr_id, "not svr_id")
	assert(g_node_info_map[svr_name],"not exists " .. svr_name)

	local node_info = g_node_info_map[svr_name]
	local id_name_map = node_info.id_name_map
	local cluster_name = id_name_map[svr_id]
	assert(cluster_name,"del_node not exists " .. svr_name .. '_' .. svr_id)

	local name_list = node_info.name_list
	local host_list = node_info.host_list

	local del_index = nil
	for i = #name_list,1,-1 do
		local tmp_name = name_list[i]
		if tmp_name == cluster_name then
			del_index = i
			break
		end
	end

	assert(del_index,"del_node not exists " .. cluster_name)
	tremove(name_list,del_index)
	tremove(host_list,del_index)
	node_info.balance = 1
	if not next(name_list) then
		g_node_info_map[svr_name] = nil
	end
end

local function get_balance(node_info)
	local name_list = node_info.name_list
	local len = #name_list
	local balance = node_info.balance

	node_info.balance = node_info.balance + 1
	if node_info.balance > len then
		node_info.balance = 1
	end
	return balance
end

local CMD = {}

--轮询给单个集群结点发
function CMD.balance_send(svr_name,...)
	assert(g_node_info_map[svr_name],"balance_send not exists " .. svr_name)
	local node_info = g_node_info_map[svr_name]
	local name_list = node_info.name_list

	local index = get_balance(node_info)
	local cluster_name = name_list[index]
	cluster.send(cluster_name,"@cluster_server",...)
end

--轮询给单个集群结点发
function CMD.balance_call(svr_name,...)
	assert(g_node_info_map[svr_name],"balance_send not exists " .. svr_name)
	local node_info = g_node_info_map[svr_name]
	local name_list = node_info.name_list

	local index = get_balance(node_info)
	local cluster_name = name_list[index]
	return cluster.call(cluster_name,"@cluster_server",...)
end

--给集群所有结点发
function CMD.send_all(svr_name,...)
	assert(g_node_info_map[svr_name],"balance_send not exists " .. svr_name)
	local node_info = g_node_info_map[svr_name]
	local name_list = node_info.name_list
	for _,cluster_name in ipairs(name_list) do
		cluster.send(cluster_name,"@cluster_server",...)
	end
end

--给集群所有结点发
function CMD.call_all(svr_name,...)
	assert(g_node_info_map[svr_name],"balance_send not exists " .. svr_name)
	local node_info = g_node_info_map[svr_name]
	local name_list = node_info.name_list
	local host_list = node_info.host_list

	local res = {}
	for i,cluster_name in ipairs(name_list) do
		local ret = {x_pcall(cluster.call,cluster_name,"@cluster_server",...)}
		local isok = tremove(ret,1)
		if not isok then
			log.error("call_all err ",svr_name,cluster_name,tunpack(ret))
		end
		local host = host_list[i]
		tinsert(res,{cluster_name = cluster_name,host = host, result = ret})
	end

	return res
end

function CMD.before_exit()
	local node_map = g_config.node_map
	for svr_name,node in pairs(node_map) do
		for svr_id,host in pairs(node) do
			del_node(svr_name,svr_id,host)
		end
	end
end

function CMD.start(config)
	g_config = config
	local node_map = config.node_map
	assert(node_map, "not node_map")
	cluster.reload {['__nowaiting'] = true}

	for svr_name,node in pairs(node_map) do
		for svr_id,host in pairs(node) do
			add_node(svr_name,svr_id,host)
		end
	end
	return true
end

function CMD.exit()
	timer:new(timer.second,1,skynet.exit)
end

return CMD
local skynet = require "skynet"
local cluster = require "cluster"
local contriner_client = require "contriner_client"
local rpc_redis = require "rpc_redis"
local log = require "log"
local timer = require "timer"

local assert = assert
local tonumber = tonumber
local setmetatable = setmetatable
local type = type
local string = string

local g_svr_name = skynet.getenv("svr_name")
local g_svr_id = tonumber(skynet.getenv("svr_id"))

local g_client_map = setmetatable({},{__index = function(t,key)
	t[key] = contriner_client:new(key)
	return t[key]
end})

local CMD = {}

--简单轮询负载均衡
function CMD.balance_send(module_name,...)
	assert(module_name,"not module_name")
	local cli = g_client_map[module_name]
	cli:balance_send(...)
end

function CMD.balance_call(module_name,...)
	assert(module_name,"not module_name")
	local cli = g_client_map[module_name]
	return cli:balance_call(...)
end

--模除以映射
function CMD.mod_send(module_name,mod_num,...)
	assert(module_name,"not module_name")
	assert(mod_num and type(mod_num) == 'number',"not mod_num")
	local cli = g_client_map[module_name]
	cli:set_mod_num(mod_num)
	cli:mod_send(...)
end

function CMD.mod_call(module_name,mod_num,...)
	assert(module_name,"not module_name")
	assert(mod_num and type(mod_num) == 'number',"not mod_num")
	local cli = g_client_map[module_name]
	cli:set_mod_num(mod_num)
	return cli:mod_call(...)
end

--广播
function CMD.broadcast(module_name,...)
	assert(module_name,"not module_name")
	local cli = g_client_map[module_name]
	cli:broadcast(...)
end

--------------------------------------------------------------
--二级
--------------------------------------------------------------
function CMD.balance_send_by_name(module_name,instance_name,...)
	assert(module_name,"not module_name")
	assert(instance_name,"not instance_name")
	local cli = g_client_map[module_name]
	cli:set_instance_name(instance_name)
	cli:balance_send_by_name(...)
end

function CMD.balance_call_by_name(module_name,instance_name,...)
	assert(module_name,"not module_name")
	assert(instance_name,"not instance_name")
	local cli = g_client_map[module_name]
	cli:set_instance_name(instance_name)
	return cli:balance_call_by_name(...)
end

function CMD.mod_send_by_name(module_name,instance_name,mod_num,...)
	assert(module_name,"not module_name")
	assert(instance_name,"not instance_name")
	assert(mod_num and type(mod_num) == 'number',"not mod_num")
	local cli = g_client_map[module_name]
	cli:set_instance_name(instance_name)
	cli:set_mod_num(mod_num)
	cli:mod_send_by_name(...)
end

function CMD.mod_call_by_name(module_name,instance_name,mod_num,...)
	assert(module_name,"not module_name")
	assert(instance_name,"not instance_name")
	assert(mod_num and type(mod_num) == 'number',"not mod_num")
	local cli = g_client_map[module_name]
	cli:set_instance_name(instance_name)
	cli:set_mod_num(mod_num)
	return cli:mod_call_by_name(...)
end

function CMD.broadcast_by_name(module_name,instance_name,...)
	assert(module_name,"not module_name")
	assert(instance_name,"not instance_name")
	local cli = g_client_map[module_name]
	cli:set_instance_name(instance_name)
	cli:broadcast_by_name(...)
end

skynet.start(function()
	skynet.dispatch('lua',function(session,source,cmd,...)
		local f = CMD[cmd]
		assert(f,'cmd no found :'..cmd)
	
		if session == 0 then
			f(...)
		else
			skynet.retpack(f(...))
		end
	end)

	local confclient = contriner_client:new("share_config_m")
	local conf = confclient:mod_call('query','cluster_server')
	assert(conf.host,"not host")
	
	local register = conf.register
	if register == 'redis' then --注册到redis
		local rpccli = rpc_redis:new()
		--一秒写一次
		timer:new(timer.second,0,function()
			rpccli:register(g_svr_name,g_svr_id,conf.host)
		end)
	end

	cluster.register("cluster_server",skynet.self())
	cluster.reload{[g_svr_name] = conf.host,['__nowaiting'] = true}

	local addr,port = cluster.open(g_svr_name)
	if addr then
		log.error("open cluster_server succ ",g_svr_name,conf.host,addr,port,register)
	else
		log.fatal("open cluster_server err ",g_svr_name,conf.host)
	end
end)
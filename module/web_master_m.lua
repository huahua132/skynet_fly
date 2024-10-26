
local skynet = require "skynet"
local socket = require "skynet.socket"
local log = require "skynet-fly.log"
local tti = require "skynet-fly.cache.tti"
local string_util = require "skynet-fly.utils.string_util"
local contriner_client = require "skynet-fly.client.contriner_client"
local timer = require "skynet-fly.timer"

contriner_client:register("web_agent_m")

local table  = table
local string = string
local assert = assert
local math = math
local os = os
local ipairs = ipairs
local tonumber = tonumber
local next = next
local pcall = pcall

local g_config = nil
local agent_client
local SELF_ADDRESS
local listen_fd
local max_client
local client_num = 0
local second_conn_limit = 0
local keep_live_limit = 0
local fd_agent_map = {}
local is_close_map = {}                      --close消息先到
---------------------------------------------
--protect
---------------------------------------------
local limit_conn_sum_map = {}                --1秒内建立连接的次数
local keep_live_list_map = {}                --相同ip的连接fd
local lock_kick_num_map = {}
local lock_kick_map = {}

local ip_connnect_cnt_cache = tti:new(100,function(ip)
	limit_conn_sum_map[ip] = nil
end)

local black_ip_map = {}
--连接建立之前检查
local function check_addr(ip,port,fd)
	if fd_agent_map[fd] then
		log.warn("rpeat fd:",fd)
		return false
	end

	if client_num >= max_client then
		log.warn("client_num full",max_client)
		return false
	end

	if limit_conn_sum_map[ip] and limit_conn_sum_map[ip] >= second_conn_limit then
		log.warn("connect so frequently ",ip,limit_conn_sum_map[ip],second_conn_limit)
		return false
	end

	local keep_live_list = keep_live_list_map[ip]
	local lock_kick_num = lock_kick_num_map[ip] or 0
	local keep_live_num = keep_live_list and #keep_live_list or 0
	if lock_kick_num >= keep_live_limit then
		log.warn("beyond keep live limit ",keep_live_num,lock_kick_num,keep_live_limit,client_num)
		return false
	end

	if black_ip_map[ip] then
		log.warn("black_ip ",ip)
		return false
	end
	return true
end
--连接建立
local function connect_succ(ip,port,fd,agent_id)
	if is_close_map[fd] then
		is_close_map[fd] = nil
		return
	end

	client_num = client_num + 1

	if not keep_live_list_map[ip] then
		keep_live_list_map[ip] = {}
		lock_kick_num_map[ip] = 0
	end

	if not limit_conn_sum_map[ip] then
		limit_conn_sum_map[ip] = 0
		ip_connnect_cnt_cache:set_cache(ip,true)
	end

	limit_conn_sum_map[ip] = limit_conn_sum_map[ip] + 1

	local keep_live_list = keep_live_list_map[ip]
	if #keep_live_list >= keep_live_limit then
		local rm_fd = nil
		for _,rfd in ipairs(keep_live_list) do
			if not lock_kick_map[rfd] then
			rm_fd = rfd
			break
			end
		end
		if rm_fd then
			local rm_fd_agent_id = fd_agent_map[rm_fd]
			if not rm_fd_agent_id then
			log.warn("connect_succ rm_fd_agent_id err",rm_fd)
			else
			lock_kick_map[rm_fd] = true
			lock_kick_num_map[ip] = lock_kick_num_map[ip] + 1
			skynet.send(rm_fd_agent_id,'lua','socket','close',rm_fd)
			end
		else
			log.warn("connect_succ beyond keep_live_limit err")
		end
	end

	table.insert(keep_live_list,fd)
	fd_agent_map[fd] = agent_id
end
--连接关闭之后
local function end_func(ip,port,fd)
	if not fd_agent_map[fd] then
		is_close_map[fd] = true
		return
	end
	client_num = client_num - 1
	local keep_live_list = keep_live_list_map[ip]

	for i = 1,#keep_live_list do
		if keep_live_list[i] == fd then
			table.remove(keep_live_list,i)
			break
		end
	end

	if lock_kick_map[fd] then
		lock_kick_map[fd] = nil
		lock_kick_num_map[ip] = lock_kick_num_map[ip] - 1
	end

	if #keep_live_list <= 0 then
		keep_live_list_map[ip] = nil
		lock_kick_num_map[ip] = nil
	end

	fd_agent_map[fd] = nil
end
---------------------------------------------------------------------------
---------------------------------------------------------------------------
local CMD = {}

function CMD.add_black(ip)
	black_ip_map[ip] = true
end

function CMD.del_black(ip)
	black_ip_map[ip] = nil
end

function CMD.get_black_ip_map()
	return black_ip_map
end

local SOCKET = {}
function CMD.socket(cmd,...)
	assert(SOCKET[cmd],"SOCKET cmd not exist")
	return SOCKET[cmd](...)
end

function SOCKET.closed(fd,ip,port)
	end_func(ip,port,fd)
end

function CMD.start(args)
	g_config = args
	max_client = args.max_client or 2048
	second_conn_limit = args.second_conn_limit or 60         --相同ip一秒内建立连接数量限制
	keep_live_limit = args.keep_live_limit or 50			 --相同ip保持连接数量限制
	assert(not listen_fd)
	local host = args.host or "0.0.0.0"
	local port = tonumber(args.port)
	local protocol = args.protocol
	assert(protocol == 'http' or protocol == 'https')

	if not port then
		port = (protocol == 'http' and 80) or (protocol == 'https' and 443)
	end

	assert(port, "[serverd] need port")
	SELF_ADDRESS = skynet.self()
	listen_fd = socket.listen(host, port)
	log.info(string.format("Listening %s://%s:%s max_client[%s] id[%s]", protocol, host, port, max_client,listen_fd))

	socket.start(listen_fd, function(fd, addr)
		if not agent_client then
			agent_client = contriner_client:new("web_agent_m")
		end
		local addrs = string_util.split(addr,':')
		local ip,port = addrs[1],addrs[2]
		if not ip or not port then
			socket.close_fd(fd)
			log.warn("connect err ",addr,ip,port)
			return
		end

		if not check_addr(ip,port,fd) then
			socket.close_fd(fd)
			log.warn("unsafe addr ",addr)
			return
		end
		local agent_id = agent_client:balance_call('socket','enter',fd,ip,port,SELF_ADDRESS)
		if not agent_id then
			socket.close_fd(fd)
		else
			connect_succ(ip,port,fd,agent_id)
		end
	end)

	return true
end

--预告退出
function CMD.herald_exit()
	--这里关闭监听，新服务会重启监听
	socket.close(listen_fd)
	listen_fd = nil
end

--取消退出
function CMD.cancel_exit()
	log.info("取消退出")
	CMD.start(g_config)
end

--检查退出
function CMD.check_exit()
	return not next(fd_agent_map)
end

--退出
function CMD.exit()
	return true
end

return CMD

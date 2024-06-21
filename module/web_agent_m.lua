
local skynet = require "skynet"
local handle_web = require "skynet-fly.web.handle_web"
local socket = require "skynet.socket"
local log = require "skynet-fly.log"
local tti = require "skynet-fly.cache.tti"
local table_pool = require "skynet-fly.pool.table_pool":new(2048)
local timer = require "skynet-fly.timer"
local skynet_util = require "skynet-fly.utils.skynet_util"
local time_util = require "skynet-fly.utils.time_util"

local table  = table
local string = string
local pcall = pcall
local type = type
local assert = assert
local pairs = pairs
local x_pcall = x_pcall
local next = next

local FD_STATE = {
  connecting = 1,    --连接中
  reading = 2,       --读取中
  handle_rspping = 3,--处理回应中
}

local web
local protocol
local SELF_ADDRESS

local keep_alive_time = nil          --保活时间
local second_req_limit = nil         --秒内请求次数限制
local max_packge_limit = nil         --消息包最大长度
local check_inval = 60 * 5
local fd_info_map = {}

local enter_map = {}
local req_cnt_map = {}


local req_cnt_cache = tti:new(100,function(fd)
	req_cnt_map[fd] = nil
end) --用于一秒内请求数量限制

---------------------------------------------
--check
---------------------------------------------
local function close_fd(fd)
	if not fd_info_map[fd] then return end
	local fd_info = fd_info_map[fd]
	fd_info.keep_alive = false
	if fd_info.state ~= FD_STATE.handle_rspping then
		socket.shutdown(fd)
	end
end

local enter_cache = tti:new(1000,function(fd,addr) 
	if enter_map[fd] then
		log.warn("enter_timer_out:",fd,addr)
		skynet.fork(close_fd,fd)
	end
end)--用于检测是否及时完成链接 请求 响应的流程，没有完成即可能是恶意链接

local function check_func()
	local now_time = time_util.time()
	local cnt = 0
	for fd,info in pairs(fd_info_map) do
		local sub_time = now_time - info.pre_msg_time
		if sub_time >= keep_alive_time then
			skynet.fork(close_fd,fd)
		end
		cnt = cnt + 1
		if cnt % 1000 == 0 then
			skynet.sleep(1)
		end
	end
end

local function check_time_out_loop()
	check_func()
	skynet.timeout(check_inval * 100,check_time_out_loop)
end

---------------------------------------------
--slave service
---------------------------------------------
local CMD = {}

local function handle_func(req)
	local fd = req.fd
	enter_map[fd] = nil
	local cur_time = time_util.time()
	fd_info_map[fd].pre_msg_time = cur_time

	if req_cnt_cache:get_cache(fd) then
		req_cnt_map[fd] = req_cnt_map[fd] + 1
	else
		req_cnt_cache:set_cache(fd,true)
		req_cnt_map[fd] = 1
	end

	local req_cnt = req_cnt_map[fd]
	if req_cnt > second_req_limit then
		log.warn("request so buzy ",fd,req_cnt,second_req_limit)
		return 400
	end
	return web.dispatch(req)
end

local SOCKET = {}
function CMD.socket(cmd,...)
	assert(SOCKET[cmd],"SOCKET cmd not exist")
	return SOCKET[cmd](...)
end

local function clear_fd(fd)
	local ot = fd_info_map[fd]
	if ot then
		table_pool:release(ot)
	end
	fd_info_map[fd] = nil
	enter_map[fd] = nil
end

function SOCKET.enter(fd, ip, port, master_id)
	if enter_cache:get_cache(fd) then
		log.warn("repeat enter fd:",fd,ip,port)
	end

	enter_map[fd] = ip
	enter_cache:set_cache(fd,ip)
	local conn_time = time_util.time()

	local new_fd_info = table_pool:get()
	new_fd_info.pre_msg_time = conn_time
	new_fd_info.state = FD_STATE.connecting
	new_fd_info.keep_alive = true
	fd_info_map[fd] = new_fd_info

	local is_ok,handle = pcall(handle_web, fd, ip, port, protocol, handle_func, max_packge_limit)
	if not is_ok then
		log.warn("handle_web err ",handle)
		clear_fd(fd)
		skynet.fork(socket.close,fd)
		return
	end

	local fd_info = fd_info_map[fd]
	fd_info.handle = handle
	local keep_alive = true

	socket.onclose(fd, function()
		fd_info.keep_alive = false
	end)
	skynet.retpack(SELF_ADDRESS)

	while keep_alive do
		fd_info.state = FD_STATE.reading
		local ret = handle.read_request()
		if not ret then break end
		fd_info.state = FD_STATE.handle_rspping
		local is_ok,ret = x_pcall(handle.handle_response)
		if not is_ok then
			log.error("handle_response err ",ret)
			break
		end

		if not ret then break end
		keep_alive = fd_info.keep_alive
	end

	handle.close()
	clear_fd(fd)
	skynet.send(master_id,'lua','socket','closed',fd,ip,port)
	return skynet_util.NOT_RET
end

function SOCKET.close(fd)
	close_fd(fd)
end

function CMD.start(args)
	keep_alive_time = args.keep_alive_time or 300       --保活时间
	second_req_limit = args.second_req_limit or 100     --一秒请求数量限制
	max_packge_limit = args.max_packge_limit or 8192
	protocol = args.protocol
	local lua_file = args.dispatch
	web = require(lua_file)
	SELF_ADDRESS = skynet.self()

	for f_name,func in pairs(web) do
		if not CMD[f_name] then
			CMD[f_name] = func
		end
	end

	assert(web,"not dispatch")
	assert(web.init,"not web init func")
	assert(web.dispatch,"not web dispatch func")
	assert(web.exit,"not web exit func")
	check_time_out_loop()
	web.init()
	return true
end

--检查退出
function CMD.check_exit()
	return not next(fd_info_map)
end

--确认退出
function CMD.fix_exit()
	log.info("web_agent_module exit begin!")
	for fd,info in pairs(fd_info_map) do
		log.info("web_agent_module exit id:",fd)
		skynet.fork(close_fd,fd)
	end
	log.info("web_agent_module exit end!")
end

--执行退出
function CMD.exit()
	web.exit()
	return true
end

skynet_util.register_info_func("fd_info_map",function()
	return fd_info_map
end)

return CMD

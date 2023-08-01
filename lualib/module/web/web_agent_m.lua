
local skynet = require "skynet"
local handle_web = require "handle_web"
local socket = require "skynet.socket"
local log = require "log"
local cache_help = require "cache_help"
local timer = require "timer"

local table  = table
local string = string
local pcall = pcall
local type = type
local assert = assert
local os = os
local pairs = pairs
local x_pcall = x_pcall

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
local check_inval = 60 * 5
local fd_info_map = {}

local enter_map = {}
local req_cnt_map = {}


local req_cnt_cache = cache_help:new(1,function(fd)
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

local enter_cache = cache_help:new(10,function(fd,addr) 
	if enter_map[fd] then
		log.error("enter_timer_out:",fd,addr)
		skynet.fork(close_fd,fd)
	end
end)--用于检测是否及时完成链接 请求 响应的流程，没有完成即可能是恶意链接

local function check_func()
	local now_time = os.time()
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
	local cur_time = os.time()
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
	fd_info_map[fd] = nil
	enter_map[fd] = nil
end

function SOCKET.enter(fd, ip,port,master_id)
	if enter_cache:get_cache(fd) then
		log.warn("repeat enter fd:",fd,ip,port)
	end

	enter_map[fd] = ip
	enter_cache:set_cache(fd,ip)
	local conn_time = os.time()
		fd_info_map[fd] = {
		pre_msg_time = conn_time,
		state = FD_STATE.connecting,
		keep_alive = true,
	}

	local is_ok,handle = pcall(handle_web,fd, ip, port, protocol, handle_func)
	if not is_ok then
		log.warn("handle_web err ",handle)
		clear_fd(fd)
		skynet.fork(socket.close,fd)
		return
	end

	local fd_info = fd_info_map[fd]
	fd_info.handle = handle
	local keep_alive = true
	skynet.fork(function()
		while keep_alive do
			if socket.disconnected(fd) or socket.invalid(fd) then
				log.warn("disconnect:fd",fd,socket.disconnected(fd),socket.invalid(fd))
				break
			end

			fd_info.state = FD_STATE.reading

			local is_ok,ret = pcall(handle.read_request)
			if not is_ok then
				log.warn("read_request err ",ret)
				break
			end

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
	end)

	return SELF_ADDRESS
end

function SOCKET.close(fd)
	close_fd(fd)
end

function CMD.exit()
	log.error("web_agent_module exit begin!")
	for fd,info in pairs(fd_info_map) do
		log.error("web_agent_module exit id:",fd)
		skynet.fork(close_fd,fd)
	end
	log.error("web_agent_module exit end!")

	timer:new(timer.minute,0,function()
		if not next(fd_info_map) then
			web.exit()
			skynet.exit()
		end
	end)
end

function CMD.start(args)
	keep_alive_time = args.keep_alive_time or 300       --保活时间
	second_req_limit = args.second_req_limit or 100     --一秒请求数量限制
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

return CMD

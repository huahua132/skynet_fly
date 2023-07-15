local skynet = require "skynet"
local log = require "log"
local timer = require "timer"

local assert = assert

local CMD = {}

local hall_plug = nil

local function dispatch(fd,source,packname,req)
	skynet.ignoreret()
	if not packname then
		log.error("unpack err ",packname,req)
		return
	end
	log.info('dispatch:',fd,source,packname,req)

	hall_plug.dispatch(fd,packname,req)
end

function CMD.connect(player_id,player_info,fd,gate)
	log.info("connect:",player_id,player_info,fd,gate)
	return hall_plug.connect(player_id,player_info,fd,gate)
end

function CMD.disconnect(player_id)
	log.info("disconnect:",player_id)
	return hall_plug.disconnect(player_id)
end

function CMD.goout(player_id)
	log.info("goout:",player_id)
	return hall_plug.goout(player_id)
end

function CMD.start(config)
	assert(config.hall_plug,"not hall_plug")

	hall_plug = require(config.hall_plug)
	assert(hall_plug.init,"not init")             --初始化
	assert(hall_plug.unpack,"not unpack")         --解包函数
	assert(hall_plug.dispatch,"not dispatch")     --消息分发
	assert(hall_plug.connect,"not connect")       --连接大厅
	assert(hall_plug.disconnect,"not disconnect") --掉线
	assert(hall_plug.goout,"not goout")           --退出
	assert(hall_plug.empty,"not empty")           --判断是否为空
	assert(hall_plug.info,"not info")             --大厅信息

	hall_plug.init()
	skynet.register_protocol {
		id = skynet.PTYPE_CLIENT,
		name = "client",
		unpack = hall_plug.unpack,
		dispatch = dispatch,
	}

	return true
end

function CMD.exit()
	timer:new(timer.minute,0,function()
		
		if hall_plug.empty() then
			log.info("hall_plug.is_empty can exit")
			skynet.exit()
		else
			log.info("not hall_plug.is_empty can`t exit",hall_plug.info)
		end
	end)
end

return CMD
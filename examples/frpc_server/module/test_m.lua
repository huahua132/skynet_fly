---@diagnostic disable: undefined-field, need-check-nil
local log = require "skynet-fly.log"
local skynet = require "skynet.manager"
local container_client = require "skynet-fly.client.container_client"
local watch_server = require "skynet-fly.rpc.watch_server"
local frpc_server = require "skynet-fly.rpc.frpc_server"
local module_info = require "skynet-fly.etc.module_info"
local env_util = require "skynet-fly.utils.env_util"
local orm_table_client = require "skynet-fly.client.orm_table_client"

container_client:register("share_config_m")
local string = string

local g_player_entity = orm_table_client:new("player")

local g_config = nil
local g_host_conf = nil

local CMD = {}

function CMD.hello(who)
	log.info(string.format("%s send hello msg for me " .. g_config.instance_name, who))
end

function CMD.ping(msg)
	if not g_host_conf then
		local confclient = container_client:new("share_config_m")
		g_host_conf = confclient:mod_call('query','frpc_server')
	end
	
	return string.format("pong %s %s %s msg[%s]", g_config.instance_name, g_host_conf.host, skynet.self(), msg)
end

function CMD.large_msg(list)
	return list
end

--测试frpc 对端出错
function CMD.call_error_test()
	error("test_one_err")
end

--测试frpc all 调用部分端出错
function CMD.call_same_error_test()
	if env_util.get_svr_id() == 1 then
		return true
	end

	error("call_same_error_test")
end

function CMD.start(config)
	g_config = config
	local base_info = module_info.get_base_info()
	if base_info.index == 1 then
		skynet.fork(function()
			local i = 0
			while true do
				--log.info("publish >>> ", i)
				watch_server.publish("test_pub", "hello test_pub", i)
				skynet.sleep(100)
				i = i + 1
			end
		end)
		-- --large msg
		-- skynet.fork(function()
		-- 	while true do
		-- 		local str = ""
		-- 		for i = 1, 1024 * 100 do
		-- 			str = str .. '1'
		-- 		end
		-- 		watch_server.publish("test_pub_large", str)

		-- 		skynet.sleep(1000)
		-- 	end
		-- end)

		skynet.fork(function()
			local i = 0
			while true do
				watch_server.pubsyn("test_syn", "hello test_syn", i)

				watch_server.pubsyn("name1:age:address", "hello name1:age:address", i)
				watch_server.pubsyn("name2:age:address", "hello name2:age:address", i)

				watch_server.pubsyn("name:age1:address", "hello name:age1:address", i)
				watch_server.pubsyn("name:age2:address", "hello name:age2:address", i)

				watch_server.pubsyn("name:age:address1", "hello name:age:address1", i)
				watch_server.pubsyn("name:age:address2", "hello name:age:address2", i)

				watch_server.pubsyn("name1:age1:address", "hello name1:age1:address", i)
				watch_server.pubsyn("name2:age2:address", "hello name2:age2:address", i)

				watch_server.pubsyn("name1:age:address1", "hello name1:age:address1", i)
				watch_server.pubsyn("name2:age:address2", "hello name2:age:address2", i)
				
				watch_server.pubsyn("name:age1:address1", "hello name:age1:address1", i)
				watch_server.pubsyn("name:age1:address2", "hello name:age1:address2", i)
				skynet.sleep(500)
				i = i + 1

				--g_player_entity:change_save_one_entry({player_id = 10001, sex = i})
			end
		end)

		--测试1：基本 unpubsyn 取消同步
		skynet.fork(function()
			skynet.sleep(100) --等1秒确保客户端已连接
			watch_server.pubsyn("test_cancel_syn", "hello test_cancel_syn data")
			log.info("pubsyn test_cancel_syn done")
			skynet.sleep(1000) --等10秒后取消
			watch_server.unpubsyn("test_cancel_syn")
			log.info("unpubsyn test_cancel_syn done")
		end)

		--测试2：取消后重新发布（验证 re-pubsyn 能再次同步到客户端）
		skynet.fork(function()
			skynet.sleep(200)
			watch_server.pubsyn("test_cancel_repub", "first publish data", 1)
			log.info("pubsyn test_cancel_repub first done")
			skynet.sleep(800) --等8秒后取消
			watch_server.unpubsyn("test_cancel_repub")
			log.info("unpubsyn test_cancel_repub done")
			skynet.sleep(500) --再等5秒后重新发布
			watch_server.pubsyn("test_cancel_repub", "second publish data after cancel", 2)
			log.info("pubsyn test_cancel_repub second done (re-publish after cancel)")
		end)

		--测试3：取消 pwatch 匹配的 channel（name1:age:address 匹配 *:age:address 模式）
		skynet.fork(function()
			skynet.sleep(1500) --等15秒后取消其中一个匹配 *:age:address 的channel
			watch_server.unpubsyn("name1:age:address")
			log.info("unpubsyn name1:age:address done (pwatch cancel test)")
		end)

		--测试4：多个 cancel handler 场景测试（用独立channel）
		skynet.fork(function()
			skynet.sleep(300)
			watch_server.pubsyn("test_multi_cancel", "multi handler data", 100)
			log.info("pubsyn test_multi_cancel done")
			skynet.sleep(1200)
			watch_server.unpubsyn("test_multi_cancel")
			log.info("unpubsyn test_multi_cancel done")
		end)

		--测试5：快速 pubsyn + unpubsyn（边界场景：快速取消）
		skynet.fork(function()
			skynet.sleep(400)
			watch_server.pubsyn("test_quick_cancel", "quick data")
			log.info("pubsyn test_quick_cancel done")
			skynet.sleep(50) --仅等0.5秒即取消
			watch_server.unpubsyn("test_quick_cancel")
			log.info("unpubsyn test_quick_cancel done (quick cancel)")
		end)

		--测试服务端监听连接进来的节点上下线
		frpc_server:watch_up("frpc_client", function(svr_name, svr_id)
			log.info("[frpc_server] 节点上线:", svr_name, svr_id)
		end, "test_watch_up")

		frpc_server:watch_down("frpc_client", function(svr_name, svr_id)
			log.info("[frpc_server] 节点下线:", svr_name, svr_id)
		end, "test_watch_down")
	end
	--注册别名
	skynet.register(".testserver_" .. base_info.index)
	return true
end

function CMD.exit()
	return true
end

return CMD
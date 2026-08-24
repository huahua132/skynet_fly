---#API
---#content ---
---#content title: etcd 服务发现
---#content date: 2026-08-21 00:00:00
---#content categories: ["skynet_fly API 文档","rpc相关"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [rpc_etcd](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/rpc/rpc_etcd.lua)

---#content 基于 etcd3 的服务注册与服务发现，接口形态与 rpc_redis 对齐
---#content share_config 配置：etcd = { rpc = { http_host = "http://127.0.0.1:2379", prefix = "skynet_fly:rpc", ttl = 10, poll_time = 100 } }

local skynet = require "skynet"
local etcd3 = require "skynet-fly.db.etcd3"
local container_client = require "skynet-fly.client.container_client"
local string_util = require "skynet-fly.utils.string_util"
local log = require "skynet-fly.log"

local setmetatable = setmetatable
local assert = assert
local string = string
local tonumber = tonumber
local pairs = pairs
local ipairs = ipairs
local type = type

local M = {}
local meta = {__index = M}

local g_db_name = "rpc"
local DEFAULT_TTL = 10
local DEFAULT_POLL_TIME = 100     --skynet tick，100=1秒
local DEFAULT_PREFIX = "skynet_fly:rpc"

function M:new()
	local cli = container_client:new('share_config_m')
	local conf_map = cli:mod_call('query','etcd')
	assert(conf_map and conf_map[g_db_name], "not etcd conf:" .. g_db_name)

	local conf = conf_map[g_db_name]
	local t = {
		cli = etcd3:new({
			http_host = conf.http_host,
			user = conf.user,
			password = conf.password,
			prefix = conf.prefix or DEFAULT_PREFIX,
		}),
		ttl = conf.ttl or DEFAULT_TTL,
		poll_time = conf.poll_time or DEFAULT_POLL_TIME,
		prefix = conf.prefix or DEFAULT_PREFIX,
	}
	setmetatable(t, meta)
	return t
end

--生成key
local function make_key(prefix, svr_name, svr_id)
	return string.format("%s:%s:%s", prefix, svr_name, svr_id)
end

--生成value，与rpc_redis格式一致 host_secretkey_isencrypt
local function make_value(host, secret_key, is_encrypt)
	local info = host
	if secret_key then
		info = info .. '_' .. secret_key
	else
		info = info .. '_' .. '#'
	end
	if is_encrypt then
		info = info .. '_' .. 1
	else
		info = info .. '_' .. '#'
	end
	return info
end

--解析value
local function parse_value(info)
	local info_list = string_util.split(info, '_')
	if #info_list < 3 then
		return nil
	end
	local host = info_list[1]
	local secret_key = info_list[2] ~= "#" and info_list[2] or nil
	local is_encrypt = info_list[3] ~= "#" and true or nil
	return host, secret_key, is_encrypt
end

---#desc 注册，带lease保活
---#desc 首次调用创建lease并写入key，后续调用刷新lease并更新值；任何一步失败自愈(下次重新grant)
---@param svr_name string 集群服务名
---@param svr_id number 集群服务ID
---@param host string 地址 ip:port
---@param secret_key string|nil 连接密钥
---@param is_encrypt boolean|nil 是否加密传输
function M:register(svr_name, svr_id, host, secret_key, is_encrypt)
	assert(svr_name,"not svr_name")
	assert(svr_id,"not svr_id")
	assert(host,"not host")

	local key = make_key(self.prefix, svr_name, svr_id)
	local value = make_value(host, secret_key, is_encrypt)

	if not self.lease_id then
		local lease_id, err = self.cli:grant(self.ttl)
		if not lease_id then
			log.error("etcd3 grant err ", key, err)
			return
		end
		self.lease_id = lease_id
	end

	--每次都set更新值(这样即使key被意外删除也会重建)，同时keepalive延长lease
	local isok = true
	local res, err = self.cli:set(key, value, self.lease_id)
	if not res then
		log.error("etcd3 set err ", key, err)
		isok = false
	end

	res, err = self.cli:keepalive(self.lease_id)
	if not res then
		log.error("etcd3 keepalive err ", key, err)
		isok = false
	end

	if not isok then
		--自愈：下次重新grant
		self.lease_id = nil
	end
end

---#desc 获取结点的ip和端口
---@param svr_name string
---@param svr_id number
---@return string|nil host
---@return string|nil secret_key
---@return boolean|nil is_encrypt
function M:get_node_host(svr_name, svr_id)
	assert(svr_name,"not svr_name")
	assert(svr_id,"not svr_id")

	local key = make_key(self.prefix, svr_name, svr_id)
	local res, err = self.cli:get(key)
	if not res or not res.body.kvs or not res.body.kvs[1] then
		return nil, err
	end

	return parse_value(res.body.kvs[1].value)
end

---#desc 监听结点host
---#desc 轮询etcd + 本地diff，事件语义与rpc_redis对齐(set/expired)
---@param svr_name string
---@param call_back function(event, svr_name, svr_id, host, secret_key, is_encrypt)
---@return function 取消监听函数
function M:watch(svr_name, call_back)
	local is_cancel = false
	local old_map = {}   --svr_id -> value

	local function do_poll()
		if is_cancel then return end
		local prefix = string.format("%s:%s:", self.prefix, svr_name)
		local res, err = self.cli:readdir(prefix)
		if not res then
			--etcd不可用是基础设施抖动，不主动断开已有连接，下次轮询再diff
			log.error("etcd3 readdir err ", svr_name, err)
			return
		end

		local new_map = {}
		if res.body.kvs then
			for _, kv in ipairs(res.body.kvs) do
				--key = prefix..svr_name..':'..svr_id
				local key = kv.key
				local sp = string_util.split(key, ':')
				local svr_id = tonumber(sp[#sp])
				local value = kv.value
				new_map[svr_id] = value
				if old_map[svr_id] ~= value then
					local host, secret_key, is_encrypt = parse_value(value)
					if host then
						call_back('set', svr_name, svr_id, host, secret_key, is_encrypt)
					end
				end
			end
		end

		for svr_id, _ in pairs(old_map) do
			if not new_map[svr_id] then
				call_back('expired', svr_name, svr_id)
			end
		end

		old_map = new_map
	end

	skynet.fork(function()
		while not is_cancel do
			do_poll()
			skynet.sleep(self.poll_time)
		end
	end)

	return function()
		is_cancel = true
	end
end

return M

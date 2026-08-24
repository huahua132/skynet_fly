---#API
---#content ---
---#content title: etcd v3 调用
---#content date: 2026-08-21 00:00:00
---#content categories: ["skynet_fly API 文档","数据库相关"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [etcd3](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/db/etcd3.lua)

---#content 基于 http.httpc 的 etcd v3 HTTP(gateway) 客户端，参考 https://github.com/JieTrancender/skynet-etcd
---#content key/value 均以 base64 传输，body 为 JSON。支持多节点轮询与可选 Basic 鉴权(JWT token)

local skynet = require "skynet"
local httpc  = require "http.httpc"
local cjson  = require "cjson"
local crypt  = require "skynet.crypt"
local log    = require "skynet-fly.log"

local setmetatable = setmetatable
local pcall = pcall
local ipairs = ipairs
local pairs = pairs
local type = type
local string = string
local table = table
local tonumber = tonumber
local tostring = tostring

local M = {}
local meta = {__index = M}

local encode_base64 = crypt.base64encode
local decode_base64 = crypt.base64decode
local encode_json = cjson.encode
local decode_json = cjson.decode

local DEFAULT_TIMEOUT = 3000     --skynet tick，默认30秒
local TOKEN_REFESH_INTERVAL = 60 * 3 + 15    --token刷新间隔(秒)，小于etcd默认5分钟

---#desc 创建etcd客户端
---#desc key前缀由调用方拼接，本客户端不做任何前缀处理
---@param opts table http_host(string或string数组), user/password(可选鉴权), timeout(默认3000)
---@return table obj
function M:new(opts)
	opts = opts or {}
	local http_host = opts.http_host
	assert(http_host, "not http_host")
	local http_hosts = {}
	if type(http_host) == 'string' then
		http_hosts[1] = http_host
	else
		http_hosts = http_host
	end

	local endpoints = {}
	for _, host in ipairs(http_hosts) do
		table.insert(endpoints, {
			http_host = host,
			full_prefix = host .. "/v3",
		})
	end

	local t = {
		endpoints = endpoints,
		endpoints_len = #endpoints,
		init_count = 0,
		timeout = opts.timeout or DEFAULT_TIMEOUT,
		user = opts.user,
		password = opts.password,
		is_auth = not not (opts.user and opts.password),
		jwt_token = nil,
		last_auth_time = 0,
	}
	setmetatable(t, meta)
	return t
end

--轮询选择节点
local function choose_endpoint(self)
	local endpoints = self.endpoints
	local len = self.endpoints_len
	if len == 1 then
		return endpoints[1]
	end

	self.init_count = self.init_count + 1
	local pos = self.init_count % len + 1
	return endpoints[pos]
end

local function get_range_end(key)
	if #key == 0 then
		return string.char(0)
	end

	local last = string.sub(key, -1)
	key = string.sub(key, 1, #key - 1)

	local ascii = string.byte(last) + 1
	local str = string.char(ascii)

	return key .. str
end

--发起请求
--成功返回 status, res_body，失败返回 nil, err
local function do_request(self, method, endpoint, path, headers, content)
	local old_timeout = httpc.timeout
	httpc.timeout = self.timeout
	local ok, status, res_body = pcall(httpc.request, method, endpoint.http_host, endpoint.full_prefix .. path, {}, headers, content)
	httpc.timeout = old_timeout
	if not ok then
		return nil, tostring(res_body)
	end
	return status, res_body
end

--刷新jwt token
local function refresh_token(self)
	if self.jwt_token and skynet.now() - self.last_auth_time < TOKEN_REFESH_INTERVAL * 100 then
		return true
	end

	local endpoint = choose_endpoint(self)
	local body = encode_json({name = self.user, password = self.password})
	local status, res_body = do_request(self, "POST", endpoint, "/auth/authenticate", {
		["Content-Type"] = "application/json",
	}, body)

	if not status or status >= 300 then
		log.error("etcd3 authenticate err ", status, res_body)
		return false
	end

	local info = decode_json(res_body)
	if not info or not info.token then
		log.error("etcd3 authenticate not token ", res_body)
		return false
	end

	self.jwt_token = info.token
	self.last_auth_time = skynet.now()
	return true
end

--发起请求，401时刷新token重试一次
--网络失败(节点不可用)自动切换下一个节点，全部节点都失败才返回错误
--HTTP层成功但业务错误(>=300或body带error)直接返回，不切节点
--成功返回 {status=, body=}(body已decode)，失败返回 nil, err
local function _request(self, method, path, body)
	local headers = {
		["Content-Type"] = "application/json",
	}
	if self.is_auth then
		local isok = refresh_token(self)
		if not isok then
			return nil, "authenticate err"
		end
		headers["Authorization"] = self.jwt_token
	end

	local content = nil
	if body then
		content = encode_json(body)
	end

	local last_err = nil
	for _ = 1, self.endpoints_len do
		local endpoint = choose_endpoint(self)
		local status, res_body = do_request(self, method, endpoint, path, headers, content)
		if not status then
			--网络失败，该节点可能挂了，记下错误切下一个节点
			last_err = res_body
		elseif status == 401 and self.is_auth then
			--token失效，刷新后重试当前节点一次
			self.jwt_token = nil
			self.last_auth_time = 0
			local isok = refresh_token(self)
			if not isok then
				return nil, "authenticate err"
			end
			headers["Authorization"] = self.jwt_token
			status, res_body = do_request(self, method, endpoint, path, headers, content)
			if not status then
				last_err = res_body
			end
		end

		if status then
			if status >= 300 then
				--HTTP业务错误，如404等，换节点也一样，直接返回
				return nil, "http status " .. status .. " body " .. tostring(res_body)
			end

			if res_body then
				local ok2, info = pcall(decode_json, res_body)
				if not ok2 then
					return nil, "decode json err " .. tostring(res_body)
				end
				--gRPC gateway对业务错误(如lease不存在)返回200但body带error字段
				if info and info.error then
					return nil, "etcd err " .. tostring(info.error)
				end
				return {status = status, body = info}
			end

			return {status = status}
		end
	end

	if not last_err then
		last_err = "unknown err"
	end
	return nil, last_err
end

---#desc 写入key value
---@param key string
---@param value string
---@param lease_id number|nil 关联的lease id
---@return table|nil res {status=, body=}
---@return string|nil err
function M:set(key, value, lease_id)
	local body = {
		key = encode_base64(key),
		value = encode_base64(value),
	}
	if lease_id then
		body.lease = lease_id
	end
	return _request(self, "POST", "/kv/put", body)
end

---#desc 查询单个key
---@param key string
---@return table|nil res 返回体中的key/value已base64解码
---@return string|nil err
function M:get(key)
	local res, err = _request(self, "POST", "/kv/range", {
		key = encode_base64(key),
	})
	if not res then
		return nil, err
	end

	if res.body.kvs and next(res.body.kvs) then
		for _, kv in ipairs(res.body.kvs) do
			kv.key = decode_base64(kv.key)
			kv.value = decode_base64(kv.value or "")
		end
	end
	return res, err
end

---#desc 前缀查询
---@param prefix string 前缀(不含range_end)，查询 [prefix, prefix+1) 区间
---@return table|nil res 返回体中的key/value已base64解码
---@return string|nil err
function M:readdir(prefix)
	local res, err = _request(self, "POST", "/kv/range", {
		key = encode_base64(prefix),
		range_end = encode_base64(get_range_end(prefix)),
	})
	if not res then
		return nil, err
	end

	if res.body.kvs and next(res.body.kvs) then
		for _, kv in ipairs(res.body.kvs) do
			kv.key = decode_base64(kv.key)
			kv.value = decode_base64(kv.value or "")
		end
	end
	return res, err
end

---#desc 删除单个key
---@param key string
---@return table|nil res
---@return string|nil err
function M:delete(key)
	return _request(self, "POST", "/kv/deleterange", {
		key = encode_base64(key),
	})
end

---#desc 前缀删除
---@param prefix string
---@return table|nil res
---@return string|nil err
function M:rmdir(prefix)
	return _request(self, "POST", "/kv/deleterange", {
		key = encode_base64(prefix),
		range_end = encode_base64(get_range_end(prefix)),
	})
end

---#desc 创建lease
---@param ttl number 存活秒数
---@return number|nil lease_id
---@return string|nil err
function M:grant(ttl)
	local res, err = _request(self, "POST", "/lease/grant", {
		TTL = ttl,
		ID = 0,
	})
	if not res then
		return nil, err
	end
	return tonumber(res.body.ID), err
end

---#desc 刷新lease
---@param lease_id number
---@return table|nil res
---@return string|nil err
function M:keepalive(lease_id)
	return _request(self, "POST", "/lease/keepalive", {
		ID = lease_id,
	})
end

---#desc 撤销lease
---@param lease_id number
---@return table|nil res
---@return string|nil err
function M:revoke(lease_id)
	return _request(self, "POST", "/lease/revoke", {
		ID = lease_id,
	})
end

return M

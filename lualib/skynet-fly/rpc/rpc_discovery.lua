---#API
---#content ---
---#content title: rpc 服务发现接口
---#content date: 2026-08-24 00:00:00
---#content categories: ["skynet_fly API 文档","rpc相关"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [rpc_discovery](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/rpc/rpc_discovery.lua)

---#content 统一的服务注册/发现接口，按类型分发到具体实现(rpc_redis / rpc_etcd)
---#content frpc_server / frpc_client_m 只依赖本接口，新增实现时只需在 impl_map 增加映射

local assert = assert
local tostring = tostring
local require = require
local container_client = require "skynet-fly.client.container_client"

--share_config_m 为核心配置服务，接口层保证其可用
--实现模块(rpc_redis/rpc_etcd)通过container_client访问share_config_m读配置
container_client:register("share_config_m")

local M = {}

--实现注册表，type_name -> 模块路径
local impl_map = {
	["redis"] = "skynet-fly.rpc.rpc_redis",
	["etcd"] = "skynet-fly.rpc.rpc_etcd",
}

---#desc 创建服务发现客户端
---#desc 按类型动态require实现模块(一次加载终生缓存)，无需外部预加载
---@param type_name string 实现类型名，如 'redis' / 'etcd'
---@return table obj 实现实例(提供 register/get_node_host/watch)
function M:new(type_name)
	assert(type_name, "not rpc_discovery type_name")
	local path = impl_map[type_name]
	assert(path, "not rpc_discovery impl:" .. tostring(type_name))
	local impl = require(path)
	return impl:new()
end

return M

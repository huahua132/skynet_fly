---#API
---#content ---
---#content title: orm访问对象
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","数据库相关"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [orm_table_client](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/client/orm_table_client.lua)

---#content 因为orm有缓存的情况下，只能一个服务持有，那么我们又想多个服务访问情况下，我们一般把ormtable挂靠在orm_table_m可热更服务中
---#content 这时候我们通过orm_table_client来访问

local contriner_client = require "skynet-fly.client.contriner_client"
local skynet = require "skynet"
local table_util = require "skynet-fly.utils.table_util"
local setmetatable = setmetatable
local tpack = table.pack
local tunpack = table.unpack
local assert = assert
local error = error


contriner_client:register("orm_table_m")
contriner_client:set_always_swtich("orm_table_m")   --一直会切换访问新服务

local g_instance_map = {}

local M = {}

local mt = {__index = function(t,k)
    t[k] = function(self,...)
        t._client = t._client or contriner_client:new("orm_table_m",t._orm_name)
        local ret = nil
        --尝试 100 次，还不成功，那肯定是数据库挂逼了或者热更后执行保存比较耗时
        for i = 1,100 do
            ret = tpack(t._client:mod_call_by_name("call", k, ...))
            local is_move = ret[1]
            if not is_move then
                return tunpack(ret, 2, ret.n)
            end
            skynet.yield()
        end
        
        error("call err " .. k .. ' ' .. table_util.dump({...}))
    end
    return t[k]
end}

---#desc 创建一个orm访问对象
---@param orm_name string orm_table_m 中的instance_name
---@return table obj
function M:new(orm_name)
    assert(orm_name, "not orm_name")
    local t = {
        _orm_name = orm_name,
        _client = false
    }
    setmetatable(t, mt)
    return t
end

---#desc 使用常驻实例
---@param orm_name string orm_table_m 中的instance_name
---@return table obj
function M:instance(orm_name)
    if not g_instance_map[orm_name] then
        g_instance_map[orm_name] = M:new(orm_name)
    end

    return g_instance_map[orm_name]
end

return M
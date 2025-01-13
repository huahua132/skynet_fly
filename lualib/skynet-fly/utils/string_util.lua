---#API
---#content ---
---#content title: string_util string相关
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","工具函数"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [string_util](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/utils/string_util.lua)
local M = {}

local tremove = table.remove
local tinsert = table.insert
local tunpack = table.unpack
local sgmatch = string.gmatch
local next = next
local pairs = pairs
local strgsub = string.gsub
local sfind = string.find

---#desc 字符串分割，可以嵌套分割 例如：split('1:2_3:4','_',':') res = {{1,2},{3,4}}
---@param inputstr string 被分割字符串
---@param ... string 分隔符列表
---@return table 分割结果
function M.split(inputstr, ...)
    local seps = {...}
    local sep = tremove(seps,1)

    if sep == nil then
---@diagnostic disable-next-line: return-type-mismatch
        return inputstr
    end
    local result={}
    for str in sgmatch(inputstr, "([^"..sep.."]+)") do
        tinsert(result,str)
    end
    if seps and next(seps) then
        for k,v in pairs(result) do
            result[k] = M.split(v,tunpack(seps))
        end
    end

    return result
end

local escape_map = {
    ['\0'] = "\\0",
    ['\b'] = "\\b",
    ['\n'] = "\\n",
    ['\r'] = "\\r",
    ['\t'] = "\\t",
    ['\26'] = "\\Z",
    ['\\'] = "\\\\",
    ["'"] = "\\'",
    ['"'] = '\\"',
}

---#desc 防sql注入
---@param str string sql语句串
---@return string 防sql注入转换后的
function M.quote_sql_str(str)
    local str = strgsub(str, "[\0\b\n\r\t\26\\\'\"]", escape_map)
    return str
end

return M
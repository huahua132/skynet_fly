---#API
---#content ---
---#content title: 启动函数
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","可热更服务模块"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [container_launcher](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/container/container_launcher.lua)

local skynet = require "skynet"
local table_util = require "skynet-fly.utils.table_util"
require "skynet.manager"

local table = table
local ipairs = ipairs

local loadmodsfile = skynet.getenv("loadmodsfile")

local load_mods = {}
do
    local chunk, err = loadfile(loadmodsfile)
    assert(chunk, err)
    load_mods = chunk()
end

--这是可热更服务的启动

local M = {}

---#desc 这是启动函数通常在main.lua中调用
---@return function 返回需要延迟启动的可热更模块
function M.run()
    skynet.monitor('monitor_exit')
    local cmgr = skynet.uniqueservice('container_mgr')
	skynet.uniqueservice("debug_console", skynet.getenv('debug_port'))

    local before_run_list = {} --先跑
    local delay_run_list = {}  --延迟再次调用再跑
	for mod_name,mod_cfg in table_util.sort_ipairs(load_mods,function(a,b)
		return a.launch_seq < b.launch_seq
	end) do
        if not mod_cfg.delay_run then
            table.insert(before_run_list, mod_name)
        else
            table.insert(delay_run_list, mod_name)
        end
	end
    local self_address = skynet.self()
    skynet.call(cmgr, 'lua', 'load_modules', self_address, table.unpack(before_run_list))
    return function()
        if not delay_run_list then return end
        skynet.call(cmgr, 'lua', 'load_modules', self_address, table.unpack(delay_run_list))
        delay_run_list = nil
    end
end

return M
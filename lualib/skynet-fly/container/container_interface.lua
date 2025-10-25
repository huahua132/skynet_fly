---#API
---#content ---
---#content title: 对外接口
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","可热更服务模块"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [container_interface](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/container/container_interface.lua)

local M = {}
---#content loading = 1,            --加载中
---#content starting = 2,           --启动成功
---#content fix_exited = 3,         --确定退出
---#content exited = 4,             --退出
---#content start_failed = 5,       --启动失败

---#desc 获取服务状态
---@param tabname string 表名
---@return number
function M.get_server_state()
    error("not implemented interface")    --没有实现该接口
end

---#desc hook 可热更服务start_after
---@param func function 执行函数
function M.hook_start_after(func)
    error("not implemented interface")    --没有实现该接口
end
 
---#desc hook 可热更服务fix_exit_after
---@param func function 执行函数
function M.hook_fix_exit_after(func)
    error("not implemented interface")    --没有实现该接口
end

---#desc hook 关闭此模块热更支持(新服务替换旧服务)
function M.close_hotreload()
    error("not implemented interface")    --没有实现该接口
end

return M 
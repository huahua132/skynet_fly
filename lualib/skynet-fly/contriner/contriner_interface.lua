local M = {}

function M.get_server_state()
    error("not implemented interface")    --没有实现该接口
end

--hook 可热更服务start_after
function M.hook_start_after(func)
    error("not implemented interface")    --没有实现该接口
end
 
--hook 可热更服务fix_exit_after
function M.hook_fix_exit_after(func)
    error("not implemented interface")    --没有实现该接口
end

-- 关闭此模块热更支持
function M.close_hotreload()
    error("not implemented interface")    --没有实现该接口
end

return M 
local M = {}

local assert = assert

M.SERVER_STATE_TYPE = {
    loading = 1,            --加载中
    starting = 2,           --启动中
    fix_exited = 3,         --确定退出
    exited = 4,             --退出
}

local SERVER_STATE = M.SERVER_STATE_TYPE.loading

function M.set_server_state(state)
    assert(state)
    SERVER_STATE = state
end

function M.get_server_state()
    return SERVER_STATE
end

return M 
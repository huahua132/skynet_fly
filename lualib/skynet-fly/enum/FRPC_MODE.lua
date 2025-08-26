---@class FRPC_MODE
local enum = {
    one = 1,                --简单负载均衡发个一个节点
    byid = 2,               --发给指定节点
    all = 3,                --发给所有结点
}

return enum
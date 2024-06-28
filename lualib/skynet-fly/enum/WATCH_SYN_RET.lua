local t = {
    syn = 1,          --正常同步数据
    unsyn = 2,        --取消同步数据
    disconnect = 3,   --watch掉线
    move = 4,         --frpc_client_m 服务切换了
}

return t
-- 这是frpc 的错误码
local enum = {
    WAIT_CONNECT_TIME_OUT  = 1,          --等待建立连接超时
    SOCKET_ERROR           = 2,          --网络错误(通常是断开导致)
    TRANSLATION_PEER_ERROR = 3,          --对端出错
}

return enum
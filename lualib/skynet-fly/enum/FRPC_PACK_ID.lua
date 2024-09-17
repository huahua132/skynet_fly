--这是frpc 调用的协议号

local enum = {
    hand_shake              = 1,             --握手

    pubmessage              = 10,            --推送消息
    sub                     = 11,            --订阅
    unsub                   = 12,            --取消订阅
    subsyn                  = 13,            --订阅同步
    unsubsyn                = 14,            --取消订阅同步

    balance_send            = 100,           --简单轮询负载均衡
    mod_send                = 101,
    broadcast               = 102,
    balance_send_by_name    = 103,
    mod_send_by_name        = 104,
    broadcast_by_name       = 105,
    send_by_name            = 106,           --指定别名发送消息

    balance_call            = 200,           --简单轮询负载均衡
    mod_call                = 201,
    broadcast_call          = 202,
    balance_call_by_name    = 203,
    mod_call_by_name        = 204,
    broadcast_call_by_name  = 205,
    call_by_name            = 206,           --指定别名调用
}

return enum
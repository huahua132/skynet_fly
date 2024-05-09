--这是frpc 调用的协议号

local enum = {
    hand_shake              = 1,             --握手
    hand_shake_rsp          = 2,             --握手回复
    call_rsp                = 3,             --call消息回应
    call_error              = 4,             --call调用s端出错

    balance_send            = 100,           --简单轮询负载均衡
    mod_send                = 101,
    broadcast               = 102,
    balance_send_by_name    = 103,
    mod_send_by_name        = 104,
    broadcast_by_name       = 105,

    balance_call            = 200,           --简单轮询负载均衡
    mod_call                = 201,
    broadcast_call          = 202,
    balance_call_by_name    = 203,
    mod_call_by_name        = 204,
    broadcast_call_by_name  = 205,
}

return enum
local msg_id = require "enum.msg_id"

local ENUM = {
    [msg_id.login_LoginReq] = msg_id.login_LoginRes,
    [msg_id.login_LoginOutReq] = msg_id.login_LoginOutRes,
    [msg_id.login_matchReq] = msg_id.login_matchRes,
    [msg_id.login_serverInfoReq] = msg_id.login_serverInfoRes,
    [msg_id.game_GameStatusReq] = msg_id.game_GameStatusRes,
}

return ENUM
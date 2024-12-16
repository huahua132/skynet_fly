local ENUM = {
    --common
    errors_Error = 1,                        --通用消息通知
    --login
    login_LoginReq = 101,                    --登录请求
    login_LoginRes = 102,                    --登录回复
    login_LoginOutReq = 103,                 --登出请求
    login_LoginOutRes = 104,                 --登出回复
    login_matchReq = 105,                    --匹配请求
    login_matchRes = 106,                    --匹配回复
    login_serverInfoReq = 107,               --请求服务器信息
    login_serverInfoRes = 108,               --回复服务器信息

    --game
    game_DoingReq = 201,                     --请求操作
    game_GameStatusReq = 203,                --游戏状态请求
    game_GameStatusRes = 204,                --游戏状态回复
    game_EnterCast = 281,                    --坐下广播
    game_GameStartCast = 282,                --游戏开始广播
    game_NextDoingCast = 283,                --下一个操作人广播
    game_GameOverCast = 284,                 --游戏结束广播
    game_LeaveCast = 285,                    --离开广播
    game_DoingCast = 286,                    --操作广播
}

return ENUM
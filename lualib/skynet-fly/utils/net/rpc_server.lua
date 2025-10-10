local log = require "skynet-fly.log"
local netpack_base = require "skynet-fly.netpack.netpack_base"
local math_util = require "skynet-fly.utils.math_util"
local service = require "skynet.service"
local skynet = require "skynet"
local wait = require "skynet-fly.time_extend.wait":new()

local setmetatable = setmetatable
local sfmt = string.format
local assert = assert

local function alloc_push_session()
    local skynet = require "skynet"
    local skynet_util = require "skynet-fly.utils.skynet_util"
    local math_util = require "skynet-fly.utils.math_util"

    local one_alloc_num = 10000    --1次分配1万 不建议把这个值改的特别大，数越大，使用的服务越多，越快回绕，越容易造成session的冲突，正常42亿 一个分包推送的消息不可能回绕了还没发送-接收完
    local cur_session = 1

    local CMD = {}
    function CMD.new_session()
        local e = cur_session + one_alloc_num - 1
        if e > math_util.uint32max then
            cur_session = 1
            e = cur_session + one_alloc_num - 1
        end

        local s = cur_session
        cur_session = e + 1
        return s, e
    end

    skynet.start(function()
        skynet_util.lua_dispatch(CMD)
    end)
end

local g_cur, g_end = nil, nil
local g_allocing = false
local g_session_service = nil
local function new_session()
    while g_allocing do       --避免并发多次分配
        wait:wait("alloc")
    end                 

    if not g_cur or g_cur > g_end then
        g_allocing = true
        local session_service = g_session_service or service.new("session_service", alloc_push_session)
        g_session_service = session_service
        g_cur, g_end = skynet.call(session_service, 'lua', 'new_session')
        g_allocing = false
        wait:wakeup("alloc")
    end

    local session = g_cur
    g_cur = g_cur + 1

    return session
end

local M = {}

local VALID_MSG_TYPE = {
    [netpack_base.MSG_TYPE.CLIENT_REQ] = true,
    [netpack_base.MSG_TYPE.CLIENT_PUSH] = true,
}

--处理消息
function M.handle_msg(packid, body)
    local msgtype = body.msgtype
    local packtype = body.packtype
    local session = body.session
    if not VALID_MSG_TYPE[msgtype] then             --只能是客户端消息
        return nil, sfmt("invalid msgtype packid[%s] msgtype[%s]", packid, msgtype)
    end

    if packtype ~= netpack_base.PACK_TYPE.WHOLE then    --只收整包
        return nil, sfmt("invalid packtype packid[%s] packtype[%s]", packid, packtype)
    end

    local rsp_session = nil
    if msgtype == netpack_base.MSG_TYPE.CLIENT_REQ then
        if session % 2 ~= 1 then --请求必须是奇数
            return nil, sfmt("invalid req session packid[%s] session[%s]", packid, session)
        end
        rsp_session = session + 1
    end

    local decode_func = body.decode_func
    
    local isok, msgbody = decode_func(packid, body.msgstr)
    if not isok then
        return nil, "decode msg err:" .. packid
    end
    
    return packid, msgbody, rsp_session
end

--打包回复消息
function M.pack_rsp(msgbody, rsp_session)
    local body = {
        msgtype = netpack_base.MSG_TYPE.SERVER_RSP,
        msgbody = msgbody,
        session = rsp_session,
    }
    return body
end

--打包错误消息
function M.pack_error(msgbody, rsp_session)
    local body = {
        msgtype = netpack_base.MSG_TYPE.SERVER_ERR,
        msgbody = msgbody,
        session = rsp_session,
    }
    return body
end

--打包推送消息
function M.pack_push(msgbody)
    local body = {
        msgtype = netpack_base.MSG_TYPE.SERVER_PUSH,
        msgbody = msgbody,
        session = new_session(),
    }

    return body
end

return M
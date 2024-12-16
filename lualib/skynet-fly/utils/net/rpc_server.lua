local log = require "skynet-fly.log"
local netpack_base = require "skynet-fly.netpack.netpack_base"
local math_util = require "skynet-fly.utils.math_util"
local service = require "skynet.service"
local skynet = require "skynet"

local setmetatable = setmetatable
local sfmt = string.format

local function alloc_push_session()
    local skynet = require "skynet"
    local skynet_util = require "skynet-fly.utils.skynet_util"
    local math_util = require "skynet-fly.utils.math_util"

    local cur_session = 1

    local CMD = {}
    function CMD.new_session()
        local session = cur_session
        cur_session = cur_session + 1
        if cur_session > math_util.uint32max then
            cur_session = 1
        end
        return session
    end

    skynet.start(function()
        skynet_util.lua_dispatch(CMD)
    end)
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
    local session_service = service.new("session_service", alloc_push_session)
    local new_session = skynet.call(session_service, 'lua', 'new_session')
    local body = {
        msgtype = netpack_base.MSG_TYPE.SERVER_PUSH,
        msgbody = msgbody,
        session = new_session,
    }

    return body
end

return M
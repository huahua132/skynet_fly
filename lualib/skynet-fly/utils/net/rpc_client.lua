local netpack_base = require "skynet-fly.netpack.netpack_base"
local math_util = require "skynet-fly.utils.math_util"
local log = require "skynet-fly.log"
local timer = require "skynet-fly.timer"
local wait = require "skynet-fly.time_extend.wait"

local setmetatable = setmetatable
local sfmt = string.format
local assert = assert
local pairs = pairs

-------------------------------------------------------------
--这是用skynet_fly实现客户端协议处理的例子，服务端rpc通信请用frpc
-------------------------------------------------------------

local M = {}
local mt = {__index = M}

local VALID_MSG_TYPE = {
    [netpack_base.MSG_TYPE.SERVER_ERR] = true,
    [netpack_base.MSG_TYPE.SERVER_RSP] = true,
    [netpack_base.MSG_TYPE.SERVER_PUSH] = true,
}

--新建一个req_sesion
local function new_req_session(t)
    local session = t.req_session
    t.req_session = t.req_session + 2
    if t.req_session >= math_util.uint32max then
        t.req_session = 1
    end
    return session
end

--清理msg数据
local function clear_msg_data(msg_map, session)
    log.warn("timeout clear_msg_data session:", session)
    msg_map[session] = nil
end

--新建rpc客户端
function M:new(send, timeout)
    assert(send, "not send func")
    assert(timeout, "not timeout") --100 表示 1秒
    local t = {
        rsp_msg_map = {},   --服务端回复的消息(包含错误)
        push_msg_map = {},  --服务端推送
        send = send,        --发送函数
        timeout = timeout,  --粘合消息销毁最大等待时间
        req_session = 1,    --req消息开始的session
        rpc_wait = wait:new(timeout),
        wait_result_map = {}, --等待结果
    }

    setmetatable(t, mt)

    return t
end

--消息处理
function M:handle_msg(packid, body)
    local packtype = body.packtype
    local msgtype = body.msgtype
    local session = body.session

    if not VALID_MSG_TYPE[msgtype] then             --只能是服务端消息
        return nil, sfmt("invalid msgtype packid[%s] msgtype[%s]", packid, msgtype)
    end

    local req_session = nil
    if msgtype ~= netpack_base.MSG_TYPE.SERVER_PUSH then    --回复消息
        if session % 2 ~= 0 then --回复必须是偶数
            return nil, sfmt("invalid req session packid[%s] session[%s]", packid, session)
        end
        req_session = session - 1
        if not self.wait_result_map[req_session] then
            return nil, sfmt("not exists packid[%s] req_session[%s]", packid, req_session)
        end
    else
        if session <= 0 or session > math_util.uint32max then
            return nil, sfmt("invalid push session packid[%s] session[%s]", packid, session)
        end
    end

    if packtype == netpack_base.PACK_TYPE.WHOLE then   --整包
        local decode_func = body.decode_func
        local isok, msgbody = decode_func(packid, body.msgstr)
        if not isok then
            return nil, "decode msg err:" .. packid
        end
        if req_session then
            self.wait_result_map[req_session] = {packid, msgbody}
            self.rpc_wait:wakeup(req_session)
            return false
        else
            return packid, msgbody
        end
    end

    local msg_map = nil
    if msgtype == netpack_base.MSG_TYPE.SERVER_RSP
    or msgtype == netpack_base.MSG_TYPE.SERVER_ERR then
        msg_map = self.rsp_msg_map
    else
        msg_map = self.push_msg_map
    end

    if packtype == netpack_base.PACK_TYPE.HEAD then --包头处理
        if msg_map[session] then
            return nil, sfmt("repeat session[%s] packtype[%s] packid[%s]", session, packtype, packid) --消息session不能重复
        end
        local msgsz = body.msgsz
        msg_map[session] = {
            msgbuff = "",
            msgsz = msgsz,
            time_obj = timer:new(self.timeout, 1, clear_msg_data, msg_map, session)
        }
        return false    --表示忽悠结果
    elseif packtype == netpack_base.PACK_TYPE.BODY then --包体处理
        local one_msg = msg_map[session]
        if not one_msg then
            return nil, sfmt("invalid body msg session[%s] packtype[%s] packid[%s]", session, packtype, packid)
        end
        one_msg.msgbuff = one_msg.msgbuff .. body.msgstr
        return false
    elseif packtype == netpack_base.PACK_TYPE.TAIL then --包尾处理
        local one_msg = msg_map[session]
        if not one_msg then
            return nil, sfmt("invalid tail msg session[%s] packtype[%s] packid[%s]", session, packtype, packid)
        end
        one_msg.msgbuff = one_msg.msgbuff .. body.msgstr
        one_msg.time_obj:cancel()
        if one_msg.msgbuff:len() ~= one_msg.msgsz then
            return nil, sfmt("msg len err session[%s] packtype[%s] packid[%s] msglen[%s] recvlen[%s]", session, packtype, packid, one_msg.msgsz, one_msg.msg_buff:len())
        end

        local decode_func = body.decode_func
        local isok, msgbody = decode_func(packid, one_msg.msgbuff)
        if not isok then
            return nil, "decode msg err:" .. packid
        end
        if req_session then
            self.wait_result_map[req_session] = {packid, msgbody}
            self.rpc_wait:wakeup(req_session)
            return false
        else
            return packid, msgbody
        end
    end
end

--rpc请求
function M:req(packid, msgbody)
    local body = {
        msgtype = netpack_base.MSG_TYPE.CLIENT_REQ,
        session = new_req_session(self),
        msgbody = msgbody,
    }

    self.send(packid, body)
    self.wait_result_map[body.session] = true
    assert(self.wait_result_map[body.session], "session exists")
    self.rpc_wait:wait(body.session)        --等待返回值
    local result = self.wait_result_map[body.session]
    self.wait_result_map[body.session] = nil
    if result == true then
        return nil, sfmt("call timeout packid[%s]", packid)
    end
    
    local packid, msgbody = result[1], result[2]
    return packid, msgbody
end

--push发送
function M:push(packid, msgbody)
    local body = {
        msgtype = netpack_base.MSG_TYPE.CLIENT_PUSH,
        session = 0,
        msgbody = msgbody,
    }
    self.send(packid, body)
end

--关闭
function M:close()
    for req_session in pairs(self.wait_result_map) do
        self.wait_result_map[req_session] = {nil, "closed"}
        self.rpc_wait:wakeup(req_session)
    end
end

return M
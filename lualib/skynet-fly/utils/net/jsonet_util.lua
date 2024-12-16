local socket = require "skynet.socket"
local json_netpack = require "skynet-fly.netpack.json_netpack"
local util_net_base = require "skynet-fly.utils.net.util_net_base"

--------------------------------------------------------
--这是给skynet gate网关服务处理消息用的 基于json协议
--------------------------------------------------------

local M = {}

--给fd发送socket消息
M.send = util_net_base.create_gate_send(json_netpack.pack)

--群发
M.broadcast = util_net_base.create_gate_broadcast(json_netpack.pack)

--解包
M.unpack = util_net_base.create_gate_unpack(json_netpack.unpack)

--客户端读取消息包
M.recv = util_net_base.create_recv(socket.read,json_netpack.unpack)

return M 
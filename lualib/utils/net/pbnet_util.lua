local socket = require "socket"
local pb_netpack = require "pb_netpack"
local util_net_base = require "util_net_base"

--------------------------------------------------------
--这是给skynet gate网关服务处理消息用的 基于protobuf协议
--------------------------------------------------------

local M = {}

--给fd发送socket消息
M.send = util_net_base.create_gate_send(pb_netpack.pack)

--解包
M.unpack = util_net_base.create_gate_unpack(pb_netpack.unpack)

--客户端读取消息包
M.recv = util_net_base.create_recv(socket.read,pb_netpack.unpack)

return M 
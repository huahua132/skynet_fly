local socket = require "skynet.socket"
local frpc_netpack = require "skynet-fly.netpack.frpc_netpack"
local util_net_base = require "skynet-fly.utils.net.util_net_base"

--------------------------------------------------------
--这是给skynet gate网关服务处理消息用的 基于frpc协议
--------------------------------------------------------

local M = {}

--给fd发送socket消息
M.send = util_net_base.create_gate_send(frpc_netpack.pack_by_id)

--给fd_list发送socket消息
M.broadcast = util_net_base.create_gate_broadcast(frpc_netpack.pack_by_id)

--解包
M.unpack = util_net_base.create_gate_unpack(frpc_netpack.unpack_by_id)

--客户端读取消息包
M.recv = util_net_base.create_recv(socket.read,frpc_netpack.unpack_by_id)

return M 
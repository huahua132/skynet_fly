local pb_netpack = require "pb_netpack"
local websocket = require "websocket"
local util_net_base = require "util_net_base"

local M = {}

--给fd发送socket binary消息
M.send = util_net_base.create_ws_gate_send_binary(pb_netpack.pack)

--解包
M.unpack = util_net_base.create_ws_gate_unpack(pb_netpack.unpack)

--读取
M.recv = util_net_base.create_recv(websocket.read,pb_netpack.unpack)

return M
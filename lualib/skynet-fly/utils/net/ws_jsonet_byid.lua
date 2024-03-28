local json_netpack = require "skynet-fly.netpack.json_netpack"
local websocket = require "http.websocket"
local util_net_base = require "skynet-fly.utils.net.util_net_base"

local M = {}

--给fd发送socket text消息
M.send = util_net_base.create_ws_gate_send_text(json_netpack.pack_by_id)

--给fd_list发送socket消息
M.broadcast = util_net_base.create_ws_gate_broadcast_text(json_netpack.pack_by_id)

--解包
M.unpack = util_net_base.create_ws_gate_unpack(json_netpack.unpack_by_id)

--读取
M.recv = util_net_base.create_recv(websocket.read,json_netpack.unpack_by_id)

return M
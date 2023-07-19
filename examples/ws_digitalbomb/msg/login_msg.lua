local ws_pbnet_util = require "ws_pbnet_util"

local M = {}

function M.login_res(gate,fd,login_res)
	ws_pbnet_util.send(gate,fd,'.login.LoginRes',login_res)
end

function M.login_out_res(gate,fd,login_out_res)
	ws_pbnet_util.send(gate,fd,'.login.LoginOutRes',login_out_res)
end

return M
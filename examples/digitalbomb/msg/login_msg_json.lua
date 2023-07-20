local jsonet_util = require "jsonet_util"

local M = {}

function M.login_res(gate,fd,login_res)
	jsonet_util.send(gate,fd,'.login.LoginRes',login_res)
end

function M.login_out_res(gate,fd,login_out_res)
	jsonet_util.send(gate,fd,'.login.LoginOutRes',login_out_res)
end

return M
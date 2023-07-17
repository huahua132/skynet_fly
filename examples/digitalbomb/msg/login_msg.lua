local pbnet_util = require "pbnet_util"

local M = {}

function M.login_res(fd,login_res)
	pbnet_util.send(fd,'.login.LoginRes',login_res)
end

function M.login_out_res(fd,login_out_res)
	pbnet_util.send(fd,'.login.LoginOutRes',login_out_res)
end

return M
local pbnet_util = require "pbnet_util"

local M = {}

function M.login_res(fd,login_res)
	pbnet_util.send(fd,'.login.LoginRes',login_res)
end

function M.login_out_res(fd,player_id)
	pbnet_util.send(fd,'.login.LoginOutRes',{
		player_id = player_id
	})
end

return M
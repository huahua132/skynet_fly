local pbnet_util = require "pbnet_util"

local M = {}

function M.login_res(fd,player_id)
	pbnet_util.send(fd,'.login.LoginRes',{
		player_id = player_id
	})
end

function M.login_out_res(fd,player_id)
	pbnet_util.send(fd,'.login.LoginOutRes',{
		player_id = player_id
	})
end

return M
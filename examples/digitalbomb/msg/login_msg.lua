local pbnet_util = require "pbnet_util"

local M = {}

function M.login_res(fd,player_id)
	pbnet_util.send(fd,'.LoginRes',{
		player_id = player_id
	})
end

return M
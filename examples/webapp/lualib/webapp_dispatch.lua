local log = require "log"

local M = {}

function M.dispatch(req)
	log.error("dispatch:")
	return 200,"hello skynet_fly!!!"
end

return M
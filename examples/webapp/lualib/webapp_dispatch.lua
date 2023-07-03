local skynet = require "skynet"
local log = require "log"
local string = string
local M = {}

local html = [[
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>文档标题</title>
</head>
 
<body>
	hello skynet_fly!!!
</body>
 
</html>
]]

function M.dispatch(req)
	log.error("dispatch:",skynet.self())
	return 200,html
end

return M
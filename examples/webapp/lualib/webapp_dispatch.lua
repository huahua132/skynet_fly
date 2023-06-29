local log = require "log"
local util = require "util"
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
	<form action="">
		翻译内容: <input type="text" name="text"><br>
		目标语言编码: <input type="text" name="target">
  		<button>翻译</button>
	</form>
	翻译内容：%s
</body>
 
</html>
]]

function M.dispatch(req)
	local url = req.url
	local b,e = string.find(url,'?',nil,true)
	local args = {}
	if b then
		url = url:sub(e + 1,url:len())
		local strobj = util.string_split(url,'&','=')
		for _,kv in pairs(strobj) do
			args[kv[1]] = kv[2]
		end
	end

	local ret = string.format(html,"我是翻译内容！！！")
	log.error("dispatch:",args)
	return 200,ret
end

return M
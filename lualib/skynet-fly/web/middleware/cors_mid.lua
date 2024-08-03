--处理跨域的中间件
local M = {}

function M.mid(c)
    c:next()
    c.res:set_header('Access-Control-Allow-Origin', '*')
    c.res:set_header('Access-Control-Allow-Methods', '*')
    c.res:set_header('Access-Control-Allow-Credentials', 'true')
    c.res:set_header('Access-Control-Allow-Headers', 'Keep-Alive,Content-Type,Authorization')
end

function M.end_point(c)
    c.res:set_header('Access-Control-Allow-Origin', '*')
    c.res:set_header('Access-Control-Allow-Methods', '*')
    c.res:set_header('Access-Control-Allow-Credentials', 'true')
    c.res:set_header('Access-Control-Allow-Headers', 'Keep-Alive,Content-Type,Authorization')
    c.res:set_header('Access-Control-Max-Age', 1728000)
    c.res:set_rsp("", 200)
end

return M
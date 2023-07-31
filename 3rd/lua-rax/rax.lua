local rax_core = require "rax.core"

local function gc_free(self)
    rax_core.destroy(self.tree)
end

local M = { VERSION = '0.0.1' }
local mt = { __index = M, __gc = gc_free }

local log_info = function () end
local log_debug = function () end
local log_info = print
local log_debug = print

local _METHOD_GET     = 2
local _METHOD_POST    = 2 << 1
local _METHOD_PUT     = 2 << 2
local _METHOD_DELETE  = 2 << 3
local _METHOD_PATCH   = 2 << 4
local _METHOD_HEAD    = 2 << 5
local _METHOD_OPTIONS = 2 << 6

local _METHODS = {
    GET     = _METHOD_GET,
    POST    = _METHOD_POST,
    PUT     = _METHOD_PUT,
    DELETE  = _METHOD_DELETE,
    PATCH   = _METHOD_PATCH,
    HEAD    = _METHOD_HEAD,
    OPTIONS = _METHOD_OPTIONS,
}

function M:new()
    local tree = rax_core.new()
    local tree_it = rax_core.newit(tree)
    local instance = {
        tree = tree,
        tree_it = tree_it,
        match_data_index = 0,
        match_data = {},
        hash_path = {},
        hash_pattern = {},
    }
    return setmetatable(instance, mt)
end

function M:insert(method, path, data)
    if type(path) ~= "string" then
        error("invalid argument path")
    end

    if (not method) or (not path) or (not data) then
        error("invalid argument of route")
    end

    local bit_methods
    if type(method) ~= "table" then
        bit_methods = method and _METHODS[method] or 0
    else
        bit_methods = 0
        for _, m in ipairs(method) do
            bit_methods = bit_methods | _METHODS[m]
        end
    end

    local opts = {
        data = data,
        method = bit_methods,
        path_org = path,
        param = false,
    }
    local pos = path:find(":", 1, true)
    if pos then
        path = path:sub(1, pos -1)
        opts.path_op = "<="
        opts.path = path
        opts.param = true
    else
        pos = path:find("*", 1, true)
        if pos then
            if pos ~= #path then
                opts.param = true
            end
            path = path:sub(1, pos - 1)
            opts.path = "<="
        else
            opts.path_op = "="
        end
        opts.path = path
    end

    if opts.path_op == "=" then
        if not self.hash_path[path] then
            self.hash_path[path] = {opts}
        else
            table.insert(self.hash_path[path], opts)
        end
        return true
    end

    local idx = rax_core.find(self.tree, path)
    if idx ~= nil then
        local routes = self.match_data[idx]
        if routes and routes[1].path == path then
            table.insert(routes, opts)
            return true
        end
    end

    self.match_data_index = self.match_data_index + 1
    self.match_data[self.match_data_index] = {opts}
    log_info("insert route path: ", path, " dataprt: ", self.match_data_index)
    return rax_core.insert(self.tree, path, self.match_data_index)
end

-- compat for lua-r3
function M:compile()
    return true
end

local function _match_route_opts(route, opts)
    local method = opts.method
    if route.method ~= 0 then
        if (not method)
        or (type(_METHODS[method]) ~= "number")
        or (route.method & _METHODS[method] == 0) then
            return false
        end
    end

    opts.matched._method = method
    return true
end

function M:_fetch_pat(path)
    local pat = self.hash_pattern[path]
    if pat then
        return pat[1], pat[2] -- pat, names
    end

    local i = 0
    local j = 0
    local nameidx = 0
    local names = {}
    local res = {}
    for item in path:gmatch("[^/]+") do
        j = j + 1
        res[j] = item

        local first_byte = item:byte(1, 1)
        if first_byte == string.byte(":") then
            i = i + 1
            names[i] = item:sub(2)
            -- See https://www.rfc-editor.org/rfc/rfc1738.txt BNF for specific URL schemes
            res[j] = [=[([%w%-_;:@&=!',%%%$%.%+%*%(%)]+)]=]
        elseif first_byte == string.byte("*") then
            local name = item:sub(2)
            if name == "" then
                nameidx = nameidx + 1
                name = nameidx
            end
            i = i + 1
            names[i] = name
            -- '.' matches any character except newline
            res[j] = [=[(.*)]=]
        end
    end
    local pat = table.concat(res, [[/]])
    self.hash_pattern[path] = {pat, names}
    return pat, names
end

function M:_compare_param(req_path, route, opts)
    if not route.param then
        return true
    end

    local pat, names = self:_fetch_pat(route.path_org)
    log_debug("pat: ", pat)
    if #names == 0 then
        return true
    end

    local m = table.pack(string.gmatch(req_path, pat)())
    if not m[1] then
        return false
    end

    for i,v in ipairs(m) do
        local name = names[i]
        if name and v then
            opts.matched[name] = v
        end
    end
    return true
end

function M:_match_from_routes(routes, path, opts)
    for _, route in ipairs(routes) do
        if _match_route_opts(route, opts) then
            if self:_compare_param(path, route, opts) then
                opts.matched._path = route.path_org
                return route
            end
        end
    end

    return nil
end

function M:match(path, method)
    local opts = {
        method = method,
        matched = {},
    }
    local routes = self.hash_path[path]
    if routes then
        for _, route in ipairs(routes) do
            if _match_route_opts(route, opts) then
                opts.matched._path = path
                return route.data, opts.matched
            end
        end
    end

    local ret = rax_core.search(self.tree_it, path)
    if not ret then
        return
    end

    while true do
        local idx = rax_core.prev(self.tree_it, path)
        if idx <= 0 then
            break
        end

        routes = self.match_data[idx]
        if routes then
            local route = self:_match_from_routes(routes, path, opts)
            if route then
                return route.data, opts.matched
            end
        end
    end
end

function M:dump()
    rax_core.dump(self.tree)
end

return M

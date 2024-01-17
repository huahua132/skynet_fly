package = "radix-router"
version = "0.3.0-1"

source = {
  url = "git://github.com/vm-001/lua-radix-router",
  tag = "v0.3.0",
}

description = {
  summary = "Fast API Router for Lua/LuaJIT",
  detailed = [[
    A lightweight high-performance and radix tree based router for Lua/LuaJIT/OpenResty.

    local Router = require "radix-router"
    local router, err = Router.new({
      { -- static path
        paths = { "/foo", "/foo/bar", "/html/index.html" },
        handler = "1" -- handler can be any non-nil value. (e.g. boolean, table, function)
      },
      { -- variable path
        paths = { "/users/{id}/profile-{year}.{format}" },
        handler = "2"
      },
      { -- prefix path
        paths = { "/api/authn/{*path}" },
        handler = "3"
      },
      { -- methods condition
        paths = { "/users/{id}" },
        methods = { "POST" },
        handler = "4"
      }
    })
    if not router then
      error("failed to create router: " .. err)
    end

    assert("1" == router:match("/html/index.html"))
    assert("2" == router:match("/users/100/profile-2023.pdf"))
    assert("3" == router:match("/api/authn/token/genreate"))
    assert("4" == router:match("/users/100", { method = "POST" }))

    -- variable binding
    local params = {}
    router:match("/users/100/profile-2023.pdf", nil, params)
    assert(params.year == "2023")
    assert(params.format == "pdf")
  ]],
  homepage = "https://github.com/vm-001/lua-radix-router",
  license = "BSD-2-Clause license"
}
dependencies = {
  "lua >= 5.1, < 5.5"
}

build = {
  type = "builtin",
  modules = {
    ["radix-router"] = "src/router.lua",
    ["radix-router.route"] = "src/route.lua",
    ["radix-router.trie"] = "src/trie.lua",
    ["radix-router.utils"] = "src/utils.lua",
    ["radix-router.constants"] = "src/constants.lua",
    ["radix-router.iterator"] = "src/iterator.lua",
    ["radix-router.parser"] = "src/parser/parser.lua",
    ["radix-router.parser.style.default"] = "src/parser/style/default.lua",
  },
}
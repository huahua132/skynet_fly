local Router = require "radix-router"
local router, err = Router.new({
  {
    paths = { "/foo", "/foo/bar", "/html/index.html" },
    handler = "1" -- handler can be any non-nil value. (e.g. boolean, table, function)
  },
  {
    -- variable path
    paths = { "/users/{id}/profile-{year}.{format}" },
    handler = "2"
  },
  {
    -- prefix path
    paths = { "/api/authn/{*path}" },
    handler = "3"
  },
  {
    -- methods
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

-- parameter binding
local params = {}
router:match("/users/100/profile-2023.pdf", nil, params)
assert(params.year == "2023")
assert(params.format == "pdf")

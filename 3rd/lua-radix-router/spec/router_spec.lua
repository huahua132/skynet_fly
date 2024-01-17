require 'busted.runner'()

local Router = require "radix-router"

describe("Router", function()
  describe("new", function()
    it("new()", function()
      local router, err = Router.new()
      assert.is_nil(err)
      assert.not_nil(router)
    end)
    it("new() with routes argument", function()
      local router, err = Router.new({})
      assert.is_nil(err)
      assert.not_nil(router)

      local router, err = Router.new({
        {
          paths = { "/" },
          handler = "/",
        }
      })
      assert.is_nil(err)
      assert.not_nil(router)
    end)
    it("new() with invalid routes arugment", function()
      local router, err

      router, err = Router.new(false)
      assert.is_nil(router)
      assert.equal("invalid args routes: routes must be table or nil", err)

      router, err = Router.new("")
      assert.is_nil(router)
      assert.equal("invalid args routes: routes must be table or nil", err)

      router, err = Router.new({
        {
          paths = { "/" },
          handler = "/",
        },
        {
          paths = { "/" },
          handler = nil,
        },
      })
      assert.is_nil(router)
      assert.equal("invalid route(index 2): handler must not be nil", err)

      router, err = Router.new({
        {
          paths = { "/" },
          methods = { "unknown" },
          handler = "/",
        },
      })
      assert.is_nil(router)
      assert.equal("unable to process route(index 1): invalid methond", err)
    end)
    it("new() with opts argument", function()
      local router, err = Router.new({}, {
        trailing_slash_match = true,
        matcher_names = { "host" },
        matchers = {
          {
            match = function(route, ctx, matched) return true end
          }
        }
      })
      assert.is_nil(err)
      assert.not_nil(router)
      assert.equal(true, router.options.trailing_slash_match)
    end)
    it("new() with invalid opts argument", function()
      local router, err = Router.new({}, {
        matchers = { { match = "" } }
      })
      assert.is_nil(router)
      assert.equal("invalid args opts: invalid type matcher.match", err)

      local router, err = Router.new({}, { trailing_slash_match = "" })
      assert.is_nil(router)
      assert.equal("invalid args opts: invalid type trailing_slash_match", err)

      local router, err = Router.new({}, { matcher_names = "" })
      assert.is_nil(router)
      assert.equal("invalid args opts: invalid type matcher_names", err)

      local router, err = Router.new({}, { matcher_names = { "inexistent" } })
      assert.is_nil(router)
      assert.equal("invalid matcher name: inexistent", err)
    end)
  end)
  describe("match", function()
    it("handler can be an arbitrary value except nil", function()
      local tests = {
        { path = "/number", value = 1 },
        { path = "/boolean", value = false },
        { path = "/string", value = "string" },
        { path = "/table", value = { key = "value" } },
        { path = "/function", value = function() print("function") end },
      }
      local routes = {}
      for i, test in ipairs(tests) do
        routes[i] = {
          paths = { test.path },
          handler = test.value
        }
      end
      local router = assert(Router.new(routes))
      for _, test in ipairs(tests) do
        local handler = router:match(test.path)
        assert.equal(test.value, handler)
      end
    end)
    describe("paths", function()
      describe("static path", function()
        it("sanity", function()
          local router = Router.new({
            {
              paths = { "/a" },
              handler = "1",
            },
            {
              paths = { "/b" },
              handler = "2",
            },
          })
          assert.equal("1", router:match("/a"))
          assert.equal("2", router:match("/b"))
        end)
      end)
      describe("variable path", function()
        it("sanity", function()
          local router = Router.new({
            {
              paths = { "/{var1}" },
              handler = "1"
            },
            {
              paths = { "/aa/{var1}" },
              handler = "2",
            },
            {
              paths = { "/aa/{var1}/bb/{var2}" },
              handler = "3",
            },
            {
              paths = { "/bb/{var1}/cc/{var2}" },
              handler = "4",
            },
            {
              paths = { "/bb/{var1}/cc/dd" },
              handler = "5",
            }
          })

          assert.equal("1", router:match("/var1"))
          assert.equal("2", router:match("/aa/var1"))
          assert.equal("3", router:match("/aa/var1/bb/var2"))
          assert.equal("4", router:match("/bb/var1/cc/var2"))
          -- path /bb/var1/cc/dd overlap with handle 4
          assert.equal("5", router:match("/bb/var1/cc/dd"))
        end)
      end)
      describe("prefix path", function()
        it("sanity", function()
          local router = Router.new({
            {
              paths = { "/{*var1}" },
              handler = "1"
            },
            {
              paths = { "/aa/{*var1}" },
              handler = "2",
            },
          })
          assert.equal("1", router:match("/"))
          assert.equal("1", router:match("/aaa"))
          assert.equal("1", router:match("/a/b/c"))
          assert.equal("2", router:match("/aa/"))
          assert.equal("2", router:match("/aa/b"))
          assert.equal("2", router:match("/aa/b/c/d"))
        end)
      end)
      describe("mixed path", function()
        it("longer path has higher priority", function()
          local router = Router.new({
            {
              paths = { "/a/{name}/dog{*}" },
              handler = "1",
            },
            {
              paths = { "/a/{name}/doge" },
              handler = "2",
            },
          })
          local handler = router:match("/a/john/doge")
          assert.equal("2", handler)
        end)
      end)
    end)
    describe("methods", function()
      local router = Router.new({
        {
          paths = { "/00/11/22" },
          handler = "static",
          methods = { "GET" },
        },
        {
          paths = { "/00/{}/22" },
          handler = "dynamic",
          methods = { "POST" },
        },
        {
          paths = { "/aa" },
          handler = "1",
          methods = { "GET" }
        },
        {
          paths = { "/aa" },
          handler = "2",
          methods = { "POST" }
        },
        {
          paths = { "/aa/bb{*}" },
          handler = "3",
          methods = { "GET" }
        },
        {
          paths = { "/aa/{name}" },
          handler = "4",
          methods = { "POST" }
        },
        {
          paths = { "/cc/dd{*}" },
          handler = "5",
          methods = { "GET" }
        },
        {
          paths = { "/cc/{p1}/ee/{p2}" },
          handler = "6",
          methods = { "POST" },
        },
        {
          paths = { "/cc/{p1}/ee/p2{*}" },
          handler = "7",
          methods = { "PUT" },
        },
        {
          paths = { "/cc/{p1}/ee/{p2}/ff" },
          handler = "8",
          methods = { "PATCH" },
        },
        {
          paths = { "/dd/{p1}/ee{*}" },
          handler = "9",
          methods = { "GET" },
        },
        {
          paths = { "/dd/{p1}/ee" },
          handler = "10",
          methods = { "POST" },
        },
        {
          paths = { "/ee{*}" },
          methods = { "GET" },
          handler = "11",
        },
        {
          paths = { "/ee/ff{*}" },
          methods = { "POST" },
          handler = "12",
        },
      })
      it("sanity", function()
        assert.equal("1", router:match("/aa", { method = "GET" }))
        assert.equal("2", router:match("/aa", { method = "POST" }))
        assert.equal("3", router:match("/aa/bb", { method = "GET" }))
        assert.equal("4", router:match("/aa/name", { method = "POST" }))
        assert.equal("5", router:match("/cc/dd", { method = "GET" }))
        assert.equal("6", router:match("/cc/p1/ee/p2", { method = "POST" }))
        assert.equal("7", router:match("/cc/p1/ee/p2x", { method = "PUT" }))
        assert.equal("8", router:match("/cc/p1/ee/p2/ff", { method = "PATCH" }))
      end)
      it("path matches multiple routes", function()
        assert.equal("static", router:match("/00/11/22", { method = "GET" }))
        assert.equal("dynamic", router:match("/00/11/22", { method = "POST" }))
        -- path matches handler3 and handler4
        assert.equal("4", router:match("/aa/bb", { method = "POST" }))
        -- path matches handler5 and handler6 and handler7
        assert.equal("5", router:match("/cc/dd/ee/p2", { method = "GET" }))
        assert.equal("6", router:match("/cc/dd/ee/p2", { method = "POST" }))
        assert.equal("7", router:match("/cc/dd/ee/p2", { method = "PUT" }))
        -- path matches handler5 and handler7 and handler8
        assert.equal("5", router:match("/cc/dd/ee/p2/ff", { method = "GET" }))
        assert.equal("7", router:match("/cc/dd/ee/p2/ff", { method = "PUT" }))
        assert.equal("8", router:match("/cc/dd/ee/p2/ff", { method = "PATCH" }))

        assert.equal("9", router:match("/dd/p1/ee", { method = "GET" }))
        assert.equal("11", router:match("/ee/bb", { method = "GET" }))
      end)
    end)
    describe("priority", function()
      it("highest priority first match", function()
        local router = Router.new({
          {
            paths = { "/static" },
            handler = "1",
            priority = 1,
          },
          {
            paths = { "/static" },
            handler = "2",
            priority = 2,
          },
          {
            paths = { "/param/{name}" },
            handler = "3",
            priority = 1,
          },
          {
            paths = { "/param/{name}" },
            handler = "4",
            priority = 2,
          },
          {
            paths = { "/prefix{*}" },
            handler = "5",
            priority = 1,
          },
          {
            paths = { "/prefix{*}" },
            handler = "6",
            priority = 2,
          },
        })
        assert.equal("2", router:match("/static"))
        assert.equal("4", router:match("/param/name"))
        assert.equal("6", router:match("/prefix"))
      end)
    end)
    describe("hosts", function()
      it("exact host", function()
        local router = Router.new({
          {
            paths = { "/single-host" },
            handler = "1",
            hosts = { "example.com" }
          },
          {
            paths = { "/multiple-hosts" },
            handler = "2",
            hosts = { "foo.com", "bar.com" }
          },
        })
        assert.equal("1", router:match("/single-host", { host = "example.com" }))
        assert.equal(nil, router:match("/single-host", { host = "www.example.com" }))
        assert.equal(nil, router:match("/single-host", { host = "example1.com" }))
        assert.equal(nil, router:match("/single-host", { host = ".com" }))

        assert.equal("2", router:match("/multiple-hosts", { host = "foo.com" }))
        assert.equal("2", router:match("/multiple-hosts", { host = "bar.com" }))
        assert.equal(nil, router:match("/multiple-hosts", { host = "example.com" }))
      end)
      it("wildcard host", function()
        local router = Router.new({
          {
            paths = { "/" },
            handler = "1",
            hosts = { "*.example.com" }
          },
          {
            paths = { "/" },
            handler = "2",
            hosts = { "www.example.*" }
          },
          {
            paths = { "/multiple-hosts" },
            handler = "3",
            hosts = { "foo.com", "*.foo.com", "*.bar.com" }
          },
        })

        assert.equal("1", router:match("/", { host = "www.example.com" }))
        assert.equal("1", router:match("/", { host = "foo.bar.example.com" }))
        assert.equal(nil, router:match("/", { host = ".example.com" }))

        assert.equal("2", router:match("/", { host = "www.example.org" }))
        assert.equal("2", router:match("/", { host = "www.example.foo.bar" }))
        assert.equal(nil, router:match("/", { host = "www.example." }))

        assert.equal("3", router:match("/multiple-hosts", { host = "foo.com" }))
        assert.equal("3", router:match("/multiple-hosts", { host = "www.foo.com" }))
        assert.equal("3", router:match("/multiple-hosts", { host = "www.bar.com" }))
      end)
      it("host value is case-sensitive", function()
        local router = Router.new({
          {
            paths = { "/" },
            hosts = { "example.com" },
            handler = "1",
          }
        })
        assert.equal("1", router:match("/", { host = "example.com" }))
        assert.equal(nil, router:match("/", { host = "examplE.com" }))
      end)
    end)
  end)
  describe("match with params binding", function()
    it("sanity", function()
      local router = Router.new({
        {
          paths = { "/{var}" },
          handler = "0",
        },
        {
          paths = { "/{var1}/{var2}/" },
          handler = "1",
        },
        {
          paths = { "/aa/{var1}/cc/{var2}" },
          handler = "2",
        },
        {
          paths = { "/bb/{*path}" },
          handler = "3",
        },
        {
          paths = { "/cc/{var}/dd/{*path}" },
          handler = "4",
        },
        {
          paths = { "/cc/{*path}" },
          handler = "5",
        },
        {
          paths = { "/dd{*cat}" },
          handler = "6",
        },
        {
          paths = { "/dd{*dog}" },
          handler = "7",
        },
      })
      local ctx = {}
      local binding

      binding = {}
      assert.equal("0", router:match("/var", ctx, binding))
      assert.same({ var = "var" }, binding)

      binding = {}
      assert.equal(nil, router:match("/var1/", ctx, binding))
      assert.equal("1", router:match("/var11111/var222222/", ctx, binding))
      assert.same({ var1 = "var11111", var2 = "var222222" }, binding)

      binding = {}
      assert.equal("2", router:match("/aa/var1/cc/var2", ctx, binding))
      assert.same({ var1 = "var1", var2 = "var2" }, binding)

      binding = {}
      assert.equal("3", router:match("/bb/", ctx, binding))
      assert.same({ path = "" }, binding)

      binding = {}
      assert.equal("3", router:match("/bb/a/b/c/", ctx, binding))
      assert.same({ path = "a/b/c/" }, binding)

      binding = {}
      assert.equal("4", router:match("/cc/var/dd/", ctx, binding))
      assert.same({ var = "var", path = "" }, binding)

      binding = {}
      assert.equal("4", router:match("/cc/var/dd/a/b/c", ctx, binding))
      assert.same({ var = "var", path = "a/b/c" }, binding)

      binding = {}
      assert.equal("6", router:match("/ddsuffix", ctx, binding))
      assert.same({ cat = "suffix" }, binding)
    end)
  end)
  describe("matching order", function()
    it("first registered first match", function()
      local router = Router.new({
        {
          paths = { "/static" },
          handler = "1",
        },
        {
          paths = { "/static" },
          handler = "2",
        },
        {
          paths = { "/param/{name}" },
          handler = "3",
        },
        {
          paths = { "/param/{name}" },
          handler = "4",
        },
        {
          paths = { "/prefix{*}" },
          handler = "5",
        },
        {
          paths = { "/prefix{*}" },
          handler = "6",
        },
      })
      assert.equal("1", router:match("/static"))
      assert.equal("3", router:match("/param/name"))
      assert.equal("5", router:match("/prefix"))
    end)
    it("static > dynamic", function()
      local router = Router.new({
        {
          paths = { "/aa/bb" },
          handler = "1",
        },
        {
          paths = { "/aa/bb{*path}" },
          handler = "2",
        },
        {
          paths = { "/aa/{name}" },
          handler = "3",
        }
      })
      assert.equal("1", router:match("/aa/bb"))
    end)
  end)
  describe("match with matched", function()
    it("sanity", function()
      local router = Router.new({
        {
          paths = { "/static" },
          methods = { "GET" },
          hosts = { "example.com" },
          handler = "1",
        },
        {
          paths = { "/a/{var}", "/b/{var}" },
          methods = { "POST", "PUT" },
          hosts = { "*.example.com" },
          handler = "2",
        },
      })

      local matched = {}
      assert.equal("1", router:match("/static", { method = "GET", host = "example.com" }, nil, matched))
      assert.same({
        path = "/static",
        host = "example.com",
        method = "GET",
      }, matched)

      local matched = {}
      assert.equal("2", router:match("/b/var", { method = "PUT", host = "www.example.com" }, nil, matched))
      assert.same({
        path = "/b/{var}",
        host = "*.example.com",
        method = "PUT",
      }, matched)
    end)
  end)
  describe("trailing slash match", function()
    it("sanity", function()
      local options = {
        trailing_slash_match = true,
      }

      local router = Router.new({
        -- static routes
        {
          paths = { "/static1" },
          handler = "static1",
        },
        {
          paths = { "/static2/" },
          handler = "static2",
        },
        -- variable in the middle
        {
          paths = { "/users/{id}/profile" },
          handler = "0",
        },
        {
          paths = { "/pets/{id}/profile/" },
          handler = "1",
        },
        -- variable at the end
        {
          paths = { "/zz/{id}" },
          handler = "2",
        },
        {
          paths = { "/ww/{id}/" },
          handler = "3",
        },
      }, options)

      assert.equal("static1", router:match("/static1/"))
      assert.equal("static2", router:match("/static2"))

      -- matched when path has a extra trailing slash
      assert.equal("0", router:match("/users/1/profile/"))
      -- matched when path misses trailing slash
      assert.equal("1", router:match("/pets/1/profile"))

      -- matched when path has a extra trailing slash
      assert.equal("2", router:match("/zz/1/"))
      -- matched when path misses trailing slash
      assert.equal("3", router:match("/ww/1"))
    end)
    it("with methods condition", function()
      local options = {
        trailing_slash_match = true,
      }

      local router = Router.new({
        {
          paths = { "/a/{var}" },
          methods = { "GET" },
          handler = "10",
        },
        {
          paths = { "/a/{var}/" },
          methods = { "POST" },
          handler = "20",
        },
        {
          paths = { "/bb/{var}/foo" },
          methods = { "GET" },
          handler = "30",
        },
        {
          paths = { "/bb/{var}/bar" },
          methods = { "GET" },
          handler = "40",
        },
      }, options)

      -- exact match
      assert.equal("10", router:match("/a/var", { method = "GET" }))
      -- matched when path has a extra trailing slash
      assert.equal("10", router:match("/a/var/", { method = "GET" }))

      -- exact match
      assert.equal("20", router:match("/a/var/", { method = "POST" }))
      -- matched when path misses trailing slash
      assert.equal("20", router:match("/a/var", { method = "POST" }))

      -- the prepreerence for path /a/var is handle 10, but the method is not matched
      assert.equal("20", router:match("/a/var", { method = "POST" }))
      -- the prepreerence for path /a/var/ is handle 20, but the method is not matched
      assert.equal("10", router:match("/a/var/", { method = "GET" }))

      assert.equal("30", router:match("/bb/var/foo/", {  method = "GET" }))
      assert.equal("40", router:match("/bb/var/bar/", {  method = "GET" }))
    end)
  end)
  describe("custom matchers", function()
    it("disable all of the built-in matcher", function()
      local opts = {
        matcher_names = {}
      }
      local router = Router.new({
        {
          paths = { "/" },
          methods = { "GET" },
          hosts = { "www.a.com" },
          handler = "1",
        },
      }, opts)
      assert.equal("1", router:match("/"))
    end)
    it("disable some of the built-in matcher", function()
      local opts = {
        matcher_names = { "method" }
      }
      local router = Router.new({
        {
          paths = { "/" },
          methods = { "GET" },
          hosts = { "www.a.com" },
          handler = "1",
        },
      }, opts)
      assert.equal("1", router:match("/", { method = "GET", host = "no-matter-what" }))
    end)
    it("custom matcher", function()
      local ip_matcher = {
        process = function(route)
          if route.ips then
            local ips = {}
            for _, ip in ipairs(route.ips) do
              ips[ip] = true
            end
            route.ips = ips
          end
        end,
        match = function(route, ctx, matched)
          if route.ips then
            local ip = ctx.ip
            if not route.ips[ip] then
              return false
            end
            if matched then
              matched["ip"] = ip
            end
          end
          return true
        end
      }
      local opts = {
        matchers = { ip_matcher }
      }

      local router = Router.new({
        {
          paths = { "/" },
          ips = { "127.0.0.1", "127.0.0.2" },
          handler = "1",
        },
        {
          paths = { "/" },
          ips = { "192.168.1.1", "192.168.1.2" },
          handler = "2",
        }
      }, opts)
      assert.equal("1", router:match("/", { ip = "127.0.0.2" }))
      assert.equal("2", router:match("/", { ip = "192.168.1.2" }))
      -- with matched
      local matched = {}
      assert.equal("2", router:match("/", { ip = "192.168.1.2" }, nil, matched))
      assert.equal("192.168.1.2", matched.ip)
    end)
  end)
end)

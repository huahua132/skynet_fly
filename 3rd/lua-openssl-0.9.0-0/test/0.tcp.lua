local lu = require 'luaunit'
local helper = require'helper'

local ok, uv = pcall(require, 'luv')
if not ok then uv = nil end

local LUA = arg and arg[-1] or nil
TestTCP = {}

if not LUA then
    return
end

if uv then
  local function set_timeout(timeout, callback)
    local timer = uv.new_timer()
    local function ontimeout()
      uv.timer_stop(timer)
      uv.close(timer)
      callback(timer)
    end
    uv.timer_start(timer, timeout, 0, ontimeout)
    return timer
  end

  function TestTCP:testUVTcp()
    local port = math.random(8000, 9000)
    helper.spawn(LUA,
      {"0.tcp_s.lua",  '127.0.0.1',  port},
      'accepting...',
      function()
        print('started')
        helper.spawn(LUA,
          {"0.tcp_c.lua",  '127.0.0.1',  port}
        )
      end
    )
    uv.run()
  end
end

local luv
ok, luv = pcall(require, 'lluv')
if not ok then luv = nil end

if luv then

  local function P(pipe, read)
    return {
      stream = pipe,
      flags = luv.CREATE_PIPE +
        (read and luv.READABLE_PIPE or luv.WRITABLE_PIPE)
    }
  end

  local lua_spawn = function(f, o, e, c)
    return luv.spawn({
      file = LUA,
      args = {f},
      stdio = {{},  P(o, false),  P(e, false)}
    }, c)
  end

  function TestTCP:testLUVTCP()
    local function onread(pipe, err, chunk)
      if err then
        if err:name() ~= 'EOF' then assert(not err, tostring(err)) end
      end
      if chunk then print(chunk) end
    end

    local function onclose(child, err, status)
      if err then return print("Error spawn:", err) end
      lu.assertEquals(status, 0)
      child:close()
    end

    local stdout1 = luv.pipe()
    local stderr1 = luv.pipe()
    local stdout2 = luv.pipe()
    local stderr2 = luv.pipe()

    lua_spawn("0.tcp_s.lua", stdout1, stderr1, onclose)
    lua_spawn("0.tcp_c.lua", stdout2, stderr2, onclose)

    stdout1:start_read(onread)
    stderr1:start_read(onread)
    stdout2:start_read(onread)
    stderr2:start_read(onread)

    luv.run()
    luv.close()
  end
end

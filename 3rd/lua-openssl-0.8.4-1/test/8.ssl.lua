local lu = require 'luaunit'
local ok, uv = pcall(require, 'luv')
local math = require 'math'
local openssl = require "openssl"
local helper = require 'helper'
local bio, ssl = openssl.bio, openssl.ssl
local unpack = table.unpack or unpack

if not ok then
  uv = nil
  print('skip SSL, bacause luv not avalible')
end

TestSSL = {}
local LUA
if arg then
  local i = 0
  repeat
    LUA = arg[i]
    print(i, LUA)
    i = i - 1
  until not arg[i]
  assert(LUA)
end

if uv then

  math.randomseed(os.time())
  local function set_timeout(timeout, callback)
    local timer = uv.new_timer()
    local function ontimeout()
      uv.timer_stop(timer)
      uv.close(timer)
      callback()
    end
    uv.timer_start(timer, timeout, 0, ontimeout)
    return timer
  end

  function TestSSL:testMisc()
    assert(ssl.alert_type(1) == 'W')
    assert(ssl.alert_type(1, true) == 'warning')
    assert(ssl.alert_type(2) == 'F')
    assert(ssl.alert_type(2, true) == 'fatal')
    assert(ssl.alert_type(3) == 'U')
    assert(ssl.alert_type(3, true) == 'unknown')

    local list = {10,  20,  21,  22,  30,  40,  50,  60,  70,  80,  90,  100}
    for _, i in pairs(list) do
      assert(ssl.alert_desc(i) ~= 'U', i)
      assert(ssl.alert_desc(i, true) ~= 'unknown', i)
    end
  end

  function TestSSL:testUV_1SSL()
    local port = math.random(8000, 9000)
    helper.spawn(LUA,
      {"8.ssl_s.lua",  '127.0.0.1',  port},
      'accpeting...',
      function()
        print('started')
        helper.spawn(LUA,
          {"8.ssl_c.lua",  '127.0.0.1',  port}
        )
      end
    )
    uv.run()
  end

  function TestSSL:testUV_2BIO()
    local port = math.random(8000, 9000)
    helper.spawn(LUA,
      {"8.bio_s.lua",  '127.0.0.1',  port},
      'accpeting...',
      function()
        print('started')
        helper.spawn(LUA,
          {"8.bio_c.lua",  '127.0.0.1',  port}
        )
      end
    )
    uv.run()
  end

  function TestSSL:testUV_3SSLCBIO()
    local port = math.random(8000, 9000)
    helper.spawn(LUA,
      {"8.bio_s.lua",  '127.0.0.1',  port},
      'accpeting...',
      function()
        print('started')
        helper.spawn(LUA,
          {"8.ssl_c.lua",  '127.0.0.1',  port}
        )
      end
    )
    uv.run()
  end

  function TestSSL:testUV_4BIOCSSL()
    local port = math.random(8000, 9000)
    helper.spawn(LUA,
      {"8.ssl_s.lua",  '127.0.0.1',  port},
      'accpeting...',
      function()
        print('started')
        helper.spawn(LUA,
          {"8.bio_c.lua",  '127.0.0.1',  port}
        )
      end
    )
    uv.run()
  end

  function TestSSL:testUV_SSL4UV()
    local port = math.random(8000, 9000)
    helper.spawn(LUA,
      {"8.ssl_uv_s.lua",  '127.0.0.1',  port},
      'accpeting...',
      function()
        print('started')
        helper.spawn(LUA,
          {"8.bio_uv_c.lua",  '127.0.0.1',  port}
        )
      end
    )
    uv.run()
  end

  function TestSSL:testUV_DTLS()
    if helper.opensslv:match('1.0.2') then
      return
    end
    local port = math.random(8000, 9000)
    helper.spawn(LUA,
      {"8.bio_dtls_s.lua",  '127.0.0.1',  port},
      'accpeting...',
      function()
        print('started')
        helper.spawn(LUA,
          {"8.bio_dtls_c.lua",  '127.0.0.1',  port}
        )
      end
    )
    uv.run()
  end

end

local luv
ok, luv = pcall(require, 'lluv')
if not ok then luv = nil end

local lua_spawn
do
  local function P(pipe, read)
    return {
      stream = pipe,
      flags = luv.CREATE_PIPE +
        (read and luv.READABLE_PIPE or luv.WRITABLE_PIPE)
    }
  end

  lua_spawn = function(f, o, e, c)
    return luv.spawn({
      file = LUA,
      args = {f},
      stdio = {{},  P(o, false),  P(e, false)}
    }, c)
  end
end

local function onread(pipe, err, chunk)
  if err then
    if err:name() ~= 'EOF' then assert(not err, tostring(err)) end
    pipe:close()
  end

  if chunk then
    print(chunk)
  else
    print("end")
  end
end

local function onclose(child, err, status)
  if err then return print("Error spawn:", err) end
  lu.assertEquals(status, 0)
  child:close()
end

if luv then
  function TestSSL:testLUVSSL()
    local stdout1 = luv.pipe()
    local stderr1 = luv.pipe()
    local stdout2 = luv.pipe()
    local stderr2 = luv.pipe()

    lua_spawn("8.ssl_s.lua", stdout1, stderr1, onclose)
    os.execute('ping -n 3 127.0.0.1')
    lua_spawn("8.ssl_c.lua", stdout2, stderr2, onclose)

    stdout1:start_read(onread)
    stderr1:start_read(onread)
    stdout2:start_read(onread)
    stderr2:start_read(onread)

    luv.run()
    luv.close()
  end

  function TestSSL:testLUVBio()
    local stdout1 = luv.pipe()
    local stderr1 = luv.pipe()
    local stdout2 = luv.pipe()
    local stderr2 = luv.pipe()

    lua_spawn("8.bio_s.lua", stdout1, stderr1, onclose)
    os.execute('ping -n 3 127.0.0.1')
    lua_spawn("8.bio_c.lua", stdout2, stderr2, onclose)

    stdout1:start_read(onread)
    stderr1:start_read(onread)
    stdout2:start_read(onread)
    stderr2:start_read(onread)

    luv.run()
    luv.close()
  end

  function TestSSL:testLUVsslconnectbio()
    local stdout1 = luv.pipe()
    local stderr1 = luv.pipe()
    local stdout2 = luv.pipe()
    local stderr2 = luv.pipe()

    lua_spawn("8.bio_s.lua", stdout1, stderr1, onclose)
    os.execute('ping -n 3 127.0.0.1')
    lua_spawn("8.ssl_c.lua", stdout2, stderr2, onclose)

    stdout1:start_read(onread)
    stderr1:start_read(onread)
    stdout2:start_read(onread)
    stderr2:start_read(onread)

    luv.run()
    luv.close()
  end

  function TestSSL:testLUVbioconnectssl()
    local stdout1 = luv.pipe()
    local stderr1 = luv.pipe()
    local stdout2 = luv.pipe()
    local stderr2 = luv.pipe()

    lua_spawn("8.ssl_s.lua", stdout1, stderr1, onclose)
    os.execute('ping -n 3 127.0.0.1')
    lua_spawn("8.bio_c.lua", stdout2, stderr2, onclose)

    stdout1:start_read(onread)
    stderr1:start_read(onread)
    stdout2:start_read(onread)
    stderr2:start_read(onread)

    luv.run()
    luv.close()
  end
end

function TestSSL:testSNI()
  local ca = helper.get_ca()
  local store = ca:get_store()
  assert(store:trust(true))
  store:add(ca.cacert)
  store:add(ca.crl)

  local certs = {}

  local session_cache = {}

  local function create_ctx(dn, mode)
    mode = mode or '_server'
    local ctx = ssl.ctx_new(ssl.default .. mode)
    if dn then
      local cert, pkey = helper.sign(dn)
      assert(ctx:use(pkey, cert))
      certs[#certs + 1] = cert
    end
    ctx:set_session_callback(
      function(s, ss)
        -- add
        assert(tostring(s):match('openssl.ssl '))
        assert(tostring(ss):match('openssl.ssl_session'))
        local id = ss:id()
        session_cache[id] = ss
        return true
      end
      ,function(s, id)
        -- get
        assert(tostring(s):match('openssl.ssl '))
        assert(type(id)=='string')
        local ss = session_cache[id]
        print(ss)
        return ss
      end,
      function(id)
        session_cache[id] = nil
      end
    )
    ctx:session_cache_mode('both', 'no_internal')
    -- warning: https://stackoverflow.com/questions/14397917/reuse-ssl-session-on-c-client-server-application
    if ssl.no_ticket then
      ctx:options(ssl.no_ticket)
    end
    return ctx
  end

  local function create_srv_ctx()
    local ctx = create_ctx({{CN = "server"},  {C = "CN"}})
    ctx:set_servername_callback({
      ["serverA"] = create_ctx {{CN = "serverA"},  {C = "CN"}},
      ["serverB"] = create_ctx {{CN = "serverB"},  {C = "CN"}}
    })
    if store then ctx:cert_store(store) end

    ctx:set_cert_verify()
    ctx:set_cert_verify({always_continue = true,  verify_depth = 4})
    return ctx
  end

  local function create_cli_ctx()
    local ctx = create_ctx(nil, '_client')
    if store then ctx:cert_store(store) end
    ctx:set_cert_verify({always_continue = true,  verify_depth = 4})
    return ctx
  end
  local bs, bc = bio.pair()

  local rs, cs, es, ec, i, o, sess

  local srv_ctx = create_srv_ctx()
  local ss = assert(srv_ctx:ssl())
  assert(ss:dup())
  local cli_ctx = create_cli_ctx()
  local srv = assert(srv_ctx:ssl(bs, bs, true))
  local cli = assert(cli_ctx:ssl(bc, bc, false))
  srv_ctx:add(ca.cacert, certs)
  srv_ctx:set_engine(openssl.engine('openssl'))
  srv_ctx:timeout(500)
  assert(srv_ctx:timeout() == 500)
  local t = assert(srv_ctx:session_cache_mode())
  srv_ctx:mode(true, "enable_partial_write", "accept_moving_write_buffer",
               "auto_retry", "no_auto_chain")
  srv_ctx:mode(false, "enable_partial_write", "accept_moving_write_buffer",
               "auto_retry", "no_auto_chain")

  srv_ctx:flush_sessions(10000)
  repeat
    cs, ec = cli:handshake()
    rs, es = srv:handshake()
  until (rs and cs) or (rs == nil or cs == nil)
  assert(rs and cs)
  i, o = cli:pending()
  local msg = openssl.random(20)
  cli:write(msg)
  srv:write(srv:read())
  local got = cli:read()
  assert(got == msg)
  local peer = cli:peer()
  assert(peer:subject():oneline() == "/CN=server/C=CN")
  sess = cli:session()
  cli:shutdown()
  srv:shutdown()
  bs:close()
  bc:close()

  bs, bc = bio.pair()
  srv = assert(srv_ctx:ssl(bs, true))
  cli = assert(cli_ctx:ssl(bc, false))
  cli:set('hostname', 'serverB')
  cli:session(sess)
  repeat
    cs, ec = cli:handshake()
    rs, es = srv:handshake()
  until (rs and cs) or (rs == nil or cs == nil)
  assert(rs and cs)
  peer = cli:peer()
  -- FIXME: libressl sni hostname
  if not helper.libressl then
    assert(peer:subject():oneline() == "/CN=server/C=CN")
  else
    assert(peer:subject():oneline() == "/CN=serverB/C=CN")
  end
  if not helper.libressl then
    rc, ec = cli:renegotiate()
    rs, es = srv:renegotiate_abbreviated()
    cli:renegotiate_pending()
    assert(cli:read() == false)
    assert(srv:read() == false)
    repeat
      cs, ec = cli:handshake()
      rs, es = srv:handshake()
    until (rs and cs) or (rs == nil or cs == nil)
    assert(rs and cs)
  end
  cli:write(msg)
  srv:write(srv:read())
  got = cli:read()
  assert(got == msg)
  peer = cli:peer()
  cli:shutdown('read')
  cli:shutdown('write')
  cli:shutdown('quiet')
  cli:shutdown('noquiet')
  cli:shutdown(true)
  cli:shutdown(false)
  local oneline = peer:subject():oneline()
  assert(oneline == "/CN=server/C=CN" or oneline == "/CN=serverB/C=CN")
  bs:close()
  bc:close()

  local cert, pkey = helper.sign({{CN = "server"},  {C = "CN"}})

  bs, bc = bio.pair()
  srv = assert(srv_ctx:ssl(bs))
  srv:set_accept_state()
  cli = assert(cli_ctx:ssl(bc))
  cli:use(cert, pkey)
  cli:set_connect_state()
  cli:set('hostname', 'serverB')
  repeat
    cs, ec = cli:handshake()
    rs, es = srv:handshake()
    srv:want()
  until (rs and cs) or (rs == nil or cs == nil)
  assert(rs and cs)
  cli:write(msg)
  srv:write(srv:read())
  got = cli:peek()
  assert(got == msg)
  got = cli:read()
  assert(got == msg)
  peer = cli:peer()
  if cli.current_compression then
    cli:current_compression()
  end
  assert(peer:subject():oneline() == "/CN=serverB/C=CN")
  assert(cli:get('hostname') == 'serverB')
  sess = cli:session()
  local S = sess:export()
  S = ssl.session_read(S)
  assert(S)
  if sess.has_ticket then assert(type(sess:has_ticket()) == 'boolean') end
  if sess.is_resumable then assert(sess:is_resumable()) end
  assert(sess:peer())
  assert(sess:compress_id())
  assert(sess:timeout())
  assert(sess:timeout(500))
  assert(sess:time())
  assert(sess:time(50))
  assert(sess:id())
  local id = assert(sess:id())
  sess:id(id)
  cli:getpeerverification()
  cli:get('version')
  cli:get('certificate')
  cli:get('client_CA_list')
  cli:set('fd',    cli:get('fd'))
  cli:set('rfd',   cli:get('rfd'))
  cli:set('wfd',   cli:get('wfd'))
  cli:set('client_CA',  ca.cacert)
  cli:set('read_ahead', cli:get('read_ahead'))
  cli:get('shared_ciphers')
  cli:set('cipher_list', cli:get('cipher_list'))
  cli:get('verify_mode')
  cli:set('verify_depth', cli:get('verify_depth'))
  cli:set('purpose',   1)
  cli:set('trust',   1)
  cli:get('state_string')
  cli:get('state_string_long')
  cli:get('rstate_string')
  cli:get('rstate_string_long')
  cli:get('iversion')
  cli:get('version')
  cli:get('default_timeout')
  cli:set('verify_result', cli:get('verify_result'))
  cli:get('state')
  cli:get('state_string')
  cli:get('side')
  cli:set('hostname', cli:get('hostname'))

  cli:cache_hit()
  cli:session_reused()

  local ret, msg = cli:dup()
  assert(ret==nil)
  assert(msg:match("^invalid state:"))

  local ctx = cli:ctx()
  assert(ctx)
  assert(cli:ctx(ctx))
  srv_ctx:session(sess, true)
  srv_ctx:session(sess, false)
  srv_ctx:session(sess:id(), false)

  srv_ctx:quiet_shutdown(1)
  assert(srv_ctx:quiet_shutdown()==1)
  srv_ctx:verify_locations('certs/ca1-cert.pem')
  assert(srv_ctx:cert_store())
  assert(srv_ctx:verify_depth(9))
  assert(srv_ctx:verify_mode())
  srv_ctx:verify_mode(ssl.peer, function()
    return true
  end)

  if srv_ctx.num_tickets then
    srv_ctx:num_tickets(assert(srv_ctx:num_tickets()))
  end

  local cache_mode = {
    'client', 'server',
    'no_auto_clear',
    'no_internal_lookup', 'no_internal_store'
  }

  local old = srv_ctx:session_cache_mode()

  srv_ctx:session_cache_mode(0)
  local t = srv_ctx:session_cache_mode()
  assert(#t==1 and t[1]=='off')

  srv_ctx:session_cache_mode('client', 'no_internal_lookup')
  t = srv_ctx:session_cache_mode()
  assert(#t==2 and t[1]=='client' and t[2]=='no_internal_lookup')

  srv_ctx:session_cache_mode('server', 'no_internal_store')
  t = srv_ctx:session_cache_mode()
  assert(#t==2 and t[1]=='server' and t[2]=='no_internal_store')

  srv_ctx:session_cache_mode(unpack(cache_mode))
  t = srv_ctx:session_cache_mode()
  assert(#t==3 and t[1]=='no_auto_clear' and t[2]=='both' and t[3]=='no_internal')

  srv_ctx:session_cache_mode(unpack(old))
  lu.assertEquals(old, srv_ctx:session_cache_mode())

  local eng = openssl.engine('openssl')
  eng:load_ssl_client_cert(cli)
  cli:clear()
  cli:shutdown()

  bs:close()
  bc:close()

  sess = ssl.session_new()
  sess:id(id)
end

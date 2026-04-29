
local openssl = require "openssl"
local bio = openssl.bio

local lu = require('luaunit')
------------------------------------------------------------------------------
TestBIO = {}

function TestBIO:testMem()
  local m = bio.mem(4)
  local s = m:get_mem()
  assert(s=='')

  m = bio.mem('abcd')
  s = m:get_mem()
  assert(s=='abcd')
  local rp, wp = m:pending()
  assert(rp==4)
  assert(wp==0)

  m:write('aa')
  s = m:read()
  assert(s=='abcdaa')

  m:puts("aa")
  s = m:gets(1024)
  assert(s=='aa')
  assert(m:type()=="memory buffer")
  m:reset()
end

function TestBIO:testNetwork()
  local cli = bio.connect("kkhub.com", false)
  cli:retry()
  assert(cli)
  cli = bio.connect({
      hostname= 'kkhub.com',
      port = "12345"
  }, false)
  assert(cli:nbio(false))
  cli:retry()
  assert(cli)
  cli = bio.connect()
  assert(cli:nbio(true))
  cli:shutdown()
  assert(cli)
end

function TestBIO:testFilter()
  local m

  local buf = bio.filter('buffer')
  buf:close()

  local b64 = bio.filter('base64')
  local mem = bio.mem()
  b64 = assert(b64:push(mem))
  b64:write('abcd')
  b64:flush()
  local s = b64:get_mem()
  assert(s=='YWJjZA==\n')
  b64:free()

  local md = bio.filter('md', 'sha1')
  mem = bio.mem('abcd')
  md = assert(md:push(mem))
  md:write('abcd')
  md:flush()
  md, m = md:get_md()
  assert(md)
  assert( m)
  assert(md:next():get_md()==nil)

  md = md:pop()
  assert(md)
  assert(nil==md:pop())
  md:free()

  m = '1234567812345678'
  local cipher = bio.filter('cipher', 'aes-128-ecb', '1234567812345678', '1234567812345678', true)
  mem = bio.mem()

  cipher = assert(cipher:push(mem))
  mem:write(m)
  assert(cipher:cipher_status())
  s = cipher:read()
  assert(#s==16)
  cipher:free()

  cipher = bio.filter('cipher', 'aes-128-ecb', '1234567812345678', '1234567812345678', false)
  mem = bio.mem(s)

  cipher = assert(cipher:push(mem))
  assert(cipher:cipher_status())
  s = cipher:read()
  assert(s)
  cipher:free()
end

function TestBIO:testSocket()
  local s = bio.socket(555)
  s:close()

  local d = bio.dgram(555)
  d:close()

  s = bio.accept(899)
  s:close()
end

function TestBIO:testFile()
  local f = bio.fd(2)
  assert(2==f:fd())
  assert(1==f:fd(1))
  f:close()

  f = bio.file('./test.lua')
  assert(f:seek(0));
  assert(f:tell())
  f:close()
end

function TestBIO:testNull()
  local n = bio.null()
  n:write('abcd')
  assert(n:read()==nil)
  n:close()
end


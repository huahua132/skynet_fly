-- Testcase
local lu = require 'luaunit'
local openssl = require 'openssl'
local ssl = openssl.ssl
local helper = require 'helper'

local proto = helper.sslProtocol()

local SET = function(t)
  local s = {}
  for _, k in ipairs(t) do s[k] = true end
  return s
end
local libressl = helper.libressl

TestSSLOptions = {}
function TestSSLOptions:setUp()
  self.ctx = assert(ssl.ctx_new(proto))
end

function TestSSLOptions:testSet()
  local t, e = self.ctx:options()
  assert(type(t) == "table", e or type(t))
  t = SET(t)
  lu.assertIsTable(t)
  lu.assertEquals(0, #t)

  t = self.ctx:options(ssl.no_sslv3, "no_ticket")
  t = SET(t)
  lu.assertIsTable(t)
  assert(libressl or t.no_sslv3)
  assert(t.no_ticket)

  assert(not pcall(self.ctx.options, self.ctx, true, nil))
  lu.assertIsTable(t)
  assert(libressl or t.no_sslv3)
  assert(t.no_ticket)
end

function TestSSLOptions:testClear()
  self.ctx:options(true, ssl.no_sslv3, "no_ticket")

  local t = SET(assert(self.ctx:options()))
  lu.assertIsTable(t)
  assert(not t.no_sslv3)
  assert(not t.no_ticket)
end

function TestSSLOptions:testCiphersuites()
  if helper.supportTLSv1_3() then
    local ctx = openssl.ssl.ctx_new('TLS', 'TLS_AES_128_GCM_SHA256:ECDHE-RSA-AES128-SHA256')
  end
end

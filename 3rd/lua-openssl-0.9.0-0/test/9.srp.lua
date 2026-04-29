local lu = require 'luaunit'
local openssl = require 'openssl'
local srp = openssl.srp
if srp == nil then
  print('Skip test srp')
  return
end

local GN = assert(srp.get_default_gN('1024'));

TestSRP = {}
function TestSRP:setUp()
  self.user = 'zhaozg'
  self.pass = 'password'
end

function TestSRP:tearDown()
end

function TestSRP:test_1_SRV_CreateVerifier()
  self.salt, self.verifier = GN:create_verifier(self.user, self.pass)
  assert(self.salt)
  assert(self.verifier)
end

function TestSRP:test_2_SRV_Calc_b()
  self.Bpub, self.Brnd = GN:calc_b(self.verifier)
  assert(self.Bpub)
  assert(self.Brnd)
end

function TestSRP:test_3_CLI_Calc_a()
  self.Apub, self.Arnd = GN:calc_a()
  assert(self.Apub)
  assert(self.Arnd)
end

function TestSRP:test_4_Calc_u()
  self.u = assert(GN:calc_u(self.Apub, self.Bpub))
end

function TestSRP:test_5_cli_key()
  local x = assert(GN.calc_x(self.salt, self.user, self.pass))
  self.Kclient = assert(GN:calc_client_key(self.Bpub, x, self.Arnd, self.u))
end

function TestSRP:test_6_srv_key()
  local Kserver = assert(GN:calc_server_key(self.Apub, self.verifier, self.u,
                                               self.Brnd))
  assert(Kserver == self.Kclient)
end

function TestSRP:test_7_cli_key()
  local x = assert(GN.calc_x(self.salt, self.user, self.pass .. '1'))
  self.Kclient = assert(GN:calc_client_key(self.Bpub, x, self.Arnd, self.u))
end

function TestSRP:test_8_srv_key()
  local Kserver = assert(GN:calc_server_key(self.Apub, self.verifier, self.u,
                                               self.Brnd))
  assert(Kserver ~= self.Kclient)
end


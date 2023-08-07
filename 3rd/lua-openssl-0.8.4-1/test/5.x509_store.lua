local lu = require 'luaunit'

local openssl = require 'openssl'
local helper = require'helper'

TestStore = {}

function TestStore:testAll()
  local ca = helper.get_ca()
  local store = ca:get_store()
  assert(store:trust(true))
  store:add(ca.cacert)
  store:add(ca.crl)
  assert(store:load('certs/agent1-cert.pem', 'certs'))
  assert(store:add_lookup('certs', 'dir', 'pem'))
  assert(store:add_lookup('certs/agent1-cert.pem', 'file', 'pem'))
  assert(store:depth(9))
  assert(store:flags(0))
  store:add({ca.cacert, ca.crl})

  assert(store:purpose(1))
end


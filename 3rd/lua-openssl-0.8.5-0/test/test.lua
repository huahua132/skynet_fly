--[[
--2021.09.26 uncommit this block will cause ci fail
--Should be bug in LuaJIT
--https://github.com/LuaJIT/LuaJIT/commits/v2.1
collectgarbage('setpause', 0)
collectgarbage('setstepmul', 10000000000000)
--]]

local lu = require'luaunit'
local openssl = require'openssl'
local helper = require'helper'

openssl.rand_load()
print('VERSION:', openssl.version())
assert(openssl.rand_status())

if not (helper.openssl3 or helper.libressl) then
assert(openssl.FIPS_mode()==false)
assert(openssl.FIPS_mode(false))
assert(openssl.FIPS_mode()==false)
end

dofile('0.bio.lua')
dofile('0.bn.lua')
dofile('0.engine.lua')
dofile('0.misc.lua')
dofile('0.tcp.lua')
dofile('1.asn1.lua')
dofile('2.asn1.lua')
dofile('1.x509_algor.lua')
dofile('1.x509_name.lua')
dofile('1.x509_extension.lua')
dofile('1.x509_attr.lua')
dofile('2.digest.lua')
dofile('2.hmac.lua')
dofile('2.mac.lua')
dofile('3.cipher.lua')
dofile('4.pkey.lua')
dofile('4.pkey_ctx.lua')
dofile('5.x509_req.lua')
dofile('5.x509_crl.lua')
dofile('5.x509_store.lua')
dofile('5.x509.lua')
dofile('5.ts.lua')
dofile('6.pkcs7.lua')
dofile('6.cms.lua')
dofile('7.pkcs12.lua')
dofile('8.ssl_options.lua')
dofile('8.ssl.lua')
dofile('9.ocsp.lua')
dofile('9.srp.lua')
dofile('9.issue.lua')
dofile('issue#156.lua')
dofile('issue#185.lua')
dofile('dh.lua')
dofile('dsa.lua')
dofile('rsa.lua')
dofile('ec.lua')
dofile('sm2.lua')

local runner = lu.LuaUnit.new()
runner:setOutputType("tap")
local retcode = runner:runSuite()
assert(openssl.rand_write())
print(openssl.errors())
openssl.clear_error()
collectgarbage()
os.exit(retcode, true)


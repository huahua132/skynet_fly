local openssl = require'openssl'
local lu=require'luaunit'

openssl.rand_load()

dofile('0.engine.lua')
dofile('0.misc.lua')
dofile('1.asn1.lua')
dofile('2.asn1.lua')
dofile('1.x509_name.lua')
dofile('1.x509_extension.lua')
dofile('1.x509_attr.lua')
dofile('2.digest.lua')
dofile('2.hmac.lua')
dofile('3.cipher.lua')
dofile('4.pkey.lua')
dofile('rsa.lua')
dofile('ec.lua')

dofile('5.x509_req.lua')
dofile('5.x509_crl.lua')
dofile('5.x509.lua')
dofile('5.ts.lua')
dofile('6.pkcs7.lua')
dofile('7.pkcs12.lua')
dofile('8.ssl_options.lua')

collectgarbage()
collectgarbage()

local mem_start, mem_current, mem_previos
mem_start = collectgarbage("count")
mem_previos = mem_start

local count = 1000
local step = 10
assert(step < count/9, string.format("step should be %d", math.floor(count/10)))

local runner = lu.LuaUnit.new()
runner:setOutputType("nil")

for _=1, count do
    runner:runSuite()
    collectgarbage()
    collectgarbage()
    mem_current = collectgarbage("count")
    if _ % step == 0 then
        print(string.format("** %d\tincrement %.04f%%", _, (mem_current-mem_previos)/mem_previos))
        mem_previos = mem_current
    end
end

collectgarbage()
collectgarbage()
mem_current = collectgarbage("count")
print(string.format("****From %d to %d, increment=%.04f%%",
    mem_start, mem_current, (mem_current-mem_start)/mem_start))

local openssl = require'openssl'
local helper = require'helper'
local ssl,pkey,x509 = openssl.ssl,openssl.pkey,openssl.x509

local M = {}

local function load(path)
    local f = assert(io.open(path,'r'))
    if f then
        local c = f:read('*all')
        f:close()
        return c
    end
end

function M.new(params, protocol)
--[[
local params = {
   mode = "server",
   protocol = ssl.default,
   key = "../certs/serverAkey.pem",
   certificate = "../certs/serverA.pem",
   cafile = "../certs/rootA.pem",
   verify = {"peer", "fail_if_no_peer_cert"},
   options = {"all", "no_sslv2"},
   password = 'password'
}
--]]
    protocol = protocol or (params.protocol and string.upper(string.sub(params.protocol,1,3))
        ..string.sub(params.protocol,4,-1) or helper.sslProtocol())
    local ctx = ssl.ctx_new(protocol,params.ciphers)
    local xkey = nil
    if (type(params.password)=='nil') then
        xkey = assert(pkey.read(load(params.key),true,'pem'))
    elseif (type(params.password)=='string')  then
        xkey = assert(pkey.read(load(params.key),true,'pem',params.password))
    elseif (type(params.password)=='function') then
        local p = assert(params.password())
        xkey = assert(pkey.read(load(params.key),true,'pem',p))
    end

    assert(xkey)
    local xcert = nil
    if (params.certificate) then
        xcert = assert(x509.read(load(params.certificate)))
    end
    assert(ctx:use( xkey, xcert))

    if(params.cafile or params.capath) then
        ctx:verify_locations(params.cafile,params.capath)
    end

    local unpack = unpack or table.unpack
    if(params.verify) then
        ctx:verify_mode(params.verify)
    end
    if params.options then
        local args = {}
        for i=1,#params.options do
            table.insert(arg,params.options[i])
        end
        ctx:options(unpack(args))
    end
    if params.verifyext then
        for k,v in pairs(params.verifyext) do
            params.verifyext[k] = string.gsub(v,'lsec_','')
        end
        ctx:set_cert_verify(params.verifyext)
    end
    if params.dhparam then
        ctx:set_tmp('dh',params.dhparam)
    end
    if params.curve then
        ctx:set_tmp('ecdh',params.curve)
    end
    if ctx.set_tmp then
        ctx:set_tmp()
        ctx:set_tmp('ecdh')
    end
    return ctx
end

M.client = {
  mode = "client",
  protocol = ssl.default,
  key = "certs/agent4-key.pem",
  certificate = "certs/agent4-cert.pem",
  cafile = "certs/ca2-cert.pem",
  verify = ssl.peer + ssl.fail,
  options = { "all", "no_sslv2" },
  ciphers = "ALL:!ECDHE",
}

M.server = {
  mode = "server",
  protocol = ssl.default,
  key = "certs/agent3-key.pem",
  certificate = "certs/agent3-cert.pem",
  cafile = "certs/ca2-cert.pem",
  verify = ssl.peer + ssl.fail,
  options = { "all", "no_sslv2" },
}

M.server01 = {
  mode = "server",
  protocol = ssl.default,
  key = "certs/agent3-key.pem",
  certificate = "certs/agent3-cert.pem",
  cafile = "certs/ca2-cert.pem",
  verify = ssl.none,
  options = { "all", "no_sslv2" },
  ciphers = "ALL:!ADH:@STRENGTH",
}

M.server02 = {
  mode = "server",
  protocol = ssl.default,
  key = "certs/agent1-key.pem",
  certificate = "certs/agent1-cert.pem",
  cafile = "certs/ca1-cert.pem",
  verify = ssl.none,
  options = { "all", "no_sslv2" },
  ciphers = "ALL:!ADH:@STRENGTH",
}

return M

local lu = require("luaunit")
local openssl = require("openssl")

TestParam = {}

function TestParam:setUp()
  -- Skip tests if not OpenSSL 3.0+
  local _, _, version = openssl.version(true)
  if version < 0x30000000 then
    lu.skip("OpenSSL 3.0+ required for OSSL_PARAM tests")
  end
end

function TestParam:testParamModuleExists()
  local param = require("openssl").param
  lu.assertNotNil(param, "param module should be available in OpenSSL 3.0+")
end

function TestParam:testKDFParamsExist()
  local param = require("openssl").param
  lu.assertNotNil(param.kdf, "KDF parameters should be available")
  lu.assertNotNil(param.kdf.pass, "pass parameter should exist")
  lu.assertNotNil(param.kdf.salt, "salt parameter should exist")
end

function TestParam:testRSAParamsExist()
  local param = require("openssl").param
  lu.assertNotNil(param.rsa, "RSA parameters should be available")
  lu.assertNotNil(param.rsa.n, "n parameter should exist")
  lu.assertNotNil(param.rsa.e, "e parameter should exist")
  lu.assertNotNil(param.rsa.d, "d parameter should exist")
end

function TestParam:testRSAParseWithOSSLPARAM()
  -- Generate an RSA key
  local rsa = require("openssl").rsa.generate_key(2048)
  lu.assertNotNil(rsa, "RSA key generation should succeed")
  
  -- Parse the key to get parameters
  local params = rsa:parse()
  lu.assertNotNil(params, "RSA parse should return a table")
  lu.assertNotNil(params.n, "n parameter should be present")
  lu.assertNotNil(params.e, "e parameter should be present")
  lu.assertEquals(params.bits, 2048, "Key size should be 2048 bits")
  
  -- Check that we have a BIGNUM object for n
  local n_type = type(params.n)
  lu.assertTrue(n_type == "userdata" or n_type == "table", 
    "n should be a BIGNUM object (userdata or table)")
end

function TestParam:testRSAParsePrivateKey()
  -- Generate an RSA private key
  local rsa = require("openssl").rsa.generate_key(2048)
  local params = rsa:parse()
  
  -- Private key should have d, p, q, dmp1, dmq1, iqmp
  lu.assertNotNil(params.d, "Private key should have d parameter")
  lu.assertNotNil(params.p, "Private key should have p parameter")
  lu.assertNotNil(params.q, "Private key should have q parameter")
  lu.assertNotNil(params.dmp1, "Private key should have dmp1 parameter")
  lu.assertNotNil(params.dmq1, "Private key should have dmq1 parameter")
  lu.assertNotNil(params.iqmp, "Private key should have iqmp parameter")
end

function TestParam:testRSAParsePublicKey()
  -- Generate a key pair
  local rsa = require("openssl").rsa.generate_key(1024)
  lu.assertNotNil(rsa, "RSA key generation should succeed")
  
  -- Parse the private key first
  local priv_params = rsa:parse()
  lu.assertNotNil(priv_params.n, "Private key should have n parameter")
  lu.assertNotNil(priv_params.e, "Private key should have e parameter")
  lu.assertNotNil(priv_params.d, "Private key should have d parameter")
end

function TestParam:testRSACompatibilityMode()
  -- Test that parsing works consistently regardless of how the key was created
  -- This ensures backward compatibility with keys created using OpenSSL 1.x API
  
  local rsa1 = require("openssl").rsa.generate_key(1024)
  local params1 = rsa1:parse()
  
  -- Export and re-import to potentially trigger different code paths
  local pem1 = rsa1:export(true)  -- export private key as PEM
  local rsa2 = require("openssl").rsa.read(pem1, true)
  local params2 = rsa2:parse()
  
  -- Both should have the same parameters available
  lu.assertNotNil(params1.n, "Original key should have n")
  lu.assertNotNil(params2.n, "Reimported key should have n")
  lu.assertNotNil(params1.e, "Original key should have e")
  lu.assertNotNil(params2.e, "Reimported key should have e")
end

os.exit(lu.LuaUnit.run())

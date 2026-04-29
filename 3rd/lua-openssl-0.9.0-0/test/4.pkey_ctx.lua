local lu = require 'luaunit'
local openssl = require 'openssl'

local pem_key =
[[
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDujoQuDvHO5wZ3
rZTiLw0TNeShJw389wd4POfqp8GjbQcjdIHpBH5W77sBiif06JV/3pWMNdFfz630
PBojR2raEW7h6Bq3mF3JAGamUZwmjibW4uA8i+Jd9vDag+fWCfEv+Kvf0NjtmT62
njC+1HdsvqvXP8w9rD3Nwl2WpYIRw34f7wnF6KZqoKhIbUIxSNzIiu/FTANIV8BG
WGytHV/+skGfO3L2L+BSKDuymPvgh1qgjg+bPMCl8sBpS99V8AFqGmu83fdIO+Jj
B1WpHkKqMz4zcTVue5KdSxH/EVxBP6UCXHn3sYF4owy0m8l2m+qRSFMEhZhk7AEF
9Vi0UWHpAgMBAAECggEAAsEkgv+iCI9o5v5I0Dsx/ZimtQPukdgsWlXGROTsaHSF
rd1EF+FmsAxKAOnVUkZ28AO/fyjPWaduXzDZ5Ps+jQd37iXUpbbmz3ZVS2BUbWGJ
80RgyZbBCjmRkYRYGV9Luuta2LDggFgbEEUGeH2bQbBTojENrM7pCX2ZLi8eL8je
yxsxFymvy7K6VlQXvWMigjEybGATTdI080HqccB3B0ZMyhiiuJfxRePbyEOWkmVP
QzWYDDsjfYdTrIv2Yfttedq2mnEBUbHdPLTg65TrcuEwB1IcLJFsbI9dKzDOipu2
00C93gxW1aN0Wi8/JuYc8xrnbz6i+qYXpap4DZRI8QKBgQDusoXWa7os6Bf6uhEk
USsSYtdm3oGRJ1vSzTHHqGwESHywy9xyx1E391TdFMHZQHgkIwQhS6Q+1h1wTiZO
tilwv0FfDffu7pzSfzGKdn7WfKL/7W6Bv7+1LY9NOXkk0YkjBoBKoDwuXdam8dmq
jF7P6bMQCJhTeojU1/6MxI13DQKBgQD/2WIstTZqJ+7JIg20HRoawT1nNzw5haBG
rUuShiYyMDnkyNYlUa8ZNj6Hm0xwAXuiYQZXDSDXazmsKu2r/0pAlkrOhxxvibH7
WavG4r2FeUX+BFUhEFmdQsMoexRFjZcwUYykg7TSErnwWJ4x6FAA92A093TaiwJ2
WZ1KD0IfTQKBgFjuWGDv1/hdLHn0kuhl+VcrTjd8VOegs1xRqOdLP5tE6nfwLBzz
V7YzRwHrduGbXGeSSDqjdPkYSvWJmEohIkVobFGe4a26ZuEiFHIS/eSpoQ0bB939
c85rwAU0kYb/LknHZUrociOQQKYIW2FoVPa/ikBCA4auk4ZBRwxpOo+NAoGBALYb
zT11Xt4Avn57trVVYZdZpJMrRbrL2mF0SC5rPhTLLuoh6gt2MOQJMEjlyWqQI6hY
12Ju/clXkR1zEOk0NW3zjBulICBkKkN2eEaAbdXrlF5SRyXZtW+ybacKtEstlUfX
Q/x1oudEXQUujquHaCrH6brJyGsmNwJ2lvZ4FeChAoGBAK+nll0/ulyOZveQWXc9
/5ML5ZAZXWaz2riuUfMITR2rRzw+Z/asgPg5MK1/AywHgvyCxAU/RSs+tihzPz5G
cG2UHoW6GVnP8y73pwY8p78Q7n308g74W5ZeFko8RRxhPttkJBd5szrlHQsyA8LI
fWxp0aMVVx6pHWHcwZtPAuOq
-----END PRIVATE KEY-----
]]

local pem_cert = [[
-----BEGIN CERTIFICATE-----
MIIDojCCAoqgAwIBAgIUE0iPAg8GJSGTDZACCPNUUIENaPswDQYJKoZIhvcNAQEL
BQAwMDEWMBQGA1UEAwwNcnlrb3Zhbm92LmNvbTEWMBQGA1UECgwNUmVhbHRpbWVM
b2dpYzAeFw0yMzA2MTgxMjMyNThaFw0zMzA2MTUxMjMyNThaMDAxFjAUBgNVBAMM
DXJ5a292YW5vdi5jb20xFjAUBgNVBAoMDVJlYWx0aW1lTG9naWMwggEiMA0GCSqG
SIb3DQEBAQUAA4IBDwAwggEKAoIBAQDujoQuDvHO5wZ3rZTiLw0TNeShJw389wd4
POfqp8GjbQcjdIHpBH5W77sBiif06JV/3pWMNdFfz630PBojR2raEW7h6Bq3mF3J
AGamUZwmjibW4uA8i+Jd9vDag+fWCfEv+Kvf0NjtmT62njC+1HdsvqvXP8w9rD3N
wl2WpYIRw34f7wnF6KZqoKhIbUIxSNzIiu/FTANIV8BGWGytHV/+skGfO3L2L+BS
KDuymPvgh1qgjg+bPMCl8sBpS99V8AFqGmu83fdIO+JjB1WpHkKqMz4zcTVue5Kd
SxH/EVxBP6UCXHn3sYF4owy0m8l2m+qRSFMEhZhk7AEF9Vi0UWHpAgMBAAGjgbMw
gbAwHQYDVR0OBBYEFNvyWnOsnBAxlqa1cKFDIMEI6u4iMB8GA1UdIwQYMBaAFNvy
WnOsnBAxlqa1cKFDIMEI6u4iMA8GA1UdEwEB/wQFMAMBAf8wMQYDVR0RBCowKIYX
dXJuOnJlYWx0aW1lbG9naWM6b3BjdWGCDXJ5a292YW5vdi5jb20wCwYDVR0PBAQD
AgP4MB0GA1UdJQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjANBgkqhkiG9w0BAQsF
AAOCAQEA4vK6qt1fUWgksi55HYeqXrT35fWOcHTv5qOhnWOZ3q5lX/j2bfHej4FH
ZRoHwyObIIRXulhK2DUrQqlgUnHD78vHiHCGjX8iGX/sSZbHihuZQWMo7I24MNA3
V9IMMQ3Nh7izMksvtMrC7TQqakjPC96D+0mFUJJOnL8Ca0vJYWA8KG7XuwbMPeJm
74Ykof89P2SL2os3enxrWlvoJwGiJGEXnjSBFhn5bul7ZvHK5YNvZHcsGOfXZIll
9I36RChYvNJ3YbHJBcxxsr8RqB3midXMYP885hUeWySB+OopJVYhlAAn5Odd6/gK
8upzr+Rb8XYpFQudXBjQZ6qKQd7Osw==
-----END CERTIFICATE-----
]]

local pri = openssl.pkey.read(pem_key, true, 'pem')
local cert = openssl.x509.read(pem_cert, "pem")

TestEvpPkeyCtx = {}
function TestEvpPkeyCtx:setUp()
end

function TestEvpPkeyCtx:test_RsaPkcs15Sha1_sign()
  local msg = "msg"
  local sha256 = openssl.digest.new('sha1')
  sha256:update(msg)
  local sum = sha256:final(true)

  local sign_ctx = pri:ctx()
  sign_ctx:sign_init()

  local sign = true
  sign = sign and sign_ctx:ctrl("rsa_padding_mode", "pkcs1")
  sign = sign and sign_ctx:ctrl("digest", "sha1")
  sign = sign and sign_ctx:sign(sum)
  assert(sign, openssl.error())

  local verify_ctx = cert:pubkey():ctx()
  verify_ctx:verify_init()
  local valid = true
  valid = valid and verify_ctx:ctrl("rsa_padding_mode", "pkcs1")
  valid = valid and verify_ctx:ctrl("digest", "sha1")
  valid = valid and verify_ctx:verify(sign, sum)
  assert(valid, openssl.error())
end

function TestEvpPkeyCtx:test_RsaPssSha256_sign()
  local msg = "msg"
  local sha256 = openssl.digest.new('sha256')
  sha256:update(msg)
  local sum = sha256:final(true)

  local sign_ctx = pri:ctx()
  sign_ctx:sign_init()

  local sign = true
  sign = sign and sign_ctx:ctrl("rsa_padding_mode", "pss")
  sign = sign and sign_ctx:ctrl("digest", "sha256")
  sign = sign and sign_ctx:ctrl("rsa_pss_saltlen", "digest")
  sign = sign and sign_ctx:sign(sum)
  assert(sign, openssl.error())

  local verify_ctx = cert:pubkey():ctx()
  verify_ctx:verify_init()
  local valid = true
  valid = valid and verify_ctx:ctrl("rsa_padding_mode", "pss")
  valid = valid and verify_ctx:ctrl("digest", "sha256")
  valid = valid and verify_ctx:ctrl("rsa_pss_saltlen", "digest")
  valid = valid and verify_ctx:verify(sign, sum)
  assert(valid, openssl.error())
end

function TestEvpPkeyCtx:test_Pkcs15Sha256_sign()
  local msg = "msg"
  local sha256 = openssl.digest.new('sha256')
  sha256:update(msg)
  local sum = sha256:final(true)

  local sign_ctx = pri:ctx()
  sign_ctx:sign_init()

  local sign = true
  sign = sign and sign_ctx:ctrl("rsa_padding_mode", "pkcs1")
  sign = sign and sign_ctx:ctrl("digest", "sha256")
  sign = sign and sign_ctx:sign(sum)
  assert(sign, openssl.error())

  local verify_ctx = cert:pubkey():ctx()
  verify_ctx:verify_init()
  local valid = true
  valid = valid and verify_ctx:ctrl("rsa_padding_mode", "pkcs1")
  valid = valid and verify_ctx:ctrl("digest", "sha256")
  valid = valid and verify_ctx:verify(sign, sum)
  assert(valid, openssl.error())
end

function TestEvpPkeyCtx:test_RsaPkcs15Sha1_encrypt()
  local msg = "msg"

  local pub_key = cert:pubkey()
  local pub_ctx = pub_key:ctx()
  pub_ctx:encrypt_init()
  pub_ctx:ctrl("rsa_padding_mode", "pkcs1")
  pub_ctx:ctrl("rsa_oaep_md", "sha1")
  local cipher = pub_ctx:encrypt(msg)
  assert(cipher, openssl.error())

  local priv_ctx = pri:ctx()
  priv_ctx:decrypt_init()
  priv_ctx:ctrl("rsa_padding_mode", "pkcs1")
  priv_ctx:ctrl("rsa_oaep_md", "sha1")
  local msg1 = priv_ctx:decrypt(cipher)
  assert(msg == msg1)
end

function TestEvpPkeyCtx:RsaOaep_Sha1_encrypt()
  local msg = "msg"

  local pub_key = cert:pubkey()
  local pub_ctx = pub_key:ctx()
  pub_ctx:encrypt_init()
  pub_ctx:ctrl("rsa_padding_mode", "oaep")
  pub_ctx:ctrl("rsa_oaep_md", "sha1")
  local cipher = pub_ctx:encrypt(msg)
  assert(cipher, openssl.error())

  local priv_ctx = pri:ctx()
  priv_ctx:decrypt_init()
  priv_ctx:ctrl("rsa_padding_mode", "oaep")
  priv_ctx:ctrl("rsa_oaep_md", "sha1")
  local msg1 = priv_ctx:decrypt(cipher)
  assert(msg == msg1)
end

function TestEvpPkeyCtx:test_Oaep_Sha256_encrypt()
  local msg = "msg"

  local pub_key = cert:pubkey()
  local pub_ctx = pub_key:ctx()
  pub_ctx:encrypt_init()
  pub_ctx:ctrl("rsa_padding_mode", "oaep")
  pub_ctx:ctrl("rsa_oaep_md", "sha256")
  local cipher = pub_ctx:encrypt(msg)
  assert(cipher, openssl.error())

  local priv_ctx = pri:ctx()
  priv_ctx:decrypt_init()
  priv_ctx:ctrl("rsa_padding_mode", "oaep")
  priv_ctx:ctrl("rsa_oaep_md", "sha256")
  local msg1 = priv_ctx:decrypt(cipher)
  assert(msg == msg1)
end

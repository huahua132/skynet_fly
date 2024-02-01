local openssl = require("openssl")
local cms = openssl.cms
local x509 = openssl.x509

local console_public_key_data = [[-----BEGIN CERTIFICATE-----
MIIBmzCCAUGgAwIBAgIUceXybAulcsDfhFapwpZRqPNMkV4wCgYIKoZIzj0EAwIw
IjEgMB4GA1UEAwwXbWVzaC1jb25zb2xlLjIyMzYwMzY2NzMwIBcNMTcwMTAxMDAw
MDAwWhgPMjExODEwMjMwNzQzMTZaMCIxIDAeBgNVBAMMF21lc2gtY29uc29sZS4y
MjM2MDM2NjczMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEtpMry4ECQ94FyzjS
3gTgfomQnfkW2W1803j4XLK1kupo0/blLIsz5djdV6vS9n9qoJo4W6Mbt7h4qolg
ILsXUaNTMFEwHQYDVR0OBBYEFDAI4nhDcrvQPhydcsuRnB+Zftp0MA8GA1UdEwEB
/wQFMAMBAf8wHwYDVR0jBBgwFoAUMAjieENyu9A+HJ1yy5GcH5l+2nQwCgYIKoZI
zj0EAwIDSAAwRQIhAOU3gVO+llWqLJGLe2uPEEyCFQO1h9Ll/JodizfZv7j5AiBx
LPd0OELmajQzwJuRLiA5l4B2wUrIjdCFtKEVIuGF+w==
-----END CERTIFICATE-----
]]

local ver_blob = [[-----BEGIN CMS-----
MIAGCSqGSIb3DQEHAqCAMIACAQMxDTALBglghkgBZQMEAgEwgAYJKoZIhvcNAQcB
oIAkgAQGMTA3OTI1AAAAAAAAoIIBnzCCAZswggFBoAMCAQICFHHl8mwLpXLA34RW
qcKWUajzTJFeMAoGCCqGSM49BAMCMCIxIDAeBgNVBAMMF21lc2gtY29uc29sZS4y
MjM2MDM2NjczMCAXDTE3MDEwMTAwMDAwMFoYDzIxMTgxMDIzMDc0MzE2WjAiMSAw
HgYDVQQDDBdtZXNoLWNvbnNvbGUuMjIzNjAzNjY3MzBZMBMGByqGSM49AgEGCCqG
SM49AwEHA0IABLaTK8uBAkPeBcs40t4E4H6JkJ35FtltfNN4+FyytZLqaNP25SyL
M+XY3Ver0vZ/aqCaOFujG7e4eKqJYCC7F1GjUzBRMB0GA1UdDgQWBBQwCOJ4Q3K7
0D4cnXLLkZwfmX7adDAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFDAI4nhD
crvQPhydcsuRnB+Zftp0MAoGCCqGSM49BAMCA0gAMEUCIQDlN4FTvpZVqiyRi3tr
jxBMghUDtYfS5fyaHYs32b+4+QIgcSz3dDhC5mo0M8CbkS4gOZeAdsFKyI3QhbSh
FSLhhfsxfTB7AgEDgBQwCOJ4Q3K70D4cnXLLkZwfmX7adDALBglghkgBZQMEAgEw
CgYIKoZIzj0EAwIERzBFAiBtZ3lJ14NbPvG53u4fBZ8dVCEWCRW+A9jm22gr1HTg
dgIhAPEBU53+71sigZYYn5CEM7+Np9dR+2iKFBTh47OpL1TIAAAAAAAA
-----END CMS-----
]]

function testIssue185()
  local store = assert(x509.store.new({
    assert(x509.read(console_public_key_data, "pem"))
  }))
  local i = 0
  collectgarbage()
  collectgarbage()
  collectgarbage()
  local b = collectgarbage("count")
  local box = assert(cms.read(ver_blob, "pem"))
  while i<10 do
    assert(cms.verify(box, {}, store))
    i = i + 1
  end
  collectgarbage()
  collectgarbage()
  collectgarbage()
  local e = collectgarbage("count")
  assert(e-b <= 0.2, "Memleaks ".. tostring(e-b))
end

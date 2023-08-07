local lu = require 'luaunit'
local openssl = require 'openssl'

local csr, x509 = openssl.x509.req, openssl.x509

local helper = require('helper')

TestX509 = {}
function TestX509:setUp()
  self.alg = 'sha1'

  self.dn = {{commonName = 'DEMO'},  {C = 'CN'}}

  self.digest = 'sha1WithRSAEncryption'
end

function TestX509:testX509()
  local t = x509.certtypes("standard")
  assert(type(t)=='table')
  t = x509.certtypes("netscape")
  assert(type(t)=='table')
  t = x509.certtypes("extend")
  assert(type(t)=='table')
  t = x509.verify_cert_error_string(1)
  assert(type(t)=='string')
end

function TestX509:testNew()
  local ca = helper.get_ca()
  local cert, pkey = helper.sign(self.dn)

  local subject = x509.new(self.subject)
  assert(x509.new(subject))

  lu.assertEquals(ca.cacert:subject(), cert:issuer())
  assert(ca.cacert:parse().ca, 'invalid ca certificate')

  local c = cert:pubkey():encrypt('abcd')
  local d = pkey:decrypt(c)
  assert(d == 'abcd')
  assert(cert:check(pkey), 'self sign check failed')
  local store = assert(ca:get_store())
  assert(cert:check(store))
  assert(cert:verify(ca.cacert:pubkey()))

  local x, t = cert:verify()
  assert(x)
  assert(type(t)=='table')

  local s = cert:export('der')
  x = x509.read(s, 'der')
  assert(x==cert)

  s = cert:export('pem')
  x = x509.read(s, 'pem')
  assert(x==cert)

  assert(cert:pubkey(assert(cert:pubkey())))
  assert(cert:subject(assert(cert:subject())))
  assert(cert:issuer(assert(cert:issuer())))
  assert(cert:version(assert(cert:version())))
  assert(cert:serial(assert(cert:serial(false))))
  assert(string.len(cert:digest()) == 32)
  local b, e = cert:validat()
  assert(b, e)
  assert(cert:validat(os.time()))

  local extensions = {
    {
      object = 'subjectAltName',
      value = 'email:123@abc.com'
    }
  }

  cert = assert(helper.sign(self.dn, extensions))
  assert(cert:check_email('123@abc.com'))

  extensions = {
    {
      object = 'subjectAltName',
      value = 'DNS:abc.xyz'
    }
  }

  cert = assert(helper.sign(self.dn, extensions))
  assert(cert:check_host('abc.xyz'))

  extensions = {
    {
      object = 'subjectAltName',
      value = 'IP:192.168.1.1'
    }
  }

  cert = assert(helper.sign(self.dn, extensions))
  assert(cert:check_ip_asc('192.168.1.1'))

  extensions = {
    {
      object = 'subjectAltName',
      value = 'IP:192.168.1.1,RID:1.2.3.4'
    },
    {
      object = 'subjectAltName',
      value = 'IP:192.168.1.1'
    },
    {
      object = 'subjectAltName',
      value = 'DNS:abc.xyz'
    },
    {
      object = 'subjectAltName',
      value = 'URI:http://my.url.here/'
    },
    {
      object = 'subjectAltName',
      value = 'otherName:1.2.3.4;UTF8:some other identifier'
    },
    {
      object = 'subjectAltName',
      value = 'email:123@abc.com'
    },
    --{
    --  object = 'subjectAltName',
    --  value = 'X400Name:C=US/O=Organization/G=Nuno/CN=demo'
    --},
    --{
    --  object = 'subjectAltName',
    --  value = 'EdiPartyName:123@abc.com'
    --},
    --{
    --  object = 'subjectAltName',
    --  value = 'DirName:/C=NZ/L=Wellington/OU=Cert-stamping/CN=Jackov'
    --}
  }

  cert = assert(helper.sign(self.dn, extensions))
  local info = cert:parse()
  for i=1, #info.extensions do
    assert(type(info.extensions[i]:info())=='table')
  end
  cert:notbefore("Jan 16 05:19:30 2002 GMT")
  cert:notafter("Jan 16 05:19:30 2022 GMT")
  --advance
  s = cert:sign()
  assert(type(s)=='string')
  s = ca.pkey:sign(s)
  local o  = openssl.asn1.new_object('sha1WithRSAEncryption')
  assert(cert:sign(s, o))
end

function TestX509:testIO()
  local raw_data = [=[
-----BEGIN CERTIFICATE-----
MIIFajCCBPGgAwIBAgIQDNCovsYyz+ZF7KCpsIT7HDAKBggqhkjOPQQDAzBWMQsw
CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMTAwLgYDVQQDEydEaWdp
Q2VydCBUTFMgSHlicmlkIEVDQyBTSEEzODQgMjAyMCBDQTEwHhcNMjMwMjE0MDAw
MDAwWhcNMjQwMzE0MjM1OTU5WjBmMQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2Fs
aWZvcm5pYTEWMBQGA1UEBxMNU2FuIEZyYW5jaXNjbzEVMBMGA1UEChMMR2l0SHVi
LCBJbmMuMRMwEQYDVQQDEwpnaXRodWIuY29tMFkwEwYHKoZIzj0CAQYIKoZIzj0D
AQcDQgAEo6QDRgPfRlFWy8k5qyLN52xZlnqToPu5QByQMog2xgl2nFD1Vfd2Xmgg
nO4i7YMMFTAQQUReMqyQodWq8uVDs6OCA48wggOLMB8GA1UdIwQYMBaAFAq8CCkX
jKU5bXoOzjPHLrPt+8N6MB0GA1UdDgQWBBTHByd4hfKdM8lMXlZ9XNaOcmfr3jAl
BgNVHREEHjAcggpnaXRodWIuY29tgg53d3cuZ2l0aHViLmNvbTAOBgNVHQ8BAf8E
BAMCB4AwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMIGbBgNVHR8EgZMw
gZAwRqBEoEKGQGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRMU0h5
YnJpZEVDQ1NIQTM4NDIwMjBDQTEtMS5jcmwwRqBEoEKGQGh0dHA6Ly9jcmw0LmRp
Z2ljZXJ0LmNvbS9EaWdpQ2VydFRMU0h5YnJpZEVDQ1NIQTM4NDIwMjBDQTEtMS5j
cmwwPgYDVR0gBDcwNTAzBgZngQwBAgIwKTAnBggrBgEFBQcCARYbaHR0cDovL3d3
dy5kaWdpY2VydC5jb20vQ1BTMIGFBggrBgEFBQcBAQR5MHcwJAYIKwYBBQUHMAGG
GGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBPBggrBgEFBQcwAoZDaHR0cDovL2Nh
Y2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VExTSHlicmlkRUNDU0hBMzg0MjAy
MENBMS0xLmNydDAJBgNVHRMEAjAAMIIBgAYKKwYBBAHWeQIEAgSCAXAEggFsAWoA
dwDuzdBk1dsazsVct520zROiModGfLzs3sNRSFlGcR+1mwAAAYZQ3Rv6AAAEAwBI
MEYCIQDkFq7T4iy6gp+pefJLxpRS7U3gh8xQymmxtI8FdzqU6wIhALWfw/nLD63Q
YPIwG3EFchINvWUfB6mcU0t2lRIEpr8uAHYASLDja9qmRzQP5WoC+p0w6xxSActW
3SyB2bu/qznYhHMAAAGGUN0cKwAABAMARzBFAiAePGAyfiBR9dbhr31N9ZfESC5G
V2uGBTcyTyUENrH3twIhAPwJfsB8A4MmNr2nW+sdE1n2YiCObW+3DTHr2/UR7lvU
AHcAO1N3dT4tuYBOizBbBv5AO2fYT8P0x70ADS1yb+H61BcAAAGGUN0cOgAABAMA
SDBGAiEAzOBr9OZ0+6OSZyFTiywN64PysN0FLeLRyL5jmEsYrDYCIQDu0jtgWiMI
KU6CM0dKcqUWLkaFE23c2iWAhYAHqrFRRzAKBggqhkjOPQQDAwNnADBkAjAE3A3U
3jSZCpwfqOHBdlxi9ASgKTU+wg0qw3FqtfQ31OwLYFdxh0MlNk/HwkjRSWgCMFbQ
vMkXEPvNvv4t30K6xtpG26qmZ+6OiISBIIXMljWnsiYR1gyZnTzIg3AQSw4Vmw==
-----END CERTIFICATE-----
]=]

  local x = assert(x509.read(raw_data))

  local t = x:parse()
  lu.assertEquals(type(t), 'table')
  assert(x:pubkey())

  lu.assertEquals(x:version(), 2)
  assert(x:notbefore())
  assert(x:notafter())

  lu.assertIsTable(x:extensions())

  assert(x:subject())
  assert(x:issuer())

  t = x509.purpose()
  assert(#t == 9)
  assert(type(x509.purpose(t[1].purpose))=='table')
  assert(type(x509.purpose(t[1].sname))=='table')
end

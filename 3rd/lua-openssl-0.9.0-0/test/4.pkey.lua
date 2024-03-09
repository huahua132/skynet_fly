local lu = require 'luaunit'
local openssl = require 'openssl'
local pkey = require('openssl').pkey
local unpack = unpack or table.unpack
local digest = openssl.digest
local helper = require'helper'

local function mk_key(args)
  assert(type(args), 'table')

  local k = assert(pkey.new(unpack(args)), args[1])
  return k
end

TestPKEYMY = {}

function TestPKEYMY:setUp()
  self.genalg = {
    {nil},  -- default to create rsa 1024 bits with 65537
    {'rsa',  2048,  3},   -- create rsa with give bits length and e
    {'ec',  'prime256v1'},
    {'dh',  1024}
  }
  if not helper.openssl3 then
    --FIXME: dsa key generate
    self.genalg[#self.genalg+1] = {'dsa',  1024}
  end
end

function TestPKEYMY:testBasic()
  local eng = openssl.engine('openssl')
  assert(eng)
  for _, v in ipairs(self.genalg) do
    local k = mk_key(v)
    assert(k:is_private())
    if v[1]~='dh' then
      k:set_engine(eng)
    end
    assert(not k:missing_paramaters())
    local k1 = assert(pkey.get_public(k), v[1])
    assert(not k1:is_private())

    local t = k:parse()
    local len = t.bits / 8
    assert(t.bits==k:bits())
    assert(t.bits==k1:bits())

    local msg = openssl.random(len - 11)
    if t.type == 'RSA' then
      local out = pkey.encrypt(k1, msg)
      local raw = pkey.decrypt(k, out)

      lu.assertEquals(len, #out)
      lu.assertEquals(msg, raw)

      local sk, iv
      out, sk, iv = pkey.seal({k1}, msg)
      assert(out)
      assert(type(sk)=='table')
      assert(iv)
      out, sk, iv = pkey.seal(k1, msg)
      raw = pkey.open(k, out, sk, iv)
      lu.assertEquals(msg, raw)

      local ctx
      ctx, sk, iv = pkey.seal_init({k1})
      assert(ctx)
      assert(type(sk)=='table')
      assert(iv)
      ctx, sk, iv = pkey.seal_init(k1)
      out = assert(pkey.seal_update(ctx, msg))
      out = out .. assert(pkey.seal_final(ctx))

      ctx = pkey.open_init(k, sk, iv)
      out = assert(pkey.open_update(ctx, out))
      raw = out .. assert(pkey.open_final(ctx))
      lu.assertEquals(msg, raw)
    end
    if t.type ~= 'DH' then
      local sig = assert(pkey.sign(k, msg))
      assert(true == pkey.verify(k1, msg, sig))
    end
    if t.type == 'EC' then
      local p = mk_key(v)
      p = pkey.get_public(p)
      assert(not p:is_private())
      p,_ = k:derive(p)
      assert(type(p)=='string')
    end

    assert(string.len(k1:export()) > 0)
    assert(string.len(k:export()) > 0)

    assert(k1:export():find('^-----BEGIN PUBLIC KEY-----'))

    assert(string.len(k:export('pem', false)) > 0)
    assert(string.len(k:export('der')) > 0)

    if(t.type~='DH') then
    assert(string.len(k:export('pem', true)) > 0)
    assert(string.len(k:export('pem', true, 'secret')) > 0)
    end

    assert(string.len(k:export('pem', false, 'secret')) > 0)
    assert(string.len(k:export('der', false, 'secret')) > 0)
    assert(pkey.new(t[t.type]))
  end
end

function testRSA()
  local nrsa = {'rsa',  1024,  3}
  local rsa = pkey.new(unpack(nrsa))

  local k1 = pkey.get_public(rsa)
  assert(not k1:is_private())
  local t = rsa:parse()
  assert(t.bits == 1024)
  assert(t.type == 'RSA')
  assert(t.size == 128)
  local r = t.rsa
  t = r:parse()
  assert(t.n)
  assert(t.e)
  t.alg = 'rsa'
  local r2 = pkey.new(t)
  assert(r2:is_private())
  local msg = openssl.random(128 - 11)

  local out = pkey.encrypt(k1, msg)
  local raw = pkey.decrypt(r2, out)
  assert(msg == raw)

  r2 = openssl.pkey.new(r)
  assert(r2:is_private())

end

function testEC()
  local nec = {'EC',  'prime256v1'}
  local ec = pkey.new(unpack(nec))

  local k1 = pkey.get_public(ec)
  assert(not k1:is_private())
  local t = ec:parse()
  assert(t.bits == 256)
  assert(t.type == 'EC')
  assert(t.size == 72)
  local r = t.ec
  t = r:parse()

  assert(t.priv_key)
  assert(t.pub_key)

  local r2 = assert(pkey.new(r))
  assert(r2:is_private())
end

function testDSA()
  local dsa = {'dsa',  1024}
  dsa = pkey.new(unpack(dsa))

  local k1 = pkey.get_public(dsa)
  assert(not k1:is_private())
  local t = dsa:parse()
  assert(t.bits == 1024)
  assert(t.type == 'DSA')
  assert(t.size)

  local r = t.dsa
  t = r:parse()
  assert(t.g)
  assert(t.p)
  assert(t.q)
  assert(t.pub_key)

  t.alg = 'dsa'
  local r2 = pkey.new(t)
  assert(r2:is_private())
  local msg = openssl.random(128 - 11)

  local out = pkey.sign(r2, msg)
  local ret = pkey.verify(k1, msg, out)
  assert(ret)
  ret = pkey.verify(r2, msg, out)
  assert(ret)

  r2 = openssl.pkey.new(r)
  assert(r2:is_private())
end

function testKeyFmt()
  local keys = {
    RSA = {
      [[
-----BEGIN PRIVATE KEY-----
MIICdQIBADALBgkqhkiG9w0BAQEEggJhMIICXQIBAAKBgQC7JHoJfg6yNzLMOWet
8Z49a4KD0dCspMAYvo2YAMB7/wdEycocujbhJ2n/seONi+5XqTqqFkM5VBl8rmkk
FPZk/7x0xmdsTPECSWnHK+HhoaNDFPR3j8jQhVo1laxiqcEhAHegi5cwtFosuJAv
SKAFKEvyD43si00DQnXWrYHAEQIDAQABAoGAAPy5SiYHiVErU3KR4Bg+pl4x75wM
FiRC0Cgz+frQPFQEBsAV9RuasyQxqzxrR0Ow0qncBeGBWbYE6WZhqtcLAI895b+i
+F4lbB4iD7T9QeIDMV/aIMXA81UO4cns1z4qDAHKeyLLrPQrJ/B4X7XC+egUWm5+
hr1qmyAMusyXIBECQQDJWZ8piluf4yrYfsJAn6hF5T4RjTztbqvO0GVG2McHY7Uj
NPSffhzHx/ll0fQEQji+OgydCCX8o3HZrgw5YfSJAkEA7e+rqdU5nO5ZG//PSEQb
tjLnRiTzBH/elQhtdZ5nF7pcpNTi4k13zutmKcWW4GK75azcRGJUhu1kDM7QYAOd
SQJAVNkYcifkvna7GmooL5VYEsQsqLbM4v0NF2TIGNfG3z1MGp75KrC5LhL97MNR
we2p/bd2k0HYyCKUGnf2nMPDiQJBAI75pwittSoE240EobUGIDTSz8CJsXIxuDmL
z+KOpdpPRR5TQmbEMEspjsFpFymMiuYPgmihQbO2cJl1qScY5OkCQQCJ6m5tcN8l
Xxg/SNpjEIv+qAyUD96XVlOJlOIeLHQ8kYE0C6ZA+MsqYIzgAreJk88Yn0lU/X0/
mu/UpE/BRZmR
-----END PRIVATE KEY-----
]],
      "3082025D02010002818100BB247A097E0EB23732CC3967ADF19E3D6B8283D1D0ACA4C018BE8D9800C07BFF0744C9CA1CBA36E12769FFB1E38D8BEE57A93AAA16433954197CAE692414F664FFBC74C6676C4CF1024969C72BE1E1A1A34314F4778FC8D0855A3595AC62A9C1210077A08B9730B45A2CB8902F48A005284BF20F8DEC8B4D034275D6AD81C011020301000102818000FCB94A260789512B537291E0183EA65E31EF9C0C162442D02833F9FAD03C540406C015F51B9AB32431AB3C6B4743B0D2A9DC05E18159B604E96661AAD70B008F3DE5BFA2F85E256C1E220FB4FD41E203315FDA20C5C0F3550EE1C9ECD73E2A0C01CA7B22CBACF42B27F0785FB5C2F9E8145A6E7E86BD6A9B200CBACC972011024100C9599F298A5B9FE32AD87EC2409FA845E53E118D3CED6EABCED06546D8C70763B52334F49F7E1CC7C7F965D1F4044238BE3A0C9D0825FCA371D9AE0C3961F489024100EDEFABA9D5399CEE591BFFCF48441BB632E74624F3047FDE95086D759E6717BA5CA4D4E2E24D77CEEB6629C596E062BBE5ACDC44625486ED640CCED060039D49024054D9187227E4BE76BB1A6A282F955812C42CA8B6CCE2FD0D1764C818D7C6DF3D4C1A9EF92AB0B92E12FDECC351C1EDA9FDB7769341D8C822941A77F69CC3C3890241008EF9A708ADB52A04DB8D04A1B5062034D2CFC089B17231B8398BCFE28EA5DA4F451E534266C4304B298EC16917298C8AE60F8268A141B3B6709975A92718E4E902410089EA6E6D70DF255F183F48DA63108BFEA80C940FDE9756538994E21E2C743C9181340BA640F8CB2A608CE002B78993CF189F4954FD7D3F9AEFD4A44FC1459991",

"3082025D02010002818100BB247A097E0EB23732CC3967ADF19E3D6B8283D1D0ACA4C018BE8D9800C07BFF0744C9CA1CBA36E12769FFB1E38D8BEE57A93AAA16433954197CAE692414F664FFBC74C6676C4CF1024969C72BE1E1A1A34314F4778FC8D0855A3595AC62A9C1210077A08B9730B45A2CB8902F48A005284BF20F8DEC8B4D034275D6AD81C011020301000102818000FCB94A260789512B537291E0183EA65E31EF9C0C162442D02833F9FAD03C540406C015F51B9AB32431AB3C6B4743B0D2A9DC05E18159B604E96661AAD70B008F3DE5BFA2F85E256C1E220FB4FD41E203315FDA20C5C0F3550EE1C9ECD73E2A0C01CA7B22CBACF42B27F0785FB5C2F9E8145A6E7E86BD6A9B200CBACC972011024100C9599F298A5B9FE32AD87EC2409FA845E53E118D3CED6EABCED06546D8C70763B52334F49F7E1CC7C7F965D1F4044238BE3A0C9D0825FCA371D9AE0C3961F489024100EDEFABA9D5399CEE591BFFCF48441BB632E74624F3047FDE95086D759E6717BA5CA4D4E2E24D77CEEB6629C596E062BBE5ACDC44625486ED640CCED060039D49024054D9187227E4BE76BB1A6A282F955812C42CA8B6CCE2FD0D1764C818D7C6DF3D4C1A9EF92AB0B92E12FDECC351C1EDA9FDB7769341D8C822941A77F69CC3C3890241008EF9A708ADB52A04DB8D04A1B5062034D2CFC089B17231B8398BCFE28EA5DA4F451E534266C4304B298EC16917298C8AE60F8268A141B3B6709975A92718E4E902410089EA6E6D70DF255F183F48DA63108BFEA80C940FDE9756538994E21E2C743C9181340BA640F8CB2A608CE002B78993CF189F4954FD7D3F9AEFD4A44FC1459991",
      "30819F300D06092A864886F70D010101050003818D0030818902818100BB247A097E0EB23732CC3967ADF19E3D6B8283D1D0ACA4C018BE8D9800C07BFF0744C9CA1CBA36E12769FFB1E38D8BEE57A93AAA16433954197CAE692414F664FFBC74C6676C4CF1024969C72BE1E1A1A34314F4778FC8D0855A3595AC62A9C1210077A08B9730B45A2CB8902F48A005284BF20F8DEC8B4D034275D6AD81C0110203010001",
      "30818902818100BB247A097E0EB23732CC3967ADF19E3D6B8283D1D0ACA4C018BE8D9800C07BFF0744C9CA1CBA36E12769FFB1E38D8BEE57A93AAA16433954197CAE692414F664FFBC74C6676C4CF1024969C72BE1E1A1A34314F4778FC8D0855A3595AC62A9C1210077A08B9730B45A2CB8902F48A005284BF20F8DEC8B4D034275D6AD81C0110203010001"
    },

    EC = {
      [[
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgYirTZSx+5O8Y6tlG
cka6W6btJiocdrdolfcukSoTEk+hRANCAAQkvPNu7Pa1GcsWU4v7ptNfqCJVq8Cx
zo0MUVPQgwJ3aJtNM1QMOQUayCrRwfklg+D/rFSUwEUqtZh7fJDiFqz3
-----END PRIVATE KEY-----
]],
      '30770201010420622AD3652C7EE4EF18EAD9467246BA5BA6ED262A1C76B76895F72E912A13124FA00A06082A8648CE3D030107A1440342000424BCF36EECF6B519CB16538BFBA6D35FA82255ABC0B1CE8D0C5153D0830277689B4D33540C39051AC82AD1C1F92583E0FFAC5494C0452AB5987B7C90E216ACF7',
      "30770201010420622AD3652C7EE4EF18EAD9467246BA5BA6ED262A1C76B76895F72E912A13124FA00A06082A8648CE3D030107A1440342000424BCF36EECF6B519CB16538BFBA6D35FA82255ABC0B1CE8D0C5153D0830277689B4D33540C39051AC82AD1C1F92583E0FFAC5494C0452AB5987B7C90E216ACF7",
      "3059301306072A8648CE3D020106082A8648CE3D0301070342000424BCF36EECF6B519CB16538BFBA6D35FA82255ABC0B1CE8D0C5153D0830277689B4D33540C39051AC82AD1C1F92583E0FFAC5494C0452AB5987B7C90E216ACF7",
      '3059301306072A8648CE3D020106082A8648CE3D0301070342000424BCF36EECF6B519CB16538BFBA6D35FA82255ABC0B1CE8D0C5153D0830277689B4D33540C39051AC82AD1C1F92583E0FFAC5494C0452AB5987B7C90E216ACF7'
    },

    DSA = {
      [[
-----BEGIN PRIVATE KEY-----
MIIBTAIBADCCASwGByqGSM44BAEwggEfAoGBAKoJMMwUWCUiHK/6KKwolBlqJ4M9
5ewhJweRaJQgd3Si57I4sNNvGySZosJYUIPrAUMpJEGNhn+qIS3RBx1NzrJ4J5St
OTzAik1K2n9o1ug5pfzTS05ALYLLioy0D+wxkRv5vTYLA0yqy0xelHmSVzyekAmc
Gw8FlAyr5dLeSaFnAhUArcDoabNvCsATpoH99NSJnWmCBFECgYEAjGtFia+lOk0Q
SL/DRtHzhsp1UhzPct2qJRKGiA7hMgH/SIkLv8M9ebrK7HHnp3hQe9XxpmQi45QV
vgPnEUG6Mk9bkxMZKRgsiKn6QGKDYGbOvnS1xmkMfRARBsJAq369VOTjMB/Qhs5q
2ski+ycTorCIfLoTubxozlz/8kHNMkYEFwIVAKU1qOHQ2Rvq/IvuHZsqOo3jMRID
-----END PRIVATE KEY-----
]],
      '308201BC02010002818100AA0930CC145825221CAFFA28AC2894196A27833DE5EC212707916894207774A2E7B238B0D36F1B2499A2C2585083EB01432924418D867FAA212DD1071D4DCEB2782794AD393CC08A4D4ADA7F68D6E839A5FCD34B4E402D82CB8A8CB40FEC31911BF9BD360B034CAACB4C5E947992573C9E90099C1B0F05940CABE5D2DE49A167021500ADC0E869B36F0AC013A681FDF4D4899D69820451028181008C6B4589AFA53A4D1048BFC346D1F386CA75521CCF72DDAA251286880EE13201FF48890BBFC33D79BACAEC71E7A778507BD5F1A66422E39415BE03E71141BA324F5B93131929182C88A9FA4062836066CEBE74B5C6690C7D101106C240AB7EBD54E4E3301FD086CE6ADAC922FB2713A2B0887CBA13B9BC68CE5CFFF241CD32460281802B260EA97DC6A12AE932C640E7DF3D8FF04A8A05A0324F8D5F1B23F15FA170FF3F42061124EFF2586CB11B49A82DCDC1B90FC6A84FB10109CB67DB5D2DA971AEAF17BE5E37284563E4C64D9E5FC8480258B319F0DE29D54D835070D9E287914D77DF81491F4423B62DA984EB3F45EB2A29FCEA5DAE525AC6AB6BCCE04BFDF5B6021500A535A8E1D0D91BEAFC8BEE1D9B2A3A8DE3311203',

'308201BC02010002818100AA0930CC145825221CAFFA28AC2894196A27833DE5EC212707916894207774A2E7B238B0D36F1B2499A2C2585083EB01432924418D867FAA212DD1071D4DCEB2782794AD393CC08A4D4ADA7F68D6E839A5FCD34B4E402D82CB8A8CB40FEC31911BF9BD360B034CAACB4C5E947992573C9E90099C1B0F05940CABE5D2DE49A167021500ADC0E869B36F0AC013A681FDF4D4899D69820451028181008C6B4589AFA53A4D1048BFC346D1F386CA75521CCF72DDAA251286880EE13201FF48890BBFC33D79BACAEC71E7A778507BD5F1A66422E39415BE03E71141BA324F5B93131929182C88A9FA4062836066CEBE74B5C6690C7D101106C240AB7EBD54E4E3301FD086CE6ADAC922FB2713A2B0887CBA13B9BC68CE5CFFF241CD32460281802B260EA97DC6A12AE932C640E7DF3D8FF04A8A05A0324F8D5F1B23F15FA170FF3F42061124EFF2586CB11B49A82DCDC1B90FC6A84FB10109CB67DB5D2DA971AEAF17BE5E37284563E4C64D9E5FC8480258B319F0DE29D54D835070D9E287914D77DF81491F4423B62DA984EB3F45EB2A29FCEA5DAE525AC6AB6BCCE04BFDF5B6021500A535A8E1D0D91BEAFC8BEE1D9B2A3A8DE3311203',
      "308201B73082012C06072A8648CE3804013082011F02818100AA0930CC145825221CAFFA28AC2894196A27833DE5EC212707916894207774A2E7B238B0D36F1B2499A2C2585083EB01432924418D867FAA212DD1071D4DCEB2782794AD393CC08A4D4ADA7F68D6E839A5FCD34B4E402D82CB8A8CB40FEC31911BF9BD360B034CAACB4C5E947992573C9E90099C1B0F05940CABE5D2DE49A167021500ADC0E869B36F0AC013A681FDF4D4899D69820451028181008C6B4589AFA53A4D1048BFC346D1F386CA75521CCF72DDAA251286880EE13201FF48890BBFC33D79BACAEC71E7A778507BD5F1A66422E39415BE03E71141BA324F5B93131929182C88A9FA4062836066CEBE74B5C6690C7D101106C240AB7EBD54E4E3301FD086CE6ADAC922FB2713A2B0887CBA13B9BC68CE5CFFF241CD3246038184000281802B260EA97DC6A12AE932C640E7DF3D8FF04A8A05A0324F8D5F1B23F15FA170FF3F42061124EFF2586CB11B49A82DCDC1B90FC6A84FB10109CB67DB5D2DA971AEAF17BE5E37284563E4C64D9E5FC8480258B319F0DE29D54D835070D9E287914D77DF81491F4423B62DA984EB3F45EB2A29FCEA5DAE525AC6AB6BCCE04BFDF5B6",
      "308201B73082012C06072A8648CE3804013082011F02818100AA0930CC145825221CAFFA28AC2894196A27833DE5EC212707916894207774A2E7B238B0D36F1B2499A2C2585083EB01432924418D867FAA212DD1071D4DCEB2782794AD393CC08A4D4ADA7F68D6E839A5FCD34B4E402D82CB8A8CB40FEC31911BF9BD360B034CAACB4C5E947992573C9E90099C1B0F05940CABE5D2DE49A167021500ADC0E869B36F0AC013A681FDF4D4899D69820451028181008C6B4589AFA53A4D1048BFC346D1F386CA75521CCF72DDAA251286880EE13201FF48890BBFC33D79BACAEC71E7A778507BD5F1A66422E39415BE03E71141BA324F5B93131929182C88A9FA4062836066CEBE74B5C6690C7D101106C240AB7EBD54E4E3301FD086CE6ADAC922FB2713A2B0887CBA13B9BC68CE5CFFF241CD3246038184000281802B260EA97DC6A12AE932C640E7DF3D8FF04A8A05A0324F8D5F1B23F15FA170FF3F42061124EFF2586CB11B49A82DCDC1B90FC6A84FB10109CB67DB5D2DA971AEAF17BE5E37284563E4C64D9E5FC8480258B319F0DE29D54D835070D9E287914D77DF81491F4423B62DA984EB3F45EB2A29FCEA5DAE525AC6AB6BCCE04BFDF5B6"
    },

    DH = {
      [[
-----BEGIN PRIVATE KEY-----
MIIBIQIBADCBlQYJKoZIhvcNAQMBMIGHAoGBAJ2jQYfwDc8o/yEBwRp9l6uzUagD
I8+uvXpifPrDQFDYPXS4EIezTvY+q8leB0oGtuxeUhVssAACbKku4wfrUOAwniu5
kyxs6DIhOlTf/NRiLFMAC4mDVKgFo60YuNcdJH5nhRuBK1ARpK7X/g/ywS7pDRKM
aXgQ8lWdZJih+OK7AgECBIGDAoGAZJ9KttF13mCIzAnZF9ylagU+l9XRxwlQOdCz
pZNkY16cFLFt9VY/oaXeYwwCcUQLFTsMUU7AQ6q5jt71fEpf1N3VnIdxuANxyV3c
DBBB0yS7tVNX3skMx0aSM0oLnUDJ1BXf9bBSkcvK584Vj9ihTKdDs7BDzfR6f1Er
FV/lrqg=
-----END PRIVATE KEY-----
]],

"3082012102010030819506092A864886F70D010301308187028181009DA34187F00DCF28FF2101C11A7D97ABB351A80323CFAEBD7A627CFAC34050D83D74B81087B34EF63EABC95E074A06B6EC5E52156CB000026CA92EE307EB50E0309E2BB9932C6CE832213A54DFFCD4622C53000B898354A805A3AD18B8D71D247E67851B812B5011A4AED7FE0FF2C12EE90D128C697810F2559D6498A1F8E2BB020102048183028180649F4AB6D175DE6088CC09D917DCA56A053E97D5D1C7095039D0B3A59364635E9C14B16DF5563FA1A5DE630C0271440B153B0C514EC043AAB98EDEF57C4A5FD4DDD59C8771B80371C95DDC0C1041D324BBB55357DEC90CC74692334A0B9D40C9D415DFF5B05291CBCAE7CE158FD8A14CA743B3B043CDF47A7F512B155FE5AEA8",

'3082012102010030819506092A864886F70D010301308187028181009DA34187F00DCF28FF2101C11A7D97ABB351A80323CFAEBD7A627CFAC34050D83D74B81087B34EF63EABC95E074A06B6EC5E52156CB000026CA92EE307EB50E0309E2BB9932C6CE832213A54DFFCD4622C53000B898354A805A3AD18B8D71D247E67851B812B5011A4AED7FE0FF2C12EE90D128C697810F2559D6498A1F8E2BB020102048183028180649F4AB6D175DE6088CC09D917DCA56A053E97D5D1C7095039D0B3A59364635E9C14B16DF5563FA1A5DE630C0271440B153B0C514EC043AAB98EDEF57C4A5FD4DDD59C8771B80371C95DDC0C1041D324BBB55357DEC90CC74692334A0B9D40C9D415DFF5B05291CBCAE7CE158FD8A14CA743B3B043CDF47A7F512B155FE5AEA8',

"3082012030819506092A864886F70D010301308187028181009DA34187F00DCF28FF2101C11A7D97ABB351A80323CFAEBD7A627CFAC34050D83D74B81087B34EF63EABC95E074A06B6EC5E52156CB000026CA92EE307EB50E0309E2BB9932C6CE832213A54DFFCD4622C53000B898354A805A3AD18B8D71D247E67851B812B5011A4AED7FE0FF2C12EE90D128C697810F2559D6498A1F8E2BB020102038185000281810090B0F9FE3055ECE3E18304835A345E2CA555DEAD08CDBB67CD25DCF06D5F099CB34A7ABACEF406E58A850205FC8D7E67377218C0A493F1EAAC06B37EB86B9FE29F33A5A6927AD6694B2557864E693BA019A7EE13C9CB4D3B13C7C45E6E0F423B9EFBA4897FE2F6C0A0C4E4AC1B14B66CE7290CE016828950A12BCBFF27A1548D",

"3082012030819506092A864886F70D010301308187028181009DA34187F00DCF28FF2101C11A7D97ABB351A80323CFAEBD7A627CFAC34050D83D74B81087B34EF63EABC95E074A06B6EC5E52156CB000026CA92EE307EB50E0309E2BB9932C6CE832213A54DFFCD4622C53000B898354A805A3AD18B8D71D247E67851B812B5011A4AED7FE0FF2C12EE90D128C697810F2559D6498A1F8E2BB020102038185000281810090B0F9FE3055ECE3E18304835A345E2CA555DEAD08CDBB67CD25DCF06D5F099CB34A7ABACEF406E58A850205FC8D7E67377218C0A493F1EAAC06B37EB86B9FE29F33A5A6927AD6694B2557864E693BA019A7EE13C9CB4D3B13C7C45E6E0F423B9EFBA4897FE2F6C0A0C4E4AC1B14B66CE7290CE016828950A12BCBFF27A1548D",
    }
  }

  for k, v in pairs(keys) do
    local pri = pkey.read(v[1], true, 'pem')
    assert(pri:is_private())
    local pub = assert(pri:get_public())
    assert(not pub:is_private(), k)

    -- private
    -- 1 format='pem', raw=false, passphrase=nil
    local pem1 = pri:export()
    lu.assertStrContains(pem1, '-----BEGIN PRIVATE KEY-----')
    lu.assertStrContains(pem1, '-----END PRIVATE KEY-----')
    local tmp = assert(pkey.read(pem1, true))
    assert(tmp:export()==pri:export())

    pem1 = pri:export('pem')
    lu.assertStrContains(pem1, '-----BEGIN PRIVATE KEY-----')
    lu.assertStrContains(pem1, '-----END PRIVATE KEY-----')
    tmp = assert(pkey.read(pem1, true))
    assert(tmp:export()==pri:export())

    pem1 = pri:export('pem', false)
    lu.assertStrContains(pem1, '-----BEGIN PRIVATE KEY-----')
    lu.assertStrContains(pem1, '-----END PRIVATE KEY-----')
    tmp = assert(pkey.read(pem1, true))
    assert(tmp:export()==pri:export())

    -- format='pem', raw=false, passphrase='secret'
    local pem3 = pri:export('pem', false, 'secret')
    lu.assertStrContains(pem3, '-----BEGIN ENCRYPTED PRIVATE KEY-----')
    lu.assertStrContains(pem3, '-----END ENCRYPTED PRIVATE KEY-----')

    local k2 = pkey.read(pem3, true, 'pem', 'secret')
    lu.assertEquals(pri:export(), k2:export())

    if k~='DH' then
      -- 2 format='pem', raw=true, passphrase=nil
      local pem2 = pri:export('pem', true)
      lu.assertStrContains(pem2, '-----BEGIN ' .. k .. ' PRIVATE KEY-----')
      lu.assertStrContains(pem2, '-----END ' .. k .. ' PRIVATE KEY-----')
      lu.assertNotStrContains(pem2, 'Proc-Type: 4,ENCRYPTED')
      lu.assertNotStrContains(pem2, 'DEK-Info: DES-EDE3-CBC,')

      k2 = assert(pkey.read(pem2, true, 'pem'))
      lu.assertEquals(pri:export(), k2:export())

      -- format='pem' raw=true,  passphrase='secret'
      local pem4 = pri:export('pem', true, 'secret')
      lu.assertStrContains(pem4, '-----BEGIN ' .. k .. ' PRIVATE KEY-----')
      lu.assertStrContains(pem4, '-----END ' .. k .. ' PRIVATE KEY-----')
      lu.assertStrContains(pem4, 'Proc-Type: 4,ENCRYPTED')
      lu.assertStrContains(pem4, 'DEK-Info: AES-128-CBC,')

      k2 = pkey.read(pem4, true, 'pem', 'secret')
      lu.assertEquals(pri:export(), k2:export())
    end

    -- 3 format='der', raw=false, passphrase=nil
    local export = pri:export('der')
    local hex = openssl.hex(export)
    lu.assertEquals(hex:upper(), v[2])

    k2 = pkey.read(export, true, 'der')
    lu.assertEquals(pri:export(), k2:export())

    if k~='DH' then
      k2 = assert(pkey.read(export, true, 'der', k), k)
      lu.assertEquals(pri:export(), k2:export())
    end

    export = pri:export('der', false)
    hex = openssl.hex(export)
    lu.assertEquals(hex:upper(), v[2])

    k2 = pkey.read(export, true, 'der')
    lu.assertEquals(pri:export(), k2:export())

    export = pri:export('der', nil)
    hex = openssl.hex(export)
    lu.assertEquals(hex:upper(), v[2])

    k2 = pkey.read(export, true, 'der')
    lu.assertEquals(pri:export(), k2:export())

    -- pem=false, raw=false, passphrase='secret'
    export = pri:export('der', false, 'secret')
    k2 = pkey.read(export, true, 'der', 'secret')
    lu.assertEquals(pri:export(), k2:export())

    export = pri:export('der', nil, 'secret')
    k2 = pkey.read(export, true, 'der', 'secret')
    lu.assertEquals(pri:export(), k2:export())

    -- 4 format='der', raw=true, passphrase=nil
    export = assert(pri:export('der', true))
    hex = openssl.hex(export)
    lu.assertEquals(hex:upper(), v[3], k)

    k2 = assert(pkey.read(export, true, 'der'))
    lu.assertEquals(pri:export(), k2:export(), k)

    -------------------------------
    -- public
    -- 1 format='pem', raw=false, passphrase=nil
    pem1 = pub:export()
    lu.assertEquals(pem1, pub:export('pem'))
    lu.assertStrContains(pem1, '-----BEGIN PUBLIC KEY-----')
    lu.assertStrContains(pem1, '-----END PUBLIC KEY-----')
    k2 = assert(pkey.read(pem1, false))
    lu.assertEquals(pub:export(), k2:export())
    -- 2 format='pem', raw=true, passphrase=nil
    if k~='DH' then
      pem2 = pub:export('pem', true)
      tmp = (k~='EC' and k~='DSA') and k..' ' or ''
      lu.assertStrContains(pem2, '-----BEGIN ' .. tmp .. 'PUBLIC KEY-----')
      lu.assertStrContains(pem2, '-----END ' .. tmp .. 'PUBLIC KEY-----')
      k2 = assert(pkey.read(pem2, false, 'pem', k))
      lu.assertEquals(pub:export(), k2:export())
    end

    -- 3 format='der', raw=false, passphrase=nil
    export = pub:export('der')
    hex = openssl.hex(export)
    lu.assertEquals(hex:upper(), v[4])

    export = pub:export('der', false)
    k2 = pkey.read(export, false, 'der')
    lu.assertEquals(hex:upper(), v[4])
    lu.assertEquals(pub:export(), k2:export())

    k2 = pkey.read(export, false, 'der')
    lu.assertEquals(pub:export(), k2:export())

    -- 4 format='der', raw=true, passphrase=nil
    export = pub:export('der', true)
    hex = openssl.hex(export)
    lu.assertEquals(hex:upper(), v[5])

    k1 = assert(pkey.read(export, false, 'der', k))
    local p1 = k1:export('der', true)
    lu.assertEquals(p1, export)
    lu.assertEquals(k1:export(), pub:export())
  end
end

TestPKEYSignVry = {}
function TestPKEYSignVry:setUp()
  self.msg = 'abcd'
  self.alg = 'sha1'
  self.prik = mk_key({'rsa',  2048,  3})
  self.pubk = openssl.pkey.get_public(self.prik)
  assert(self.prik:export('pem', true))
  assert(self.pubk:export('pem'))
end
function TestPKEYSignVry:testSignVry()
  local md = digest.get(self.alg)
  local sctx = digest.signInit(md, self.prik);
  assert(sctx:signUpdate(self.msg))
  assert(sctx:signUpdate(self.msg))
  local sig = assert(sctx:signFinal())
  assert(#sig == 256)
  local vctx = digest.verifyInit(md, self.pubk)
  assert(vctx:verifyUpdate(self.msg))
  assert(vctx:verifyUpdate(self.msg))
  assert(vctx:verifyFinal(sig))
end
function TestPKEYSignVry:testSignVry1()
  local md = digest.get(self.alg)
  local sctx = md:signInit(self.prik);
  assert(sctx:signUpdate(self.msg))
  assert(sctx:signUpdate(self.msg))
  local sig = sctx:signFinal()
  assert(#sig == 256)
  local vctx = md:verifyInit(self.pubk)
  assert(vctx:verifyUpdate(self.msg))
  assert(vctx:verifyUpdate(self.msg))
  assert(vctx:verifyFinal(sig))
end
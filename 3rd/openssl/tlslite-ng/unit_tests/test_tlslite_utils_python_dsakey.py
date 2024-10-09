try:
    import unittest2 as unittest
except  ImportError:
    import unittest

try:
    import mock
    from mock import call
except ImportError:
    import unittest.mock as mock
    from unittest.mock import call

from tlslite.utils.python_key import Python_Key
from tlslite.utils.python_dsakey import Python_DSAKey

from tlslite.utils.compat import a2b_hex
from tlslite.utils.cryptomath import bytesToNumber
from ecdsa.der import encode_sequence, encode_integer
class TestDSAKey(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.key_pem = (
            "-----BEGIN DSA PRIVATE KEY-----\n"
            "MIGXAgEAAiEAmeFbCUhVUZgVpljXObhmRaQYIQ12YSr9zlCja2kpTiUCFQCfCyag\n"
            "vEDkgK5nHqscaYlF32ekRwIgYgpNP8JjVxfJ4P3IErO07qqzWS21hSyMhsaCN0an\n"
            "0OsCICUjj3Np+JO42v8Mc8oH6T8yNd5X0ssy8XdK3Bo9nfNpAhQJkJXFuhZDER1X\n"
            "wOwvNiFYUPPZaA==\n"
            "-----END DSA PRIVATE KEY-----\n")

        cls.key = Python_DSAKey(p=69602034731989554929546346371414762967051205729581487767213360812510562307621,
                                q=907978205720450240238233398695599264980368073799,
                                g=44344860785224683582210580276798141855549498608976964582640232671615126065387,
                                x=54605271259585079176392566431938393409383029096,
                                y=16798405106129606882295006910154614336997455047535738179977898112652777747305)


        # Different key
        key = ( "-----BEGIN DSA PRIVATE KEY-----\n"
                "MIGYAgEAAiEAhOlFCxh6ZzzNUAttFeHWVe7TFplkqYsYXHeX4skwsvkCFQDqFZcN\n"
                "v+YbZamq6pHs5W0j81+qhwIgWTJjpklonHoFu37GS72Sk/6mC3Y+wR44xIuxQr1H\n"
                "ArMCIDOk+NSr13kYK8edl4fEdRhHRN8JOW/G42WB8oTvEQ7tAhUAyxDkbWXWyust\n"
                "bxHP2TPZV9kFzYY=\n"
                "-----END DSA PRIVATE KEY-----\n")

        cls.key_diff = Python_Key.parsePEM(key)

        # dsa sha1 signature of "some message to sign"
        cls.sha1_sig =(b'\x30\x2C\x02\x14\x54\x07\x13\xC9\xE6\xB4\x48\x75\x19\x4D\x88\x61'
                       b'\xBA\x73\x46\x37\xDA\x78\x1C\xB1\x02\x14\x58\x2A\xE1\x17\x20\x46'
                       b'\x5A\xD9\xA8\xC0\x5F\xEA\x1A\x1A\x3D\xE5\x41\x01\x45\xDB')


    def test_parse_from_pem(self):

        parsed_key = Python_Key.parsePEM(self.key_pem)
        self.assertIsInstance(parsed_key, Python_DSAKey)
        self.assertTrue(parsed_key.hasPrivateKey())
        self.assertEqual(parsed_key.private_key, self.key.private_key)
        self.assertEqual(parsed_key.public_key, self.key.public_key)
        self.assertEqual(parsed_key.q, self.key.q)
        self.assertEqual(parsed_key.p, self.key.p)
        self.assertEqual(parsed_key.g, self.key.g)

    def test_generate(self):
        key = Python_DSAKey.generate(1024, 160)
        self.assertIsInstance(key, Python_DSAKey)
        self.assertTrue(key.hasPrivateKey())

    def test_sign_default(self):
        msg = b'some message to sign'

        sig = self.key.hashAndSign(msg)

        self.assertTrue(sig)
    def test_verify(self):
        msg = b'some message to sign'

        self.assertTrue(self.key.hashAndVerify(self.sha1_sig, msg))

    def test_sign_verify_malformed_signature_r(self):
        msg = b'some message to sign'
        # signature with r component equal to q
        sig = (b'\x30\x2d\x02\x15\x00\x9f\x0b\x26\xa0\xbc\x40\xe4\x80\xae\x67\x1e\xab\x1c\x69'
               b'\x89\x45\xdf\x67\xa4\x47\x02\x14\x49\x27\x07\xde\x17\x27\xa5\x78\x05\xaf\x0e'
               b'\x1f\x03\x61\x10\xe4\x99\x2d\xff\x03')

        self.assertFalse(self.key_diff.hashAndVerify(sig, msg))

    def test_sign_verify_malformed_signature_s(self):
        msg = b'some message to sign'
        # signature with s component equal to q
        sig = (b'\x30\x2d\x02\x14\x1a\x6e\x40\x15\x68\xe5\xbd\x02\x65\xc2\x76\xf0\x97\x0a\xab'
               b'\x4a\xb0\xb6\xc8\x43\x02\x15\x00\x9f\x0b\x26\xa0\xbc\x40\xe4\x80\xae\x67\x1e'
               b'\xab\x1c\x69\x89\x45\xdf\x67\xa4\x47')

        self.assertFalse(self.key_diff.hashAndVerify(sig, msg))

    def test_sign_verify_malformed_signature_unrecognized(self):
        msg = b'some message to sign'
        # signature with 3 integer sequence
        sig = (b'\x30\x30\x02\x14\x1a\x6e\x40\x15\x68\xe5\xbd\x02\x65\xc2\x76\xf0\x97\x0a\xab'
               b'\x4a\xb0\xb6\xc8\x43\x02\x15\x00\x9f\x0b\x26\xa0\xbc\x40\xe4\x80\xae\x67\x1e'
               b'\xab\x1c\x69\x89\x45\xdf\x67\xa4\x47\x02\x01\x00')

        self.assertFalse(self.key_diff.hashAndVerify(sig, msg))

    def test_sign_verify_malformed_signature_garbage(self):
        msg = b'some message to sign'
        # signature with garbage byte at the end
        sig = (b'\x30\x2d\x02\x14\x1a\x6e\x40\x15\x68\xe5\xbd\x02\x65\xc2\x76\xf0\x97\x0a\xab'
               b'\x4a\xb0\xb6\xc8\x43\x02\x15\x00\x9f\x0b\x26\xa0\xbc\x40\xe4\x80\xae\x67\x1e'
               b'\xab\x1c\x69\x89\x45\xdf\x67\xa4\x47')

        self.assertFalse(self.key_diff.hashAndVerify(sig, msg))

    def test_verify_diff_key(self):
        msg = b'some message to sign'

        self.assertFalse(self.key_diff.hashAndVerify(self.sha1_sig, msg))

    def test_verify_diff_sign(self):
        msg = b'some message to sign'

        # dsa sha1 signature of "another message to sign"
        sig = (b'\x30\x2D\x02\x15\x00\x88\xE8\xAF\x9C\xDA\x6D\x0B\x4A\xC4\x0E\x52'
               b'\x49\xE2\xA5\x28\x08\x45\x8E\xD6\x1F\x02\x14\x14\x38\xE2\x92\x2B'
               b'\x16\xA7\x4B\xB2\x2D\xEA\xFC\x23\xE3\x1B\x84\xCE\x30\x98\x32')

        self.assertFalse(self.key.hashAndVerify(sig, msg))

    def test_sign_and_verify_with_md5(self):
        msg = b"some message to sign"

        sig = self.key.hashAndSign(msg, hAlg="md5")

        self.assertTrue(self.key.hashAndVerify(sig, msg, hAlg="md5"))

    def test_sign_and_verify_with_sha1(self):
        #message
        msg = a2b_hex(
                "3b46736d559bd4e0c2c1b2553a33ad3c6cf23cac998d3d0c0e8fa4b19bca06"
                "f2f386db2dcff9dca4f40ad8f561ffc308b46c5f31a7735b5fa7e0f9e6cb51"
                "2e63d7eea05538d66a75cd0d4234b5ccf6c1715ccaaf9cdc0a2228135f716e"
                "e9bdee7fc13ec27a03a6d11c5c5b3685f51900b1337153bc6c4e8f52920c33"
                "fa37f4e7")
        # key
        key = Python_DSAKey(
                p = bytesToNumber(a2b_hex(
                    "a8f9cd201e5e35d892f85f80e4db2599a5676a3b1d4f190330ed3256b2"
                    "6d0e80a0e49a8fffaaad2a24f472d2573241d4d6d6c7480c80b4c67bb4"
                    "479c15ada7ea8424d2502fa01472e760241713dab025ae1b02e1703a14"
                    "35f62ddf4ee4c1b664066eb22f2e3bf28bb70a2a76e4fd5ebe2d122968"
                    "1b5b06439ac9c7e9d8bde283")),
                q = bytesToNumber(
                    a2b_hex("f85f0f83ac4df7ea0cdf8f469bfeeaea14156495")),
                g = bytesToNumber(a2b_hex(
                    "2b3152ff6c62f14622b8f48e59f8af46883b38e79b8c74deeae9df131f"
                    "8b856e3ad6c8455dab87cc0da8ac973417ce4f7878557d6cdf40b35b4a"
                    "0ca3eb310c6a95d68ce284ad4e25ea28591611ee08b8444bd64b25f3f7"
                    "c572410ddfb39cc728b9c936f85f419129869929cdb909a6a3a99bbe08"
                    "9216368171bd0ba81de4fe33")),
                y = bytesToNumber(a2b_hex(
                    "313fd9ebca91574e1c2eebe1517c57e0c21b0209872140c5328761bbb2"
                    "450b33f1b18b409ce9ab7c4cd8fda3391e8e34868357c199e16a6b2eba"
                    "06d6749def791d79e95d3a4d09b24c392ad89dbf100995ae19c0106205"
                    "6bb14bce005e8731efde175f95b975089bdcdaea562b32786d96f5a31a"
                    "edf75364008ad4fffebb970b")))
        # signature
        r = bytesToNumber(a2b_hex("50ed0e810e3f1c7cb6ac62332058448bd8b284c0"))
        s = bytesToNumber(a2b_hex("c6aded17216b46b7e4b6f2a97c1ad7cc3da83fde"))
        sig = encode_sequence(encode_integer(r), encode_integer(s))
        # test
        self.assertTrue(key.hashAndVerify(sig, msg))

    def test_sign_and_verify_with_sha224(self):
        #message
        msg = a2b_hex(
                "fb2128052509488cad0745ed3e6312850dd96ddaf791f1e624e22a6b9beaa6"
                "5319c325c78ef59cacba0ccfa722259f24f92c17b77a8f6d8e97c93d880d2d"
                "8dbbbedcf6acefa06b0e476ca2013d0394bd90d56c10626ef43cea79d1ef0b"
                "c7ac452bf9b9acaef70325e055ac006d34024b32204abea4be5faae0a6d46d"
                "365ed0d9")
        # key
        key = Python_DSAKey(
                p = bytesToNumber(a2b_hex(
                    "8b9b32f5ba38faad5e0d506eb555540d0d7963195558ca308b7466228d"
                    "92a17b3b14b8e0ab77a9f3b2959a09848aa69f8df92cd9e9edef0adf79"
                    "2ce77bfceccadd9352700ca5faecf181fa0c326db1d6e5d352458011e5"
                    "1bd3248f4e3bd7c820d7e0a81932aca1eba390175e53eada197223674e"
                    "3900263e90f72d94e7447bff")),
                q = bytesToNumber(a2b_hex(
                    "bc550e965647fb3a20f245ec8475624abbb26edd")),
                g = bytesToNumber(a2b_hex(
                    "11333a931fba503487777376859fdc12f7c687b0948ae889d287f1b7a7"
                    "12ad220ae4f1ce379d0dbb5c9abf419621f005fc123c327e5055d18506"
                    "34c36d397e689e111d598c1c3636b940c84f42f436846e8e7fcad9012c"
                    "eda398720f32fffd1a45ab6136ce417069207ac140675b8f86dd063915"
                    "ae6f62b0cec729fbd509ac17")),
                y = bytesToNumber(a2b_hex(
                    "7e339f3757450390160e02291559f30bed0b2d758c5ccc2d8d456232bb"
                    "435ae49de7e7957e3aad9bfdcf6fd5d9b6ee3b521bc2229a8421dc2aa5"
                    "9b9952345a8fc1de49b348003a9b18da642d7f6f56e3bc665131ae9762"
                    "088a93786f7b4b72a4bcc308c67e2532a3a5bf09652055cc26bf3b1883"
                    "3598cffd7011f2285f794557")))
        # signature
        r = bytesToNumber(a2b_hex("afee719e7f848b54349ccc3b4fb26065833a4d8e"))
        s = bytesToNumber(a2b_hex("734efe992256f31325e749bc32a24a1f957b3a1b"))
        sig = encode_sequence(encode_integer(r), encode_integer(s))
        # test
        self.assertTrue(key.hashAndVerify(sig, msg, hAlg="sha224"))

    def test_sign_and_verify_with_sha254(self):
        #message
        msg = a2b_hex(
                    "812172f09cbae62517804885754125fc6066e9a902f9db2041eeddd7e8"
                    "da67e4a2e65d0029c45ecacea6002f9540eb1004c883a8f900fd84a98b"
                    "5c449ac49c56f3a91d8bed3f08f427935fbe437ce46f75cd666a070726"
                    "5c61a096698dc2f36b28c65ec7b6e475c8b67ddfb444b2ee6a984e9d6d"
                    "15233e25e44bd8d7924d129d")
        # key
        key = Python_DSAKey(
                p = bytesToNumber(a2b_hex(
                    "cba13e533637c37c0e80d9fcd052c1e41a88ac325c4ebe13b7170088d5"
                    "4eef4881f3d35eae47c210385a8485d2423a64da3ffda63a26f92cf5a3"
                    "04f39260384a9b7759d8ac1adc81d3f8bfc5e6cb10efb4e0f75867f4e8"
                    "48d1a338586dd0648feeb163647ffe7176174370540ee8a8f588da8cc1"
                    "43d939f70b114a7f981b8483")),
                q = bytesToNumber(a2b_hex(
                    "95031b8aa71f29d525b773ef8b7c6701ad8a5d99")),
                g = bytesToNumber(a2b_hex(
                    "45bcaa443d4cd1602d27aaf84126edc73bd773de6ece15e97e7fef46f1"
                    "3072b7adcaf7b0053cf4706944df8c4568f26c997ee7753000fbe477a3"
                    "7766a4e970ff40008eb900b9de4b5f9ae06e06db6106e78711f3a67fec"
                    "a74dd5bddcdf675ae4014ee9489a42917fbee3bb9f2a24df67512c1c35"
                    "c97bfbf2308eaacd28368c5c")),
                y = bytesToNumber(a2b_hex(
                    "4cd6178637d0f0de1488515c3b12e203a3c0ca652f2fe30d088dc7278a"
                    "87affa634a727a721932d671994a958a0f89223c286c3a9b10a9656054"
                    "2e2626b72e0cd28e5133fb57dc238b7fab2de2a49863ecf998751861ae"
                    "668bf7cad136e6933f57dfdba544e3147ce0e7370fa6e8ff1de690c51b"
                    "4aeedf0485183889205591e8")))
        # signature
        r = bytesToNumber(a2b_hex("76683a085d6742eadf95a61af75f881276cfd26a"))
        s = bytesToNumber(a2b_hex("3b9da7f9926eaaad0bebd4845c67fcdb64d12453"))
        sig = encode_sequence(encode_integer(r), encode_integer(s))
        # test
        self.assertTrue(key.hashAndVerify(sig, msg, hAlg="sha256"))

    def test_sign_and_verify_with_sha384(self):
        #message
        msg = a2b_hex(
                "ed9a64d3109ef8a9292956b946873ca4bd887ce624b81be81b82c69c67aadd"
                "f5655f70fe4768114db2834c71787f858e5165da1a7fa961d855ad7e5bc4b7"
                "be31b97dbe770798ef7966152b14b86ae35625a28aee5663b9ef3067cbdfba"
                "bd87197e5c842d3092eb88dca57c6c8ad4c00a19ddf2e1967b59bd06ccaef9"
                "33bc28e7")
        # key
        key = Python_DSAKey(
                p = bytesToNumber(a2b_hex(
                    "a410d23ed9ad9964d3e401cb9317a25213f75712acbc5c12191abf3f1c"
                    "0e723e2333b49eb1f95b0f9748d952f04a5ae358859d384403ce364aa3"
                    "f58dd9769909b45048548c55872a6afbb3b15c54882f96c20df1b2df16"
                    "4f0bac849ca17ad2df63abd75c881922e79a5009f00b7d631622e90e7f"
                    "a4e980618575e1d6bd1a72d5b6a50f4f6a68b793937c4af95fc1154175"
                    "9a1736577d9448b87792dff07232415512e933755e12250d466e9cc8df"
                    "150727d747e51fea7964158326b1365d580cb190f4518291598221fdf3"
                    "6c6305c8b8a8ed05663dd7b006e945f592abbecae460f77c71b6ec649d"
                    "3fd5394202ed7bbbd040f7b8fd57cb06a99be254fa25d71a3760734046"
                    "c2a0db383e02397913ae67ce65870d9f6c6f67a9d00497be1d763b2193"
                    "7cf9cbf9a24ef97bbcaa07916f8894e5b7fb03258821ac46140965b23c"
                    "5409ca49026efb2bf95bce025c4183a5f659bf6aaeef56d7933bb29697"
                    "d7d541348c871fa01f869678b2e34506f6dc0a4c132b689a0ed27dc3c8"
                    "d53702aa584877")),
                q = bytesToNumber(a2b_hex(
                    "abc67417725cf28fc7640d5de43825f416ebfa80e191c42ee886303338"
                    "f56045")),
                g = bytesToNumber(a2b_hex(
                    "867d5fb72f5936d1a14ed3b60499662f3124686ef108c5b3da6663a0e8"
                    "6197ec2cc4c9460193a74ff16028ac9441b0c7d27c2272d483ac7cd794"
                    "d598416c4ff9099a61679d417d478ce5dd974bf349a14575afe74a88b1"
                    "2dd5f6d1cbd3f91ddd597ed68e79eba402613130c224b94ac28714a1f1"
                    "c552475a5d29cfcdd8e08a6b1d65661e28ef313514d1408f5abd3e06eb"
                    "e3a7d814d1ede316bf495273ca1d574f42b482eea30db53466f454b51a"
                    "175a0b89b3c05dda006e719a2e6371669080d768cc038cdfb8098e9aad"
                    "9b8d83d4b759f43ac9d22b353ed88a33723550150de0361b7a376f37b4"
                    "5d437f71cb711f2847de671ad1059516a1d45755224a15d37b4aeada3f"
                    "58c69a136daef0636fe38e3752064afe598433e80089fda24b144a4627"
                    "34bef8f77638845b00e59ce7fa4f1daf487a2cada11eaba72bb23e1df6"
                    "b66a183edd226c440272dd9b06bec0e57f1a0822d2e00212064b6dba64"
                    "562085f5a75929afa5fe509e0b78e630aaf12f91e4980c9b0d6f7e059a"
                    "2ea3e23479d930")),
                y = bytesToNumber(a2b_hex(
                    "1f0a5c75e7985d6e70e4fbfda51a10b925f6accb600d7c6510db90ec36"
                    "7b93bb069bd286e8f979b22ef0702f717a8755c18309c87dae3fe82cc3"
                    "dc8f4b7aa3d5f3876f4d4b3eb68bfe910c43076d6cd0d39fc88dde78f0"
                    "9480db55234e6c8ca59fe2700efec04feee6b4e8ee2413721858be7190"
                    "dbe905f456edcab55b2dc2916dc1e8731988d9ef8b619abcf8955aa960"
                    "ef02b3f02a8dc649369222af50f1338ed28d667f3f10cae2a3c28a3c1d"
                    "08df639c81ada13c8fd198c6dae3d62a3fe9f04c985c65f610c06cb8fa"
                    "ea68edb80de6cf07a8e89c00218185a952b23572e34df07ce5b4261e5d"
                    "e427eb503ee1baf5992db6d438b47434c40c22657bc163e7953fa33eff"
                    "39dc2734607039aadd6ac27e4367131041f845ffa1a13f556bfba2307a"
                    "5c78f2ccf11298c762e08871968e48dc3d1569d09965cd09da43cf0309"
                    "a16af1e20fee7da3dc21b364c4615cd5123fa5f9b23cfc4ffd9cfdcea6"
                    "70623840b062d4648d2eba786ad3f7ae337a4284324ace236f9f7174fb"
                    "f442b99043002f")))
        # signature
        r = bytesToNumber(a2b_hex("7695698a14755db4206e850b4f5f19c540b07d07e08a"
                "ac591e20081646e6eedc"))
        s = bytesToNumber(a2b_hex("3dae01154ecff7b19007a953f185f0663ef7f2537f0b"
                "15e04fb343c961f36de2"))
        sig = encode_sequence(encode_integer(r), encode_integer(s))
        # test
        self.assertTrue(key.hashAndVerify(sig, msg, hAlg="sha384"))

    def test_sign_and_verify_with_sha512(self):
        #message
        msg = a2b_hex(
                "494180eed0951371bbaf0a850ef13679df49c1f13fe3770b6c13285bf3ad93"
                "dc4ab018aab9139d74200808e9c55bf88300324cc697efeaa641d37f3acf72"
                "d8c97bff0182a35b940150c98a03ef41a3e1487440c923a988e53ca3ce883a"
                "2fb532bb7441c122f1dc2f9d0b0bc07f26ba29a35cdf0da846a9d8eab405cb"
                "f8c8e77f")
        # key
        key = Python_DSAKey(
                p = bytesToNumber(a2b_hex(
                    "c1d0a6d0b5ed615dee76ac5a60dd35ecb000a202063018b1ba0a06fe7a"
                    "00f765db1c59a680cecfe3ad41475badb5ad50b6147e2596b88d346560"
                    "52aca79486ea6f6ec90b23e363f3ab8cdc8b93b62a070e02688ea87784"
                    "3a4685c2ba6db111e9addbd7ca4bce65bb10c9ceb69bf806e2ebd7e54e"
                    "deb7f996a65c907b50efdf8e575bae462a219c302fef2ae81d73cee752"
                    "74625b5fc29c6d60c057ed9e7b0d46ad2f57fe01f823230f3142272231"
                    "9ce0abf1f141f326c00fbc2be4cdb8944b6fd050bd300bdb1c5f4da725"
                    "37e553e01d51239c4d461860f1fb4fd8fa79f5d5263ff62fed7008e2e0"
                    "a2d36bf7b9062d0d75db226c3464b67ba24101b085f2c670c0f87ae530"
                    "d98ee60c5472f4aa15fb25041e19106354da06bc2b1d322d40ed97b21f"
                    "d1cdad3025c69da6ce9c7ddf3dcf1ea4d56577bfdec23071c1f05ee407"
                    "7b5391e9a404eaffe12d1ea62d06acd6bf19e91a158d2066b4cd20e4c4"
                    "e52ffb1d5204cd022bc7108f2c799fb468866ef1cb09bce09dfd49e474"
                    "0ff8140497be61")),
                q = bytesToNumber(a2b_hex(
                    "bf65441c987b7737385eadec158dd01614da6f15386248e59f3cddbefc"
                    "8e9dd1")),
                g = bytesToNumber(a2b_hex(
                    "c02ac85375fab80ba2a784b94e4d145b3be0f92090eba17bd12358cf3e"
                    "03f4379584f8742252f76b1ede3fc37281420e74a963e4c088796ff2ba"
                    "b8db6e9a4530fc67d51f88b905ab43995aab46364cb40c1256f0466f3d"
                    "bce36203ef228b35e90247e95e5115e831b126b628ee984f349911d30f"
                    "fb9d613b50a84dfa1f042ba536b82d5101e711c629f9f2096dc834deec"
                    "63b70f2a2315a6d27323b995aa20d3d0737075186f5049af6f512a0c38"
                    "a9da06817f4b619b94520edfac85c4a6e2e186225c95a04ec3c3422b8d"
                    "eb284e98d24b31465802008a097c25969e826c2baa59d2cba33d6c1d9f"
                    "3962330c1fcda7cfb18508fea7d0555e3a169daed353f3ee6f4bb30244"
                    "319161dff6438a37ca793b24bbb1b1bc2194fc6e6ef60278157899cb03"
                    "c5dd6fc91a836eb20a25c09945643d95f7bd50d206684d6ffc14d16d82"
                    "d5f781225bff908392a5793b803f9b70b4dfcb394f9ed81c18e391a09e"
                    "b3f93a032d81ba670cabfd6f64aa5e3374cb7c2029f45200e4f0bfd820"
                    "c8bd58dc5eeb34")),
                y = bytesToNumber(a2b_hex(
                    "6da54f2b0ddb4dcce2da1edfa16ba84953d8429ce60cd111a5c65edcf7"
                    "ba5b8d9387ab6881c24880b2afbdb437e9ed7ffb8e96beca7ea80d1d90"
                    "f24d546112629df5c9e9661742cc872fdb3d409bc77b75b17c7e6cfff8"
                    "6261071c4b5c9f9898be1e9e27349b933c34fb345685f8fc6c12470d12"
                    "4cecf51b5d5adbf5e7a2490f8d67aac53a82ed6a2110686cf631c348bc"
                    "bc4cf156f3a6980163e2feca72a45f6b3d68c10e5a2283b470b7292674"
                    "490383f75fa26ccf93c0e1c8d0628ca35f2f3d9b6876505d1189889572"
                    "37a2fc8051cb47b410e8b7a619e73b1350a9f6a260c5f16841e7c4db53"
                    "d8eaa0b4708d62f95b2a72e2f04ca14647bca6b5e3ee707fcdf758b925"
                    "eb8d4e6ace4fc7443c9bc5819ff9e555be098aa055066828e21b818fed"
                    "c3aac517a0ee8f9060bd86e0d4cce212ab6a3a243c5ec0274563353ca7"
                    "103af085e8f41be524fbb75cda88903907df94bfd69373e288949bd062"
                    "6d85c1398b3073a139d5c747d24afdae7a3e745437335d0ee993eef36a"
                    "3041c912f7eb58")))

        # signature
        r = bytesToNumber(a2b_hex("a40a6c905654c55fc58e99c7d1a3feea2c5be64823d4"
                "086ce811f334cfdc448d"))
        s = bytesToNumber(a2b_hex("6478050977ec585980454e0a2f26a03037b921ca588a"
                "78a4daff7e84d49a8a6c"))
        sig = encode_sequence(encode_integer(r), encode_integer(s))
        # test
        self.assertTrue(key.hashAndVerify(sig, msg, hAlg="sha512"))


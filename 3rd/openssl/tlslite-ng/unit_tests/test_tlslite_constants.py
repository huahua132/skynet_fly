# Copyright (c) 2015, Hubert Kario
#
# See the LICENSE file for legal information regarding use of this file.

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest
try:
    import mock
    from mock import call
except ImportError:
    import unittest.mock as mock
    from unittest.mock import call

from tlslite.handshakesettings import HandshakeSettings
from tlslite.constants import CipherSuite, HashAlgorithm, SignatureAlgorithm, \
        ContentType, AlertDescription, AlertLevel, HandshakeType, GroupName, \
        TLSEnum, SignatureScheme

class TestTLSEnumSubClassing(unittest.TestCase):

    class SubClass(TLSEnum):
        value = 1

    def test_toRepr(self):
        self.assertEqual(self.SubClass.toStr(1), 'value')

    class SubSubClass(SubClass):
        new_value = 2

    def test_toRepr_SubSubClass(self):
        self.assertEqual(self.SubSubClass.toStr(1), 'value')
        self.assertEqual(self.SubSubClass.toStr(2), 'new_value')


class TestHashAlgorithm(unittest.TestCase):

    def test_toRepr(self):
        self.assertEqual(HashAlgorithm.toRepr(5), 'sha384')

    def test_toRepr_with_invalid_id(self):
        self.assertIsNone(HashAlgorithm.toRepr(None))

    def test_toRepr_with_unknown_id(self):
        self.assertIsNone(HashAlgorithm.toRepr(200))

    def test_toStr_with_unknown_id(self):
        self.assertEqual(HashAlgorithm.toStr(200), '200')

    def test_toStr(self):
        self.assertEqual(HashAlgorithm.toStr(6), 'sha512')

class TestSignatureAlgorithm(unittest.TestCase):

    def test_toRepr(self):
        self.assertEqual(SignatureAlgorithm.toRepr(1), 'rsa')

class TestContentType(unittest.TestCase):

    def test_toRepr_with_invalid_value(self):
        self.assertIsNone(ContentType.toRepr((20, 21, 22, 23)))

    def test_toStr_with_invalid_value(self):
        self.assertEqual(ContentType.toStr((20, 21, 22, 23)),
                         '(20, 21, 22, 23)')

class TestGroupName(unittest.TestCase):

    def test_toRepr(self):
        self.assertEqual(GroupName.toRepr(256), 'ffdhe2048')

    def test_toRepr_with_brainpool(self):
        self.assertEqual(GroupName.toRepr(27), 'brainpoolP384r1')

class TestAlertDescription(unittest.TestCase):
    def test_toRepr(self):
        self.assertEqual(AlertDescription.toStr(40), 'handshake_failure')

class TestAlertLevel(unittest.TestCase):
    def test_toRepr(self):
        self.assertEqual(AlertLevel.toStr(1), 'warning')

class TestHandshakeType(unittest.TestCase):
    def test_toRepr(self):
        self.assertEqual(HandshakeType.toStr(1), 'client_hello')

class TestCipherSuite(unittest.TestCase):

    def test___init__(self):
        cipherSuites = CipherSuite()

        self.assertIsNotNone(cipherSuites)

    def test_filterForVersion_with_SSL3_ciphers(self):
        suites = [CipherSuite.TLS_RSA_WITH_3DES_EDE_CBC_SHA,
                  CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                  CipherSuite.TLS_RSA_WITH_RC4_128_MD5]

        filtered = CipherSuite.filterForVersion(suites, (3, 0), (3, 0))

        self.assertEqual(filtered,
                         [CipherSuite.TLS_RSA_WITH_3DES_EDE_CBC_SHA,
                          CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                          CipherSuite.TLS_RSA_WITH_RC4_128_MD5])

        filtered = CipherSuite.filterForVersion(suites, (3, 3), (3, 3))

        self.assertEqual(filtered,
                         [CipherSuite.TLS_RSA_WITH_3DES_EDE_CBC_SHA,
                          CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                          CipherSuite.TLS_RSA_WITH_RC4_128_MD5])

    def test_filterForVersion_with_unknown_ciphers(self):
        suites = [0, 0xfffe]

        filtered = CipherSuite.filterForVersion(suites, (3, 0), (3, 3))

        self.assertEqual(filtered, [])

    def test_filterForVersion_with_TLS_1_1(self):
        suites = [CipherSuite.TLS_RSA_WITH_3DES_EDE_CBC_SHA,
                  CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                  CipherSuite.TLS_RSA_WITH_RC4_128_MD5,
                  CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA256,
                  CipherSuite.TLS_RSA_WITH_AES_256_CBC_SHA256,
                  CipherSuite.TLS_AES_128_GCM_SHA256]

        filtered = CipherSuite.filterForVersion(suites, (3, 2), (3, 2))

        self.assertEqual(filtered,
                         [CipherSuite.TLS_RSA_WITH_3DES_EDE_CBC_SHA,
                          CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                          CipherSuite.TLS_RSA_WITH_RC4_128_MD5])

    def test_filterForVersion_with_TLS_1_2(self):
        suites = [CipherSuite.TLS_RSA_WITH_3DES_EDE_CBC_SHA,
                  CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                  CipherSuite.TLS_RSA_WITH_RC4_128_MD5,
                  CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA256,
                  CipherSuite.TLS_RSA_WITH_AES_256_CBC_SHA256,
                  CipherSuite.TLS_AES_128_GCM_SHA256]

        filtered = CipherSuite.filterForVersion(suites, (3, 3), (3, 3))

        self.assertEqual(filtered,
                         [CipherSuite.TLS_RSA_WITH_3DES_EDE_CBC_SHA,
                          CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA,
                          CipherSuite.TLS_RSA_WITH_RC4_128_MD5,
                          CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA256,
                          CipherSuite.TLS_RSA_WITH_AES_256_CBC_SHA256])

    def test_filterForVersion_with_TLS_1_3(self):
        suites = [CipherSuite.TLS_RSA_WITH_3DES_EDE_CBC_SHA,
                  CipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA256,
                  CipherSuite.TLS_RSA_WITH_AES_128_GCM_SHA256,
                  CipherSuite.TLS_AES_128_GCM_SHA256]

        filtered = CipherSuite.filterForVersion(suites, (3, 4), (3, 4))

        self.assertEqual(filtered,
                         [CipherSuite.TLS_AES_128_GCM_SHA256])

    def test_getEcdsaSuites(self):
        hs = HandshakeSettings()
        hs.keyExchangeNames = ["ecdhe_ecdsa"]
        hs.cipherNames = ["aes128"]

        filtered = CipherSuite.getEcdsaSuites(hs)

        self.assertEqual(filtered,
                         [CipherSuite.TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256,
                          CipherSuite.TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA])

    def test_getTLS13Suites(self):
        hs = HandshakeSettings()
        hs.maxVersion = (3, 4)
        self.assertEqual(CipherSuite.getTLS13Suites(hs),
                         [CipherSuite.TLS_AES_256_GCM_SHA384,
                          CipherSuite.TLS_AES_128_GCM_SHA256,
                          CipherSuite.TLS_CHACHA20_POLY1305_SHA256,
                          CipherSuite.TLS_AES_128_CCM_SHA256])

    def test_getTLS13Suites_with_TLS1_2(self):
        hs = HandshakeSettings()
        hs.maxVersion = (3, 4)
        self.assertEqual(CipherSuite.getTLS13Suites(hs, (3, 3)),
                         [])

    def test_filter_for_certificate_with_no_cert(self):
        orig_ciphers = [CipherSuite.TLS_RSA_WITH_3DES_EDE_CBC_SHA,
                        CipherSuite.TLS_ECDH_ANON_WITH_3DES_EDE_CBC_SHA,
                        CipherSuite.TLS_AES_128_GCM_SHA256]

        new_ciphers = CipherSuite.filter_for_certificate(
            orig_ciphers,
            None)

        self.assertFalse(orig_ciphers is new_ciphers)
        self.assertEqual(new_ciphers,
                         [CipherSuite.TLS_ECDH_ANON_WITH_3DES_EDE_CBC_SHA,
                          CipherSuite.TLS_AES_128_GCM_SHA256])

    def test_filter_for_certificate_with_rsa(self):
        cert_list = mock.MagicMock()
        cert = mock.MagicMock()
        cert.certAlg = "rsa"
        cert_list.x509List = [cert]

        orig_ciphers = [CipherSuite.TLS_RSA_WITH_3DES_EDE_CBC_SHA,
                        CipherSuite.TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA,
                        CipherSuite.TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA,
                        CipherSuite.TLS_AES_128_GCM_SHA256]

        new_ciphers = CipherSuite.filter_for_certificate(
            orig_ciphers, cert_list)

        self.assertEqual(new_ciphers,
                         [CipherSuite.TLS_RSA_WITH_3DES_EDE_CBC_SHA,
                          CipherSuite.TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA,
                          CipherSuite.TLS_AES_128_GCM_SHA256])

    def test_filter_for_certificate_with_rsa_pss(self):
        cert_list = mock.MagicMock()
        cert = mock.MagicMock()
        cert.certAlg = "rsa-pss"
        cert_list.x509List = [cert]

        orig_ciphers = [CipherSuite.TLS_RSA_WITH_3DES_EDE_CBC_SHA,
                        CipherSuite.TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA,
                        CipherSuite.TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA,
                        CipherSuite.TLS_AES_128_GCM_SHA256]

        new_ciphers = CipherSuite.filter_for_certificate(
            orig_ciphers, cert_list)

        self.assertEqual(new_ciphers,
                         [CipherSuite.TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA,
                          CipherSuite.TLS_AES_128_GCM_SHA256])

    def test_filter_for_certificate_with_dsa(self):
        cert_list = mock.MagicMock()
        cert = mock.MagicMock()
        cert.certAlg = "dsa"
        cert_list.x509List = [cert]

        orig_ciphers = [CipherSuite.TLS_RSA_WITH_3DES_EDE_CBC_SHA,
                        CipherSuite.TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA,
                        CipherSuite.TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA,
                        CipherSuite.TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA,
                        CipherSuite.TLS_AES_128_GCM_SHA256]

        new_ciphers = CipherSuite.filter_for_certificate(
            orig_ciphers, cert_list)

        self.assertEqual(new_ciphers,
                         [CipherSuite.TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA,
                          CipherSuite.TLS_AES_128_GCM_SHA256])

    def test_filter_for_certificate_with_ecdsa(self):
        cert_list = mock.MagicMock()
        cert = mock.MagicMock()
        cert.certAlg = "ecdsa"
        cert_list.x509List = [cert]

        orig_ciphers = [CipherSuite.TLS_RSA_WITH_3DES_EDE_CBC_SHA,
                        CipherSuite.TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA,
                        CipherSuite.TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA,
                        CipherSuite.TLS_AES_128_GCM_SHA256]

        new_ciphers = CipherSuite.filter_for_certificate(
            orig_ciphers, cert_list)

        self.assertEqual(new_ciphers,
                         [CipherSuite.TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA,
                          CipherSuite.TLS_AES_128_GCM_SHA256])


class TestSignatureScheme(unittest.TestCase):
    def test_toRepr_with_valid_value(self):
        ret = SignatureScheme.toRepr((6, 1))

        self.assertEqual(ret, "rsa_pkcs1_sha512")

    def test_toRepr_with_obsolete_value(self):
        ret = SignatureScheme.toRepr((1, 1))

        self.assertIsNone(ret)

    def test_getKeyType_with_valid_name(self):
        ret = SignatureScheme.getKeyType('rsa_pkcs1_sha256')

        self.assertEqual(ret, 'rsa')

    def test_getKeyType_with_invalid_name(self):
        with self.assertRaises(ValueError):
            SignatureScheme.getKeyType('eddsa_sha512')

    def test_getPadding_with_valid_name(self):
        ret = SignatureScheme.getPadding('rsa_pss_sha512')

        self.assertEqual(ret, 'pss')

    def test_getPadding_with_new_valid_name(self):
        ret = SignatureScheme.getPadding('rsa_pss_rsae_sha256')

        self.assertEqual(ret, 'pss')

    def test_getPadding_with_invalid_name(self):
        with self.assertRaises(ValueError):
            SignatureScheme.getPadding('rsa_oead_sha256')

    def test_getHash_with_valid_name(self):
        ret = SignatureScheme.getHash('rsa_pss_sha256')

        self.assertEqual(ret, 'sha256')

    def test_getHash_with_invalid_name(self):
        with self.assertRaises(ValueError):
            SignatureScheme.getHash('rsa_oead_sha256')

    def test_getHash_with_valid_new_name(self):
        ret = SignatureScheme.getHash('rsa_pss_pss_sha384')

        self.assertEqual(ret, 'sha384')

    def test_getKeyType_with_valid_new_name(self):
        ret = SignatureScheme.getKeyType('rsa_pss_pss_sha384')

        self.assertEqual(ret, 'rsa')

    def test_getPadding_with_valid_new_name(self):
        ret = SignatureScheme.getPadding('rsa_pss_pss_sha256')

        self.assertEqual(ret, 'pss')

    def test_getKeyType_with_eddsa(self):
        ret = SignatureScheme.getKeyType('ed25519')

        self.assertEqual(ret, 'eddsa')

    def test_getHash_with_eddsa(self):
        ret = SignatureScheme.getHash('ed25519')

        self.assertEqual(ret, 'intrinsic')

# Copyright (c) 2014, Hubert Kario
#
# See the LICENSE file for legal information regarding use of this file.

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
        import unittest2 as unittest
except ImportError:
        import unittest

from tlslite.mathtls import PRF_1_2, calc_key, paramStrength
from tlslite.handshakehashes import HandshakeHashes
from tlslite.constants import CipherSuite

class TestCalcMasterSecret(unittest.TestCase):
    def test_with_empty_values(self):
        ret = calc_key((3, 3), bytearray(48), 0,
                       b"master secret",
                       client_random=bytearray(32),
                       server_random=bytearray(32),
                       output_length=48)

        self.assertEqual(bytearray(
            b'I\xcf\xae\xe5[\x86\x92\xd3\xbbm\xd6\xeekSo/' +
            b'\x17\xaf\xbc\x84\x18\tGc\xbc\xb5\xbe\xd6\xb0\x05\xad\xf8' +
            b'\x88\xd0`\xe4\x8c^\xb2&ls\xcb\x1a=-Kh'
            ), ret)
        self.assertEqual(48, len(ret))

class TestCalcExtendedMasterSecret(unittest.TestCase):
    def setUp(self):
        self.handshakeHashes = HandshakeHashes()
        self.handshakeHashes.update(bytearray(48))

    def test_with_TLS_1_0(self):
        ret = calc_key((3, 1), bytearray(48), 0,
                       b"extended master secret",
                       handshake_hashes=self.handshakeHashes,
                       output_length=48)
        self.assertEqual(ret, bytearray(
            b'/\xe9\x86\xda\xda\xa9)\x1eyJ\xc9\x13E\xe4\xfc\xe7\x842m7(\xb4'
            b'\x98\xb7\xbc\xa5\xda\x1d\xf3\x15\xea\xdf:i\xeb\x9bA\x8f\xe7'
            b'\xd4<\xe0\xe8\x1d\xa0\xf0\x10\x83'
            ))

    def test_with_TLS_1_2(self):
        ret = calc_key((3, 3), bytearray(48), 0,
                       b"extended master secret",
                       handshake_hashes=self.handshakeHashes,
                       output_length=48)
        self.assertEqual(ret, bytearray(
            b'\x03\xc93Yx\xcbjSEmz*\x0b\xc3\xc04G\xf3\xe3{\xee\x13\x8b\xac'
            b'\xd7\xb7\xe6\xbaY\x86\xd5\xf2o?\x8f\xc6\xf2\x19\x1d\x06\xe0N'
            b'\xb5\xcaJX\xe8\x1d'
            ))

    def test_with_TLS_1_2_and_SHA384_PRF(self):
        ret = calc_key((3, 3), bytearray(48),
                       CipherSuite.
                       TLS_RSA_WITH_AES_256_GCM_SHA384,
                       b"extended master secret",
                       handshake_hashes=self.handshakeHashes,
                       output_length=48)
        self.assertEqual(ret, bytearray(
            b"\xd6\xed}K\xfbo\xb2\xdb\xa4\xee\xa1\x0f\x8f\x07*\x84w/\xbf_"
            b"\xbd\xc1U^\x93\xcf\xe8\xca\x82\xb7_B\xa3O\xd9V\x86\x12\xfd\x08"
            b"$\x92\'L\xae\xc0@\x01"
            ))

class TestPRF1_2(unittest.TestCase):
    def test_with_bogus_values(self):
        ret = PRF_1_2(bytearray(1), b"key expansion", bytearray(1), 10)

        self.assertEqual(bytearray(b'\xaa2\xca\r\x8b\x85N\xad?\xab'), ret)

    def test_with_realistic_values(self):
        ret = PRF_1_2(bytearray(48), b"key expansion", bytearray(64), 16)

        self.assertEqual(bytearray(b'S\xb5\xdb\xc8T }u)BxuB\xe4\xeb\xeb'), ret)

class TestCalcFinished(unittest.TestCase):
    def setUp(self):
        self.hhashes = HandshakeHashes()
        self.hhashes.update(bytearray(10))

class TestCalcFinishedInSSL3(TestCalcFinished):
    def setUp(self):
        super(TestCalcFinishedInSSL3, self).setUp()

        self.finished = calc_key((3, 0), bytearray(48), 0, b"client finished",
                                 handshake_hashes=self.hhashes,
                                 output_length=12)
    def test_client_value(self):
        self.assertEqual(bytearray(
            b'\x15\xa9\xd7\xf1\x8bV\xecY\xab\xee\xbaS\x9c}\xffW\xa0'+
            b'\xa8\\q\xe5x8"\xf4\xedp\xabl\x8aV\xd9G\xab\x0fz'),
            self.finished)

    def test_server_value(self):
        ret = calc_key((3, 0), bytearray(48), 0, b"server finished",
                       handshake_hashes=self.hhashes,
                       output_length=12)

        self.assertEqual(bytearray(
            b'\xe3^aCb\x8a\xfc\x98\xbf\xd7\x08\xddX\xdc[\xeac\x02\xdb'+
            b'\x9b\x8aN\xed\xed\xaaZ\xcb\xda"\x87K\xff\x89m\xa9/'),
            ret)

    def test_if_multiple_runs_are_the_same(self):
        ret2 = calc_key((3, 0), bytearray(48), 0, b"client finished",
                        handshake_hashes=self.hhashes,
                        output_length=12)

        self.assertEqual(self.finished, ret2)

    def test_if_client_and_server_values_differ(self):
        ret_srv = calc_key((3, 0), bytearray(48), 0, b"server finished",
                           handshake_hashes=self.hhashes,
                           output_length=12)

        self.assertNotEqual(self.finished, ret_srv)

class TestCalcFinishedInTLS1_0(TestCalcFinished):
    def setUp(self):
        super(TestCalcFinishedInTLS1_0, self).setUp()

        self.finished = calc_key((3, 1), bytearray(48), 0, b"client finished",
                                 handshake_hashes=self.hhashes,
                                 output_length=12)

    def test_client_value(self):
        self.assertEqual(12, len(self.finished))
        self.assertEqual(bytearray(
            b'\xf8N\x8a\x8dx\xb8\xfe\x9e1\x0b\x8a#'),
            self.finished)

    def test_server_value(self):
        ret_srv = calc_key((3, 1), bytearray(48), 0, b"server finished",
                           handshake_hashes=self.hhashes,
                           output_length=12)

        self.assertEqual(12, len(ret_srv))
        self.assertEqual(bytearray(
            b'kYB\xce \x7f\xbb\xee\xe5\xe7<\x9d'),
            ret_srv)

    def test_if_client_and_server_values_differ(self):
        ret_srv = calc_key((3, 1), bytearray(48), 0, b"server finished",
                           handshake_hashes=self.hhashes,
                           output_length=12)

        self.assertNotEqual(self.finished, ret_srv)

    def test_if_values_for_TLS1_0_and_TLS1_0_are_same(self):
        ret = calc_key((3, 2), bytearray(48), 0, b"client finished",
                       handshake_hashes=self.hhashes,
                       output_length=12)

        self.assertEqual(self.finished, ret)

class TestCalcFinishedInTLS1_2WithSHA256(TestCalcFinished):
    def setUp(self):
        super(TestCalcFinishedInTLS1_2WithSHA256, self).setUp()

        self.finished = calc_key((3, 3), bytearray(48), 0, b"client finished",
                                 handshake_hashes=self.hhashes,
                                 output_length=12)

    def test_client_value(self):
        self.assertEqual(12, len(self.finished))
        self.assertEqual(bytearray(
            b'\x8e\x8c~\x03lU$S\x9fz\\\xcc'),
            self.finished)

    def test_server_value(self):
        ret_srv = calc_key((3, 3), bytearray(48), 0, b"server finished",
                           handshake_hashes=self.hhashes,
                           output_length=12)

        self.assertEqual(12, len(self.finished))
        self.assertEqual(bytearray(
            b'\xa8\xf1\xdf8s|\xedU\\Z=U'),
            ret_srv)

    def test_if_client_and_server_values_differ(self):
       ret_srv = calc_key((3, 3), bytearray(48), 0, b"server finished",
                          handshake_hashes=self.hhashes,
                          output_length=12)

       self.assertNotEqual(ret_srv, self.finished)

class TestCalcFinishedInTLS1_2WithSHA384(TestCalcFinished):
    def setUp(self):
        super(TestCalcFinishedInTLS1_2WithSHA384, self).setUp()

        self.finished = calc_key((3, 3), bytearray(48),
                                 CipherSuite.TLS_RSA_WITH_AES_256_GCM_SHA384,
                                 b"client finished",
                                 handshake_hashes=self.hhashes,
                                 output_length=12)

    def test_client_value(self):
        self.assertEqual(12, len(self.finished))
        self.assertEqual(bytearray(
            b'UB\xeeq\x86\xa5\x88L \x04\x893'),
            self.finished)

    def test_server_value(self):
        ret_srv = calc_key((3, 3), bytearray(48),
                           CipherSuite.TLS_RSA_WITH_AES_256_GCM_SHA384,
                           b"server finished",
                           handshake_hashes=self.hhashes,
                           output_length=12)
        self.assertEqual(bytearray(
            b'\x02St\x13\xa8\xe6\xb6\xa2\x1c4\xff\xc5'),
            ret_srv)

    def test_if_client_and_server_values_differ(self):
        ret_srv = calc_key((3, 3), bytearray(48),
                           CipherSuite.TLS_RSA_WITH_AES_256_GCM_SHA384,
                           b"server finished",
                           handshake_hashes=self.hhashes,
                           output_length=12)
        self.assertNotEqual(self.finished, ret_srv)


class TestParamStrength(unittest.TestCase):
    def test_480(self):
        self.assertEqual(48, paramStrength(2**480))

    def test_512(self):
        self.assertEqual(56, paramStrength(2**512))

    def test_768(self):
        self.assertEqual(64, paramStrength(2**768))

    def test_900(self):
        self.assertEqual(72, paramStrength(2**900))

    def test_1024(self):
        self.assertEqual(80, paramStrength(2**1024))

    def test_1536(self):
        self.assertEqual(88, paramStrength(2**1536))

    def test_2048(self):
        self.assertEqual(112, paramStrength(2**2048))

    def test_3072(self):
        self.assertEqual(128, paramStrength(2**3072))

    def test_4096(self):
        self.assertEqual(152, paramStrength(2**4096))

    def test_6144(self):
        self.assertEqual(168, paramStrength(2**6144))

    def test_7680(self):
        self.assertEqual(192, paramStrength(2**7680))

    def test_8192(self):
        self.assertEqual(192, paramStrength(2**8192))

    def test_15360(self):
        self.assertEqual(256, paramStrength(2**15360))

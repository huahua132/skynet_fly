# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest

from tlslite.utils.cryptomath import m2cryptoLoaded
from tlslite.utils.rijndael import Rijndael
from tlslite.utils.aesccm import AESCCM
from tlslite.utils import openssl_aesccm
from tlslite.utils.cipherfactory import createAESCCM, createAESCCM_8


class TestAESCCM(unittest.TestCase):

    @classmethod
    def setUpClass(self):
        if m2cryptoLoaded:
            self.defaultimpl = "openssl"
        else:
            self.defaultimpl = "python"

    def test___init__128(self):
        key = bytearray(16)
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt)

        self.assertIsNotNone(aesCCM)
        self.assertEqual(aesCCM.name, "aes128ccm")

    def test___init__128_8(self):
        key = bytearray(16)
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt, 8)

        self.assertIsNotNone(aesCCM)
        self.assertEqual(aesCCM.name, "aes128ccm_8")

    def test___init__256(self):
        key = bytearray(32)
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt)

        self.assertIsNotNone(aesCCM)
        self.assertEqual(aesCCM.name, "aes256ccm")

    def test___init__256_8(self):
        key = bytearray(32)
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt, 8)

        self.assertIsNotNone(aesCCM)
        self.assertEqual(aesCCM.name, "aes256ccm_8")

    def test___init___with_invalid_key(self):
        key = bytearray(8)

        with self.assertRaises(AssertionError):
            aesCCM = AESCCM(key, "python", Rijndael(bytearray(16), 16).encrypt)

    def test_default_implementation(self):
        key = bytearray(16)

        aesCCM = createAESCCM(key) 
        self.assertEqual(aesCCM.implementation, self.defaultimpl)

    def test_default_implementation_small_tag(self):
        key = bytearray(16)

        aesCCM = createAESCCM_8(key) 
        self.assertEqual(aesCCM.implementation, self.defaultimpl)

    def test_seal(self):
        key = bytearray(b'\x01'*16)
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x02'*12)

        plaintext = bytearray(b'text to encrypt.')
        self.assertEqual(len(plaintext), 16)

        encData = aesCCM.seal(nonce, plaintext, bytearray(0))

        self.assertEqual(bytearray(b'%}Q.\x99\xa3\r\xae\xcbMc\xf2\x16,^\xff'
                                   b'\xa0I\x8e\xf9\xc9F>\xbf\xa4\x00Y\x02p'
                                   b'\xe3\xb8\xa2'), encData)

    def test_seal_256(self):
        key = bytearray(b'\x01'*32)
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x02'*12)

        plaintext = bytearray(b'text to encrypt.')
        self.assertEqual(len(plaintext), 16)

        encData = aesCCM.seal(nonce, plaintext, bytearray(0))

        self.assertEqual(bytearray(b'IN\x1c\x06\xb8\x0b9SD<\xf8RL'
                                   b'\xb4,=\xd6&d\xae^1\xf8\xbf'
                                   b'\xfa8D\x98\xdd\x14\xb51'), encData)

    def test_seal_small_tag(self):
        key = bytearray(b'\x01'*16)
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt, 8)

        nonce = bytearray(b'\x02'*12)

        plaintext = bytearray(b'text to encrypt.')
        self.assertEqual(len(plaintext), 16)

        encData = aesCCM.seal(nonce, plaintext, bytearray(0))

        self.assertEqual(bytearray(b'%}Q.\x99\xa3\r\xae\xcbMc\xf2\x16,^\xff'
                                   b'\x14\xb8-?\x7f\xac\x8bI'), encData)

    def test_seal_256_small_tag(self):
        key = bytearray(b'\x01'*32)
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt, 8)

        nonce = bytearray(b'\x02'*12)

        plaintext = bytearray(b'text to encrypt.')
        self.assertEqual(len(plaintext), 16)

        encData = aesCCM.seal(nonce, plaintext, bytearray(0))

        self.assertEqual(bytearray(b'IN\x1c\x06\xb8\x0b9SD<\xf8RL'
                                   b'\xb4,=\xa2\x91\x84j1*\x0f\xeb'), encData)

    def test_seal_with_invalid_nonce(self):
        key = bytearray(b'\x01'*16)
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x02'*11)

        plaintext = bytearray(b'text to encrypt.')
        self.assertEqual(len(plaintext), 16)

        with self.assertRaises(ValueError) as err:
            aesCCM.seal(nonce, plaintext, bytearray(0))
        self.assertEqual("Bad nonce length", str(err.exception))

    def test_open(self):
        key = bytearray(b'\x01'*16)
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x02'*12)

        ciphertext = bytearray(b'%}Q.\x99\xa3\r\xae\xcbMc\xf2\x16,^\xff\xa0I'
                               b'\x8e\xf9\xc9F>\xbf\xa4\x00Y\x02p\xe3\xb8\xa2')

        plaintext = aesCCM.open(nonce, ciphertext, bytearray(0))

        self.assertEqual(plaintext, bytearray(b'text to encrypt.'))

    def test_open_256(self):
        key = bytearray(b'\x01'*32)
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x02'*12)

        ciphertext = bytearray(b'IN\x1c\x06\xb8\x0b9SD<\xf8RL'
                               b'\xb4,=\xd6&d\xae^1\xf8\xbf'
                               b'\xfa8D\x98\xdd\x14\xb51')

        plaintext = aesCCM.open(nonce, ciphertext, bytearray(0))

        self.assertEqual(plaintext, bytearray(b'text to encrypt.'))

    def test_open_small_tag(self):
        key = bytearray(b'\x01'*16)
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt, 8)

        nonce = bytearray(b'\x02'*12)

        ciphertext = bytearray(b'%}Q.\x99\xa3\r\xae\xcbMc\xf2\x16,^\xff\x14'
                               b'\xb8-?\x7f\xac\x8bI')

        plaintext = aesCCM.open(nonce, ciphertext, bytearray(0))

        self.assertEqual(plaintext, bytearray(b'text to encrypt.'))

    def test_open_256_small_tag(self):
        key = bytearray(b'\x01'*32)
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt, 8)

        nonce = bytearray(b'\x02'*12)

        ciphertext = bytearray(b'IN\x1c\x06\xb8\x0b9SD<\xf8RL'
                               b'\xb4,=\xa2\x91\x84j1*\x0f\xeb')
        plaintext = aesCCM.open(nonce, ciphertext, bytearray(0))

        self.assertEqual(plaintext, bytearray(b'text to encrypt.'))

    def test_open_with_incorrect_key(self):
        key = bytearray(b'\x01'*15 + b'\x00')
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x02'*12)

        ciphertext = bytearray(
            b'\'\x81h\x17\xe6Z)\\\xf2\x8emF\xcb\x91\x0eu'
            b'z1:\xf6}\xa7\\@\xba\x11\xd8r\xdf#K\xd4')

        plaintext = aesCCM.open(nonce, ciphertext, bytearray(0))

        self.assertIsNone(plaintext)

    def test_open_with_incorrect_nonce(self):
        key = bytearray(b'\x01'*16)
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x02'*11 + b'\x01')

        ciphertext = bytearray(
            b'\'\x81h\x17\xe6Z)\\\xf2\x8emF\xcb\x91\x0eu'
            b'z1:\xf6}\xa7\\@\xba\x11\xd8r\xdf#K\xd4')

        plaintext = aesCCM.open(nonce, ciphertext, bytearray(0))

        self.assertIsNone(plaintext)

    def test_open_with_invalid_nonce(self):
        key = bytearray(b'\x01'*16)
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x02'*11)

        ciphertext = bytearray(
            b'\'\x81h\x17\xe6Z)\\\xf2\x8emF\xcb\x91\x0eu'
            b'z1:\xf6}\xa7\\@\xba\x11\xd8r\xdf#K\xd4')

        with self.assertRaises(ValueError) as err:
            aesCCM.open(nonce, ciphertext, bytearray(0))
        self.assertEqual("Bad nonce length", str(err.exception))

    def test_open_with_invalid_ciphertext(self):
        key = bytearray(b'\x01'*16)
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x02'*12)

        ciphertext = bytearray(
            b'\xff'*15)

        self.assertIsNone(aesCCM.open(nonce, ciphertext, bytearray(0)))

    def test_seal_with_test_vector_1(self):
        key = bytearray(b'\x00'*16)
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x00'*12)

        plaintext = bytearray(b'')
        self.assertEqual(len(plaintext), 0)

        encData = aesCCM.seal(nonce, plaintext, bytearray(0))
        self.assertEqual(bytearray(b'\xb9\xf6P\xfb<9\xbb\x1b\xee\x0e)\x1d3'
                                   b'\xf6\xae('), encData)

    def test_seal_with_test_vector_2(self):
        key = bytearray(b'\x00'*16)
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x00'*12)

        plaintext = bytearray(b'\x00'*16)
        self.assertEqual(len(plaintext), 16)

        encData = aesCCM.seal(nonce, plaintext, bytearray(0))

        self.assertEqual(bytearray(b'n\xc7_\xb2\xe2\xb4\x87F\x1e\xdd\xcb\xb8'
                                   b'\x97\x11\x92\xbaMO\xa3\xaf\x0b\xf6\xd3E'
                                   b'Aq0o\xfa\xdd\x9a\xfd'), encData)

    def test_seal_with_test_vector_3(self):
        key = bytearray(b'\xfe\xff\xe9\x92\x86\x65\x73\x1c'
                        b'\x6d\x6a\x8f\x94\x67\x30\x83\x08')
        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\xca\xfe\xba\xbe\xfa\xce\xdb\xad\xde\xca\xf8\x88')

        plaintext = bytearray(b'\xd9\x31\x32\x25\xf8\x84\x06\xe5'
                              b'\xa5\x59\x09\xc5\xaf\xf5\x26\x9a'
                              b'\x86\xa7\xa9\x53\x15\x34\xf7\xda'
                              b'\x2e\x4c\x30\x3d\x8a\x31\x8a\x72'
                              b'\x1c\x3c\x0c\x95\x95\x68\x09\x53'
                              b'\x2f\xcf\x0e\x24\x49\xa6\xb5\x25'
                              b'\xb1\x6a\xed\xf5\xaa\x0d\xe6\x57'
                              b'\xba\x63\x7b\x39\x1a\xaf\xd2\x55')

        self.assertEqual(len(plaintext), 4*16)

        encData = aesCCM.seal(nonce, plaintext, bytearray(0))

        self.assertEqual(bytearray(b"\x08\x93\xe9K\x91H\x80\x1a\xf0\xf74&"
                                   b"\xab\xb0\x0e<\xa4\x9b\xf0\x9dy\xa2"
                                   b"\x01\'\xa7\xeb\x19&\xfa\x89\x057\x87"
                                   b"\xff\x02\xd0}q\x81;\x88[\x85\xe7\xf9"
                                   b"lN\xed\xf4 \xdb\x12j\x04Q\xce\x13\xbdA"
                                   b"\xba\x01\x8d\x1b\xa7\xfc\xece\x99Dg\xa7"
                                   b"{\x8b&B\xde\x91,\x01."), encData)

    def test_seal_with_test_vector_4(self):
        key = bytearray(b'\xfe\xff\xe9\x92\x86\x65\x73\x1c' +
                        b'\x6d\x6a\x8f\x94\x67\x30\x83\x08')

        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\xca\xfe\xba\xbe\xfa\xce\xdb\xad\xde\xca\xf8\x88')

        plaintext = bytearray(b'\xd9\x31\x32\x25\xf8\x84\x06\xe5'
                              b'\xa5\x59\x09\xc5\xaf\xf5\x26\x9a'
                              b'\x86\xa7\xa9\x53\x15\x34\xf7\xda'
                              b'\x2e\x4c\x30\x3d\x8a\x31\x8a\x72'
                              b'\x1c\x3c\x0c\x95\x95\x68\x09\x53'
                              b'\x2f\xcf\x0e\x24\x49\xa6\xb5\x25'
                              b'\xb1\x6a\xed\xf5\xaa\x0d\xe6\x57'
                              b'\xba\x63\x7b\x39')

        data = bytearray(b'\xfe\xed\xfa\xce\xde\xad\xbe\xef'
                         b'\xfe\xed\xfa\xce\xde\xad\xbe\xef'
                         b'\xab\xad\xda\xd2')

        encData = aesCCM.seal(nonce, plaintext, data)

        self.assertEqual(bytearray(b'\x08\x93\xe9K\x91H\x80\x1a\xf0\xf74&\xab'
                                   b'\xb0\x0e<\xa4\x9b\xf0\x9dy\xa2\x01\'\xa7'
                                   b'\xeb\x19&\xfa\x89\x057\x87\xff\x02\xd0}q'
                                   b'\x81;\x88[\x85\xe7\xf9lN\xed\xf4 \xdb'
                                   b'\x12j\x04Q\xce\x13\xbdA\xba\x028\xc3&'
                                   b'\xb4{4\xf7\x8fe\x9eu'
                                   b'\x10\x96\xcd"'), encData)

    def test_seal_with_test_vector_5(self):
        key = bytearray(32)

        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(12)
        plaintext = bytearray(0)
        data = bytearray(0)

        encData = aesCCM.seal(nonce, plaintext, data)

        self.assertEqual(bytearray(b'\xa8\x90&^C\xa2hU\xf2i'
                                   b'\xb9?\xf4\xdd\xde\xf6'), encData)

    def test_seal_with_test_vector_6(self):
        key = bytearray(32)

        aesCCM = AESCCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(12)
        plaintext = bytearray(16)
        data = bytearray(0)

        encData = aesCCM.seal(nonce, plaintext, data)

        self.assertEqual(bytearray(b'\xc1\x94@D\xc8\xe7\xaa\x95\xd2\xde\x95'
                                   b'\x13\xc7\xf3\xdd\x8cK\n>^Q\xf1Q\xeb\x0f'
                                   b'\xfa\xe7\xc4=\x01\x0f\xdb'), encData)

    @unittest.skipUnless(m2cryptoLoaded, "requires M2Crypto")
    def test_seal_with_test_vector_1_openssl(self):
        key = bytearray(b'\x00'*16)
        aesCCM = openssl_aesccm.new(key)

        nonce = bytearray(b'\x00'*12)

        plaintext = bytearray(b'')
        self.assertEqual(len(plaintext), 0)

        encData = aesCCM.seal(nonce, plaintext, bytearray(0))
        self.assertEqual(bytearray(b'\xb9\xf6P\xfb<9\xbb\x1b\xee\x0e)\x1d3'
                                   b'\xf6\xae('), encData)

    @unittest.skipUnless(m2cryptoLoaded, "requires M2Crypto")
    def test_seal_with_test_vector_2_openssl(self):
        key = bytearray(b'\x00'*16)
        aesCCM = openssl_aesccm.new(key)

        nonce = bytearray(b'\x00'*12)

        plaintext = bytearray(b'\x00'*16)
        self.assertEqual(len(plaintext), 16)

        encData = aesCCM.seal(nonce, plaintext, bytearray(0))

        self.assertEqual(bytearray(b'n\xc7_\xb2\xe2\xb4\x87F\x1e\xdd\xcb\xb8'
                                   b'\x97\x11\x92\xbaMO\xa3\xaf\x0b\xf6\xd3E'
                                   b'Aq0o\xfa\xdd\x9a\xfd'), encData)

    @unittest.skipUnless(m2cryptoLoaded, "requires M2Crypto")
    def test_seal_with_test_vector_3_openssl(self):
        key = bytearray(b'\xfe\xff\xe9\x92\x86\x65\x73\x1c'
                        b'\x6d\x6a\x8f\x94\x67\x30\x83\x08')
        aesCCM = openssl_aesccm.new(key)

        nonce = bytearray(b'\xca\xfe\xba\xbe\xfa\xce\xdb\xad\xde\xca\xf8\x88')

        plaintext = bytearray(b'\xd9\x31\x32\x25\xf8\x84\x06\xe5'
                              b'\xa5\x59\x09\xc5\xaf\xf5\x26\x9a'
                              b'\x86\xa7\xa9\x53\x15\x34\xf7\xda'
                              b'\x2e\x4c\x30\x3d\x8a\x31\x8a\x72'
                              b'\x1c\x3c\x0c\x95\x95\x68\x09\x53'
                              b'\x2f\xcf\x0e\x24\x49\xa6\xb5\x25'
                              b'\xb1\x6a\xed\xf5\xaa\x0d\xe6\x57'
                              b'\xba\x63\x7b\x39\x1a\xaf\xd2\x55')

        self.assertEqual(len(plaintext), 4*16)

        encData = aesCCM.seal(nonce, plaintext, bytearray(0))

        self.assertEqual(bytearray(b"\x08\x93\xe9K\x91H\x80\x1a\xf0\xf74&"
                                   b"\xab\xb0\x0e<\xa4\x9b\xf0\x9dy\xa2"
                                   b"\x01\'\xa7\xeb\x19&\xfa\x89\x057\x87"
                                   b"\xff\x02\xd0}q\x81;\x88[\x85\xe7\xf9"
                                   b"lN\xed\xf4 \xdb\x12j\x04Q\xce\x13\xbdA"
                                   b"\xba\x01\x8d\x1b\xa7\xfc\xece\x99Dg\xa7"
                                   b"{\x8b&B\xde\x91,\x01."), encData)

    @unittest.skipUnless(m2cryptoLoaded, "requires M2Crypto")
    def test_seal_with_test_vector_4_openssl(self):
        key = bytearray(b'\xfe\xff\xe9\x92\x86\x65\x73\x1c' +
                        b'\x6d\x6a\x8f\x94\x67\x30\x83\x08')
        aesCCM = openssl_aesccm.new(key)

        nonce = bytearray(b'\xca\xfe\xba\xbe\xfa\xce\xdb\xad\xde\xca\xf8\x88')

        plaintext = bytearray(b'\xd9\x31\x32\x25\xf8\x84\x06\xe5'
                              b'\xa5\x59\x09\xc5\xaf\xf5\x26\x9a'
                              b'\x86\xa7\xa9\x53\x15\x34\xf7\xda'
                              b'\x2e\x4c\x30\x3d\x8a\x31\x8a\x72'
                              b'\x1c\x3c\x0c\x95\x95\x68\x09\x53'
                              b'\x2f\xcf\x0e\x24\x49\xa6\xb5\x25'
                              b'\xb1\x6a\xed\xf5\xaa\x0d\xe6\x57'
                              b'\xba\x63\x7b\x39')

        data = bytearray(b'\xfe\xed\xfa\xce\xde\xad\xbe\xef'
                         b'\xfe\xed\xfa\xce\xde\xad\xbe\xef'
                         b'\xab\xad\xda\xd2')

        encData = aesCCM.seal(nonce, plaintext, data)

        self.assertEqual(bytearray(b'\x08\x93\xe9K\x91H\x80\x1a\xf0\xf74&\xab'
                                   b'\xb0\x0e<\xa4\x9b\xf0\x9dy\xa2\x01\'\xa7'
                                   b'\xeb\x19&\xfa\x89\x057\x87\xff\x02\xd0}q'
                                   b'\x81;\x88[\x85\xe7\xf9lN\xed\xf4 \xdb'
                                   b'\x12j\x04Q\xce\x13\xbdA\xba\x028\xc3&'
                                   b'\xb4{4\xf7\x8fe\x9eu'
                                   b'\x10\x96\xcd"'), encData)

    @unittest.skipUnless(m2cryptoLoaded, "requires M2Crypto")
    def test_seal_with_test_vector_5_openssl(self):
        key = bytearray(32)

        aesCCM = openssl_aesccm.new(key)

        nonce = bytearray(12)
        plaintext = bytearray(0)
        data = bytearray(0)

        encData = aesCCM.seal(nonce, plaintext, data)

        self.assertEqual(bytearray(b'\xa8\x90&^C\xa2hU\xf2i'
                                   b'\xb9?\xf4\xdd\xde\xf6'), encData)
    @unittest.skipUnless(m2cryptoLoaded, "requires M2Crypto")
    def test_seal_with_test_vector_6_openssl(self):
        key = bytearray(32)

        aesCCM = openssl_aesccm.new(key)

        nonce = bytearray(12)
        plaintext = bytearray(16)
        data = bytearray(0)

        encData = aesCCM.seal(nonce, plaintext, data)

        self.assertEqual(bytearray(b'\xc1\x94@D\xc8\xe7\xaa\x95\xd2\xde\x95'
                                   b'\x13\xc7\xf3\xdd\x8cK\n>^Q\xf1Q\xeb\x0f'
                                   b'\xfa\xe7\xc4=\x01\x0f\xdb'), encData)


class TestAESCCMIdentical(unittest.TestCase):
    @classmethod
    def setUpClass(self):
        self.plaintext = bytearray(b'\x6b\xc1\xbe\xe2\x2e\x40\x9f'
                                   b'\x96\xe9\x3d\x7e\x11\x73\x93'
                                   b'\x17\x2a\xae\x2d\x8a\x57\x1e'
                                   b'\x03\xac\x9c\x9e\xb7\x6f\xac'
                                   b'\x45\xaf\x8e\x51\x30\xc8\x1c'
                                   b'\x46\xa3\x5c\xe4\x11\xe5\xfb'
                                   b'\xc1\x19\x1a\x0a\x52\xef\xf6'
                                   b'\x9f\x24\x45\xdf\x4f\x9b\x17'
                                   b'\xad\x2b\x41\x7b\xe6\x6c\x37\x10')

        self.ciphertext = bytearray(b'\xbace\x8cG\x8c\x19i\xbc\x93C\xf2w\xd6?'
                                    b'\x8c\x8c\x11\xd3\x99r\x95Za\x17\x10F'
                                    b'\xb75\x17\x01\x14\xab\x0b\x12\x03KElyBoJ'
                                    b'\xda\xaa\xc0\xa9\'\xb3\xd5\x12\xa2\x1fF,'
                                    b'\x8e\x04\xf5{\xf8\xfdN\xfe\xe2\xe9x\xfe1'
                                    b'\x175\xa6\xc4\\Q3\x80\xf4\xcaR\x8c')

        self.ciphertext_8 = bytearray(b'\xbace\x8cG\x8c\x19i\xbc\x93C\xf2w'
                                      b'\xd6?\x8c\x8c\x11\xd3\x99r\x95Za'
                                      b'\x17\x10F\xb75\x17\x01\x14\xab\x0b'
                                      b'\x12\x03KElyBoJ\xda\xaa\xc0\xa9\'\xb3'
                                      b'\xd5\x12\xa2\x1fF,\x8e\x04\xf5{\xf8'
                                      b'\xfdN\xfe\xe2\x1f\xae\xeb\xcb:\xb2/\xd0')

        self.key = bytearray(b'\xfe\xff\xe9\x92\x86\x65\x73\x1c'
                             b'\x6d\x6a\x8f\x94\x67\x30\x83\x08')

        self.nonce = bytearray(b'\xca\xfe\xba\xbe\xfa\xce\xdb\xad\xde\xca\xf8\x88')

        self.data = bytearray(b'\xfe\xed\xfa\xce\xde\xad\xbe\xef'
                              b'\xfe\xed\xfa\xce\xde\xad\xbe\xef'
                              b'\xab\xad\xda\xd2')

    def test_seal_identical_messages_python(self):

        aesCCM = AESCCM(self.key, "python", Rijndael(self.key, 16).encrypt)

        for _ in range(2):
            encData = aesCCM.seal(self.nonce, self.plaintext, self.data)
            self.assertEqual(self.ciphertext, encData)

    def test_open_identical_messages_python(self):

        aesCCM = AESCCM(self.key, "python", Rijndael(self.key, 16).encrypt)

        for _ in range(2):
            decData = aesCCM.open(self.nonce, self.ciphertext, self.data)
            self.assertEqual(self.plaintext, decData)

    def test_seal_identical_messages_8_python(self):

        aesCCM = AESCCM(self.key, "python", Rijndael(self.key, 16).encrypt, 8)

        for _ in range(2):
            encData = aesCCM.seal(self.nonce, self.plaintext, self.data)
            self.assertEqual(self.ciphertext_8, encData)

    def test_open_identical_messages_8_python(self):

        aesCCM = AESCCM(self.key, "python", Rijndael(self.key, 16).encrypt, 8)

        for _ in range(2):
            decData = aesCCM.open(self.nonce, self.ciphertext_8, self.data)
            self.assertEqual(self.plaintext, decData)

    @unittest.skipUnless(m2cryptoLoaded, "requires M2Crypto")
    def test_seal_identical_messages_openssl(self):

        aesCCM = openssl_aesccm.new(self.key)

        for _ in range(2):
            encData = aesCCM.seal(self.nonce, self.plaintext, self.data)
            self.assertEqual(self.ciphertext, encData)

    @unittest.skipUnless(m2cryptoLoaded, "requires M2Crypto")
    def test_open_identical_messages_openssl(self):

        aesCCM = openssl_aesccm.new(self.key)

        for _ in range(2):
            decData = aesCCM.open(self.nonce, self.ciphertext, self.data)
            self.assertEqual(self.plaintext, decData)

    @unittest.skipUnless(m2cryptoLoaded, "requires M2Crypto")
    def test_seal_identical_messages_8_openssl(self):

        aesCCM = openssl_aesccm.new(self.key, 8)

        for _ in range(2):
            encData = aesCCM.seal(self.nonce, self.plaintext, self.data)
            self.assertEqual(self.ciphertext_8, encData)

    @unittest.skipUnless(m2cryptoLoaded, "requires M2Crypto")
    def test_open_identical_messages_8_openssl(self):

        aesCCM = openssl_aesccm.new(self.key, 8)

        for _ in range(2):
            decData = aesCCM.open(self.nonce, self.ciphertext_8, self.data)
            self.assertEqual(self.plaintext, decData)

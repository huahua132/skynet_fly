# Copyright (c) 2014, Hubert Kario
#
# See the LICENSE file for legal information regarding use of this file.

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
        import unittest2 as unittest
except ImportError:
        import unittest

from tlslite.utils.cryptomath import *
from tlslite.utils.rijndael import Rijndael
from tlslite.utils.aesgcm import AESGCM
from tlslite.utils import openssl_aesgcm

class TestAESGCM(unittest.TestCase):
    def test___init__(self):
        key = bytearray(16)
        aesGCM = AESGCM(key, "python", Rijndael(key, 16).encrypt)

        self.assertIsNotNone(aesGCM)

    def test___init___with_invalid_key(self):
        key = bytearray(8)

        with self.assertRaises(AssertionError):
            aesGCM = AESGCM(key, "python", Rijndael(bytearray(16), 16).encrypt)

    def test_seal(self):
        key = bytearray(b'\x01'*16)
        aesGCM = AESGCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x02'*12)

        plaintext = bytearray(b'text to encrypt.')
        self.assertEqual(len(plaintext), 16)

        encData = aesGCM.seal(nonce, plaintext, bytearray(0))

        self.assertEqual(bytearray(
            b'\'\x81h\x17\xe6Z)\\\xf2\x8emF\xcb\x91\x0eu'
            b'z1:\xf6}\xa7\\@\xba\x11\xd8r\xdf#K\xd4'), encData)

    def test_seal_with_invalid_nonce(self):
        key = bytearray(b'\x01'*16)
        aesGCM = AESGCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x02'*11)

        plaintext = bytearray(b'text to encrypt.')
        self.assertEqual(len(plaintext), 16)

        with self.assertRaises(ValueError):
            aesGCM.seal(nonce, plaintext, bytearray(0))

    def test_open(self):
        key = bytearray(b'\x01'*16)
        aesGCM = AESGCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x02'*12)

        ciphertext = bytearray(
            b'\'\x81h\x17\xe6Z)\\\xf2\x8emF\xcb\x91\x0eu'
            b'z1:\xf6}\xa7\\@\xba\x11\xd8r\xdf#K\xd4')

        plaintext = aesGCM.open(nonce, ciphertext, bytearray(0))

        self.assertEqual(plaintext, bytearray(b'text to encrypt.'))

    def test_open_with_incorrect_key(self):
        key = bytearray(b'\x01'*15 + b'\x00')
        aesGCM = AESGCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x02'*12)

        ciphertext = bytearray(
            b'\'\x81h\x17\xe6Z)\\\xf2\x8emF\xcb\x91\x0eu'
            b'z1:\xf6}\xa7\\@\xba\x11\xd8r\xdf#K\xd4')

        plaintext = aesGCM.open(nonce, ciphertext, bytearray(0))

        self.assertIsNone(plaintext)

    def test_open_with_incorrect_nonce(self):
        key = bytearray(b'\x01'*16)
        aesGCM = AESGCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x02'*11 + b'\x01')

        ciphertext = bytearray(
            b'\'\x81h\x17\xe6Z)\\\xf2\x8emF\xcb\x91\x0eu'
            b'z1:\xf6}\xa7\\@\xba\x11\xd8r\xdf#K\xd4')

        plaintext = aesGCM.open(nonce, ciphertext, bytearray(0))

        self.assertIsNone(plaintext)

    def test_open_with_invalid_nonce(self):
        key = bytearray(b'\x01'*16)
        aesGCM = AESGCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x02'*11)

        ciphertext = bytearray(
            b'\'\x81h\x17\xe6Z)\\\xf2\x8emF\xcb\x91\x0eu'
            b'z1:\xf6}\xa7\\@\xba\x11\xd8r\xdf#K\xd4')

        with self.assertRaises(ValueError):
            aesGCM.open(nonce, ciphertext, bytearray(0))

    def test_open_with_invalid_ciphertext(self):
        key = bytearray(b'\x01'*16)
        aesGCM = AESGCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x02'*12)

        ciphertext = bytearray(
            b'\xff'*15)

        self.assertIsNone(aesGCM.open(nonce, ciphertext, bytearray(0)))

    def test_seal_with_test_vector_1(self):
        key = bytearray(b'\x00'*16)
        aesGCM = AESGCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x00'*12)

        plaintext = bytearray(b'')
        self.assertEqual(len(plaintext), 0)

        encData = aesGCM.seal(nonce, plaintext, bytearray(0))

        self.assertEqual(bytearray(
            b'\x58\xe2\xfc\xce\xfa\x7e\x30\x61' +
            b'\x36\x7f\x1d\x57\xa4\xe7\x45\x5a'), encData)

    def test_seal_with_test_vector_2(self):
        key = bytearray(b'\x00'*16)
        aesGCM = AESGCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\x00'*12)

        plaintext = bytearray(b'\x00'*16)
        self.assertEqual(len(plaintext), 16)

        encData = aesGCM.seal(nonce, plaintext, bytearray(0))

        self.assertEqual(bytearray(
            b'\x03\x88\xda\xce\x60\xb6\xa3\x92' +
            b'\xf3\x28\xc2\xb9\x71\xb2\xfe\x78' +
            b'\xab\x6e\x47\xd4\x2c\xec\x13\xbd' +
            b'\xf5\x3a\x67\xb2\x12\x57\xbd\xdf'), encData)

    def test_seal_with_test_vector_3(self):
        key = bytearray(b'\xfe\xff\xe9\x92\x86\x65\x73\x1c' +
                        b'\x6d\x6a\x8f\x94\x67\x30\x83\x08')
        aesGCM = AESGCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\xca\xfe\xba\xbe\xfa\xce\xdb\xad\xde\xca\xf8\x88')

        plaintext = bytearray(b'\xd9\x31\x32\x25\xf8\x84\x06\xe5' +
                              b'\xa5\x59\x09\xc5\xaf\xf5\x26\x9a' +
                              b'\x86\xa7\xa9\x53\x15\x34\xf7\xda' +
                              b'\x2e\x4c\x30\x3d\x8a\x31\x8a\x72' +
                              b'\x1c\x3c\x0c\x95\x95\x68\x09\x53' +
                              b'\x2f\xcf\x0e\x24\x49\xa6\xb5\x25' +
                              b'\xb1\x6a\xed\xf5\xaa\x0d\xe6\x57' +
                              b'\xba\x63\x7b\x39\x1a\xaf\xd2\x55')

        self.assertEqual(len(plaintext), 4*16)

        encData = aesGCM.seal(nonce, plaintext, bytearray(0))

        self.assertEqual(bytearray(
            b'\x42\x83\x1e\xc2\x21\x77\x74\x24' +
            b'\x4b\x72\x21\xb7\x84\xd0\xd4\x9c' +
            b'\xe3\xaa\x21\x2f\x2c\x02\xa4\xe0' +
            b'\x35\xc1\x7e\x23\x29\xac\xa1\x2e' +
            b'\x21\xd5\x14\xb2\x54\x66\x93\x1c' +
            b'\x7d\x8f\x6a\x5a\xac\x84\xaa\x05' +
            b'\x1b\xa3\x0b\x39\x6a\x0a\xac\x97' +
            b'\x3d\x58\xe0\x91\x47\x3f\x59\x85' +
            b'\x4d\x5c\x2a\xf3\x27\xcd\x64\xa6' +
            b'\x2c\xf3\x5a\xbd\x2b\xa6\xfa\xb4'
            ), encData)

    def test_seal_with_test_vector_4(self):
        key = bytearray(b'\xfe\xff\xe9\x92\x86\x65\x73\x1c' +
                        b'\x6d\x6a\x8f\x94\x67\x30\x83\x08')

        aesGCM = AESGCM(key, "python", Rijndael(key, 16).encrypt)

        nonce = bytearray(b'\xca\xfe\xba\xbe\xfa\xce\xdb\xad\xde\xca\xf8\x88')

        plaintext = bytearray(b'\xd9\x31\x32\x25\xf8\x84\x06\xe5' +
                              b'\xa5\x59\x09\xc5\xaf\xf5\x26\x9a' +
                              b'\x86\xa7\xa9\x53\x15\x34\xf7\xda' +
                              b'\x2e\x4c\x30\x3d\x8a\x31\x8a\x72' +
                              b'\x1c\x3c\x0c\x95\x95\x68\x09\x53' +
                              b'\x2f\xcf\x0e\x24\x49\xa6\xb5\x25' +
                              b'\xb1\x6a\xed\xf5\xaa\x0d\xe6\x57' +
                              b'\xba\x63\x7b\x39')

        data = bytearray(b'\xfe\xed\xfa\xce\xde\xad\xbe\xef' +
                         b'\xfe\xed\xfa\xce\xde\xad\xbe\xef' +
                         b'\xab\xad\xda\xd2')

        encData = aesGCM.seal(nonce, plaintext, data)

        self.assertEqual(bytearray(
            b'\x42\x83\x1e\xc2\x21\x77\x74\x24' +
            b'\x4b\x72\x21\xb7\x84\xd0\xd4\x9c' +
            b'\xe3\xaa\x21\x2f\x2c\x02\xa4\xe0' +
            b'\x35\xc1\x7e\x23\x29\xac\xa1\x2e' +
            b'\x21\xd5\x14\xb2\x54\x66\x93\x1c' +
            b'\x7d\x8f\x6a\x5a\xac\x84\xaa\x05' +
            b'\x1b\xa3\x0b\x39\x6a\x0a\xac\x97' +
            b'\x3d\x58\xe0\x91' +
            b'\x5b\xc9\x4f\xbc\x32\x21\xa5\xdb' +
            b'\x94\xfa\xe9\x5a\xe7\x12\x1a\x47'), encData)

    def test_seal_with_test_vector_13(self):
        key = bytearray(32)

        aesGCM = AESGCM(key, "python", Rijndael(key, 16).encrypt)

        self.assertEqual(aesGCM.name, "aes256gcm")

        nonce = bytearray(12)
        data = bytearray(0)

        encData = aesGCM.seal(nonce, data, data)

        self.assertEqual(bytearray(
            b'\x53\x0f\x8a\xfb\xc7\x45\x36\xb9' +
            b'\xa9\x63\xb4\xf1\xc4\xcb\x73\x8b'
            ), encData)

    def test_seal_with_test_vector_14(self):
        key = bytearray(32)

        aesGCM = AESGCM(key, "python", Rijndael(key, 16).encrypt)

        self.assertEqual(aesGCM.name, "aes256gcm")

        nonce = bytearray(12)
        plaintext = bytearray(16)
        data = bytearray(0)

        encData = aesGCM.seal(nonce, plaintext, data)

        self.assertEqual(bytearray(
            b'\xce\xa7\x40\x3d\x4d\x60\x6b\x6e' +
            b'\x07\x4e\xc5\xd3\xba\xf3\x9d\x18' +
            b'\xd0\xd1\xc8\xa7\x99\x99\x6b\xf0' +
            b'\x26\x5b\x98\xb5\xd4\x8a\xb9\x19'
            ), encData)

    if m2cryptoLoaded:
        def test_seal_with_test_vector_1_openssl(self):
            key = bytearray(b'\x00'*16)
            aesGCM = openssl_aesgcm.new(key)

            nonce = bytearray(b'\x00'*12)

            plaintext = bytearray(b'')
            self.assertEqual(len(plaintext), 0)

            encData = aesGCM.seal(nonce, plaintext, bytearray(0))

            self.assertEqual(bytearray(
                b'\x58\xe2\xfc\xce\xfa\x7e\x30\x61' +
                b'\x36\x7f\x1d\x57\xa4\xe7\x45\x5a'), encData)

        def test_seal_with_test_vector_2_openssl(self):
            key = bytearray(b'\x00'*16)
            aesGCM = openssl_aesgcm.new(key)

            nonce = bytearray(b'\x00'*12)

            plaintext = bytearray(b'\x00'*16)
            self.assertEqual(len(plaintext), 16)

            encData = aesGCM.seal(nonce, plaintext, bytearray(0))

            self.assertEqual(bytearray(
                b'\x03\x88\xda\xce\x60\xb6\xa3\x92' +
                b'\xf3\x28\xc2\xb9\x71\xb2\xfe\x78' +
                b'\xab\x6e\x47\xd4\x2c\xec\x13\xbd' +
                b'\xf5\x3a\x67\xb2\x12\x57\xbd\xdf'), encData)

        def test_seal_with_test_vector_3_openssl(self):
            key = bytearray(b'\xfe\xff\xe9\x92\x86\x65\x73\x1c' +
                            b'\x6d\x6a\x8f\x94\x67\x30\x83\x08')
            aesGCM = openssl_aesgcm.new(key)

            nonce = bytearray(b'\xca\xfe\xba\xbe\xfa\xce\xdb\xad\xde\xca\xf8\x88')

            plaintext = bytearray(b'\xd9\x31\x32\x25\xf8\x84\x06\xe5' +
                                  b'\xa5\x59\x09\xc5\xaf\xf5\x26\x9a' +
                                  b'\x86\xa7\xa9\x53\x15\x34\xf7\xda' +
                                  b'\x2e\x4c\x30\x3d\x8a\x31\x8a\x72' +
                                  b'\x1c\x3c\x0c\x95\x95\x68\x09\x53' +
                                  b'\x2f\xcf\x0e\x24\x49\xa6\xb5\x25' +
                                  b'\xb1\x6a\xed\xf5\xaa\x0d\xe6\x57' +
                                  b'\xba\x63\x7b\x39\x1a\xaf\xd2\x55')

            self.assertEqual(len(plaintext), 4*16)

            encData = aesGCM.seal(nonce, plaintext, bytearray(0))

            self.assertEqual(bytearray(
                b'\x42\x83\x1e\xc2\x21\x77\x74\x24' +
                b'\x4b\x72\x21\xb7\x84\xd0\xd4\x9c' +
                b'\xe3\xaa\x21\x2f\x2c\x02\xa4\xe0' +
                b'\x35\xc1\x7e\x23\x29\xac\xa1\x2e' +
                b'\x21\xd5\x14\xb2\x54\x66\x93\x1c' +
                b'\x7d\x8f\x6a\x5a\xac\x84\xaa\x05' +
                b'\x1b\xa3\x0b\x39\x6a\x0a\xac\x97' +
                b'\x3d\x58\xe0\x91\x47\x3f\x59\x85' +
                b'\x4d\x5c\x2a\xf3\x27\xcd\x64\xa6' +
                b'\x2c\xf3\x5a\xbd\x2b\xa6\xfa\xb4'
                ), encData)

        def test_seal_with_test_vector_4_openssl(self):
            key = bytearray(b'\xfe\xff\xe9\x92\x86\x65\x73\x1c' +
                            b'\x6d\x6a\x8f\x94\x67\x30\x83\x08')

            aesGCM = openssl_aesgcm.new(key)

            nonce = bytearray(b'\xca\xfe\xba\xbe\xfa\xce\xdb\xad\xde\xca\xf8\x88')

            plaintext = bytearray(b'\xd9\x31\x32\x25\xf8\x84\x06\xe5' +
                                  b'\xa5\x59\x09\xc5\xaf\xf5\x26\x9a' +
                                  b'\x86\xa7\xa9\x53\x15\x34\xf7\xda' +
                                  b'\x2e\x4c\x30\x3d\x8a\x31\x8a\x72' +
                                  b'\x1c\x3c\x0c\x95\x95\x68\x09\x53' +
                                  b'\x2f\xcf\x0e\x24\x49\xa6\xb5\x25' +
                                  b'\xb1\x6a\xed\xf5\xaa\x0d\xe6\x57' +
                                  b'\xba\x63\x7b\x39')

            data = bytearray(b'\xfe\xed\xfa\xce\xde\xad\xbe\xef' +
                             b'\xfe\xed\xfa\xce\xde\xad\xbe\xef' +
                             b'\xab\xad\xda\xd2')

            encData = aesGCM.seal(nonce, plaintext, data)

            self.assertEqual(bytearray(
                b'\x42\x83\x1e\xc2\x21\x77\x74\x24' +
                b'\x4b\x72\x21\xb7\x84\xd0\xd4\x9c' +
                b'\xe3\xaa\x21\x2f\x2c\x02\xa4\xe0' +
                b'\x35\xc1\x7e\x23\x29\xac\xa1\x2e' +
                b'\x21\xd5\x14\xb2\x54\x66\x93\x1c' +
                b'\x7d\x8f\x6a\x5a\xac\x84\xaa\x05' +
                b'\x1b\xa3\x0b\x39\x6a\x0a\xac\x97' +
                b'\x3d\x58\xe0\x91' +
                b'\x5b\xc9\x4f\xbc\x32\x21\xa5\xdb' +
                b'\x94\xfa\xe9\x5a\xe7\x12\x1a\x47'), encData)

        def test_seal_with_test_vector_13_openssl(self):
            key = bytearray(32)

            aesGCM = openssl_aesgcm.new(key)

            self.assertEqual(aesGCM.name, "aes256gcm")

            nonce = bytearray(12)
            data = bytearray(0)

            encData = aesGCM.seal(nonce, data, data)

            self.assertEqual(bytearray(
                b'\x53\x0f\x8a\xfb\xc7\x45\x36\xb9' +
                b'\xa9\x63\xb4\xf1\xc4\xcb\x73\x8b'
                ), encData)

        def test_seal_with_test_vector_14_openssl(self):
            key = bytearray(32)

            aesGCM = openssl_aesgcm.new(key)

            self.assertEqual(aesGCM.name, "aes256gcm")

            nonce = bytearray(12)
            plaintext = bytearray(16)
            data = bytearray(0)

            encData = aesGCM.seal(nonce, plaintext, data)

            self.assertEqual(bytearray(
                b'\xce\xa7\x40\x3d\x4d\x60\x6b\x6e' +
                b'\x07\x4e\xc5\xd3\xba\xf3\x9d\x18' +
                b'\xd0\xd1\xc8\xa7\x99\x99\x6b\xf0' +
                b'\x26\x5b\x98\xb5\xd4\x8a\xb9\x19'
                ), encData)

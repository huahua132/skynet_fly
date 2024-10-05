# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest

from tlslite.utils.rijndael import Rijndael
from tlslite.utils.python_aes import Python_AES_CTR


class TestAESCTR(unittest.TestCase):
    def test___init__(self):
        key = bytearray(16)
        aesCTR = Python_AES_CTR(key, mode=6, IV=bytearray(b'\x00' * 12))

        self.assertIsNotNone(aesCTR)

    def test___init___with_invalid_key(self):
        key = bytearray(8)

        with self.assertRaises(AssertionError):
            aesCTR = Python_AES_CTR(key, mode=6, IV=bytearray(b'\x00' * 12))

    def test_encrypt_with_test_vector_1(self):

        key = bytearray(b'\x2b\x7e\x15\x16\x28\xae\xd2'
                        b'\xa6\xab\xf7\x15\x88\x09\xcf\x4f\x3c')

        plaintext = bytearray(b'\x6b\xc1\xbe\xe2\x2e\x40\x9f'
                              b'\x96\xe9\x3d\x7e\x11\x73\x93'
                              b'\x17\x2a\xae\x2d\x8a\x57\x1e'
                              b'\x03\xac\x9c\x9e\xb7\x6f\xac'
                              b'\x45\xaf\x8e\x51\x30\xc8\x1c'
                              b'\x46\xa3\x5c\xe4\x11\xe5\xfb'
                              b'\xc1\x19\x1a\x0a\x52\xef\xf6'
                              b'\x9f\x24\x45\xdf\x4f\x9b\x17'
                              b'\xad\x2b\x41\x7b\xe6\x6c\x37\x10')

        ciphertext = bytearray(b'\x87\x4d\x61\x91\xb6\x20\xe3'
                               b'\x26\x1b\xef\x68\x64\x99\x0d'
                               b'\xb6\xce\x98\x06\xf6\x6b\x79'
                               b'\x70\xfd\xff\x86\x17\x18\x7b'
                               b'\xb9\xff\xfd\xff\x5a\xe4\xdf'
                               b'\x3e\xdb\xd5\xd3\x5e\x5b\x4f'
                               b'\x09\x02\x0d\xb0\x3e\xab\x1e'
                               b'\x03\x1d\xda\x2f\xbe\x03\xd1'
                               b'\x79\x21\x70\xa0\xf3\x00\x9c\xee')

        counter = bytearray(b'\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8'
                            b'\xf9\xfa\xfb\xfc\xfd\xfe\xff')

        aesCTR = Python_AES_CTR(key, mode=6, IV=bytearray(b'\x00' * 12))
        aesCTR.counter = counter
        self.assertEqual(aesCTR.encrypt(plaintext), ciphertext)

    def test_decrypt_with_test_vector_1(self):

        key = bytearray(b'\x2b\x7e\x15\x16\x28\xae\xd2'
                        b'\xa6\xab\xf7\x15\x88\x09\xcf\x4f\x3c')

        plaintext = bytearray(b'\x6b\xc1\xbe\xe2\x2e\x40\x9f'
                              b'\x96\xe9\x3d\x7e\x11\x73\x93'
                              b'\x17\x2a\xae\x2d\x8a\x57\x1e'
                              b'\x03\xac\x9c\x9e\xb7\x6f\xac'
                              b'\x45\xaf\x8e\x51\x30\xc8\x1c'
                              b'\x46\xa3\x5c\xe4\x11\xe5\xfb'
                              b'\xc1\x19\x1a\x0a\x52\xef\xf6'
                              b'\x9f\x24\x45\xdf\x4f\x9b\x17'
                              b'\xad\x2b\x41\x7b\xe6\x6c\x37\x10')

        ciphertext = bytearray(b'\x87\x4d\x61\x91\xb6\x20\xe3'
                               b'\x26\x1b\xef\x68\x64\x99\x0d'
                               b'\xb6\xce\x98\x06\xf6\x6b\x79'
                               b'\x70\xfd\xff\x86\x17\x18\x7b'
                               b'\xb9\xff\xfd\xff\x5a\xe4\xdf'
                               b'\x3e\xdb\xd5\xd3\x5e\x5b\x4f'
                               b'\x09\x02\x0d\xb0\x3e\xab\x1e'
                               b'\x03\x1d\xda\x2f\xbe\x03\xd1'
                               b'\x79\x21\x70\xa0\xf3\x00\x9c\xee')

        counter = bytearray(b'\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8'
                            b'\xf9\xfa\xfb\xfc\xfd\xfe\xff')

        aesCTR = Python_AES_CTR(key, mode=6, IV=bytearray(b'\x00' * 12))
        aesCTR.counter = counter
        self.assertEqual(aesCTR.decrypt(ciphertext), plaintext)

    def test_encrypt_with_test_vector_2(self):

        key = bytearray(b'\x8e\x73\xb0\xf7\xda\x0e\x64\x52\xc8'
                        b'\x10\xf3\x2b\x80\x90\x79\xe5\x62\xf8'
                        b'\xea\xd2\x52\x2c\x6b\x7b')

        plaintext = bytearray(b'\x6b\xc1\xbe\xe2\x2e\x40\x9f'
                              b'\x96\xe9\x3d\x7e\x11\x73\x93'
                              b'\x17\x2a\xae\x2d\x8a\x57\x1e'
                              b'\x03\xac\x9c\x9e\xb7\x6f\xac'
                              b'\x45\xaf\x8e\x51\x30\xc8\x1c'
                              b'\x46\xa3\x5c\xe4\x11\xe5\xfb'
                              b'\xc1\x19\x1a\x0a\x52\xef\xf6'
                              b'\x9f\x24\x45\xdf\x4f\x9b\x17'
                              b'\xad\x2b\x41\x7b\xe6\x6c\x37\x10')

        ciphertext = bytearray(b'\x1a\xbc\x93\x24\x17\x52\x1c\xa2'
                               b'\x4f\x2b\x04\x59\xfe\x7e\x6e\x0b'
                               b'\x09\x03\x39\xec\x0a\xa6\xfa\xef'
                               b'\xd5\xcc\xc2\xc6\xf4\xce\x8e\x94'
                               b'\x1e\x36\xb2\x6b\xd1\xeb\xc6\x70'
                               b'\xd1\xbd\x1d\x66\x56\x20\xab\xf7'
                               b'\x4f\x78\xa7\xf6\xd2\x98\x09\x58'
                               b'\x5a\x97\xda\xec\x58\xc6\xb0\x50')

        counter = bytearray(b'\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8'
                            b'\xf9\xfa\xfb\xfc\xfd\xfe\xff')

        aesCTR = Python_AES_CTR(key, mode=6, IV=bytearray(b'\x00' * 12))
        aesCTR.counter = counter
        self.assertEqual(aesCTR.encrypt(plaintext), ciphertext)

    def test_decrypt_with_test_vector_2(self):

        key = bytearray(b'\x8e\x73\xb0\xf7\xda\x0e\x64\x52\xc8'
                        b'\x10\xf3\x2b\x80\x90\x79\xe5\x62\xf8'
                        b'\xea\xd2\x52\x2c\x6b\x7b')

        ciphertext = bytearray(b'\x6b\xc1\xbe\xe2\x2e\x40\x9f'
                              b'\x96\xe9\x3d\x7e\x11\x73\x93'
                              b'\x17\x2a\xae\x2d\x8a\x57\x1e'
                              b'\x03\xac\x9c\x9e\xb7\x6f\xac'
                              b'\x45\xaf\x8e\x51\x30\xc8\x1c'
                              b'\x46\xa3\x5c\xe4\x11\xe5\xfb'
                              b'\xc1\x19\x1a\x0a\x52\xef\xf6'
                              b'\x9f\x24\x45\xdf\x4f\x9b\x17'
                              b'\xad\x2b\x41\x7b\xe6\x6c\x37\x10')

        plaintext = bytearray(b'\x1a\xbc\x93\x24\x17\x52\x1c\xa2'
                               b'\x4f\x2b\x04\x59\xfe\x7e\x6e\x0b'
                               b'\x09\x03\x39\xec\x0a\xa6\xfa\xef'
                               b'\xd5\xcc\xc2\xc6\xf4\xce\x8e\x94'
                               b'\x1e\x36\xb2\x6b\xd1\xeb\xc6\x70'
                               b'\xd1\xbd\x1d\x66\x56\x20\xab\xf7'
                               b'\x4f\x78\xa7\xf6\xd2\x98\x09\x58'
                               b'\x5a\x97\xda\xec\x58\xc6\xb0\x50')

        counter = bytearray(b'\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8'
                            b'\xf9\xfa\xfb\xfc\xfd\xfe\xff')

        aesCTR = Python_AES_CTR(key, mode=6, IV=bytearray(b'\x00' * 12))
        aesCTR.counter = counter
        self.assertEqual(aesCTR.decrypt(ciphertext), plaintext)

    def test_encrypt_with_test_vector_3(self):

        key = bytearray(b'\x60\x3d\xeb\x10\x15\xca\x71\xbe'
                        b'\x2b\x73\xae\xf0\x85\x7d\x77\x81'
                        b'\x1f\x35\x2c\x07\x3b\x61\x08\xd7'
                        b'\x2d\x98\x10\xa3\x09\x14\xdf\xf4')

        ciphertext = bytearray(b'\x60\x1e\xc3\x13\x77\x57\x89\xa5'
                               b'\xb7\xa7\xf5\x04\xbb\xf3\xd2\x28'
                               b'\xf4\x43\xe3\xca\x4d\x62\xb5\x9a'
                               b'\xca\x84\xe9\x90\xca\xca\xf5\xc5'
                               b'\x2b\x09\x30\xda\xa2\x3d\xe9\x4c'
                               b'\xe8\x70\x17\xba\x2d\x84\x98\x8d'
                               b'\xdf\xc9\xc5\x8d\xb6\x7a\xad\xa6'
                               b'\x13\xc2\xdd\x08\x45\x79\x41\xa6')

        plaintext = bytearray(b'\x6b\xc1\xbe\xe2\x2e\x40\x9f'
                              b'\x96\xe9\x3d\x7e\x11\x73\x93'
                              b'\x17\x2a\xae\x2d\x8a\x57\x1e'
                              b'\x03\xac\x9c\x9e\xb7\x6f\xac'
                              b'\x45\xaf\x8e\x51\x30\xc8\x1c'
                              b'\x46\xa3\x5c\xe4\x11\xe5\xfb'
                              b'\xc1\x19\x1a\x0a\x52\xef\xf6'
                              b'\x9f\x24\x45\xdf\x4f\x9b\x17'
                              b'\xad\x2b\x41\x7b\xe6\x6c\x37\x10')

        counter = bytearray(b'\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8'
                            b'\xf9\xfa\xfb\xfc\xfd\xfe\xff')

        aesCTR = Python_AES_CTR(key, mode=6, IV=bytearray(b'\x00' * 12))
        aesCTR.counter = counter
        self.assertEqual(aesCTR.encrypt(plaintext), ciphertext)

    def test_decrypt_with_test_vector_3(self):

        key = bytearray(b'\x60\x3d\xeb\x10\x15\xca\x71\xbe'
                        b'\x2b\x73\xae\xf0\x85\x7d\x77\x81'
                        b'\x1f\x35\x2c\x07\x3b\x61\x08\xd7'
                        b'\x2d\x98\x10\xa3\x09\x14\xdf\xf4')

        plaintext = bytearray(b'\x60\x1e\xc3\x13\x77\x57\x89\xa5'
                               b'\xb7\xa7\xf5\x04\xbb\xf3\xd2\x28'
                               b'\xf4\x43\xe3\xca\x4d\x62\xb5\x9a'
                               b'\xca\x84\xe9\x90\xca\xca\xf5\xc5'
                               b'\x2b\x09\x30\xda\xa2\x3d\xe9\x4c'
                               b'\xe8\x70\x17\xba\x2d\x84\x98\x8d'
                               b'\xdf\xc9\xc5\x8d\xb6\x7a\xad\xa6'
                               b'\x13\xc2\xdd\x08\x45\x79\x41\xa6')

        ciphertext = bytearray(b'\x6b\xc1\xbe\xe2\x2e\x40\x9f'
                              b'\x96\xe9\x3d\x7e\x11\x73\x93'
                              b'\x17\x2a\xae\x2d\x8a\x57\x1e'
                              b'\x03\xac\x9c\x9e\xb7\x6f\xac'
                              b'\x45\xaf\x8e\x51\x30\xc8\x1c'
                              b'\x46\xa3\x5c\xe4\x11\xe5\xfb'
                              b'\xc1\x19\x1a\x0a\x52\xef\xf6'
                              b'\x9f\x24\x45\xdf\x4f\x9b\x17'
                              b'\xad\x2b\x41\x7b\xe6\x6c\x37\x10')

        counter = bytearray(b'\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8'
                            b'\xf9\xfa\xfb\xfc\xfd\xfe\xff')

        aesCTR = Python_AES_CTR(key, mode=6, IV=bytearray(b'\x00' * 12))
        aesCTR.counter = counter
        self.assertEqual(aesCTR.decrypt(ciphertext), plaintext)

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest

from tlslite.utils.rijndael import Rijndael
from tlslite.utils.python_aes import Python_AES


class TestAESCBC(unittest.TestCase):
    def test___init__(self):
        key = bytearray(16)
        aesCBC = Python_AES(key, 2, bytearray(b'\x00' * 16))

        self.assertIsNotNone(aesCBC)

    def test___init___with_invalid_key(self):
        key = bytearray(8)

        with self.assertRaises(AssertionError):
            aesCBC = Python_AES(key, 2, bytearray(b'\x00' * 16))

    def test___init___with_invalid_iv(self):
        key = bytearray(16)

        with self.assertRaises(AssertionError):
            aesCBC = Python_AES(key, 2, bytearray(b'\x00' * 8))

    def test_encrypt_with_test_vector_1(self):

        key = bytearray(b'\x2b\x7e\x15\x16\x28\xae\xd2'
                        b'\xa6\xab\xf7\x15\x88\x09\xcf\x4f\x3c')

        IV = bytearray(b'\x00\x01\x02\x03\x04\x05\x06\x07'
                       b'\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f')

        plaintext = bytearray(b'\x6b\xc1\xbe\xe2\x2e\x40\x9f'
                              b'\x96\xe9\x3d\x7e\x11\x73\x93'
                              b'\x17\x2a\xae\x2d\x8a\x57\x1e'
                              b'\x03\xac\x9c\x9e\xb7\x6f\xac'
                              b'\x45\xaf\x8e\x51\x30\xc8\x1c'
                              b'\x46\xa3\x5c\xe4\x11\xe5\xfb'
                              b'\xc1\x19\x1a\x0a\x52\xef\xf6'
                              b'\x9f\x24\x45\xdf\x4f\x9b\x17'
                              b'\xad\x2b\x41\x7b\xe6\x6c\x37\x10')

        ciphertext = bytearray(b'\x76\x49\xab\xac\x81\x19\xb2\x46'
                               b'\xce\xe9\x8e\x9b\x12\xe9\x19\x7d'
                               b'\x50\x86\xcb\x9b\x50\x72\x19\xee'
                               b'\x95\xdb\x11\x3a\x91\x76\x78\xb2'
                               b'\x73\xbe\xd6\xb8\xe3\xc1\x74\x3b'
                               b'\x71\x16\xe6\x9e\x22\x22\x95\x16'
                               b'\x3f\xf1\xca\xa1\x68\x1f\xac\x09'
                               b'\x12\x0e\xca\x30\x75\x86\xe1\xa7')

        aesCBC = Python_AES(key, 2, IV)
        self.assertEqual(aesCBC.encrypt(plaintext), ciphertext)

    def test_decrypt_with_test_vector_1(self):

        key = bytearray(b'\x2b\x7e\x15\x16\x28\xae\xd2'
                        b'\xa6\xab\xf7\x15\x88\x09\xcf\x4f\x3c')

        IV = bytearray(b'\x00\x01\x02\x03\x04\x05\x06\x07'
                       b'\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f')

        plaintext = bytearray(b'\x6b\xc1\xbe\xe2\x2e\x40\x9f'
                              b'\x96\xe9\x3d\x7e\x11\x73\x93'
                              b'\x17\x2a\xae\x2d\x8a\x57\x1e'
                              b'\x03\xac\x9c\x9e\xb7\x6f\xac'
                              b'\x45\xaf\x8e\x51\x30\xc8\x1c'
                              b'\x46\xa3\x5c\xe4\x11\xe5\xfb'
                              b'\xc1\x19\x1a\x0a\x52\xef\xf6'
                              b'\x9f\x24\x45\xdf\x4f\x9b\x17'
                              b'\xad\x2b\x41\x7b\xe6\x6c\x37\x10')

        ciphertext = bytearray(b'\x76\x49\xab\xac\x81\x19\xb2\x46'
                               b'\xce\xe9\x8e\x9b\x12\xe9\x19\x7d'
                               b'\x50\x86\xcb\x9b\x50\x72\x19\xee'
                               b'\x95\xdb\x11\x3a\x91\x76\x78\xb2'
                               b'\x73\xbe\xd6\xb8\xe3\xc1\x74\x3b'
                               b'\x71\x16\xe6\x9e\x22\x22\x95\x16'
                               b'\x3f\xf1\xca\xa1\x68\x1f\xac\x09'
                               b'\x12\x0e\xca\x30\x75\x86\xe1\xa7')

        aesCBC = Python_AES(key, 2, IV)
        self.assertEqual(aesCBC.decrypt(ciphertext), plaintext)

    def test_encrypt_with_test_vector_2(self):

        key = bytearray(b'\x8e\x73\xb0\xf7\xda\x0e\x64\x52'
                        b'\xc8\x10\xf3\x2b\x80\x90\x79\xe5'
                        b'\x62\xf8\xea\xd2\x52\x2c\x6b\x7b')

        IV = bytearray(b'\x00\x01\x02\x03\x04\x05\x06\x07'
                       b'\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f')

        plaintext = bytearray(b'\x6b\xc1\xbe\xe2\x2e\x40\x9f'
                              b'\x96\xe9\x3d\x7e\x11\x73\x93'
                              b'\x17\x2a\xae\x2d\x8a\x57\x1e'
                              b'\x03\xac\x9c\x9e\xb7\x6f\xac'
                              b'\x45\xaf\x8e\x51\x30\xc8\x1c'
                              b'\x46\xa3\x5c\xe4\x11\xe5\xfb'
                              b'\xc1\x19\x1a\x0a\x52\xef\xf6'
                              b'\x9f\x24\x45\xdf\x4f\x9b\x17'
                              b'\xad\x2b\x41\x7b\xe6\x6c\x37\x10')

        ciphertext = bytearray(b'\x4f\x02\x1d\xb2\x43\xbc\x63\x3d'
                               b'\x71\x78\x18\x3a\x9f\xa0\x71\xe8'
                               b'\xb4\xd9\xad\xa9\xad\x7d\xed\xf4'
                               b'\xe5\xe7\x38\x76\x3f\x69\x14\x5a'
                               b'\x57\x1b\x24\x20\x12\xfb\x7a\xe0'
                               b'\x7f\xa9\xba\xac\x3d\xf1\x02\xe0'
                               b'\x08\xb0\xe2\x79\x88\x59\x88\x81'
                               b'\xd9\x20\xa9\xe6\x4f\x56\x15\xcd')

        aesCBC = Python_AES(key, 2, IV)
        self.assertEqual(aesCBC.encrypt(plaintext), ciphertext)

    def test_decrypt_with_test_vector_2(self):

        key = bytearray(b'\x8e\x73\xb0\xf7\xda\x0e\x64\x52'
                        b'\xc8\x10\xf3\x2b\x80\x90\x79\xe5'
                        b'\x62\xf8\xea\xd2\x52\x2c\x6b\x7b')

        IV = bytearray(b'\x00\x01\x02\x03\x04\x05\x06\x07'
                       b'\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f')

        plaintext = bytearray(b'\x6b\xc1\xbe\xe2\x2e\x40\x9f'
                              b'\x96\xe9\x3d\x7e\x11\x73\x93'
                              b'\x17\x2a\xae\x2d\x8a\x57\x1e'
                              b'\x03\xac\x9c\x9e\xb7\x6f\xac'
                              b'\x45\xaf\x8e\x51\x30\xc8\x1c'
                              b'\x46\xa3\x5c\xe4\x11\xe5\xfb'
                              b'\xc1\x19\x1a\x0a\x52\xef\xf6'
                              b'\x9f\x24\x45\xdf\x4f\x9b\x17'
                              b'\xad\x2b\x41\x7b\xe6\x6c\x37\x10')

        ciphertext = bytearray(b'\x4f\x02\x1d\xb2\x43\xbc\x63\x3d'
                               b'\x71\x78\x18\x3a\x9f\xa0\x71\xe8'
                               b'\xb4\xd9\xad\xa9\xad\x7d\xed\xf4'
                               b'\xe5\xe7\x38\x76\x3f\x69\x14\x5a'
                               b'\x57\x1b\x24\x20\x12\xfb\x7a\xe0'
                               b'\x7f\xa9\xba\xac\x3d\xf1\x02\xe0'
                               b'\x08\xb0\xe2\x79\x88\x59\x88\x81'
                               b'\xd9\x20\xa9\xe6\x4f\x56\x15\xcd')

        aesCBC = Python_AES(key, 2, IV)
        self.assertEqual(aesCBC.decrypt(ciphertext), plaintext)

    def test_encrypt_with_test_vector_3(self):

        key = bytearray(b'\x60\x3d\xeb\x10\x15\xca\x71\xbe'
                        b'\x2b\x73\xae\xf0\x85\x7d\x77\x81'
                        b'\x1f\x35\x2c\x07\x3b\x61\x08\xd7'
                        b'\x2d\x98\x10\xa3\x09\x14\xdf\xf4')

        IV = bytearray(b'\x00\x01\x02\x03\x04\x05\x06\x07'
                       b'\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f')

        plaintext = bytearray(b'\x6b\xc1\xbe\xe2\x2e\x40\x9f'
                              b'\x96\xe9\x3d\x7e\x11\x73\x93'
                              b'\x17\x2a\xae\x2d\x8a\x57\x1e'
                              b'\x03\xac\x9c\x9e\xb7\x6f\xac'
                              b'\x45\xaf\x8e\x51\x30\xc8\x1c'
                              b'\x46\xa3\x5c\xe4\x11\xe5\xfb'
                              b'\xc1\x19\x1a\x0a\x52\xef\xf6'
                              b'\x9f\x24\x45\xdf\x4f\x9b\x17'
                              b'\xad\x2b\x41\x7b\xe6\x6c\x37\x10')

        ciphertext = bytearray(b'\xf5\x8c\x4c\x04\xd6\xe5\xf1\xba'
                               b'\x77\x9e\xab\xfb\x5f\x7b\xfb\xd6'
                               b'\x9c\xfc\x4e\x96\x7e\xdb\x80\x8d'
                               b'\x67\x9f\x77\x7b\xc6\x70\x2c\x7d'
                               b'\x39\xf2\x33\x69\xa9\xd9\xba\xcf'
                               b'\xa5\x30\xe2\x63\x04\x23\x14\x61'
                               b'\xb2\xeb\x05\xe2\xc3\x9b\xe9\xfc'
                               b'\xda\x6c\x19\x07\x8c\x6a\x9d\x1b')

        aesCBC = Python_AES(key, 2, IV)
        self.assertEqual(aesCBC.encrypt(plaintext), ciphertext)

    def test_decrypt_with_test_vector_3(self):

        key = bytearray(b'\x60\x3d\xeb\x10\x15\xca\x71\xbe'
                        b'\x2b\x73\xae\xf0\x85\x7d\x77\x81'
                        b'\x1f\x35\x2c\x07\x3b\x61\x08\xd7'
                        b'\x2d\x98\x10\xa3\x09\x14\xdf\xf4')

        IV = bytearray(b'\x00\x01\x02\x03\x04\x05\x06\x07'
                       b'\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f')

        plaintext = bytearray(b'\x6b\xc1\xbe\xe2\x2e\x40\x9f'
                              b'\x96\xe9\x3d\x7e\x11\x73\x93'
                              b'\x17\x2a\xae\x2d\x8a\x57\x1e'
                              b'\x03\xac\x9c\x9e\xb7\x6f\xac'
                              b'\x45\xaf\x8e\x51\x30\xc8\x1c'
                              b'\x46\xa3\x5c\xe4\x11\xe5\xfb'
                              b'\xc1\x19\x1a\x0a\x52\xef\xf6'
                              b'\x9f\x24\x45\xdf\x4f\x9b\x17'
                              b'\xad\x2b\x41\x7b\xe6\x6c\x37\x10')

        ciphertext = bytearray(b'\xf5\x8c\x4c\x04\xd6\xe5\xf1\xba'
                               b'\x77\x9e\xab\xfb\x5f\x7b\xfb\xd6'
                               b'\x9c\xfc\x4e\x96\x7e\xdb\x80\x8d'
                               b'\x67\x9f\x77\x7b\xc6\x70\x2c\x7d'
                               b'\x39\xf2\x33\x69\xa9\xd9\xba\xcf'
                               b'\xa5\x30\xe2\x63\x04\x23\x14\x61'
                               b'\xb2\xeb\x05\xe2\xc3\x9b\xe9\xfc'
                               b'\xda\x6c\x19\x07\x8c\x6a\x9d\x1b')

        aesCBC = Python_AES(key, 2, IV)
        self.assertEqual(aesCBC.decrypt(ciphertext), plaintext)

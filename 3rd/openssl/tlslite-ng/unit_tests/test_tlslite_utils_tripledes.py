# coding=utf-8
# Copyright (c) 2018, Adam Varga
#
# See the LICENSE file for legal information regarding use of this file.
#
# This is Known Answers Tests file for python_tripledes,py,
# which implements 3DES cipher in CBC mode
#
# CAVP use 3 Keying Options:
# KO1: KEY1 != KEY2 != KEY3
# KO2: (KEY1 = KEY3) != KEY2
# KO3: KEY1 = KEY2 = KEY3

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest

from tlslite.utils.python_tripledes import *
from tlslite.utils.cryptomath import *
from tlslite.errors import *
import sys
import warnings

PY_VER = sys.version_info

class Test3DES_components(unittest.TestCase):
    # component functions NOT tested from test vectors

    def test_new(self):
        des = new(b"\xaa"*24, b"\xbb"*8)

        self.assertIsInstance(des, Python_TripleDES)

    def test_no_iv(self):
        with self.assertRaises(ValueError):
            Python_TripleDES(
                bytearray(b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                          b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                          b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'))

    def test_too_short_iv(self):
        with self.assertRaises(ValueError):
            Python_TripleDES(
                bytearray(b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                          b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                          b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'),
                b'\x55\xfe\x07\x2a\x73\x51\xa5')

    def test_too_short_key_size(self):
        with self.assertRaises(ValueError):
            Python_TripleDES(b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57',
                             b'\x55\xfe\x07\x2a\x73\x51\xa5\x00')

    @unittest.skipIf(PY_VER < (3, ),
        "DeprecationWarning check should apply only on python3")
    def test1_py3_str_instance(self):

        with self.assertWarns(DeprecationWarning):
            Python_TripleDES('asdfdasdfdsasdfdsasgdfds', b"\xbb"*8)

    @unittest.skipIf(PY_VER < (3, ),
        "DeprecationWarning check should apply only on python3")
    def test2_py3_str_instance(self):

        with self.assertWarns(DeprecationWarning):
            Python_TripleDES(b"\xaa"*24, 'asdfdasd')

    @unittest.skipIf(PY_VER < (3, ),
        "DeprecationWarning check should apply only on python3")
    def test3_py3_str_instance(self):
        key =  b"\xaa"*24
        iv = b"\xbb"*8

        with self.assertWarns(DeprecationWarning):
            Python_TripleDES(key, iv).encrypt('161514131211109876543210')

    @unittest.skipIf(PY_VER < (3, ),
        "DeprecationWarning check should apply only on python3")
    def test4_py3_str_instance(self):
        key =  b"\xaa"*24
        iv = b"\xbb"*8

        with self.assertWarns(DeprecationWarning):
            Python_TripleDES(key, iv).decrypt('161514131211109876543210')

    @unittest.skipIf(PY_VER > (3, ),
        "DeprecationWarning check should apply only on python3")
    def test1_py2_str_instance(self):

        with warnings.catch_warnings(record=True) as w:
            warnings.simplefilter("always")
            Python_TripleDES('asdfdasdfdsasdfdsasgdfds', b"\xbb"*8)
            self.assertEqual(len(w), 0)

    @unittest.skipIf(PY_VER > (3, ),
        "DeprecationWarning check should apply only on python3")
    def test2_py2_str_instance(self):

        with warnings.catch_warnings(record=True) as w:
            warnings.simplefilter("always")
            Python_TripleDES(b"\xaa"*24, 'asdfdasd')
            self.assertEqual(len(w), 0)

    @unittest.skipIf(PY_VER > (3, ),
        "DeprecationWarning check should apply only on python3")
    def test3_py2_str_instance(self):
        key =  b"\xaa"*24
        iv = b"\xbb"*8

        with warnings.catch_warnings(record=True) as w:
            warnings.simplefilter("always")
            Python_TripleDES(key, iv).encrypt('161514131211109876543210')
            self.assertEqual(len(w), 0)

    @unittest.skipIf(PY_VER > (3, ),
        "DeprecationWarning check should apply only on python3")
    def test4_py2_str_instance(self):
        key =  b"\xaa"*24
        iv = b"\xbb"*8

        with warnings.catch_warnings(record=True) as w:
            warnings.simplefilter("always")
            Python_TripleDES(key, iv).decrypt('161514131211109876543210')
            self.assertEqual(len(w), 0)

    @unittest.skipIf(PY_VER < (3, ), "Unicode string syntax on py2: u'ľáľä'")
    def test1_py3_unicode_instance(self):
        with self.assertWarns(DeprecationWarning):
            with self.assertRaises(ValueError):
                Python_TripleDES('aáäbcčdďeéfghiíjklĺľmnňo', b"\xbb"*8)

    @unittest.skipIf(PY_VER < (3, ), "Unicode string syntax on py2: u'ľáľä'")
    def test2_py3_unicode_instance(self):
        with self.assertWarns(DeprecationWarning):
            with self.assertRaises(ValueError):
                Python_TripleDES(b"\xaa"*24, 'aáäbcčdď')

    @unittest.skipIf(PY_VER < (3, ), "Unicode string syntax on py2: u'ľáľä'")
    def test3_py3_unicode_instance(self):
        key =  b"\xaa"*24
        iv = b"\xbb"*8
        with self.assertWarns(DeprecationWarning):
            with self.assertRaises(ValueError):
                Python_TripleDES(key, iv).encrypt('aáäbcčdďeéfghiíjklĺľmnňo')

    @unittest.skipIf(PY_VER < (3, ), "Unicode string syntax on py2: u'ľáľä'")
    def test4_py3_unicode_instance(self):
        key =  b"\xaa"*24
        iv = b"\xbb"*8
        with self.assertWarns(DeprecationWarning):
            with self.assertRaises(ValueError):
                Python_TripleDES(key, iv).decrypt('aáäbcčdďeéfghiíjklĺľmnňo')

    @unittest.skipIf(PY_VER > (3, ), "Unicode string syntax on py3: 'ľáľä'")
    def test1_py2_unicode_instance(self):
        key = unicode('aáäbcčdďeéfghiíjklĺľmnňo', 'utf-8')

        with self.assertRaises(ValueError):
            Python_TripleDES(key, b"\xbb"*8)

    @unittest.skipIf(PY_VER > (3, ), "Unicode string syntax on py3: 'ľáľä'")
    def test2_py2_unicode_instance(self):
        iv = unicode('aáäbcčdď', 'utf-8')

        with self.assertRaises(ValueError):
            Python_TripleDES(b"\xaa"*24, iv)

    @unittest.skipIf(PY_VER > (3, ), "Unicode string syntax on py3: 'ľáľä'")
    def test3_py2_unicode_instance(self):
        key =  b"\xaa"*24
        iv = b"\xbb"*8
        text = unicode('aáäbcčdďeéfghiíjklĺľmnňo', 'utf-8')

        with self.assertRaises(ValueError):
            Python_TripleDES(key, iv).encrypt(text)

    @unittest.skipIf(PY_VER > (3, ), "Unicode string syntax on py3: 'ľáľä'")
    def test4_py2_unicode_instance(self):
        key =  b"\xaa"*24
        iv = b"\xbb"*8
        text = unicode('aáäbcčdďeéfghiíjklĺľmnňo', 'utf-8')

        with self.assertRaises(ValueError):
            Python_TripleDES(key, iv).decrypt(text)

    def test_1des_too_short_key(self):
        with self.assertRaises(ValueError):
            Des(b'\x00\x00\x00\x00\x00\x00\x00',
                b'\x00\x00\x00\x00\x00\x00\x00\x00')

    def test_3des_16B_key(self):
        key = bytearray(b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57')
        iv = b'\x55\xfe\x07\x2a\x73\x51\xa5\xc8'

        triple_des = Python_TripleDES(key, iv)

        self.assertEqual(
            triple_des.encrypt(
                bytearray(
                    b'\x80\x00\x00\x00\x00\x00\x00\x00'
                    b'\x80\x00\x00\x00\x00\x00\x00\x00'
                    b'\x80\x00\x00\x00\x00\x00\x00\x00')),
            bytearray(
                b'\x56\x28\x4a\x04\xc9\xb5\xf7\xb6'
                b'\x8f\x36\xf6\xcd\xf6\x36\x17\xd2'
                b'\x9a\x1c\x07\x9a\xc4\x0c\xf4\x62'))

    def test1_no_data_encrypt(self):
        key = bytearray(b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57')
        iv = b'\x55\xfe\x07\x2a\x73\x51\xa5\xc8'

        ret = Python_TripleDES(key, iv).encrypt(b'')

        self.assertEqual(ret, b'')
        self.assertIsInstance(ret, bytearray)

    def test2_no_data_encrypt(self):
        key = bytearray(b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57')
        iv = b'\x55\xfe\x07\x2a\x73\x51\xa5\xc8'

        with self.assertRaises(TypeError):
            Python_TripleDES(key, iv).encrypt()

    def test1_no_data_decrypt(self):
        key = bytearray(b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57')
        iv = b'\x55\xfe\x07\x2a\x73\x51\xa5\xc8'

        ret = Python_TripleDES(key, iv).decrypt(b'')

        self.assertEqual(ret, b'')
        self.assertIsInstance(ret, bytearray)

    def test2_no_data_decrypt(self):
        key = bytearray(b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57')
        iv = b'\x55\xfe\x07\x2a\x73\x51\xa5\xc8'

        with self.assertRaises(TypeError):
            Python_TripleDES(key, iv).decrypt()

    def test_bad_data_len_encrypt(self):
        key = bytearray(b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57')
        iv = b'\x55\xfe\x07\x2a\x73\x51\xa5\xc8'

        with self.assertRaises(ValueError):
            Python_TripleDES(key, iv).encrypt(b'161514131211109876543')

    def test_bad_data_len_decrypt(self):
        key = bytearray(b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57')
        iv = b'\x55\xfe\x07\x2a\x73\x51\xa5\xc8'

        with self.assertRaises(ValueError):
            Python_TripleDES(key, iv).decrypt(b'161514131211109876543')

class Test3DES_KATs_KO3(unittest.TestCase):
    # KATs from the official CAVP
    # work with one block messages, all in KO3

    def test_3des_vartext_encrypt(self):
        #Variable Plaintext Known Answer Test, encrypt one block.

        key = bytearray(b'\x01\x01\x01\x01\x01\x01\x01\x01'
                        b'\x01\x01\x01\x01\x01\x01\x01\x01'
                        b'\x01\x01\x01\x01\x01\x01\x01\x01')
        iv = b'\x00\x00\x00\x00\x00\x00\x00\x00'

        triple_des = Python_TripleDES(key, iv)

        ret = triple_des.encrypt(b'\x80\x00\x00\x00\x00\x00\x00\x00')

        self.assertEqual(
            ret,
            b'\x95\xf8\xa5\xe5\xdd\x31\xd9\x00')
        self.assertIsInstance(ret, bytearray)

    def test_3des_vartext_decrypt(self):
        #Variable Plaintext Known Answer Test, decrypt one block

        key = bytearray(b'\x01\x01\x01\x01\x01\x01\x01\x01'
                        b'\x01\x01\x01\x01\x01\x01\x01\x01'
                        b'\x01\x01\x01\x01\x01\x01\x01\x01')
        iv = b'\x00\x00\x00\x00\x00\x00\x00\x00'

        triple_des = Python_TripleDES(key, iv)

        ret = triple_des.decrypt(b'\x95\xf8\xa5\xe5\xdd\x31\xd9\x00')

        self.assertEqual(
            ret,
            b'\x80\x00\x00\x00\x00\x00\x00\x00')
        self.assertIsInstance(ret, bytearray)

    def test_3des_invperm_encrypt(self):
        #Inverse Permutation Known Answer Test, encrypt one block.

        key = bytearray(b'\x01\x01\x01\x01\x01\x01\x01\x01'
                        b'\x01\x01\x01\x01\x01\x01\x01\x01'
                        b'\x01\x01\x01\x01\x01\x01\x01\x01')
        iv = b'\x00\x00\x00\x00\x00\x00\x00\x00'

        triple_des = Python_TripleDES(key, iv)

        self.assertEqual(
            triple_des.encrypt(b'\x95\xf8\xa5\xe5\xdd\x31\xd9\x00'),
            b'\x80\x00\x00\x00\x00\x00\x00\x00')

    def test_3des_invperm_decrypt(self):
        #Inverse Permutation Known Answer Test, decrypt one block

        key = bytearray(b'\x01\x01\x01\x01\x01\x01\x01\x01'
                        b'\x01\x01\x01\x01\x01\x01\x01\x01'
                        b'\x01\x01\x01\x01\x01\x01\x01\x01')
        iv = b'\x00\x00\x00\x00\x00\x00\x00\x00'

        triple_des = Python_TripleDES(key, iv)

        self.assertEqual(
            triple_des.decrypt(b'\x80\x00\x00\x00\x00\x00\x00\x00'),
            b'\x95\xf8\xa5\xe5\xdd\x31\xd9\x00')

    def test_3des_varkey_encrypt(self):
        #Variable Key Known Answer Test, encrypt one block.

        key = bytearray(b'\x80\x01\x01\x01\x01\x01\x01\x01'
                        b'\x01\x01\x01\x01\x01\x01\x01\x01'
                        b'\x01\x01\x01\x01\x01\x01\x01\x01')
        iv = b'\x00\x00\x00\x00\x00\x00\x00\x00'

        triple_des = Python_TripleDES(key, iv)

        self.assertEqual(
            triple_des.encrypt(b'\x00\x00\x00\x00\x00\x00\x00\x00'),
            b'\x95\xa8\xd7\x28\x13\xda\xa9\x4d')

    def test_3des_varkey_decrypt(self):
        #Variable Key Known Answer Test, decrypt one block

        key = bytearray(b'\x80\x01\x01\x01\x01\x01\x01\x01'
                        b'\x01\x01\x01\x01\x01\x01\x01\x01'
                        b'\x01\x01\x01\x01\x01\x01\x01\x01')
        iv = b'\x00\x00\x00\x00\x00\x00\x00\x00'

        triple_des = Python_TripleDES(key, iv)

        self.assertEqual(
            triple_des.decrypt(b'\x95\xa8\xd7\x28\x13\xda\xa9\x4d'),
            b'\x00\x00\x00\x00\x00\x00\x00\x00')

    def test_3des_permop_encrypt(self):
        #Permutation Operation Known Answer Test, encrypt one block.

        key = bytearray(b'\x10\x46\x91\x34\x89\x98\x01\x31'
                        b'\x10\x46\x91\x34\x89\x98\x01\x31'
                        b'\x10\x46\x91\x34\x89\x98\x01\x31')
        iv = b'\x00\x00\x00\x00\x00\x00\x00\x00'

        triple_des = Python_TripleDES(key, iv)

        self.assertEqual(
            triple_des.encrypt(b'\x00\x00\x00\x00\x00\x00\x00\x00'),
            b'\x88\xd5\x5e\x54\xf5\x4c\x97\xb4')

    def test_3des_permop_decrypt(self):
        #Permutation Operation Known Answer Test, decrypt one block

        key = bytearray(b'\x10\x46\x91\x34\x89\x98\x01\x31'
                        b'\x10\x46\x91\x34\x89\x98\x01\x31'
                        b'\x10\x46\x91\x34\x89\x98\x01\x31')
        iv = b'\x00\x00\x00\x00\x00\x00\x00\x00'

        triple_des = Python_TripleDES(key, iv)

        self.assertEqual(
            triple_des.decrypt(b'\x88\xd5\x5e\x54\xf5\x4c\x97\xb4'),
            b'\x00\x00\x00\x00\x00\x00\x00\x00')

    def test_3des_subtab_encrypt(self):
        #Substitution Table Known Answer Test, encrypt one block.

        key = bytearray(b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57')
        iv = b'\x00\x00\x00\x00\x00\x00\x00\x00'

        triple_des = Python_TripleDES(key, iv)

        self.assertEqual(
            triple_des.encrypt(b'\x01\xa1\xd6\xd0\x39\x77\x67\x42'),
            b'\x69\x0f\x5b\x0d\x9a\x26\x93\x9b')

    def test_3des_subtab_decrypt(self):
        #Substitution Table Known Answer Test, decrypt one block

        key = bytearray(b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57')
        iv = b'\x00\x00\x00\x00\x00\x00\x00\x00'

        triple_des = Python_TripleDES(key, iv)

        self.assertEqual(
            triple_des.decrypt(b'\x69\x0f\x5b\x0d\x9a\x26\x93\x9b'),
            b'\x01\xa1\xd6\xd0\x39\x77\x67\x42')

class Test3DES_multipleBlock(unittest.TestCase):
    # These custom made test cases are not from official KATs

    def test_3des_ko1_encrypt(self):
        #Variable Plaintext, encrypt multiple blocks.

        key = bytearray(b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x10\x07\xd0\x15\x98\x98\x01\x20'
                        b'\x01\x01\x01\x01\x01\x01\x01\x01')
        iv = b'\xfa\x26\x9c\x07\x0c\xc5\x71\x82'

        triple_des = Python_TripleDES(key, iv)

        self.assertEqual(
            triple_des.encrypt(
                bytearray(
                    b'\x80\x00\x00\x00\x00\x00\x00\x00'
                    b'\x80\x00\x00\x00\x00\x00\x00\x00'
                    b'\x80\x00\x00\x00\x00\x00\x00\x00')),
            bytearray(
                b'\xa1\x55\xa6\xba\x61\xcf\xda\x01'
                b'\x31\x5d\x41\xb7\xe5\x59\x80\x7a'
                b'\x6e\x96\x68\xaf\xf4\x4c\x6f\x0f'))

    def test_3des_ko1_decrypt(self):
        #Variable Plaintext, decrypt multiple blocks.

        key = bytearray(b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x10\x07\xd0\x15\x98\x98\x01\x20'
                        b'\x01\x01\x01\x01\x01\x01\x01\x01')
        iv = b'\xfa\x26\x9c\x07\x0c\xc5\x71\x82'

        triple_des = Python_TripleDES(key, iv)

        self.assertEqual(
            triple_des.decrypt(
                bytearray(
                    b'\xa1\x55\xa6\xba\x61\xcf\xda\x01'
                    b'\x31\x5d\x41\xb7\xe5\x59\x80\x7a'
                    b'\x6e\x96\x68\xaf\xf4\x4c\x6f\x0f')),
            bytearray(
                b'\x80\x00\x00\x00\x00\x00\x00\x00'
                b'\x80\x00\x00\x00\x00\x00\x00\x00'
                b'\x80\x00\x00\x00\x00\x00\x00\x00'))

    def test_3des_ko2_encrypt(self):
        #Variable Plaintext, encrypt multiple blocks.

        key = bytearray(b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x01\x07\x94\x04\x91\x19\x04\x01'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57')
        iv = b'\x8a\x4d\x35\x9f\x85\x28\x95\x4a'

        triple_des = Python_TripleDES(key, iv)

        self.assertEqual(
            triple_des.encrypt(
                bytearray(
                    b'\x80\x00\x00\x00\x00\x00\x00\x00'
                    b'\x80\x00\x00\x00\x00\x00\x00\x00'
                    b'\x80\x00\x00\x00\x00\x00\x00\x00')),
            bytearray(
                b'\x94\x93\xb0\xcd\x54\xf9\x76\xad'
                b'\xfd\x26\x7e\xa4\x33\xde\x50\x19'
                b'\x3f\x30\xc9\x4b\xa9\x57\xf7\x14'))

    def test_3des_ko2_decrypt(self):
        #Variable Plaintext, decrypt multiple blocks.

        key = bytearray(b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x01\x07\x94\x04\x91\x19\x04\x01'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57')
        iv = b'\x8a\x4d\x35\x9f\x85\x28\x95\x4a'

        triple_des = Python_TripleDES(key, iv)

        self.assertEqual(
            triple_des.decrypt(
                bytearray(
                    b'\x94\x93\xb0\xcd\x54\xf9\x76\xad'
                    b'\xfd\x26\x7e\xa4\x33\xde\x50\x19'
                    b'\x3f\x30\xc9\x4b\xa9\x57\xf7\x14')),
            bytearray(
                b'\x80\x00\x00\x00\x00\x00\x00\x00'
                b'\x80\x00\x00\x00\x00\x00\x00\x00'
                b'\x80\x00\x00\x00\x00\x00\x00\x00'))

    def test_3des_ko3_encrypt(self):
        #Variable Plaintext, encrypt multiple blocks.

        key = bytearray(b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57')
        iv = b'\x55\xfe\x07\x2a\x73\x51\xa5\xc8'

        triple_des = Python_TripleDES(key, iv)

        self.assertEqual(
            triple_des.encrypt(
                bytearray(
                    b'\x80\x00\x00\x00\x00\x00\x00\x00'
                    b'\x80\x00\x00\x00\x00\x00\x00\x00'
                    b'\x80\x00\x00\x00\x00\x00\x00\x00')),
            bytearray(
                b'\x56\x28\x4a\x04\xc9\xb5\xf7\xb6'
                b'\x8f\x36\xf6\xcd\xf6\x36\x17\xd2'
                b'\x9a\x1c\x07\x9a\xc4\x0c\xf4\x62'))

    def test_3des_ko3_decrypt(self):
        #Variable Plaintext, decrypt multiple blocks.

        key = bytearray(b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57'
                        b'\x7c\xa1\x10\x45\x4a\x1a\x6e\x57')
        iv = b'\x55\xfe\x07\x2a\x73\x51\xa5\xc8'

        triple_des = Python_TripleDES(key, iv)

        self.assertEqual(
            triple_des.decrypt(
                bytearray(
                    b'\x56\x28\x4a\x04\xc9\xb5\xf7\xb6'
                    b'\x8f\x36\xf6\xcd\xf6\x36\x17\xd2'
                    b'\x9a\x1c\x07\x9a\xc4\x0c\xf4\x62')),
            bytearray(
                b'\x80\x00\x00\x00\x00\x00\x00\x00'
                b'\x80\x00\x00\x00\x00\x00\x00\x00'
                b'\x80\x00\x00\x00\x00\x00\x00\x00'))

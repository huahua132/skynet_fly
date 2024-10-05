# Copyright (c) 2019, Hubert Kario
#
# See the LICENSE file for legal information regarding use of this file.

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest

from tlslite.utils.ecdsakey import ECDSAKey


class MockECDSAKey(ECDSAKey):
    def __init__(self, public_key, private_key):
        pass


class TestECDSAKey(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.k = MockECDSAKey(None, None)

    def test___init___not_implemented(self):
        with self.assertRaises(NotImplementedError):
            ECDSAKey(None, None)

    def test___len__(self):
        with self.assertRaises(NotImplementedError):
            len(self.k)

    def test_hasPrivateKey(self):
        with self.assertRaises(NotImplementedError):
            self.k.hasPrivateKey()

    def test__sign(self):
        with self.assertRaises(NotImplementedError):
            self.k._sign(None, None)

    def test__hashAndSign(self):
        with self.assertRaises(NotImplementedError):
            self.k._hashAndSign(None, None)

    def test__verify(self):
        with self.assertRaises(NotImplementedError):
            self.k._verify(None, None)

    def test_hashAndSign(self):
        with self.assertRaises(NotImplementedError):
            self.k.hashAndSign(bytearray(b'text'))

    def test_hashAndVerify(self):
        with self.assertRaises(NotImplementedError):
            self.k.hashAndVerify(bytearray(b'sig'), bytearray(b'text'))

    def test_sign(self):
        with self.assertRaises(NotImplementedError):
            self.k.sign(bytearray(b'hash value'))

    def test_verify(self):
        with self.assertRaises(NotImplementedError):
            self.k.verify(bytearray(b'sig'), bytearray(b'hash value'))

    def test_acceptsPassword(self):
        with self.assertRaises(NotImplementedError):
            self.k.acceptsPassword()

    def test_write(self):
        with self.assertRaises(NotImplementedError):
            self.k.write()

    def test_generate(self):
        with self.assertRaises(NotImplementedError):
            ECDSAKey.generate('NIST256p')

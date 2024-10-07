
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

from tlslite.utils.python_key import Python_Key
from tlslite.utils.python_ecdsakey import Python_ECDSAKey

class TestECDSAKey(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # 45 is not a very good or likely private value but it will work for
        # testing
        cls.key = Python_ECDSAKey(None, None, "NIST256p", 45)

        # sha1 signature of message 'some message to sign'
        cls.sha1_sig = \
                bytearray(b'0E\x02!\x00\xf7Q\x97.\xcfv\x03\xf0\xff,^\xb9'
                          b'\nZ\xbd\x0e\xaaf\xf2]\xe0\xb0\x91\xa6cY\xa9\xff'
                          b'{@\x18\xc8\x02 <\x80\x1a\xfa\x14\xd2\\\x02\xfe'
                          b'\x1a\xb7\x07X\xba\xd8`\xd4\x1d\xa9\x9cm\xc7\xcd'
                          b'\x11\xbb\x1b\xd1A\xcdO\xa2?')

    def test_parse_from_pem(self):
        key = (
            "-----BEGIN EC PRIVATE KEY-----\n"
            "MHcCAQEEIAjma9Dr7NHgpoflzEFg2FabEPrCXY4qv4raf5GJ1jUmoAoGCCqGSM49\n"
            "AwEHoUQDQgAEyDRjEAJe3F5T62MyZbhjoJnPLGL2nrTthLFymBupZ2IbnWYnqVWD\n"
            "kT/L6i8sQhf2zCLrlSjj1kn7ERqPx/KZyg==\n"
            "-----END EC PRIVATE KEY-----\n")

        parsed_key = Python_Key.parsePEM(key)
        self.assertIsInstance(parsed_key, Python_ECDSAKey)
        self.assertTrue(parsed_key.hasPrivateKey())
        self.assertFalse(parsed_key.acceptsPassword())
        self.assertEqual(len(parsed_key), 256)

    def test_python_ecdsa_fields(self):
        self.assertIsInstance(self.key, Python_ECDSAKey)
        self.assertTrue(self.key.hasPrivateKey())
        self.assertFalse(self.key.acceptsPassword())
        self.assertEqual(len(self.key), 256)

    def test_generate(self):
        with self.assertRaises(NotImplementedError):
            Python_ECDSAKey.generate(256)

    def test_sign_default(self):
        msg = b"some message to sign"

        sig = self.key.hashAndSign(msg)

        # we expect deterministic ECDSA by default
        self.assertEqual(sig, self.sha1_sig)

    def test_verify(self):
        msg = b'some message to sign'

        r = self.key.hashAndVerify(self.sha1_sig, msg)

        self.assertTrue(r)

    def test_invalid_curve_name(self):
        with self.assertRaises(ValueError) as e:
            Python_ECDSAKey(None, None, "secp256r1", 45)

        self.assertIn('not supported by python-ecdsa', str(e.exception))

    def test_no_curve_name(self):
        with self.assertRaises(ValueError) as e:
            Python_ECDSAKey(None, None, "", 45)

        self.assertIn("curve_name", str(e.exception))

    def test_sign_and_verify_with_md5(self):
        msg = b"some message to sign"

        sig = self.key.hashAndSign(msg, hAlg="md5")

        self.key.hashAndVerify(sig, msg, hAlg="md5")

    def test_sign_and_verify_with_sha1(self):
        msg = b"some message to sign"

        sig = self.key.hashAndSign(msg, hAlg="sha1")

        self.key.hashAndVerify(sig, msg)

    def test_sign_and_verify_with_sha224(self):
        msg = b"some message to sign"

        sig = self.key.hashAndSign(msg, hAlg="sha224")

        self.key.hashAndVerify(sig, msg, hAlg="sha224")

    def test_sign_and_verify_with_sha256(self):
        msg = b"some message to sign"

        sig = self.key.hashAndSign(msg, hAlg="sha256")

        self.key.hashAndVerify(sig, msg, hAlg="sha256")

    @unittest.expectedFailure
    def test_sign_and_verify_with_sha384(self):
        msg = b"some message to sign"

        sig = self.key.hashAndSign(msg, hAlg="sha384")

        self.key.hashAndVerify(sig, msg, hAlg="sha384")

    @unittest.expectedFailure
    def test_sign_and_verify_with_sha512(self):
        msg = b"some message to sign"

        sig = self.key.hashAndSign(msg, hAlg="sha512")

        self.key.hashAndVerify(sig, msg, hAlg="sha512")

# Author: Anna Khaitovich (c) 2018
# see LICENCE file for legal information regarding use of this file

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest

from tlslite.signed import SignatureSettings, SignedObject, RSA_SIGNATURE_HASHES, RSA_SCHEMES


class TestSignatureSettings(unittest.TestCase):
    def test_signature_settings_validate(self):
        settings = SignatureSettings()
        validated = settings.validate()
        self.assertEqual(validated.min_key_size, 1023)
        self.assertEqual(validated.max_key_size, 8193)
        self.assertEqual(validated.rsa_sig_hashes, RSA_SIGNATURE_HASHES)
        self.assertEqual(validated.rsa_schemes, RSA_SCHEMES)

    def test_signature_settings_min_key_size_small(self):
        settings = SignatureSettings(min_key_size=256)
        with self.assertRaises(ValueError) as ctx:
            settings.validate()
        self.assertIn("min_key_size too small", str(ctx.exception))

    def test_signature_settings_min_key_size_large(self):
        settings = SignatureSettings(min_key_size=17000)
        with self.assertRaises(ValueError) as ctx:
            settings.validate()
        self.assertIn("min_key_size too large", str(ctx.exception))

    def test_signature_settings_max_key_size_small(self):
        settings = SignatureSettings(max_key_size=256)
        with self.assertRaises(ValueError) as ctx:
            settings.validate()
        self.assertIn("max_key_size too small", str(ctx.exception))

    def test_signature_settings_max_key_size_large(self):
        settings = SignatureSettings(max_key_size=17000)
        with self.assertRaises(ValueError) as ctx:
            settings.validate()
        self.assertIn("max_key_size too large", str(ctx.exception))

    def test_signature_settings_min_key_bigger_max_key(self):
        settings = SignatureSettings(min_key_size=2048, max_key_size=1024)
        with self.assertRaises(ValueError) as ctx:
            settings.validate()
        self.assertIn("max_key_size smaller than min_key_size", str(ctx.exception))

    def test_signature_settings_invalid_sig_alg(self):
        settings = SignatureSettings(rsa_sig_hashes=list(['sha1', 'sha128', 'sha129']))
        with self.assertRaises(ValueError) as ctx:
            settings.validate()
        self.assertIn("Following signature algorithms are not allowed: sha128, sha129",
                      str(ctx.exception))
    # verify_signature method testing is happening in the test_tlslite_ocsp.py

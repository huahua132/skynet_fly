# Copyright (c) 2014, Hubert Kario
#
# See the LICENSE file for legal information regarding use of this file.

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest

from tlslite.handshakehashes import HandshakeHashes

class TestHandshakeHashes(unittest.TestCase):
    def test___init__(self):
        hh = HandshakeHashes()

        self.assertIsNotNone(hh)

    def test_update(self):
        hh = HandshakeHashes()
        hh.update(bytearray(10))

    def test_update_with_str(self):
        hh = HandshakeHashes()
        hh.update(b'text')

    def test_digest_SSL3(self):
        hh = HandshakeHashes()

        self.assertEqual(bytearray(
                b'\xb5Q\x15\xa4\xcd\xff\xfdF\xa6\x9c\xe2\x0f\x83~\x948\xc3\xb5'\
                b'\xc1\x8d\xb6|\x10n@a\x97\xccG\xfeI\xa8s T\\'),
                hh.digestSSL(bytearray(48), b''))

    def test_digest_TLS1_0(self):
        hh = HandshakeHashes()

        self.assertEqual(
                b'\xd4\x1d\x8c\xd9\x8f\x00\xb2\x04\xe9\x80\t\x98\xec\xf8B~\xda'\
                b'9\xa3\xee^kK\r2U\xbf\xef\x95`\x18\x90\xaf\xd8\x07\t',
                hh.digest())

    def test_copy(self):
        hh = HandshakeHashes()
        hh.update(b'text')

        hh2 = hh.copy()

        self.assertEqual(hh2.digest(), hh.digest())

    def test_digest_md5(self):
        hh = HandshakeHashes()

        self.assertEqual(
                b"\xd4\x1d\x8c\xd9\x8f\x00\xb2\x04\xe9\x80\t\x98\xec\xf8B~",
                hh.digest('md5'))

    def test_digest_sha1(self):
        hh = HandshakeHashes()

        self.assertEqual(
                b"\xda9\xa3\xee^kK\r2U\xbf\xef\x95`\x18\x90\xaf\xd8\x07\t",
                hh.digest('sha1'))

    def test_digest_sha256(self):
        hh = HandshakeHashes()

        self.assertEqual(
                b"\xe3\xb0\xc4B\x98\xfc\x1c\x14\x9a\xfb\xf4\xc8\x99o\xb9$'\xae"\
                b"A\xe4d\x9b\x93L\xa4\x95\x99\x1bxR\xb8U",
                hh.digest('sha256'))

    def test_digest_sha224(self):
        hh = HandshakeHashes()

        self.assertEqual((
                b'\xd1J\x02\x8c*:+\xc9Ga\x02\xbb(\x824\xc4\x15\xa2\xb0'
                b'\x1f\x82\x8e\xa6*\xc5\xb3\xe4/'),
                hh.digest('sha224'))

    def test_digest_sha512(self):
        hh = HandshakeHashes()

        self.assertEqual((
                b'\xcf\x83\xe15~\xef\xb8\xbd\xf1T(P\xd6m\x80\x07\xd6 '
                b'\xe4\x05\x0bW\x15\xdc\x83\xf4\xa9!\xd3l\xe9\xceG\xd0'
                b'\xd1<]\x85\xf2\xb0\xff\x83\x18\xd2\x87~\xec/c\xb91'
                b'\xbdGAz\x81\xa582z\xf9\'\xda>'),
                hh.digest('sha512'))

    def test_digest_with_partial_writes(self):
        hh = HandshakeHashes()
        hh.update(b'text')

        hh2 = HandshakeHashes()
        hh2.update(b'te')
        hh2.update(b'xt')

        self.assertEqual(hh.digest(), hh2.digest())

    def test_digest_with_invalid_hash(self):
        hh = HandshakeHashes()

        with self.assertRaises(ValueError):
            hh.digest('md2')

    def test_digest_with_repeated_calls(self):
        hh = HandshakeHashes()
        hh.update(b'text')

        self.assertEqual(hh.digest(), hh.digest())

        hh.update(b'ext')

        self.assertEqual(hh.digest('sha256'), hh.digest('sha256'))

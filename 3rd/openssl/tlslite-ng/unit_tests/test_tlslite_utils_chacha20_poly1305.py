# Copyright (c) 2015, Hubert Kario
#
# See the LICENSE file for legal information regarding use of this file.

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
from __future__ import division
try:
        import unittest2 as unittest
except ImportError:
        import unittest

from tlslite.utils.chacha20_poly1305 import CHACHA20_POLY1305

class TestPoly1305(unittest.TestCase):
    def test___init__(self):
        aead = CHACHA20_POLY1305(bytearray(256//8), "python")

        self.assertIsNotNone(aead)

    def test___init___with_invalid_key_size(self):
        with self.assertRaises(ValueError):
            CHACHA20_POLY1305(bytearray(128//8), "python")

    def test___init___with_unsupported_implementation(self):
        with self.assertRaises(ValueError):
            CHACHA20_POLY1305(bytearray(256//8), "pycrypto")

    def test_seal(self):
        aead = CHACHA20_POLY1305(bytearray(
            b'\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e\x8f'
            b'\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e\x9f'
            ), "python")

        plaintext = bytearray(
            b'Ladies and Gentlemen of the class of \'99: If I could offer you o'
            b'nly one tip for the future, sunscreen would be it.')

        aad = bytearray(b'\x50\x51\x52\x53\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7')

        nonce = bytearray(b'\x07\x00\x00\x00\x40\x41\x42\x43\x44\x45\x46\x47')

        ciphertext = aead.seal(nonce, plaintext, aad)

        self.assertEqual(ciphertext, bytearray(
            b'\xd3\x1a\x8d\x34\x64\x8e\x60\xdb\x7b\x86\xaf\xbc\x53\xef\x7e\xc2'
            b'\xa4\xad\xed\x51\x29\x6e\x08\xfe\xa9\xe2\xb5\xa7\x36\xee\x62\xd6'
            b'\x3d\xbe\xa4\x5e\x8c\xa9\x67\x12\x82\xfa\xfb\x69\xda\x92\x72\x8b'
            b'\x1a\x71\xde\x0a\x9e\x06\x0b\x29\x05\xd6\xa5\xb6\x7e\xcd\x3b\x36'
            b'\x92\xdd\xbd\x7f\x2d\x77\x8b\x8c\x98\x03\xae\xe3\x28\x09\x1b\x58'
            b'\xfa\xb3\x24\xe4\xfa\xd6\x75\x94\x55\x85\x80\x8b\x48\x31\xd7\xbc'
            b'\x3f\xf4\xde\xf0\x8e\x4b\x7a\x9d\xe5\x76\xd2\x65\x86\xce\xc6\x4b'
            b'\x61\x16'
            b'\x1a\xe1\x0b\x59\x4f\x09\xe2\x6a\x7e\x90\x2e\xcb\xd0\x60\x06\x91'
            ))

    def test_seal_with_invalid_nonce(self):
        aead = CHACHA20_POLY1305(bytearray(256//8), "python")

        with self.assertRaises(ValueError):
            aead.seal(bytearray(16), bytearray(10), bytearray(10))

    def test_open(self):
        #RFC 7539 Appendix A.5

        key = bytearray(
            b'\x1c\x92\x40\xa5\xeb\x55\xd3\x8a\xf3\x33\x88\x86\x04\xf6\xb5\xf0'
            b'\x47\x39\x17\xc1\x40\x2b\x80\x09\x9d\xca\x5c\xbc\x20\x70\x75\xc0'
            )

        ciphertext = bytearray(
            b'\x64\xa0\x86\x15\x75\x86\x1a\xf4\x60\xf0\x62\xc7\x9b\xe6\x43\xbd'
            b'\x5e\x80\x5c\xfd\x34\x5c\xf3\x89\xf1\x08\x67\x0a\xc7\x6c\x8c\xb2'
            b'\x4c\x6c\xfc\x18\x75\x5d\x43\xee\xa0\x9e\xe9\x4e\x38\x2d\x26\xb0'
            b'\xbd\xb7\xb7\x3c\x32\x1b\x01\x00\xd4\xf0\x3b\x7f\x35\x58\x94\xcf'
            b'\x33\x2f\x83\x0e\x71\x0b\x97\xce\x98\xc8\xa8\x4a\xbd\x0b\x94\x81'
            b'\x14\xad\x17\x6e\x00\x8d\x33\xbd\x60\xf9\x82\xb1\xff\x37\xc8\x55'
            b'\x97\x97\xa0\x6e\xf4\xf0\xef\x61\xc1\x86\x32\x4e\x2b\x35\x06\x38'
            b'\x36\x06\x90\x7b\x6a\x7c\x02\xb0\xf9\xf6\x15\x7b\x53\xc8\x67\xe4'
            b'\xb9\x16\x6c\x76\x7b\x80\x4d\x46\xa5\x9b\x52\x16\xcd\xe7\xa4\xe9'
            b'\x90\x40\xc5\xa4\x04\x33\x22\x5e\xe2\x82\xa1\xb0\xa0\x6c\x52\x3e'
            b'\xaf\x45\x34\xd7\xf8\x3f\xa1\x15\x5b\x00\x47\x71\x8c\xbc\x54\x6a'
            b'\x0d\x07\x2b\x04\xb3\x56\x4e\xea\x1b\x42\x22\x73\xf5\x48\x27\x1a'
            b'\x0b\xb2\x31\x60\x53\xfa\x76\x99\x19\x55\xeb\xd6\x31\x59\x43\x4e'
            b'\xce\xbb\x4e\x46\x6d\xae\x5a\x10\x73\xa6\x72\x76\x27\x09\x7a\x10'
            b'\x49\xe6\x17\xd9\x1d\x36\x10\x94\xfa\x68\xf0\xff\x77\x98\x71\x30'
            b'\x30\x5b\xea\xba\x2e\xda\x04\xdf\x99\x7b\x71\x4d\x6c\x6f\x2c\x29'
            b'\xa6\xad\x5c\xb4\x02\x2b\x02\x70\x9b')

        nonce = bytearray(
            b'\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08')

        aad = bytearray(
            b'\xf3\x33\x88\x86\x00\x00\x00\x00\x00\x00\x4e\x91')

        tag = bytearray(
            b'\xee\xad\x9d\x67\x89\x0c\xbb\x22\x39\x23\x36\xfe\xa1\x85\x1f\x38'
            )

        aead = CHACHA20_POLY1305(key, "python")

        plaintext = aead.open(nonce, ciphertext + tag, aad)

        self.assertEqual(plaintext, bytearray(
            b'Internet-Drafts are draft documents valid for a maximum of six m'
            b'onths and may be updated, replaced, or obsoleted by other docume'
            b'nts at any time. It is inappropriate to use Internet-Drafts as r'
            b'eference material or to cite them other than as /'
            b'\xe2\x80\x9cwork in progress\x2e\x2f\xe2\x80\x9d'))

    def test_open_with_invalid_size_nonce(self):
        aead = CHACHA20_POLY1305(bytearray(256//8), "python")

        with self.assertRaises(ValueError):
            aead.open(bytearray(128//8),
                      bytearray(64),
                      bytearray(0))

    def test_open_with_too_short_ciphertext(self):
        aead = CHACHA20_POLY1305(bytearray(256//8), "python")

        plaintext = aead.open(bytearray(96//8), bytearray(15), bytearray(0))

        self.assertIsNone(plaintext)

    def test_open_with_invalid_tag(self):
        aead = CHACHA20_POLY1305(bytearray(256//8), "python")

        plaintext = aead.open(bytearray(96//8), bytearray(32), bytearray(0))

        self.assertIsNone(plaintext)

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

from tlslite.utils.poly1305 import Poly1305

class TestPoly1305(unittest.TestCase):
    def test___init__(self):
        poly = Poly1305(bytearray(256//8))

        self.assertIsNotNone(poly)

    def test___init___with_wrong_key_size(self):
        with self.assertRaises(ValueError):
            Poly1305(bytearray(128//8))

    def test_le_bytes_to_num_32(self):
        self.assertEqual(0x01020304,
                         Poly1305.le_bytes_to_num(
                             bytearray(b'\x04\x03\x02\x01')))

    def test_le_bytes_to_num_40(self):
        self.assertEqual(0x0001020304,
                         Poly1305.le_bytes_to_num(
                             bytearray(b'\x04\x03\x02\x01\x00')))

    def test_le_bytes_to_num_64(self):
        self.assertEqual(0x0102030405060708,
                         Poly1305.le_bytes_to_num(
                             bytearray(b'\x08\x07\x06\x05\x04\x03\x02\x01')))

    def test_le_bytes_to_num_72(self):
        self.assertEqual(0x0a0102030405060708,
                         Poly1305.le_bytes_to_num(
                             bytearray(b'\x08\x07\x06\x05\x04\x03\x02\x01\x0a')))

    def test_num_to_16_le_bytes(self):
        self.assertEqual(bytearray(
            b'\x04\x03\x02\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
            ), Poly1305.num_to_16_le_bytes(0x01020304))

    def test_generate_tag(self):
        poly = Poly1305(bytearray(
            b'\x85\xd6\xbe\x78\x57\x55\x6d\x33\x7f\x44\x52\xfe\x42\xd5\x06\xa8'
            b'\x01\x03\x80\x8a\xfb\x0d\xb2\xfd\x4a\xbf\xf6\xaf\x41\x49\xf5\x1b'
            ))

        message = bytearray(b'Cryptographic Forum Research Group')

        tag = poly.create_tag(message)

        self.assertEqual(tag, bytearray(
            b'\xa8\x06\x1d\xc1\x30\x51\x36\xc6\xc2\x2b\x8b\xaf\x0c\x01\x27\xa9'
            ))

    def test_vector1(self):
        #RFC 7539 Appendix A.3 vector #1
        poly = Poly1305(bytearray(32))

        message = bytearray(64)

        tag = poly.create_tag(message)

        self.assertEqual(tag, bytearray(16))

    ietf_text = bytearray(
        b'Any submission to the IETF intended by the Contributor for publi'
        b'cation as all or part of an IETF Internet-Draft or RFC and any s'
        b'tatement made within the context of an IETF activity is consider'
        b'ed an "IETF Contribution". Such statements include oral statemen'
        b'ts in IETF sessions, as well as written and electronic communica'
        b'tions made at any time or place, which are addressed to')

    def test_vector2(self):
        #RFC 7539 Appendix A.3 vector #2
        poly = Poly1305(bytearray(16) + bytearray(
            b'\x36\xe5\xf6\xb5\xc5\xe0\x60\x70\xf0\xef\xca\x96\x22\x7a\x86\x3e'
            ))

        tag = poly.create_tag(self.ietf_text)

        self.assertEqual(tag, bytearray(
            b'\x36\xe5\xf6\xb5\xc5\xe0\x60\x70\xf0\xef\xca\x96\x22\x7a\x86\x3e'
            ))

    def test_vector3(self):
        #RFC 7539 Appendix A.3 vector #3
        poly = Poly1305(bytearray(
            b'\x36\xe5\xf6\xb5\xc5\xe0\x60\x70\xf0\xef\xca\x96\x22\x7a\x86\x3e'
            ) + bytearray(16))

        tag = poly.create_tag(self.ietf_text)

        self.assertEqual(tag, bytearray(
            b'\xf3\x47\x7e\x7c\xd9\x54\x17\xaf\x89\xa6\xb8\x79\x4c\x31\x0c\xf0'
            ))

    def test_vector4(self):
        #RFC 7539 Appendix A.3 vector #4
        poly = Poly1305(bytearray(
            b'\x1c\x92\x40\xa5\xeb\x55\xd3\x8a\xf3\x33\x88\x86\x04\xf6\xb5\xf0'
            b'\x47\x39\x17\xc1\x40\x2b\x80\x09\x9d\xca\x5c\xbc\x20\x70\x75\xc0'
            ))

        message = bytearray(
            b'\x27\x54\x77\x61\x73\x20\x62\x72\x69\x6c\x6c\x69\x67\x2c\x20\x61'
            b'\x6e\x64\x20\x74\x68\x65\x20\x73\x6c\x69\x74\x68\x79\x20\x74\x6f'
            b'\x76\x65\x73\x0a\x44\x69\x64\x20\x67\x79\x72\x65\x20\x61\x6e\x64'
            b'\x20\x67\x69\x6d\x62\x6c\x65\x20\x69\x6e\x20\x74\x68\x65\x20\x77'
            b'\x61\x62\x65\x3a\x0a\x41\x6c\x6c\x20\x6d\x69\x6d\x73\x79\x20\x77'
            b'\x65\x72\x65\x20\x74\x68\x65\x20\x62\x6f\x72\x6f\x67\x6f\x76\x65'
            b'\x73\x2c\x0a\x41\x6e\x64\x20\x74\x68\x65\x20\x6d\x6f\x6d\x65\x20'
            b'\x72\x61\x74\x68\x73\x20\x6f\x75\x74\x67\x72\x61\x62\x65\x2e')

        self.assertEqual(len(message), 112+15)

        tag = poly.create_tag(message)

        self.assertEqual(tag, bytearray(
            b'\x45\x41\x66\x9a\x7e\xaa\xee\x61\xe7\x08\xdc\x7c\xbc\xc5\xeb\x62'
            ))

    def test_vector5(self):
        #RFC 7539 Appendix A.3 vector #5
        poly = Poly1305(bytearray(b'\x02' + b'\x00'*31))

        message = bytearray(b'\xff'*16)

        tag = poly.create_tag(message)

        self.assertEqual(tag, bytearray(b'\x03' + b'\x00'*15))

    def test_vector6(self):
        #RFC 7539 Appendix A.3 vector #6
        poly = Poly1305(bytearray(b'\x02' + b'\x00'*15 + b'\xff'*16))

        message = bytearray(b'\x02' + b'\x00'*15)

        tag = poly.create_tag(message)

        self.assertEqual(tag, bytearray(b'\x03' + b'\x00'*15))

    def test_vector7(self):
        #RFC 7539 Appendix A.3 vector #7
        poly = Poly1305(bytearray(b'\x01' + b'\x00'*31))

        message = bytearray(b'\xff'*16 + b'\xf0' + b'\xff'*15 + b'\x11' +
                            b'\x00'*15)

        tag = poly.create_tag(message)

        self.assertEqual(tag, bytearray(b'\x05' + b'\x00'*15))

    def test_vector8(self):
        #RFC 7539 Appendix A.3 vector #8
        poly = Poly1305(bytearray(b'\x01' + b'\x00'*31))

        message = bytearray(b'\xff'*16 + b'\xfb' + b'\xfe'*15 + b'\x01'*16)

        tag = poly.create_tag(message)

        self.assertEqual(tag, bytearray(b'\x00'*16))

    def test_vector9(self):
        #RFC 7539 Appendix A.3 vector #9
        poly = Poly1305(bytearray(b'\x02' + b'\x00'*31))

        message = bytearray(b'\xfd' + b'\xff'*15)

        tag = poly.create_tag(message)

        self.assertEqual(tag, bytearray(b'\xfa' + b'\xff'*15))

    def test_vector10(self):
        #RFC 7539 Appendix A.3 vector #10
        poly = Poly1305(bytearray(b'\x01' + b'\x00'*7 + b'\x04' + b'\x00'*23))

        message = bytearray(
            b'\xE3\x35\x94\xD7\x50\x5E\x43\xB9\x00\x00\x00\x00\x00\x00\x00\x00'
            b'\x33\x94\xD7\x50\x5E\x43\x79\xCD\x01\x00\x00\x00\x00\x00\x00\x00'
            b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
            b'\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
            )

        tag = poly.create_tag(message)

        self.assertEqual(tag, bytearray(b'\x14' + b'\x00'*7 +
                                        b'\x55' + b'\x00'*7))

    def test_vector11(self):
        #RFC 7539 Appendix A.3 vector #11
        poly = Poly1305(bytearray(b'\x01' + b'\x00'*7 + b'\x04' + b'\x00'*23))

        message = bytearray(
            b'\xE3\x35\x94\xD7\x50\x5E\x43\xB9\x00\x00\x00\x00\x00\x00\x00\x00'
            b'\x33\x94\xD7\x50\x5E\x43\x79\xCD\x01\x00\x00\x00\x00\x00\x00\x00'
            b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
            )

        tag = poly.create_tag(message)

        self.assertEqual(tag, bytearray(b'\x13' + b'\x00'*15))

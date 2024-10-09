
# Copyright (c) 2014, Hubert Kario
#
# See the LICENSE file for legal information regarding use of this file.

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest

from tlslite.utils.ecc import decodeX962Point, encodeX962Point, getCurveByName,\
        getPointByteSize
import ecdsa

class TestEncoder(unittest.TestCase):
    def test_encode_P_256_point(self):
        point = ecdsa.NIST256p.generator * 200

        self.assertEqual(encodeX962Point(point),
                         bytearray(b'\x04'
                                   # x coordinate
                                   b'\x3a\x53\x5b\xd0\xbe\x46\x6f\xf3\xd8\x56'
                                   b'\xa0\x77\xaa\xd9\x50\x4f\x16\xaa\x5d\x52'
                                   b'\x28\xfc\xd7\xc2\x77\x48\x85\xee\x21\x3f'
                                   b'\x3b\x34'
                                   # y coordinate
                                   b'\x66\xab\xa8\x18\x5b\x33\x41\xe0\xc2\xe3'
                                   b'\xd1\xb3\xae\x69\xe4\x7d\x0f\x01\xd4\xbb'
                                   b'\xd7\x06\xd9\x57\x8b\x0b\x65\xd6\xd3\xde'
                                   b'\x1e\xfe'
                                   ))

    def test_encode_P_256_point_with_zero_first_byte_on_x(self):
        point = ecdsa.NIST256p.generator * 379

        self.assertEqual(encodeX962Point(point),
                         bytearray(b'\x04'
                                   b'\x00\x55\x43\x89\x4a\xf3\xd0\x0e\xd7\xd7'
                                   b'\x40\xab\xdb\xd7\x5c\x96\xb0\x68\x77\xb7'
                                   b'\x87\xdb\x5f\x70\xee\xa7\x8b\x90\xa8\xd7'
                                   b'\xc0\x0a'
                                   b'\xbb\x4c\x85\xa3\xd8\xea\x29\xef\xaa\xfa'
                                   b'\x24\x40\x69\x12\xdd\x84\xd5\xb1\x4d\xc3'
                                   b'\x2b\xf6\x56\xef\x6c\x6b\xd5\x8a\x5d\x94'
                                   b'\x3f\x92'
                                   ))

    def test_encode_P_256_point_with_zero_first_byte_on_y(self):
        point = ecdsa.NIST256p.generator * 43

        self.assertEqual(encodeX962Point(point),
                         bytearray(b'\x04'
                                   b'\x98\x6a\xe2\x50\x6f\x1f\xf1\x04\xd0\x42'
                                   b'\x30\x86\x1d\x8f\x4b\x49\x8f\x4b\xc4\xc6'
                                   b'\xd0\x09\xb3\x0f\x75\x44\xdc\x12\x9b\x82'
                                   b'\xd2\x8d'
                                   b'\x00\x3c\xcc\xc0\xa6\x46\x0e\x0a\xe3\x28'
                                   b'\xa4\xd9\x7d\x3c\x7b\x61\xd8\x6f\xc6\x28'
                                   b'\x9c\x18\x9f\x25\x25\x11\x0c\x44\x1b\xb0'
                                   b'\x7e\x97'
                                   ))

    def test_encode_P_256_point_with_two_zero_first_bytes_on_x(self):
        point = ecdsa.NIST256p.generator * 40393

        self.assertEqual(encodeX962Point(point),
                         bytearray(b'\x04'
                                   b'\x00\x00\x3f\x5f\x17\x8a\xa0\x70\x6c\x42'
                                   b'\x31\xeb\x6e\x54\x95\xaa\x16\x42\xc5\xb8'
                                   b'\xa9\x94\x12\x7c\x89\x46\x5f\x22\x99\x4a'
                                   b'\x42\xf9'
                                   b'\xc2\x48\xb3\x37\x59\x9f\x0c\x2f\x29\x77'
                                   b'\x2e\x25\x6f\x1d\x55\x49\xc8\x9b\xa9\xe5'
                                   b'\x73\x13\x82\xcd\x1e\x3c\xc0\x9d\x10\xd0'
                                   b'\x0b\x55'))

    def test_encode_P_521_point(self):
        point = ecdsa.NIST521p.generator * 200

        self.assertEqual(encodeX962Point(point),
                         bytearray(b'\x04'
                                   b'\x00\x3e\x2a\x2f\x9f\xd5\x9f\xc3\x8d\xfb'
                                   b'\xde\x77\x26\xa0\xbf\xc6\x48\x2a\x6b\x2a'
                                   b'\x86\xf6\x29\xb8\x34\xa0\x6c\x3d\x66\xcd'
                                   b'\x79\x8d\x9f\x86\x2e\x89\x31\xf7\x10\xc7'
                                   b'\xce\x89\x15\x9f\x35\x8b\x4a\x5c\x5b\xb3'
                                   b'\xd2\xcc\x9e\x1b\x6e\x94\x36\x23\x6d\x7d'
                                   b'\x6a\x5e\x00\xbc\x2b\xbe'
                                   b'\x01\x56\x7a\x41\xcb\x48\x8d\xca\xd8\xe6'
                                   b'\x3a\x3f\x95\xb0\x8a\xf6\x99\x2a\x69\x6a'
                                   b'\x37\xdf\xc6\xa1\x93\xff\xbc\x3f\x91\xa2'
                                   b'\x96\xf3\x3c\x66\x15\x57\x3c\x1c\x06\x7f'
                                   b'\x0a\x06\x4d\x18\xbd\x0c\x81\x4e\xf7\x2a'
                                   b'\x8f\x76\xf8\x7f\x9b\x7d\xff\xb2\xf4\x26'
                                   b'\x36\x43\x43\x86\x11\x89'))

class TestDecoder(unittest.TestCase):
    def test_decode_P_256_point(self):
        point = ecdsa.NIST256p.generator * 379
        data = bytearray(b'\x04'
                         b'\x00\x55\x43\x89\x4a\xf3\xd0\x0e\xd7\xd7'
                         b'\x40\xab\xdb\xd7\x5c\x96\xb0\x68\x77\xb7'
                         b'\x87\xdb\x5f\x70\xee\xa7\x8b\x90\xa8\xd7'
                         b'\xc0\x0a'
                         b'\xbb\x4c\x85\xa3\xd8\xea\x29\xef\xaa\xfa'
                         b'\x24\x40\x69\x12\xdd\x84\xd5\xb1\x4d\xc3'
                         b'\x2b\xf6\x56\xef\x6c\x6b\xd5\x8a\x5d\x94'
                         b'\x3f\x92'
                         )

        decoded_point = decodeX962Point(data, ecdsa.NIST256p)

        self.assertEqual(point, decoded_point)

    def test_decode_P_521_point(self):

        data = bytearray(b'\x04'
                         b'\x01\x7d\x8a\x5d\x11\x03\x4a\xaf\x01\x26'
                         b'\x5f\x2d\xd6\x2d\x76\xeb\xd8\xbe\x4e\xfb'
                         b'\x3b\x4b\xd2\x05\x5a\xed\x4c\x6d\x20\xc7'
                         b'\xf3\xd7\x08\xab\x21\x9e\x34\xfd\x14\x56'
                         b'\x3d\x47\xd0\x02\x65\x15\xc2\xdd\x2d\x60'
                         b'\x66\xf9\x15\x64\x55\x7a\xae\x56\xa6\x7a'
                         b'\x28\x51\x65\x26\x5c\xcc'
                         b'\x01\xd4\x19\x56\xfa\x14\x6a\xdb\x83\x1c'
                         b'\xb6\x1a\xc4\x4b\x40\xb1\xcb\xcc\x9e\x4f'
                         b'\x57\x2c\xb2\x72\x70\xb9\xef\x38\x15\xae'
                         b'\x87\x1f\x85\x40\x94\xda\x69\xed\x97\xeb'
                         b'\xdc\x72\x25\x25\x61\x76\xb2\xde\xed\xa2'
                         b'\xb0\x5c\xca\xc4\x83\x8f\xfb\x54\xae\xe0'
                         b'\x07\x45\x0b\xbf\x7c\xfc')

        point = decodeX962Point(data, ecdsa.NIST521p)
        self.assertIsNotNone(point)

        self.assertEqual(encodeX962Point(point), data)

    def test_decode_with_missing_data(self):
        data = bytearray(b'\x04'
                         b'\x00\x55\x43\x89\x4a\xf3\xd0\x0e\xd7\xd7'
                         b'\x40\xab\xdb\xd7\x5c\x96\xb0\x68\x77\xb7'
                         b'\x87\xdb\x5f\x70\xee\xa7\x8b\x90\xa8\xd7'
                         b'\xc0\x0a'
                         b'\xbb\x4c\x85\xa3\xd8\xea\x29\xef\xaa\xfa'
                         b'\x24\x40\x69\x12\xdd\x84\xd5\xb1\x4d\xc3'
                         b'\x2b\xf6\x56\xef\x6c\x6b\xd5\x8a\x5d\x94'
                         #b'\x3f\x92'
                         )

        # XXX will change later as decoder in tlslite-ng needs to be updated
        with self.assertRaises(SyntaxError):
            decodeX962Point(data, ecdsa.NIST256p)

class TestCurveLookup(unittest.TestCase):
    def test_with_correct_name(self):
        curve = getCurveByName('secp256r1')
        self.assertIs(curve, ecdsa.NIST256p)

    def test_with_invalid_name(self):
        with self.assertRaises(ValueError):
            getCurveByName('NIST256p')

class TestGetPointByteSize(unittest.TestCase):
    def test_with_curve(self):
        self.assertEqual(getPointByteSize(ecdsa.NIST256p), 32)

    def test_with_point(self):
        self.assertEqual(getPointByteSize(ecdsa.NIST384p.generator * 10), 48)

    def test_with_invalid_argument(self):
        with self.assertRaises(ValueError):
            getPointByteSize("P-256")

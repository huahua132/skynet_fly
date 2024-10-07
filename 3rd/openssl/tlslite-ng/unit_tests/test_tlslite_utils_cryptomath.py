# Copyright (c) 2014, Hubert Kario
#
# See the LICENSE file for legal information regarding use of this file.

# compatibility with Python 2.6, for that we need unittest2 package,
# which is not available on 3.3 or 3.4
try:
    import unittest2 as unittest
except ImportError:
    import unittest
from hypothesis import given, example
from hypothesis.strategies import integers
import math
import struct

from tlslite.utils.cryptomath import isPrime, numBits, numBytes, \
        numberToByteArray, MD5, SHA1, secureHash, HMAC_MD5, HMAC_SHA1, \
        HMAC_SHA256, HMAC_SHA384, HKDF_expand, bytesToNumber, \
        HKDF_expand_label, derive_secret, numberToMPI, mpiToNumber, \
        getRandomPrime, getRandomSafePrime, powMod
from tlslite.handshakehashes import HandshakeHashes

class TestIsPrime(unittest.TestCase):
    def test_with_small_primes(self):
        self.assertTrue(isPrime(3))
        self.assertTrue(isPrime(5))
        self.assertTrue(isPrime(7))
        self.assertTrue(isPrime(11))

    def test_with_small_composites(self):
        self.assertFalse(isPrime(4))
        self.assertFalse(isPrime(6))
        self.assertFalse(isPrime(9))
        self.assertFalse(isPrime(10))

    def test_with_hard_primes_to_test(self):

        # XXX Rabin-Miller fails to properly detect following composites
        with self.assertRaises(AssertionError):
            for i in range(100):
                # OEIS A014233
                self.assertFalse(isPrime(2047))  # base 1
                self.assertFalse(isPrime(1373653))  # base 2
                self.assertFalse(isPrime(25326001))  # base 3
                self.assertFalse(isPrime(3215031751))  # base 4
                self.assertFalse(isPrime(2152302898747))  # base 5
                self.assertFalse(isPrime(3474749660383))  # base 6
                self.assertFalse(isPrime(341550071728321))  # base 7
                self.assertFalse(isPrime(341550071728321))  # base 8
                self.assertFalse(isPrime(3825123056546413051))  # base 9
                self.assertFalse(isPrime(3825123056546413051))  # base 10
                self.assertFalse(isPrime(3825123056546413051))  # base 11
                # Zhang (2007)
                self.assertFalse(isPrime(318665857834031151167461))  # base 12
                self.assertFalse(isPrime(3317044064679887385961981))  # base 13
                # base 14
                self.assertFalse(isPrime(6003094289670105800312596501))
                # base 15
                self.assertFalse(isPrime(59276361075595573263446330101))
                # base 16
                self.assertFalse(isPrime(564132928021909221014087501701))
                # base 17
                self.assertFalse(isPrime(564132928021909221014087501701))
                # base 18
                self.assertFalse(isPrime(1543267864443420616877677640751301))
                # base 19
                self.assertFalse(isPrime(1543267864443420616877677640751301))
                # F. Arnault "Constructing Carmichael Numbers Which Are Strong
                # Pseudoprimes to Several Bases". Journal of Symbolic
                # Computation. 20 (2): 151-161. doi:10.1006/jsco.1995.1042.
                # Section 4.4 Large Example (a pseudoprime to all bases up to
                # 300)
                p = int("29 674 495 668 685 510 550 154 174 642 905 332 730 "
                        "771 991 799 853 043 350 995 075 531 276 838 753 171 "
                        "770 199 594 238 596 428 121 188 033 664 754 218 345 "
                        "562 493 168 782 883".replace(" ", ""))
                self.assertTrue(isPrime(p))
                self.assertFalse(p * (313 * (p - 1) + 1) * (353 * (p - 1) + 1))

    def test_with_big_primes(self):
        # NextPrime[2^256]
        self.assertTrue(isPrime(115792089237316195423570985008687907853269984665640564039457584007913129640233))
        # NextPrime[2^1024]
        self.assertTrue(isPrime(179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137859))

    def test_with_big_composites(self):
        # NextPrime[2^256]-2 (factors: 71, 1559, 4801, 7703, 28286...8993)
        self.assertFalse(isPrime(115792089237316195423570985008687907853269984665640564039457584007913129640233-2))
        # NextPrime[2^256]+2 (factors: 3^2, 5, 7, 11, 1753, 19063..7643)
        self.assertFalse(isPrime(115792089237316195423570985008687907853269984665640564039457584007913129640233+2))
        # NextPrime[2^1024]-2
        self.assertFalse(isPrime(179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137859-2))
        # NextPrime[2^1024]+2
        self.assertFalse(isPrime(179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639474124377767893424865485276302219601246094119453082952085005768838150682342462881473913110540827237163350510684586298239947245938479716304835356329624224137859+2))
        # NextPrime[NextPrime[2^512]]*NextPrime[2^512]
        self.assertFalse(isPrime(179769313486231590772930519078902473361797697894230657273430081157732675805500963132708477322407536021120113879871393357658789768814416622492847430639477074095512480796227391561801824887394139579933613278628104952355769470429079061808809522886423955917442317693387325171135071792698344550223571732405562649211))

class TestNumberToBytesFunctions(unittest.TestCase):
    def test_numberToByteArray(self):
        self.assertEqual(numberToByteArray(0x00000000000001),
                         bytearray(b'\x01'))

    def test_numberToByteArray_with_MSB_number(self):
        self.assertEqual(numberToByteArray(0xff),
                         bytearray(b'\xff'))

    def test_numberToByteArray_with_length(self):
        self.assertEqual(numberToByteArray(0xff, 2),
                         bytearray(b'\x00\xff'))

    def test_numberToByteArray_with_not_enough_length(self):
        self.assertEqual(numberToByteArray(0x0a0b0c, 2),
                         bytearray(b'\x0b\x0c'))

    @given(integers(min_value=0, max_value=0xff))
    @example(0)
    @example(0xff)
    def test_small_number(self, number):
        self.assertEqual(numberToByteArray(number, 1),
                         bytearray(struct.pack(">B", number)))

    @given(integers(min_value=0, max_value=0xffffffff))
    @example(0xffffffff)
    def test_big_number(self, number):
        self.assertEqual(numberToByteArray(number, 4),
                         bytearray(struct.pack(">L", number)))

    def test_very_large_number(self):
        self.assertEqual(numberToByteArray((1<<128)-1),
                         bytearray(b'\xff'*16))

    @given(integers(min_value=0, max_value=0xff))
    @example(0)
    @example(0xff)
    def test_small_number_little_endian(self, number):
        self.assertEqual(numberToByteArray(number, 1, endian="little"),
                         bytearray(struct.pack("<B", number)))

    @given(integers(min_value=0, max_value=0xffffffff))
    @example(0xffffffff)
    def test_big_number(self, number):
        self.assertEqual(numberToByteArray(number, 4, endian="little"),
                         bytearray(struct.pack("<L", number)))

    def test_very_large_number(self):
        self.assertEqual(numberToByteArray((1<<128)-1, endian="little"),
                         bytearray(b'\xff'*16))

    def test_numberToByteArray_with_not_enough_length_little_endian(self):
        self.assertEqual(numberToByteArray(0x0a0b0c, 2, endian="little"),
                         bytearray(b'\x0c\x0b'))

    def test_with_large_number_of_bytes_in_little_endian(self):
        self.assertEqual(numberToByteArray(1, 16, endian="little"),
                         bytearray(b'\x01' + b'\x00'*15))

    def test_with_bad_endian_type(self):
        with self.assertRaises(ValueError):
            numberToByteArray(1, endian="middle")

class TestNumBits(unittest.TestCase):

    @staticmethod
    def num_bits(number):
        if number == 0:
            return 0
        return len(bin(number).lstrip('-0b'))

    @staticmethod
    def num_bytes(number):
        if number == 0:
            return 0
        return (TestNumBits.num_bits(number) + 7) // 8

    @given(integers(min_value=0, max_value=1<<16384))
    @example(0)
    @example(255)
    @example(256)
    @example((1<<1024)-1)
    @example((1<<521)-1)
    @example(1<<8192)
    @example((1<<8192)-1)
    def test_numBits(self, number):
        self.assertEqual(numBits(number), self.num_bits(number))

    @given(integers(min_value=0, max_value=1<<16384))
    @example(0)
    @example(255)
    @example(256)
    @example((1<<1024)-1)
    @example((1<<521)-1)
    @example(1<<8192)
    @example((1<<8192)-1)
    def test_numBytes(self, number):
        self.assertEqual(numBytes(number), self.num_bytes(number))


class TestPowMod(unittest.TestCase):
    def test_with_small_numbers(self):
        self.assertEqual(2**10, powMod(2, 10, 10**6))

    def test_with_mod(self):
        self.assertEqual(4, powMod(3, 10, 5))
        self.assertEqual(2, powMod(3, 11, 5))


class TestHMACMethods(unittest.TestCase):
    def test_HMAC_MD5(self):
        self.assertEqual(HMAC_MD5(b'abc', b'def'),
                         bytearray(b'\xde\xbd\xa7{|\xc3\xe7\xa1\x0e\xe7'
                                   b'\x01\x04\xe6qzk'))

    def test_HMAC_SHA1(self):
        self.assertEqual(HMAC_SHA1(b'abc', b'def'),
                         bytearray(b'\x12UN\xab\xba\xf7\xe8\xe1.G7\x02'
                                   b'\x0f\x98|\xa7\x90\x10\x16\xe5'))

    def test_HMAC_SHA256(self):
        self.assertEqual(HMAC_SHA256(b'abc', b'def'),
                         bytearray(b' \xeb\xc0\xf0\x93DG\x014\xf3P@\xf6>'
                                   b'\xa9\x8b\x1d\x8eAB\x12\x94\x9e\xe5'
                                   b'\xc5\x00B'
                                   b'\x9d\x15\xea\xb0\x81'))

    def test_HMAC_SHA384(self):
        self.assertEqual(HMAC_SHA384(b'abc', b'def'),
                         bytearray(b'\xec\x14\xd6\x94\x86\tHp\x84\x07\xect\x0e'
                                   b'\t~\x85?\xe8\xfd\xba\xd4\x86s\x05\xaa\xe8'
                                   b'\xfcB\xd0\xe8\xaa\xa6V\xe07\x9e\xc5\xc9n'
                                   b'\x15\x97\xe0\xbc\xefZ\xa6\xdb\x05'))

    def test_HMAC_expand_1(self):
        # RFC 5869 Appendix A.1 Test Vector 1
        self.assertEqual(HKDF_expand(numberToByteArray(int('0x077709362c2e32df'
                                                           '0ddc3f0dc47bba6390'
                                                           'b6c73bb50f9c3122ec'
                                                           '844ad7c2b3e5',
                                                           16), 32),
                                     numberToByteArray(0xf0f1f2f3f4f5f6f7f8f9,
                                                       10), 42, 'sha256'),
                         numberToByteArray(int('0x3cb25f25faacd57a90434f64d036'
                                               '2f2a2d2d0a90cf1a5a4c5db02d56ec'
                                               'c4c5bf34007208d5b887185865',
                                               16), 42))

    def test_HMAC_expand_2(self):
        # RFC 5869 Appendix A.2 Test Vector 2
        self.assertEqual(HKDF_expand(
            numberToByteArray(int('0x06a6b88c5853361a06104c9ceb35b45cef7600149'
                                  '04671014a193f40c15fc244', 16), 32),
                                     numberToByteArray(int('0xb0b1b2b3b4b5b6b7'
                                                           'b8b9babbbcbdbebfc0'
                                                           'c1c2c3c4c5c6c7c8c9'
                                                           'cacbcccdcecfd0d1d2'
                                                           'd3d4d5d6d7d8d9dadb'
                                                           'dcdddedfe0e1e2e3e4'
                                                           'e5e6e7e8e9eaebeced'
                                                           'eeeff0f1f2f3f4f5f6'
                                                           'f7f8f9fafbfcfdf'
                                                           'eff', 16),
                                                       80), 82, 'sha256'),
                         numberToByteArray(int('0xb11e398dc80327a1c8e7f78c596a'
                                               '49344f012eda2d4efad8a050cc4c19'
                                               'afa97c59045a99cac7827271cb41c6'
                                               '5e590e09da3275600c2f09b8367793'
                                               'a9aca3db71cc30c58179ec3e87c14c'
                                               '01d5c1f3434f1d87', 16), 82))

    def test_HMAC_expand_3(self):
        # RFC 5869 Appendix A.3 Test Vector 3
        self.assertEqual(HKDF_expand(numberToByteArray(int('0x19ef24a32c717b16'
                                                           '7f33a91d6f648bdf96'
                                                           '596776afdb6377ac43'
                                                           '4c1c293ccb04', 16),
                                                       32), bytearray(),
                                     42, 'sha256'),
                         numberToByteArray(int('0x8da4e775a563c18f715f802a063c'
                                               '5a31b8a11f5c5ee1879ec3454e5f3c'
                                               '738d2d9d201395faa4b61a96c8',
                                               16), 42))

    def test_HMAC_expand_4(self):
        # RFC 5869 Appendix A.4 Test Vector 4
        self.assertEqual(HKDF_expand(numberToByteArray(int('0x9b6c18c432a7bf8f'
                                                           '0e71c8eb88f4b30baa'
                                                           '2ba243', 16), 20),
                                     numberToByteArray(int('0xf0f1f2f3f4f5f6f7'
                                                           'f8f9', 16),
                                                       10), 42, 'sha1'),
                         numberToByteArray(int('0x085a01ea1b10f36933068b56efa5'
                                               'ad81a4f14b822f5b091568a9cdd4f1'
                                               '55fda2c22e422478d305f3f896',
                                               16), 42))

    def test_HMAC_expand_5(self):
        # RFC 5869 Appendix A.5 Test Vector 5
        self.assertEqual(HKDF_expand(numberToByteArray(int('0x8adae09a2a307059'
                                                           '478d309b26c4115a22'
                                                           '4cfaf6', 16), 20),
                                     numberToByteArray(int('0xb0b1b2b3b4b5b6b7'
                                                           'b8b9babbbcbdbebfc0'
                                                           'c1c2c3c4c5c6c7c8c9'
                                                           'cacbcccdcecfd0d1d2'
                                                           'd3d4d5d6d7d8d9dadb'
                                                           'dcdddedfe0e1e2e3e4'
                                                           'e5e6e7e8e9eaebeced'
                                                           'eeeff0f1f2f3f4f5f6'
                                                           'f7f8f9fafbfcfdfe'
                                                           'ff', 16), 80),
                                     82, 'sha1'),
                         numberToByteArray(int('0x0bd770a74d1160f7c9f12cd5912a'
                                               '06ebff6adcae899d92191fe4305673'
                                               'ba2ffe8fa3f1a4e5ad79f3f334b3b2'
                                               '02b2173c486ea37ce3d397ed034c7f'
                                               '9dfeb15c5e927336d0441f4c4300e2'
                                               'cff0d0900b52d3b4', 16), 82))

    def test_HMAC_expand_6(self):
        # RFC 5869 Appendix A.6 Test Vector 6
        self.assertEqual(HKDF_expand(numberToByteArray(int('0xda8c8a73c7fa7728'
                                                           '8ec6f5e7c297786aa0'
                                                           'd32d01', 16), 20),
                                     bytearray(), 42, 'sha1'),
                         numberToByteArray(int('0x0ac1af7002b3d761d1e55298da9d'
                                               '0506b9ae52057220a306e07b6b87e8'
                                               'df21d0ea00033de03984d34918',
                                               16), 42))

    def test_HMAC_expand_7(self):
        # RFC 5869 Appendix A.7 Test Vector 7
        self.assertEqual(HKDF_expand(numberToByteArray(int('0x2adccada18779e7c'
                                                           '2077ad2eb19d3f3e73'
                                                           '1385dd', 16), 20),
                                     bytearray(), 42, 'sha1'),
                         numberToByteArray(int('0x2c91117204d745f3500d636a62f6'
                                               '4f0ab3bae548aa53d423b0d1f27ebb'
                                               'a6f5e5673a081d70cce7acfc48',
                                               16), 42))

class TestHashMethods(unittest.TestCase):
    def test_MD5(self):
        self.assertEqual(MD5(b"message digest"),
                         bytearray(b'\xf9\x6b\x69\x7d\x7c\xb7\x93\x8d'
                                   b'\x52\x5a\x2f\x31\xaa\xf1\x61\xd0'))

    def test_SHA1(self):
        self.assertEqual(SHA1(b'abc'),
                         bytearray(b'\xA9\x99\x3E\x36'
                                   b'\x47\x06\x81\x6A'
                                   b'\xBA\x3E\x25\x71'
                                   b'\x78\x50\xC2\x6C'
                                   b'\x9C\xD0\xD8\x9D'))
    def test_SHA224(self):
        self.assertEqual(secureHash(b'abc', 'sha224'),
                         bytearray(b'\x23\x09\x7D\x22'
                                   b'\x34\x05\xD8\x22'
                                   b'\x86\x42\xA4\x77'
                                   b'\xBD\xA2\x55\xB3'
                                   b'\x2A\xAD\xBC\xE4'
                                   b'\xBD\xA0\xB3\xF7'
                                   b'\xE3\x6C\x9D\xA7'))

    def test_SHA256(self):
        self.assertEqual(secureHash(b'abc', 'sha256'),
                         bytearray(b'\xBA\x78\x16\xBF'
                                   b'\x8F\x01\xCF\xEA'
                                   b'\x41\x41\x40\xDE'
                                   b'\x5D\xAE\x22\x23'
                                   b'\xB0\x03\x61\xA3'
                                   b'\x96\x17\x7A\x9C'
                                   b'\xB4\x10\xFF\x61'
                                   b'\xF2\x00\x15\xAD'))

    def test_SHA384(self):
        self.assertEqual(secureHash(b'abc', 'sha384'),
                         bytearray(b'\xCB\x00\x75\x3F'
                                   b'\x45\xA3\x5E\x8B'
                                   b'\xB5\xA0\x3D\x69'
                                   b'\x9A\xC6\x50\x07'
                                   b'\x27\x2C\x32\xAB'
                                   b'\x0E\xDE\xD1\x63'
                                   b'\x1A\x8B\x60\x5A'
                                   b'\x43\xFF\x5B\xED'
                                   b'\x80\x86\x07\x2B'
                                   b'\xA1\xE7\xCC\x23'
                                   b'\x58\xBA\xEC\xA1'
                                   b'\x34\xC8\x25\xA7'))

    def test_SHA512(self):
        self.assertEqual(secureHash(b'abc', 'sha512'),
                         bytearray(b'\xDD\xAF\x35\xA1'
                                   b'\x93\x61\x7A\xBA'
                                   b'\xCC\x41\x73\x49'
                                   b'\xAE\x20\x41\x31'
                                   b'\x12\xE6\xFA\x4E'
                                   b'\x89\xA9\x7E\xA2'
                                   b'\x0A\x9E\xEE\xE6'
                                   b'\x4B\x55\xD3\x9A'
                                   b'\x21\x92\x99\x2A'
                                   b'\x27\x4F\xC1\xA8'
                                   b'\x36\xBA\x3C\x23'
                                   b'\xA3\xFE\xEB\xBD'
                                   b'\x45\x4D\x44\x23'
                                   b'\x64\x3C\xE8\x0E'
                                   b'\x2A\x9A\xC9\x4F'
                                   b'\xA5\x4C\xA4\x9F'))

class TestBytesToNumber(unittest.TestCase):
    @given(integers(min_value=0, max_value=0xff))
    @example(0)
    @example(0xff)
    def test_small_numbers(self, number):
        self.assertEqual(bytesToNumber(bytearray(struct.pack(">B", number))),
                         number)

    @given(integers(min_value=0, max_value=0xffffffff))
    @example(0xffffffff)
    def test_multi_byte_numbers(self, number):
        self.assertEqual(bytesToNumber(bytearray(struct.pack(">I", number))),
                         number)

    def test_very_long_numbers(self):
        self.assertEqual(bytesToNumber(bytearray(b'\x00' * 16 + b'\x80')),
                         0x80)
        self.assertEqual(bytesToNumber(bytearray(b'\x80' + b'\x00' * 16)),
                         1<<(8 * 16 + 7))
        self.assertEqual(bytesToNumber(bytearray(b'\xff'*16)),
                         (1<<(8*16))-1)

    @given(integers(min_value=0, max_value=0xff))
    @example(0)
    @example(0xff)
    def test_small_numbers_little_endian(self, number):
        self.assertEqual(bytesToNumber(bytearray(struct.pack("<B", number)),
                                       "little"),
                         number)

    @given(integers(min_value=0, max_value=0xffffffff))
    @example(0xffffffff)
    def test_multi_byte_numbers_little_endian(self, number):
        self.assertEqual(bytesToNumber(bytearray(struct.pack("<I", number)),
                                       "little"),
                         number)

    def test_very_long_numbers_little_endian(self):
        self.assertEqual(bytesToNumber(bytearray(b'\x80' + b'\x00' * 16),
                                       "little"),
                         0x80)
        self.assertEqual(bytesToNumber(bytearray(b'\x00'*16 + b'\x80'),
                                       "little"),
                         1<<(8 * 16 + 7))
        self.assertEqual(bytesToNumber(bytearray(b'\xff'*16),
                                       "little"),
                         (1<<(8*16))-1)

    def test_with_unknown_type(self):
        with self.assertRaises(ValueError):
            bytesToNumber(bytearray(b'\xf0'), "middle")

    def test_with_empty_string(self):
        self.assertEqual(0, bytesToNumber(b''))

    def test_with_empty_string_little_endian(self):
        self.assertEqual(0, bytesToNumber(b'', "little"))


class TestHKDF_expand_label(unittest.TestCase):
    def test_with_sha256(self):
        secret = bytearray(32)
        label = bytearray(b'test')
        hash_value = bytearray(b'01' * 32)
        length = 32

        self.assertEqual(HKDF_expand_label(secret, label, hash_value, length,
                                           "sha256"),
                         bytearray(b"r\x91M\x13~\xd1\xa7\xf0\xa3\xa3\x0f\xce#"
                                   b" \xa9\xe4\xdd\xeb\x05\x07\x80\xee\x10\x93"
                                   b"\x7f\xc4\x18\x02\xb9\x00\'6"))

    def test_with_sha384(self):
        secret = bytearray(48)
        label = bytearray(b'test')
        hash_value = bytearray(b'01' * 48)
        length = 48

        self.assertEqual(HKDF_expand_label(secret, label, hash_value, length,
                                           "sha384"),
                         bytearray(b'\xb3\rFt\x10\xd96b\xb3\x80pm3g\xc06\xc3'
                                   b'\xa1/8\t\r\x86\xa4\xd4pFaJ\xce\xb9\xf6Nb'
                                   b'\xf76\x12p\x1dQ\xe5\xd9\xfc\n\x16\xc8\x07'
                                   b'\xb8'))

class TestDerive_secret(unittest.TestCase):
    def test_with_no_hashes(self):
        secret = bytearray(32)
        label = bytearray(b'exporter')
        handshake_hashes = None
        algorithm = "sha256"

        self.assertEqual(derive_secret(secret, label, handshake_hashes,
                                       algorithm),
                         bytearray(b'(\xef{\xee\xad\xde\x0b)9\xec\xb6\x89\xf5'
                                   b'\x83\xa2\xc5\xf2_\xf4R\x9e\xe8\xf4N\xef'
                                   b'\xbf\x06g\x95\xd0\x892'))

    def test_with_handshake_hashes(self):
        secret = bytearray(32)
        label = bytearray(b'exporter')
        handshake_hashes = HandshakeHashes()
        handshake_hashes.update(bytearray(8))
        algorithm = "sha256"

        self.assertEqual(derive_secret(secret, label, handshake_hashes,
                                       algorithm),
                         bytearray(b'\t\xec\x01W[Y\xdcP\xac\xebu\x13\xe6\x98'
                                   b'\x19\xccu;\xfa\x90\xc9\xe3\xc1\xe7\xb7'
                                   b'\xcf\x0c\x97;x\xf0F'))


class TestMPI(unittest.TestCase):
    def test_toMPI(self):
        r = numberToMPI(200)
        self.assertEqual(bytearray(b'\x00\x00\x00\x02\x00\xc8'), r)

    def test_fromMPI(self):
        r = mpiToNumber(bytearray(b'\x00\x00\x00\x02\x00\xc8'))
        self.assertEqual(r, 200)

    def test_fromMPI_with_negative_number(self):
        with self.assertRaises(ValueError):
            mpiToNumber(bytearray(b'\x00\x00\x00\x01\xc8'))


class TestPrimeGeneration(unittest.TestCase):
    def test_getRangomPrime(self):
        r = getRandomPrime(20)
        self.assertEqual(numBits(r), 20)
        self.assertTrue(isPrime(r))

    def test_getRandomSafePrime(self):
        r = getRandomSafePrime(20)
        self.assertEqual(numBits(r), 20)
        self.assertTrue(isPrime(r))
        self.assertTrue(isPrime((r-1)//2))

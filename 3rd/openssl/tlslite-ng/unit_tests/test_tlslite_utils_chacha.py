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

from tlslite.utils.chacha import ChaCha
from tlslite.utils.cryptomath import bytesToNumber

class TestChaCha(unittest.TestCase):
    def betole32(self, data):
        return ((data & 0xff000000) >> 24) | \
               ((data & 0x00ff0000) >> 8) | \
               ((data & 0x0000ff00) << 8) | \
               ((data & 0x000000ff) << 24)

    def test___init__(self):
        chacha = ChaCha(key=bytearray(256//8), nonce=bytearray(96//8))
        self.assertIsNotNone(chacha)

    def test___init___with_wrong_key_size(self):
        with self.assertRaises(ValueError):
            ChaCha(key=bytearray(16), nonce=bytearray(96//8))

    def test___init___with_wrong_nonce_size(self):
        with self.assertRaises(ValueError):
            ChaCha(key=bytearray(32), nonce=bytearray(16))

    def test_quarter_round(self):
        #RFC 7539 in text test vector
        x = [0x11111111, 0x01020304, 0x9b8d6f43, 0x01234567]

        ChaCha.quarter_round(x, 0, 1, 2, 3)

        self.assertEqual(x,
                         [0xea2a92f4, 0xcb1cf8ce, 0x4581472e, 0x5881c4bb])

    def test_quarter_round_on_state(self):
        #RFC 7539 in text test vector
        x = [0x879531e0,  0xc5ecf37d,  0x516461b1,  0xc9a62f8a,
             0x44c20ef3,  0x3390af7f,  0xd9fc690b,  0x2a5f714c,
             0x53372767,  0xb00a5631,  0x974c541a,  0x359e9963,
             0x5c971061,  0x3d631689,  0x2098d9d6,  0x91dbd320]

        ChaCha.quarter_round(x, 2, 7, 8, 13)

        self.assertEqual(x,
                         [0x879531e0,  0xc5ecf37d,  0xbdb886dc,  0xc9a62f8a,
                          0x44c20ef3,  0x3390af7f,  0xd9fc690b,  0xcfacafd2,
                          0xe46bea80,  0xb00a5631,  0x974c541a,  0x359e9963,
                          0x5c971061,  0xccc07c79,  0x2098d9d6,  0x91dbd320])

    def test_betole32(self):
        number = self.betole32(bytesToNumber(bytearray(b'\x00\x01\x02\x03')))

        self.assertEqual(number, 0x03020100)

    def test_chacha_block(self):
        # RFC 7539 in text test vector
        key = [0x00010203, 0x04050607, 0x08090a0b, 0x0c0d0e0f,
               0x10111213, 0x14151617, 0x18191a1b, 0x1c1d1e1f]
        for i, item in enumerate(key):
            key[i] = self.betole32(item)
        nonce = [0x00000009, 0x0000004a, 0x00000000]
        for i, item in enumerate(nonce):
            nonce[i] = self.betole32(item)
        counter = 1

        x = ChaCha.chacha_block(key, counter, nonce, rounds=20)

        self.assertEqual(x,
                         [0xe4e7f110,  0x15593bd1,  0x1fdd0f50,  0xc47120a3,
                          0xc7f4d1c7,  0x0368c033,  0x9aaa2204,  0x4e6cd4c3,
                          0x466482d2,  0x09aa9f07,  0x05d7c214,  0xa2028bd9,
                          0xd19c12b5,  0xb94e16de,  0xe883d0cb,  0x4e3c50a2])

        self.assertEqual(ChaCha.word_to_bytearray(x), bytearray(
            b'\x10\xf1\xe7\xe4\xd1\x3b\x59\x15\x50\x0f\xdd\x1f\xa3\x20\x71\xc4'
            b'\xc7\xd1\xf4\xc7\x33\xc0\x68\x03\x04\x22\xaa\x9a\xc3\xd4\x6c\x4e'
            b'\xd2\x82\x64\x46\x07\x9f\xaa\x09\x14\xc2\xd7\x05\xd9\x8b\x02\xa2'
            b'\xb5\x12\x9c\xd1\xde\x16\x4e\xb9\xcb\xd0\x83\xe8\xa2\x50\x3c\x4e'
            ))

    def test_chacha_encrypt(self):
        # RFC 7539 in text test vector
        key = bytearray(range(0x00, 0x20))
        nonce = bytearray(b'\x00'*7 + b'\x4a' + b'\x00'*4)
        chacha = ChaCha(key, nonce)
        self.assertIsNotNone(chacha)
        chacha.counter = 1

        plaintext = bytearray(b'Ladies and Gentlemen of the class of \'99: '
                              b'If I could offer you only one tip for the '
                              b'future, sunscreen would be it.')

        self.assertEqual(len(plaintext), 64+50)

        #import pdb; pdb.set_trace()
        ciphertext = chacha.encrypt(plaintext)

        self.assertEqual(ciphertext, bytearray(
            b'\x6e\x2e\x35\x9a\x25\x68\xf9\x80\x41\xba\x07\x28\xdd\x0d\x69\x81'
            b'\xe9\x7e\x7a\xec\x1d\x43\x60\xc2\x0a\x27\xaf\xcc\xfd\x9f\xae\x0b'
            b'\xf9\x1b\x65\xc5\x52\x47\x33\xab\x8f\x59\x3d\xab\xcd\x62\xb3\x57'
            b'\x16\x39\xd6\x24\xe6\x51\x52\xab\x8f\x53\x0c\x35\x9f\x08\x61\xd8'
            b'\x07\xca\x0d\xbf\x50\x0d\x6a\x61\x56\xa3\x8e\x08\x8a\x22\xb6\x5e'
            b'\x52\xbc\x51\x4d\x16\xcc\xf8\x06\x81\x8c\xe9\x1a\xb7\x79\x37\x36'
            b'\x5a\xf9\x0b\xbf\x74\xa3\x5b\xe6\xb4\x0b\x8e\xed\xf2\x78\x5e\x42'
            b'\x87\x4d'
            ))

        crib = chacha.decrypt(ciphertext)

        self.assertEqual(crib, plaintext)

    def test_chacha_block_vector1(self):
        # RFC 7539 Appendix A.1 test vector #1
        key = [0]*8
        nonce = [0]*3
        counter = 0

        x = ChaCha.chacha_block(key, counter, nonce, rounds=20)

        self.assertEqual(x,
                         [0xade0b876,  0x903df1a0,  0xe56a5d40,  0x28bd8653,
                          0xb819d2bd,  0x1aed8da0,  0xccef36a8,  0xc70d778b,
                          0x7c5941da,  0x8d485751,  0x3fe02477,  0x374ad8b8,
                          0xf4b8436a,  0x1ca11815,  0x69b687c3,  0x8665eeb2])

        ciphertext = ChaCha.word_to_bytearray(x)

        self.assertEqual(ciphertext, bytearray(
            b'\x76\xb8\xe0\xad\xa0\xf1\x3d\x90\x40\x5d\x6a\xe5\x53\x86\xbd\x28'
            b'\xbd\xd2\x19\xb8\xa0\x8d\xed\x1a\xa8\x36\xef\xcc\x8b\x77\x0d\xc7'
            b'\xda\x41\x59\x7c\x51\x57\x48\x8d\x77\x24\xe0\x3f\xb8\xd8\x4a\x37'
            b'\x6a\x43\xb8\xf4\x15\x18\xa1\x1c\xc3\x87\xb6\x69\xb2\xee\x65\x86'
            ))

    def test_chacha_block_vector2(self):
        # RFC 7539 Appendix A.1 test vector #2
        key = [0]*8
        nonce = [0]*3
        counter = 1

        x = ChaCha.chacha_block(key, counter, nonce, rounds=20)

        self.assertEqual(x,
                         [0xbee7079f,  0x7a385155,  0x7c97ba98,  0x0d082d73,
                          0xa0290fcb,  0x6965e348,  0x3e53c612,  0xed7aee32,
                          0x7621b729,  0x434ee69c,  0xb03371d5,  0xd539d874,
                          0x281fed31,  0x45fb0a51,  0x1f0ae1ac,  0x6f4d794b])

        ciphertext = ChaCha.word_to_bytearray(x)

        self.assertEqual(ciphertext, bytearray(
            b'\x9f\x07\xe7\xbe\x55\x51\x38\x7a\x98\xba\x97\x7c\x73\x2d\x08\x0d'
            b'\xcb\x0f\x29\xa0\x48\xe3\x65\x69\x12\xc6\x53\x3e\x32\xee\x7a\xed'
            b'\x29\xb7\x21\x76\x9c\xe6\x4e\x43\xd5\x71\x33\xb0\x74\xd8\x39\xd5'
            b'\x31\xed\x1f\x28\x51\x0a\xfb\x45\xac\xe1\x0a\x1f\x4b\x79\x4d\x6f'
            ))

    def test_chacha_block_vector3(self):
        # RFC 7539 Appendix A.1 test vector #3
        key = bytearray(b'\x00'*31 + b'\x01')
        nonce = bytearray(12)
        counter = 1

        chacha = ChaCha(key, nonce, counter=counter)

        x = ChaCha.chacha_block(chacha.key,
                                chacha.counter,
                                chacha.nonce,
                                rounds=20)

        self.assertEqual(x,
                         [0x2452eb3a,  0x9249f8ec,  0x8d829d9b,  0xddd4ceb1,
                          0xe8252083,  0x60818b01,  0xf38422b8,  0x5aaa49c9,
                          0xbb00ca8e,  0xda3ba7b4,  0xc4b592d1,  0xfdf2732f,
                          0x4436274e,  0x2561b3c8,  0xebdd4aa6,  0xa0136c00])

        ciphertext = ChaCha.word_to_bytearray(x)

        self.assertEqual(ciphertext, bytearray(
            b'\x3a\xeb\x52\x24\xec\xf8\x49\x92\x9b\x9d\x82\x8d\xb1\xce\xd4\xdd'
            b'\x83\x20\x25\xe8\x01\x8b\x81\x60\xb8\x22\x84\xf3\xc9\x49\xaa\x5a'
            b'\x8e\xca\x00\xbb\xb4\xa7\x3b\xda\xd1\x92\xb5\xc4\x2f\x73\xf2\xfd'
            b'\x4e\x27\x36\x44\xc8\xb3\x61\x25\xa6\x4a\xdd\xeb\x00\x6c\x13\xa0'
            ))

    def test_chacha_block_vector4(self):
        # RFC 7539 Appendix A.1 test vector #4
        key = bytearray(b'\x00' + b'\xff' + b'\x00'*30)
        nonce = bytearray(12)
        counter = 2

        chacha = ChaCha(key, nonce, counter=counter)

        x = ChaCha.chacha_block(chacha.key,
                                chacha.counter,
                                chacha.nonce,
                                rounds=20)

        self.assertEqual(x,
                         [0xfb4dd572,  0x4bc42ef1,  0xdf922636,  0x327f1394,
                          0xa78dea8f,  0x5e269039,  0xa1bebbc1,  0xcaf09aae,
                          0xa25ab213,  0x48a6b46c,  0x1b9d9bcb,  0x092c5be6,
                          0x546ca624,  0x1bec45d5,  0x87f47473,  0x96f0992e])

        ciphertext = ChaCha.word_to_bytearray(x)

        self.assertEqual(ciphertext, bytearray(
            b'\x72\xd5\x4d\xfb\xf1\x2e\xc4\x4b\x36\x26\x92\xdf\x94\x13\x7f\x32'
            b'\x8f\xea\x8d\xa7\x39\x90\x26\x5e\xc1\xbb\xbe\xa1\xae\x9a\xf0\xca'
            b'\x13\xb2\x5a\xa2\x6c\xb4\xa6\x48\xcb\x9b\x9d\x1b\xe6\x5b\x2c\x09'
            b'\x24\xa6\x6c\x54\xd5\x45\xec\x1b\x73\x74\xf4\x87\x2e\x99\xf0\x96'
            ))

    def test_chacha_block_vector5(self):
        # RFC 7539 Appendix A.1 test vector #5
        key = bytearray(32)
        nonce = bytearray(b'\x00'*11 + b'\x02')
        counter = 0

        chacha = ChaCha(key, nonce, counter=counter)

        x = ChaCha.chacha_block(chacha.key,
                                chacha.counter,
                                chacha.nonce,
                                rounds=20)

        self.assertEqual(x,
                         [0x374dc6c2,  0x3736d58c,  0xb904e24a,  0xcd3f93ef,
                          0x88228b1a,  0x96a4dfb3,  0x5b76ab72,  0xc727ee54,
                          0x0e0e978a,  0xf3145c95,  0x1b748ea8,  0xf786c297,
                          0x99c28f5f,  0x628314e8,  0x398a19fa,  0x6ded1b53])

        ciphertext = ChaCha.word_to_bytearray(x)

        self.assertEqual(ciphertext, bytearray(
            b'\xc2\xc6\x4d\x37\x8c\xd5\x36\x37\x4a\xe2\x04\xb9\xef\x93\x3f\xcd'
            b'\x1a\x8b\x22\x88\xb3\xdf\xa4\x96\x72\xab\x76\x5b\x54\xee\x27\xc7'
            b'\x8a\x97\x0e\x0e\x95\x5c\x14\xf3\xa8\x8e\x74\x1b\x97\xc2\x86\xf7'
            b'\x5f\x8f\xc2\x99\xe8\x14\x83\x62\xfa\x19\x8a\x39\x53\x1b\xed\x6d'
            ))

    def test_chacha_encryption_vector1(self):
        # RFC 7539 Appendix A.2 test vector #1
        key = bytearray(32)
        nonce = bytearray(12)
        counter = 0

        chacha = ChaCha(key, nonce, counter)

        ciphertext = chacha.encrypt(bytearray(64))

        self.assertEqual(ciphertext, bytearray(
            b'\x76\xb8\xe0\xad\xa0\xf1\x3d\x90\x40\x5d\x6a\xe5\x53\x86\xbd\x28'
            b'\xbd\xd2\x19\xb8\xa0\x8d\xed\x1a\xa8\x36\xef\xcc\x8b\x77\x0d\xc7'
            b'\xda\x41\x59\x7c\x51\x57\x48\x8d\x77\x24\xe0\x3f\xb8\xd8\x4a\x37'
            b'\x6a\x43\xb8\xf4\x15\x18\xa1\x1c\xc3\x87\xb6\x69\xb2\xee\x65\x86'
            ))

    def test_chacha_encryption_vector2(self):
        # RFC 7539 Appendix A.2 test vector #2
        key = bytearray(31) + bytearray(b'\x01')
        nonce = bytearray(11) + bytearray(b'\x02')
        counter = 1

        chacha = ChaCha(key, nonce, counter)

        plaintext = bytearray(b'Any submission to the IETF intended by the '
                              b'Contributor for publication as all or part of '
                              b'an IETF Internet-Draft or RFC and any statement'
                              b' made within the context of an IETF activity is'
                              b' considered an "IETF Contribution". Such '
                              b'statements include oral statements in IETF '
                              b'sessions, as well as written and electronic '
                              b'communications made at any time or place, which'
                              b' are addressed to')

        ciphertext = chacha.encrypt(plaintext)

        self.assertEqual(ciphertext, bytearray(
            b'\xa3\xfb\xf0\x7d\xf3\xfa\x2f\xde\x4f\x37\x6c\xa2\x3e\x82\x73\x70'
            b'\x41\x60\x5d\x9f\x4f\x4f\x57\xbd\x8c\xff\x2c\x1d\x4b\x79\x55\xec'
            b'\x2a\x97\x94\x8b\xd3\x72\x29\x15\xc8\xf3\xd3\x37\xf7\xd3\x70\x05'
            b'\x0e\x9e\x96\xd6\x47\xb7\xc3\x9f\x56\xe0\x31\xca\x5e\xb6\x25\x0d'
            b'\x40\x42\xe0\x27\x85\xec\xec\xfa\x4b\x4b\xb5\xe8\xea\xd0\x44\x0e'
            b'\x20\xb6\xe8\xdb\x09\xd8\x81\xa7\xc6\x13\x2f\x42\x0e\x52\x79\x50'
            b'\x42\xbd\xfa\x77\x73\xd8\xa9\x05\x14\x47\xb3\x29\x1c\xe1\x41\x1c'
            b'\x68\x04\x65\x55\x2a\xa6\xc4\x05\xb7\x76\x4d\x5e\x87\xbe\xa8\x5a'
            b'\xd0\x0f\x84\x49\xed\x8f\x72\xd0\xd6\x62\xab\x05\x26\x91\xca\x66'
            b'\x42\x4b\xc8\x6d\x2d\xf8\x0e\xa4\x1f\x43\xab\xf9\x37\xd3\x25\x9d'
            b'\xc4\xb2\xd0\xdf\xb4\x8a\x6c\x91\x39\xdd\xd7\xf7\x69\x66\xe9\x28'
            b'\xe6\x35\x55\x3b\xa7\x6c\x5c\x87\x9d\x7b\x35\xd4\x9e\xb2\xe6\x2b'
            b'\x08\x71\xcd\xac\x63\x89\x39\xe2\x5e\x8a\x1e\x0e\xf9\xd5\x28\x0f'
            b'\xa8\xca\x32\x8b\x35\x1c\x3c\x76\x59\x89\xcb\xcf\x3d\xaa\x8b\x6c'
            b'\xcc\x3a\xaf\x9f\x39\x79\xc9\x2b\x37\x20\xfc\x88\xdc\x95\xed\x84'
            b'\xa1\xbe\x05\x9c\x64\x99\xb9\xfd\xa2\x36\xe7\xe8\x18\xb0\x4b\x0b'
            b'\xc3\x9c\x1e\x87\x6b\x19\x3b\xfe\x55\x69\x75\x3f\x88\x12\x8c\xc0'
            b'\x8a\xaa\x9b\x63\xd1\xa1\x6f\x80\xef\x25\x54\xd7\x18\x9c\x41\x1f'
            b'\x58\x69\xca\x52\xc5\xb8\x3f\xa3\x6f\xf2\x16\xb9\xc1\xd3\x00\x62'
            b'\xbe\xbc\xfd\x2d\xc5\xbc\xe0\x91\x19\x34\xfd\xa7\x9a\x86\xf6\xe6'
            b'\x98\xce\xd7\x59\xc3\xff\x9b\x64\x77\x33\x8f\x3d\xa4\xf9\xcd\x85'
            b'\x14\xea\x99\x82\xcc\xaf\xb3\x41\xb2\x38\x4d\xd9\x02\xf3\xd1\xab'
            b'\x7a\xc6\x1d\xd2\x9c\x6f\x21\xba\x5b\x86\x2f\x37\x30\xe3\x7c\xfd'
            b'\xc4\xfd\x80\x6c\x22\xf2\x21'
            ))

    def test_chacha_encryption_vector3(self):
        # RFC 7539 Appendix A.2 test vector #3
        key = bytearray(
            b'\x1c\x92\x40\xa5\xeb\x55\xd3\x8a\xf3\x33\x88\x86\x04\xf6\xb5\xf0'
            b'\x47\x39\x17\xc1\x40\x2b\x80\x09\x9d\xca\x5c\xbc\x20\x70\x75\xc0'
            )
        nonce = bytearray(11) + bytearray(b'\x02')
        counter = 42

        chacha = ChaCha(key, nonce, counter)

        plaintext = bytearray(
            b'\x27\x54\x77\x61\x73\x20\x62\x72\x69\x6c\x6c\x69\x67\x2c\x20\x61'
            b'\x6e\x64\x20\x74\x68\x65\x20\x73\x6c\x69\x74\x68\x79\x20\x74\x6f'
            b'\x76\x65\x73\x0a\x44\x69\x64\x20\x67\x79\x72\x65\x20\x61\x6e\x64'
            b'\x20\x67\x69\x6d\x62\x6c\x65\x20\x69\x6e\x20\x74\x68\x65\x20\x77'
            b'\x61\x62\x65\x3a\x0a\x41\x6c\x6c\x20\x6d\x69\x6d\x73\x79\x20\x77'
            b'\x65\x72\x65\x20\x74\x68\x65\x20\x62\x6f\x72\x6f\x67\x6f\x76\x65'
            b'\x73\x2c\x0a\x41\x6e\x64\x20\x74\x68\x65\x20\x6d\x6f\x6d\x65\x20'
            b'\x72\x61\x74\x68\x73\x20\x6f\x75\x74\x67\x72\x61\x62\x65\x2e'
            )

        ciphertext = chacha.encrypt(plaintext)

        self.assertEqual(ciphertext, bytearray(
            b'\x62\xe6\x34\x7f\x95\xed\x87\xa4\x5f\xfa\xe7\x42\x6f\x27\xa1\xdf'
            b'\x5f\xb6\x91\x10\x04\x4c\x0d\x73\x11\x8e\xff\xa9\x5b\x01\xe5\xcf'
            b'\x16\x6d\x3d\xf2\xd7\x21\xca\xf9\xb2\x1e\x5f\xb1\x4c\x61\x68\x71'
            b'\xfd\x84\xc5\x4f\x9d\x65\xb2\x83\x19\x6c\x7f\xe4\xf6\x05\x53\xeb'
            b'\xf3\x9c\x64\x02\xc4\x22\x34\xe3\x2a\x35\x6b\x3e\x76\x43\x12\xa6'
            b'\x1a\x55\x32\x05\x57\x16\xea\xd6\x96\x25\x68\xf8\x7d\x3f\x3f\x77'
            b'\x04\xc6\xa8\xd1\xbc\xd1\xbf\x4d\x50\xd6\x15\x4b\x6d\xa7\x31\xb1'
            b'\x87\xb5\x8d\xfd\x72\x8a\xfa\x36\x75\x7a\x79\x7a\xc1\x88\xd1'
            ))
